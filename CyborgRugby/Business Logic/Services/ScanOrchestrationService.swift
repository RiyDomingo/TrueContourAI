//
//  ScanOrchestrationService.swift
//  CyborgRugby
//
//  Orchestrates the complete multi-angle scanning workflow
//

import Foundation
import StandardCyborgFusion
import Metal
import AVFoundation
import OSLog

@MainActor
protocol ScanOrchestrationServiceDelegate: AnyObject {
    func scanOrchestrator(_ orchestrator: ScanOrchestrationService, didStartPose pose: HeadScanningPose)
    func scanOrchestrator(_ orchestrator: ScanOrchestrationService, didCompletePose pose: HeadScanningPose, withResult result: ScanResult)
    func scanOrchestrator(_ orchestrator: ScanOrchestrationService, didFailPose pose: HeadScanningPose, withError error: Error)
    func scanOrchestrator(_ orchestrator: ScanOrchestrationService, didUpdateProgress progress: Float)
    func scanOrchestrator(_ orchestrator: ScanOrchestrationService, didFinishAllScans finalResult: CompleteScanResult)
    func scanOrchestrator(_ orchestrator: ScanOrchestrationService, poseValidationUpdate result: PoseValidationResult, for pose: HeadScanningPose)
}

@MainActor
class ScanOrchestrationService: ObservableObject {
    
    // MARK: - Properties
    
    weak var delegate: ScanOrchestrationServiceDelegate?
    
    // Services
    let scanProgressService: ScanProgressService
    private let reconstructionService: ReconstructionService
    private let measurementService: MeasurementGenerationService
    private let poseDetectionService: PoseDetectionService
    
    // State
    @Published private(set) var isActive = false
    @Published private(set) var currentPhase: ScanPhase = .idle
    
    private var currentPixelBuffer: CVPixelBuffer?
    private var frameProcessingTimer: Timer?
    
    // MARK: - Initialization
    
    init(metalDevice: MTLDevice) {
        self.scanProgressService = ScanProgressService()
        self.reconstructionService = ReconstructionService(metalDevice: metalDevice)
        self.measurementService = MeasurementGenerationService()
        self.poseDetectionService = PoseDetectionService()
        
        setupServiceDelegates()
    }
    
    deinit {
        // Only cleanup non-MainActor resources in deinit
        frameProcessingTimer?.invalidate()
        frameProcessingTimer = nil
    }
    
    // MARK: - Public Methods
    
    func startMultiAngleScan() {
        guard !isActive else {
            AppLog.scan.warning("Attempted to start scan while already active")
            return
        }
        
        isActive = true
        currentPhase = .scanning
        
        // Start services
        scanProgressService.startScanSequence()
        poseDetectionService.startMotionTracking()
        
        // Start frame processing timer
        startFrameProcessing()
        
        AppLog.scan.info("Started multi-angle scan orchestration")
    }
    
    func stopScanning() {
        guard isActive else { return }
        
        isActive = false
        currentPhase = .idle
        
        // Stop all services
        scanProgressService.stopScanSequence()
        reconstructionService.stopRecording()
        poseDetectionService.stopMotionTracking()
        
        // Stop timers
        frameProcessingTimer?.invalidate()
        frameProcessingTimer = nil
        
        AppLog.scan.info("Stopped scan orchestration")
    }
    
    func skipCurrentPose(reason: String = "User skipped") {
        scanProgressService.skipCurrentPose(reason: reason)
    }
    
    func retryCurrentPose() {
        reconstructionService.resetReconstruction()
        scanProgressService.retryCurrentPose()
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        currentPixelBuffer = pixelBuffer
        
        // Update current pose in pose detection service
        if let currentPose = scanProgressService.currentPose {
            poseDetectionService.updateCurrentPose(currentPose)
            poseDetectionService.processFrame(pixelBuffer)
        }
    }
    
    func processDepthFrame(_ depthData: AVDepthData, colorBuffer: CVPixelBuffer? = nil) {
        if reconstructionService.isRecording {
            reconstructionService.processDepthFrame(depthData, colorBuffer: colorBuffer)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupServiceDelegates() {
        scanProgressService.delegate = self
        reconstructionService.delegate = self
        measurementService.delegate = self
        poseDetectionService.delegate = self
    }
    
    private func startFrameProcessing() {
        frameProcessingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processCurrentFrame()
            }
        }
    }
    
    private func processCurrentFrame() {
        guard let pixelBuffer = currentPixelBuffer else { return }
        
        // Continue processing the current frame if available
        processFrame(pixelBuffer)
    }
    
    private func startPoseCapture() {
        currentPhase = .capturing
        reconstructionService.startRecording()
        AppLog.scan.info("Started pose capture and reconstruction")
    }
    
    private func completePoseCapture() {
        currentPhase = .processing
        
        reconstructionService.finalizeReconstruction()
        AppLog.scan.info("Finalizing pose capture")
    }
    
    private func processFinalResults(_ scanResults: [HeadScanningPose: ScanResult]) {
        currentPhase = .generatingMeasurements
        
        // Generate measurements from scan results
        measurementService.generateMeasurements(from: scanResults)
    }
}

// MARK: - ScanProgressServiceDelegate

extension ScanOrchestrationService: ScanProgressServiceDelegate {
    
    func scanProgressService(_ service: ScanProgressService, didStartPose pose: HeadScanningPose) {
        currentPhase = .waitingForValidPose
        delegate?.scanOrchestrator(self, didStartPose: pose)
        AppLog.scan.info("Started pose: \(pose.displayName)")
    }
    
    func scanProgressService(_ service: ScanProgressService, didCompletePose pose: HeadScanningPose, withResult result: ScanResult) {
        delegate?.scanOrchestrator(self, didCompletePose: pose, withResult: result)
        AppLog.scan.info("Completed pose: \(pose.displayName)")
    }
    
    func scanProgressService(_ service: ScanProgressService, didFailPose pose: HeadScanningPose, withError error: Error) {
        delegate?.scanOrchestrator(self, didFailPose: pose, withError: error)
        AppLog.scan.error("Failed pose: \(pose.displayName) - \(error.localizedDescription)")
    }
    
    func scanProgressService(_ service: ScanProgressService, didUpdateProgress progress: Float) {
        delegate?.scanOrchestrator(self, didUpdateProgress: progress)
    }
    
    func scanProgressService(_ service: ScanProgressService, didCompleteAllScans results: [HeadScanningPose: ScanResult]) {
        currentPhase = .generatingMeasurements
        processFinalResults(results)
    }
}

// MARK: - ReconstructionServiceDelegate

extension ScanOrchestrationService: ReconstructionServiceDelegate {
    
    func reconstructionService(_ service: ReconstructionService, didProcessFrame metadata: SCAssimilatedFrameMetadata, statistics: SCReconstructionManagerStatistics) {
        // Frame processed - continue capture
        AppLog.scan.debug("Processed reconstruction frame - succeeded: \(statistics.succeededCount), lost: \(statistics.lostTrackingCount)")
    }
    
    func reconstructionService(_ service: ReconstructionService, didCompleteReconstruction pointCloud: SCPointCloud?, mesh: SCMesh?) {
        // Update current scan result with point cloud
        guard let currentPose = scanProgressService.currentPose else { return }
        
        let scanResult = ScanResult(
            pose: currentPose,
            pointCloud: pointCloud,
            confidence: 0.85, // Could be derived from reconstruction quality
            status: .completed,
            timestamp: Date(),
            metadata: [:],
            earMetrics: nil
        )
        
        scanProgressService.completePose(with: scanResult)
    }
    
    func reconstructionService(_ service: ReconstructionService, didFailWithError error: Error) {
        scanProgressService.failCurrentPose(with: error)
    }
    
    func reconstructionService(_ service: ReconstructionService, didUpdateProgress progress: Float) {
        // Could update detailed progress if needed
    }
}

// MARK: - MeasurementGenerationServiceDelegate

extension ScanOrchestrationService: MeasurementGenerationServiceDelegate {
    
    func measurementService(_ service: MeasurementGenerationService, didGenerateMeasurements measurements: ScrumCapMeasurements) {
        currentPhase = .completed
        
        // Create final complete scan result
        let completeScanResult = CompleteScanResult(
            individualScans: scanProgressService.scanResults,
            overallQuality: scanProgressService.calculateOverallQuality(),
            timestamp: Date(),
            totalScanTime: scanProgressService.calculateTotalScanTime(),
            successfulPoses: scanProgressService.getSuccessfulPoses(),
            rugbyFitnessMeasurements: measurements
        )
        
        isActive = false
        delegate?.scanOrchestrator(self, didFinishAllScans: completeScanResult)
        AppLog.scan.info("Completed multi-angle scan with measurements")
    }
    
    func measurementService(_ service: MeasurementGenerationService, didFailWithError error: Error) {
        AppLog.scan.error("Measurement generation failed: \(error.localizedDescription)")
        
        // Still complete scan but with basic measurements
        let basicMeasurements = createBasicMeasurements()
        measurementService(service, didGenerateMeasurements: basicMeasurements)
    }
    
    func measurementService(_ service: MeasurementGenerationService, didUpdateProgress progress: Float) {
        // Could update UI with measurement generation progress
    }
    
    private func createBasicMeasurements() -> ScrumCapMeasurements {
        // Create basic measurements as fallback
        
        return ScrumCapMeasurements(
            headCircumference: ValidatedMeasurement(
                value: 56.0,
                confidence: 0.5,
                validationStatus: .estimated,
                alternativeValues: [],
                measurementSource: .statisticalEstimation(basedOn: ["fallback"])
            ),
            earToEarOverTop: ValidatedMeasurement(
                value: 38.0,
                confidence: 0.5,
                validationStatus: .estimated,
                alternativeValues: [],
                measurementSource: .statisticalEstimation(basedOn: ["fallback"])
            ),
            foreheadToNeckBase: ValidatedMeasurement(
                value: 34.0,
                confidence: 0.5,
                validationStatus: .estimated,
                alternativeValues: [],
                measurementSource: .statisticalEstimation(basedOn: ["fallback"])
            ),
            leftEarDimensions: createBasicEarDimensions(),
            rightEarDimensions: createBasicEarDimensions(),
            earAsymmetryFactor: 0.1,
            occipitalProminence: ValidatedMeasurement(value: 12.0, confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["fallback"])),
            neckCurveRadius: ValidatedMeasurement(value: 8.5, confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["fallback"])),
            backHeadWidth: ValidatedMeasurement(value: 15.0, confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["fallback"])),
            jawLineToEar: ValidatedMeasurement(value: 10.0, confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["fallback"])),
            chinToEarDistance: ValidatedMeasurement(value: 11.0, confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["fallback"]))
        )
    }
    
    private func createBasicEarDimensions() -> ValidatedEarDimensions {
        return ValidatedEarDimensions(
            height: ValidatedMeasurement(value: 60.0, confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["fallback"])),
            width: ValidatedMeasurement(value: 30.0, confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["fallback"])),
            protrusionAngle: ValidatedMeasurement(value: 40.0, confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["fallback"])),
            topToLobe: ValidatedMeasurement(value: 55.0, confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["fallback"]))
        )
    }
}

// MARK: - PoseDetectionServiceDelegate

extension ScanOrchestrationService: PoseDetectionServiceDelegate {
    
    func poseDetectionService(_ service: PoseDetectionService, didValidatePose pose: HeadScanningPose, isValid: Bool, confidence: Float) {
        // Forward pose validation to delegate
        let result = PoseValidationResult(
            isValid: isValid,
            confidence: confidence,
            feedback: isValid ? "Good pose detected" : "Adjust position",
            requiredAdjustments: []
        )
        
        delegate?.scanOrchestrator(self, poseValidationUpdate: result, for: pose)
    }
    
    func poseDetectionService(_ service: PoseDetectionService, didUpdateStability isStable: Bool) {
        if isStable && currentPhase == .waitingForValidPose {
            startPoseCapture()
        }
    }
    
    func poseDetectionService(_ service: PoseDetectionService, didDetectPerfectPose pose: HeadScanningPose) {
        // Perfect pose detected - ensure we're capturing
        if currentPhase == .waitingForValidPose {
            startPoseCapture()
            
            // Auto-complete pose after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.completePoseCapture()
            }
        }
    }
}

// MARK: - Supporting Types

enum ScanPhase {
    case idle
    case scanning
    case waitingForValidPose
    case capturing
    case processing
    case generatingMeasurements
    case completed
    
    var description: String {
        switch self {
        case .idle: return "Ready"
        case .scanning: return "Scanning"
        case .waitingForValidPose: return "Position head correctly"
        case .capturing: return "Capturing data"
        case .processing: return "Processing capture"
        case .generatingMeasurements: return "Calculating measurements"
        case .completed: return "Scan complete"
        }
    }
}