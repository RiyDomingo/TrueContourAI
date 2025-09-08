//
//  ScrumCapScanningViewController.swift
//  CyborgRugby
//
//  Main scanning controller for rugby scrum cap fitting with ML integration
//

import UIKit
import OSLog
import StandardCyborgFusion
import AVFoundation
import Metal
import CoreMotion
import CoreML
import Vision

class ScrumCapScanningViewController: UIViewController {
    
    // MARK: - Delegate
    weak var delegate: ScrumCapScanningViewControllerDelegate?
    
    // MARK: - UI Components (Programmatic)
    private var metalContainerView: UIView!
    private var poseInstructionLabel: UILabel!
    private var statusHintLabel: UILabel!
    private var poseProgressStack: UIStackView!
    private var poseProgressLabel: UILabel!
    private var poseProgressView: UIView!
    private var scanningButton: UIButton!
    private var skipPoseButton: UIButton!
    private var measurementDisplayView: UIView!
    
    // MARK: - Properties
    private let metalDevice = MTLCreateSystemDefaultDevice()!
    private lazy var algorithmCommandQueue = metalDevice.makeCommandQueue()!
    private lazy var visualizationCommandQueue = metalDevice.makeCommandQueue()!
    
    // StandardCyborg components
    private var reconstructionManager: SCReconstructionManager?
    private lazy var scanningViewRenderer = ScanningViewRenderer(
        device: metalDevice,
        commandQueue: visualizationCommandQueue
    )
    
    // CyborgRugby components
    private let multiAngleScanManager = MultiAngleScanManager()
    private let poseValidator = {
        let validator = MLEnhancedPoseValidator()
        validator.startInitialization()
        return validator
    }()
    private let rugbyEarAnalyzer = RugbyEarProtectionCalculator()
    private let cameraManager = CameraManager()
    private let motionManager = CMMotionManager()
    private var lastLeftProfilePixelBuffer: CVPixelBuffer?
    private var lastRightProfilePixelBuffer: CVPixelBuffer?
    
    // Scanning state
    private var currentPose: HeadScanningPose = .frontFacing
    private var completedPoses: Set<HeadScanningPose> = []
    private var poseData: [HeadScanningPose: CVPixelBuffer] = [:]
    private var isScanning = false
    private var scanningTimer: Timer?
    // Stability gating config + variables
    private var gatingConfig: ScanGatingConfig = .resolved()
    private var consecutiveValidCount: Int = 0
    private var startingSucceededCount: Int = 0
    private var assimilatedFramesForPose: Int = 0
    
    // UI state
    private let metalLayer = CAMetalLayer()
    private var latestViewMatrix = matrix_identity_float4x4
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMetalLayer()
        setupCyborgRugby()
        setupCameraManager()
        startFirstPose()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Check camera permission inside scanner
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraManager.startCapture()
            startMotionTracking()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.cameraManager.startCapture(); self.startMotionTracking() }
                    else { self.showCameraPermissionAlert() }
                }
            }
        default:
            showCameraPermissionAlert()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraManager.stopCapture()
        motionManager.stopDeviceMotionUpdates()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateMetalLayerFrame()
    }
    
    // MARK: - Setup Methods
    
    private func setupMetalLayer() {
        metalLayer.device = metalDevice
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.isOpaque = true
        metalLayer.contentsScale = UIScreen.main.scale
        metalContainerView.layer.addSublayer(metalLayer)
    }
    
    private func setupCyborgRugby() {
        // Configure reconstruction manager for rugby scanning
        reconstructionManager = SCReconstructionManager(
            device: metalDevice,
            commandQueue: algorithmCommandQueue,
            maxThreadCount: Int32(ProcessInfo.processInfo.activeProcessorCount)
        )
        reconstructionManager?.delegate = self
        
        // Configure multi-angle scan manager
        multiAngleScanManager.delegate = self
        
        // Pose validator loads ML models automatically in init
        
        // Set command queue labels for debugging
        algorithmCommandQueue.label = "CyborgRugby.algorithmQueue"
        visualizationCommandQueue.label = "CyborgRugby.visualizationQueue"
    }
    
    private func setupCameraManager() {
        cameraManager.delegate = self
        
        // Camera configuration is handled in CameraManager init
    }
    
    private func setupUI() {
        view.backgroundColor = .black

        // Metal container for live preview
        if metalContainerView == nil { metalContainerView = UIView() }
        metalContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metalContainerView)

        // Pose instruction label
        if poseInstructionLabel == nil { poseInstructionLabel = UILabel() }
        poseInstructionLabel.textColor = .white
        poseInstructionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        poseInstructionLabel.textAlignment = .center
        poseInstructionLabel.numberOfLines = 0
        poseInstructionLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        poseInstructionLabel.adjustsFontForContentSizeCategory = true
        poseInstructionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(poseInstructionLabel)

        // Status hint label (valid/stable progress)
        if statusHintLabel == nil { statusHintLabel = UILabel() }
        statusHintLabel.textColor = .systemYellow
        statusHintLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        statusHintLabel.adjustsFontForContentSizeCategory = true
        statusHintLabel.textAlignment = .center
        statusHintLabel.numberOfLines = 1
        statusHintLabel.translatesAutoresizingMaskIntoConstraints = false
        statusHintLabel.isHidden = true
        view.addSubview(statusHintLabel)

        // Pose progress stack (dots)
        poseProgressStack = UIStackView()
        poseProgressStack.axis = .horizontal
        poseProgressStack.alignment = .center
        poseProgressStack.distribution = .equalCentering
        poseProgressStack.spacing = 6
        poseProgressStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(poseProgressStack)

        // Pose progress label (e.g., 3 of 7)
        poseProgressLabel = UILabel()
        poseProgressLabel.textColor = .white
        poseProgressLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        poseProgressLabel.adjustsFontForContentSizeCategory = true
        poseProgressLabel.textAlignment = .center
        poseProgressLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(poseProgressLabel)

        // Scanning button
        if scanningButton == nil { scanningButton = UIButton(type: .system) }
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = "Start Scanning"
            config.image = UIImage(systemName: "camera.viewfinder")
            config.imagePadding = 6
            config.cornerStyle = .large
            scanningButton.configuration = config
        } else {
            scanningButton.setTitle("Start Scanning", for: .normal)
            scanningButton.setTitleColor(.white, for: .normal)
            scanningButton.backgroundColor = .systemBlue
            scanningButton.layer.cornerRadius = 12
            scanningButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        }
        scanningButton.translatesAutoresizingMaskIntoConstraints = false
        scanningButton.addTarget(self, action: #selector(scanningButtonTapped(_:)), for: .touchUpInside)
        view.addSubview(scanningButton)
        scanningButton.accessibilityIdentifier = "scan.start"
        scanningButton.accessibilityLabel = "Start scanning"

        // Skip pose button
        if skipPoseButton == nil { skipPoseButton = UIButton(type: .system) }
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.title = "Skip Pose"
            config.image = UIImage(systemName: "forward.fill")
            config.imagePadding = 6
            config.cornerStyle = .medium
            skipPoseButton.configuration = config
        } else {
            skipPoseButton.setTitle("Skip Pose", for: .normal)
            skipPoseButton.setTitleColor(.white, for: .normal)
            skipPoseButton.backgroundColor = .systemOrange
            skipPoseButton.layer.cornerRadius = 10
            skipPoseButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        }
        skipPoseButton.translatesAutoresizingMaskIntoConstraints = false
        skipPoseButton.addTarget(self, action: #selector(skipPoseButtonTapped(_:)), for: .touchUpInside)
        skipPoseButton.isHidden = true
        view.addSubview(skipPoseButton)
        skipPoseButton.accessibilityIdentifier = "scan.skipPose"
        skipPoseButton.accessibilityLabel = "Skip pose"

        // Layout constraints
        NSLayoutConstraint.activate([
            // Metal view fills the screen
            metalContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            metalContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            metalContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Pose instructions near top
            poseInstructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            poseInstructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            poseInstructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Hint label below instructions
            statusHintLabel.topAnchor.constraint(equalTo: poseInstructionLabel.bottomAnchor, constant: 6),
            statusHintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusHintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Pose progress stack below hint
            poseProgressStack.topAnchor.constraint(equalTo: statusHintLabel.bottomAnchor, constant: 8),
            poseProgressStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Pose progress label below dots
            poseProgressLabel.topAnchor.constraint(equalTo: poseProgressStack.bottomAnchor, constant: 4),
            poseProgressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            poseProgressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Scanning button at bottom center
            scanningButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanningButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            // Skip button above scanning button
            skipPoseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            skipPoseButton.bottomAnchor.constraint(equalTo: scanningButton.topAnchor, constant: -10)
        ])

        // Initial UI state
        updateUIForPose(currentPose)
    }
    
    private func updateMetalLayerFrame() {
        CATransaction.begin()
        CATransaction.disableActions()
        metalLayer.frame = metalContainerView.bounds
        metalLayer.drawableSize = CGSize(
            width: metalLayer.frame.width * metalLayer.contentsScale,
            height: metalLayer.frame.height * metalLayer.contentsScale
        )
        CATransaction.commit()
    }
    
    private func startMotionTracking() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self, self.isScanning else { return }
            // Feed device motion to reconstruction for improved tracking
            self.reconstructionManager?.accumulateDeviceMotion(motion)
        }
    }
    
    // MARK: - Scanning Control
    
    private func startFirstPose() {
        currentPose = HeadScanningPose.allCases.first!
        updateUIForPose(currentPose)
        updatePoseProgressUI()
    }
    
    @IBAction private func scanningButtonTapped(_ sender: UIButton) {
        if isScanning {
            stopCurrentPoseScanning()
        } else {
            startCurrentPoseScanning()
        }
    }
    
    @IBAction private func skipPoseButtonTapped(_ sender: UIButton) {
        skipCurrentPose()
    }
    
    @IBAction private func cancelScanning(_ sender: UIButton) {
        delegate?.scrumCapScanningDidCancel(self)
    }
    
    private func startCurrentPoseScanning() {
        guard !isScanning else { return }
        
        isScanning = true
        scanningButton.setTitle("Stop Scanning", for: .normal)
        scanningButton.backgroundColor = .systemRed
        skipPoseButton.isHidden = false
        // Prepare reconstruction manager for a new pose
        reconstructionManager?.includesColorBuffersInMetadata = false
        reconstructionManager?.includesDepthBuffersInMetadata = false
        reconstructionManager?.flipsInputHorizontally = true // using front camera
        
        // Reset gating and do not use a fixed timer; finalize when valid+stable
        consecutiveValidCount = 0
        assimilatedFramesForPose = 0
        startingSucceededCount = Int(reconstructionManager?.currentStatistics.succeededCount ?? 0)
        scanningTimer?.invalidate(); scanningTimer = nil
        statusHintLabel.isHidden = false
        updateHintLabel()
        print("🏉 Started scanning pose (gated): \(currentPose.displayName)")
    }
    
    private func stopCurrentPoseScanning() {
        guard isScanning else { return }
        
        scanningTimer?.invalidate(); scanningTimer = nil
        completePoseScanning()
    }
    
    private func completePoseScanning() {
        guard isScanning else { return }
        
        isScanning = false
        scanningButton.setTitle("Start Scanning", for: .normal)
        scanningButton.backgroundColor = .systemBlue
        skipPoseButton.isHidden = true
        
        // Finalize reconstruction and capture point cloud for the pose
        let pose = currentPose
        reconstructionManager?.finalize { [weak self] in
            guard let self = self else { return }
            let pointCloud = self.reconstructionManager?.buildPointCloud()
            self.reconstructionManager?.reset()
            
            DispatchQueue.main.async {
                // Mark pose complete and record result
                self.completedPoses.insert(pose)
                if let pc = pointCloud {
                    self.multiAngleScanManager.providePointCloud(pc, for: pose)
                    // If this is a profile pose, derive ear metrics from the captured cloud and try to refine protrusion via ML
                    if pose == .leftProfile || pose == .rightProfile, let pm = PointCloudMetricsCalculator.compute(for: pc) {
                        var protrusion: Float = 40.0
                        var confidence: Float = 0.8
                        if let pix = (pose == .leftProfile ? self.lastLeftProfilePixelBuffer : self.lastRightProfilePixelBuffer) {
                            Task { [weak self] in
                                guard let self = self else { return }
                                let side: EarSide = (pose == .leftProfile ? .left : .right)
                                let est = await self.poseValidator.estimateEarProtrusion(in: pix, side: side)
                                let feats = await self.poseValidator.detectEarFeatures(in: pix)
                                if let est = est { protrusion = est }
                                if let feats = feats { confidence = max(confidence, feats.confidence) }
                                let ear = EarMetrics(
                                    heightMM: pm.height * 1000.0,
                                    widthMM: pm.width * 1000.0 * 0.5,
                                    protrusionAngleDeg: protrusion,
                                    topToLobeMM: pm.height * 1000.0 * 0.95,
                                    confidence: confidence
                                )
                                self.multiAngleScanManager.provideEarMetrics(ear, for: pose)
                            }
                        } else {
                            let ear = EarMetrics(
                                heightMM: pm.height * 1000.0,
                                widthMM: pm.width * 1000.0 * 0.5,
                                protrusionAngleDeg: protrusion,
                                topToLobeMM: pm.height * 1000.0 * 0.95,
                                confidence: confidence
                            )
                            self.multiAngleScanManager.provideEarMetrics(ear, for: pose)
                        }
                    }
                }
                self.statusHintLabel.isHidden = true
                print("🏉 Completed scanning pose: \(pose.displayName)")
                // Move to next pose or finish
                self.moveToNextPose()
            }
        }
    }
    
    private func skipCurrentPose() {
        print("🏉 Skipped pose: \(currentPose.displayName)")
        
        if isScanning {
            stopCurrentPoseScanning()
        } else {
            moveToNextPose()
        }
    }
    
    private func moveToNextPose() {
        // Find next unscanned pose
        let remainingPoses = HeadScanningPose.allCases.filter { !completedPoses.contains($0) && $0 != currentPose }
        
        if let nextPose = remainingPoses.first {
            currentPose = nextPose
            updateUIForPose(nextPose)
            
            // Reset reconstruction manager for next pose to ensure clean point cloud capture
            if let manager = reconstructionManager {
                manager.reset()
                AppLog.scan.info("Reset reconstruction manager for pose: \(nextPose.rawValue)")
            }
        } else {
            completeAllScanning()
        }
    }
    
    private func completeAllScanning() {
        print("🏉 All poses completed! Processing measurements...")
        
        // Compute measurements from captured point clouds using a robust local calculator
        let perPoseResults = multiAngleScanManager.results()
        let fullMeasurements = computeMeasurements(from: perPoseResults)
        
        // Show results
        showScanResults(fullMeasurements)
    }
    
    // MARK: - UI Updates
    
    private func updateUIForPose(_ pose: HeadScanningPose) {
        // Update instruction label
        poseInstructionLabel.text = pose.instructions
        poseInstructionLabel.accessibilityIdentifier = "scan.poseInstruction"
        poseInstructionLabel.accessibilityLabel = pose.instructions
        
        // Update progress (simple version for MVP)
        let totalPoses = HeadScanningPose.allCases.count
        let completedCount = completedPoses.count
        let progressText = "Pose \(completedCount + 1) of \(totalPoses): \(pose.displayName)"
        title = progressText
        
        // Show detailed guidance for difficult poses
        if pose.difficultyLevel == .hard {
            showDetailedGuidance(for: pose)
        }
        
        // Reset scanning button
        scanningButton.setTitle("Start \(pose.displayName)", for: .normal)
        scanningButton.backgroundColor = pose.rugbyImportance == .critical ? .systemRed : .systemBlue
        updatePoseProgressUI()
    }
    
    private func showDetailedGuidance(for pose: HeadScanningPose) {
        let alert = UIAlertController(
            title: "\(pose.displayName) - \(pose.rugbyImportance.description)",
            message: pose.detailedGuidance,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Got It", style: .default))
        present(alert, animated: true)
    }

    private func updatePoseProgressUI() {
        let poses = HeadScanningPose.allCases
        // Clear existing indicators
        poseProgressStack.arrangedSubviews.forEach { v in
            poseProgressStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        // Build symbol-based indicators
        for pose in poses {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFit
            iv.tintColor = .white
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.widthAnchor.constraint(equalToConstant: 16).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 16).isActive = true
            if completedPoses.contains(pose) {
                iv.image = UIImage(systemName: "checkmark.circle.fill")
                iv.tintColor = .systemGreen
            } else if pose == currentPose {
                iv.image = UIImage(systemName: "circle.fill")
                iv.tintColor = .systemBlue
            } else {
                iv.image = UIImage(systemName: "circle")
                iv.tintColor = .systemGray3
            }
            poseProgressStack.addArrangedSubview(iv)
        }
        // Update numeric label (e.g., 3 of 7)
        let total = poses.count
        let index = (poses.firstIndex(of: currentPose) ?? 0) + 1
        poseProgressLabel.text = "Pose \(index) of \(total)"
        poseProgressLabel.accessibilityIdentifier = "scan.progress"
        poseProgressLabel.accessibilityLabel = "Pose \(index) of \(total)"
    }
    
    // MARK: - Results Processing
    
    private func showScanResults(_ measurements: ScrumCapMeasurements) {
        // Use per-pose results with point clouds captured during scanning
        let perPoseResults = multiAngleScanManager.results()
        // Create complete scan result
        let completeScanResult = CompleteScanResult(
            individualScans: perPoseResults,
            overallQuality: measurements.overallConfidence,
            timestamp: Date(),
            totalScanTime: 45.0, // Estimated total time
            successfulPoses: perPoseResults.values.filter { $0.status == .completed }.count,
            rugbyFitnessMeasurements: measurements
        )
        // Log a quick summary for verification
        let nonNilClouds = perPoseResults.values.compactMap { $0.pointCloud }.count
        AppLog.scan.info("Results ready: poses=\(perPoseResults.count), clouds=\(nonNilClouds)")
        
        // Notify delegate of completion
        delegate?.scrumCapScanning(self, didComplete: completeScanResult)
    }
    
    private func showSimpleResults(_ measurements: ScrumCapMeasurements) {
        let message = """
        Scan Complete! 
        
        Recommended Size: \(measurements.recommendedSize.rawValue)
        Head Shape: \(measurements.headShapeClassification.description)
        Measurement Quality: \(measurements.measurementQuality.description)
        
        Overall Confidence: \(String(format: "%.0f", measurements.overallConfidence * 100))%
        """
        
        let alert = UIAlertController(title: "🏉 Scrum Cap Results", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Awesome!", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentColorBuffer() -> CVPixelBuffer? {
        // This would be implemented to capture current color buffer
        // For MVP, returning nil - full implementation would store buffers
        return nil
    }
    
    private func createMockEarDimensions() -> ValidatedEarDimensions {
        let mockMeasurement = ValidatedMeasurement(
            value: 60.0,
            confidence: 0.8,
            validationStatus: .estimated,
            alternativeValues: [],
            measurementSource: .directScan(poses: Array(completedPoses))
        )
        
        return ValidatedEarDimensions(
            height: mockMeasurement,
            width: ValidatedMeasurement(
                value: 30.0,
                confidence: 0.8,
                validationStatus: .estimated,
                alternativeValues: [],
                measurementSource: .directScan(poses: Array(completedPoses))
            ),
            protrusionAngle: ValidatedMeasurement(
                value: 45.0,
                confidence: 0.7,
                validationStatus: .estimated,
                alternativeValues: [],
                measurementSource: .directScan(poses: Array(completedPoses))
            ),
            topToLobe: mockMeasurement
        )
    }
    
    private func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "Camera Permission Required",
            message: "CyborgRugby needs camera access for 3D head scanning. Please grant permission in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showCameraConfigurationError() {
        let alert = UIAlertController(
            title: "Camera Configuration Failed",
            message: "Unable to configure the TrueDepth camera. Please ensure you're using a device with TrueDepth camera support.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - CameraManagerDelegate

extension ScrumCapScanningViewController: CameraManagerDelegate {
    
    func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer) {
        
        // For MVP, simplified implementation
        // Process the pixel buffer for pose validation
        Task {
            let validationResult = await poseValidator.validatePose(currentPose, in: pixelBuffer)
            DispatchQueue.main.async {
                self.updateValidationFeedback(validationResult)
            }
        }
        
        // Pass to multi-angle scan manager
        multiAngleScanManager.processPixelBuffer(pixelBuffer)

        // Keep last color buffer for profile poses for optional ML-based ear estimates
        switch currentPose {
        case .leftProfile:
            lastLeftProfilePixelBuffer = pixelBuffer
        case .rightProfile:
            lastRightProfilePixelBuffer = pixelBuffer
        default:
            break
        }
    }
    
    func cameraManager(_ manager: CameraManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.poseInstructionLabel.textColor = .systemRed
            self.poseInstructionLabel.text = "⚠️ Camera error: \(error.localizedDescription)"
        }
    }
    
    // New: synchronized color + depth frames for reconstruction
    func cameraManager(_ manager: CameraManager,
                       didOutput colorBuffer: CVPixelBuffer,
                       depthBuffer: CVPixelBuffer,
                       calibrationData: AVCameraCalibrationData) {
        guard isScanning else { return }
        reconstructionManager?.accumulate(depthBuffer: depthBuffer,
                                          colorBuffer: colorBuffer,
                                          calibrationData: calibrationData)
    }
    
    private func updateValidationFeedback(_ validation: PoseValidationResult) {
        DispatchQueue.main.async {
            if validation.isValid {
                self.poseInstructionLabel.textColor = .systemGreen
                if validation.confidence > 0.8 {
                    self.poseInstructionLabel.text = "✅ Perfect position! \(self.currentPose.instructions)"
                } else {
                    self.poseInstructionLabel.text = "✅ Good position. \(self.currentPose.instructions)"
                }
                // Stability gating: count consecutive valid checks and evaluate finalize
                self.consecutiveValidCount += 1
                self.updateHintLabel(); self.maybeFinalizePoseIfReady()
            } else {
                self.poseInstructionLabel.textColor = .systemOrange
                // Inline advice (keeps build robust if helper is unavailable)
                let adviceText: String
                if validation.confidence < 0.3 {
                    adviceText = "Lighting looks low. Move to a brighter area or face a light source."
                } else {
                    switch self.currentPose {
                    case .leftProfile: adviceText = "Turn a bit more to the left and hold steady."
                    case .rightProfile: adviceText = "Turn a bit more to the right and hold steady."
                    case .lookingDown: adviceText = "Tilt your head slightly down to show the back of your head."
                    default: adviceText = "Hold steady. Sit comfortably and keep your head still."
                    }
                }
                self.poseInstructionLabel.text = "⚠️ \(validation.feedback)\n\(adviceText)"
                self.consecutiveValidCount = 0
                self.updateHintLabel()
            }
        }
    }
}

// MARK: - SCReconstructionManagerDelegate
extension ScrumCapScanningViewController: SCReconstructionManagerDelegate {
    func reconstructionManager(_ manager: SCReconstructionManager,
                               didProcessWith metadata: SCAssimilatedFrameMetadata,
                               statistics: SCReconstructionManagerStatistics) {
        latestViewMatrix = metadata.viewMatrix
        DispatchQueue.main.async {
            let progress = min(Float(statistics.succeededCount) / 100.0, 1.0)
            self.updateScanningProgress(progress)
            // Track assimilated frames for gating
            let succeeded = Int(statistics.succeededCount)
            self.assimilatedFramesForPose = max(0, succeeded - self.startingSucceededCount)
            self.maybeFinalizePoseIfReady()
        }
    }
    
    func reconstructionManager(_ manager: SCReconstructionManager,
                               didEncounterAPIError error: Error) {
        AppLog.scan.error("Reconstruction error: \(String(describing: error))")
        DispatchQueue.main.async {
            self.poseInstructionLabel.textColor = .systemRed
            self.poseInstructionLabel.text = "⚠️ Scanning error - please try again"
        }
    }
    
    private func updateScanningProgress(_ progress: Float) {
        let percentage = Int(progress * 100)
        if isScanning {
            scanningButton.setTitle("Scanning... \(percentage)%", for: .normal)
        }
    }

    private func maybeFinalizePoseIfReady() {
        guard isScanning else { return }
        let validOK = consecutiveValidCount >= gatingConfig.requiredConsecutiveValid
        let framesOK = assimilatedFramesForPose >= gatingConfig.requiredAssimilatedFrames
        if validOK && framesOK {
            let h = UINotificationFeedbackGenerator()
            h.notificationOccurred(.success)
            // Prevent double finalize
            consecutiveValidCount = 0
            assimilatedFramesForPose = 0
            stopCurrentPoseScanning()
        }
    }

    private func updateHintLabel() {
        guard isScanning else { statusHintLabel.isHidden = true; return }
        statusHintLabel.isHidden = false
        let v = min(consecutiveValidCount, gatingConfig.requiredConsecutiveValid)
        let f = min(assimilatedFramesForPose, gatingConfig.requiredAssimilatedFrames)
        if v < gatingConfig.requiredConsecutiveValid || f < gatingConfig.requiredAssimilatedFrames {
            statusHintLabel.text = "Hold steady… valid \(v)/\(gatingConfig.requiredConsecutiveValid), frames \(f)/\(gatingConfig.requiredAssimilatedFrames)"
            statusHintLabel.textColor = .systemYellow
        } else {
            statusHintLabel.text = "Capturing…"
            statusHintLabel.textColor = .systemGreen
        }
    }
}
// 
// MARK: - MultiAngleScanManagerDelegate

extension ScrumCapScanningViewController: MultiAngleScanManagerDelegate {
    
    func scanManager(_ manager: MultiAngleScanManager, didStartPose pose: HeadScanningPose) {
        AppLog.scan.info("Started pose: \(pose.displayName)")
        currentPose = pose
        updateUIForPose(pose)
    }
    
    func scanManager(_ manager: MultiAngleScanManager, didCompletePose pose: HeadScanningPose, withResult result: ScanResult) {
        AppLog.scan.info("Completed pose: \(pose.displayName)")
        let h = UINotificationFeedbackGenerator()
        h.notificationOccurred(.success)
        completedPoses.insert(pose)
    }
    
    func scanManager(_ manager: MultiAngleScanManager, didFailPose pose: HeadScanningPose, withError error: Error) {
        AppLog.scan.error("Failed pose: \(pose.displayName) - \(String(describing: error))")
        let h = UINotificationFeedbackGenerator()
        h.notificationOccurred(.warning)
    }
    
    func scanManager(_ manager: MultiAngleScanManager, didUpdateProgress progress: Float) {
        // Update progress UI if needed
    }
    
    func scanManager(_ manager: MultiAngleScanManager, didFinishAllScans finalResult: CompleteScanResult) {
        print("🏉 All poses completed!")
        showScanResults(finalResult.rugbyFitnessMeasurements)
    }
    
    func scanManager(_ manager: MultiAngleScanManager, poseValidationUpdate result: PoseValidationResult, for pose: HeadScanningPose) {
        updateValidationFeedback(result)
    }
}
// 
// // MARK: - Implementations are in separate files
// // MultiAngleScanManager, MLEnhancedPoseValidator, etc. are implemented in their respective files
// 


// MARK: - Robust Local Measurement Calculator

private extension ScrumCapScanningViewController {
    func computeMeasurements(from scans: [HeadScanningPose: ScanResult]) -> ScrumCapMeasurements {
        // Select densest cloud as fused (placeholder)
        var fused: SCPointCloud?
        var maxPoints = -1
        for (_, s) in scans { if let pc = s.pointCloud { let c = Int(pc.pointCount); if c > maxPoints { maxPoints = c; fused = pc } } }

        func mm(_ meters: Float) -> Float { meters * 1000.0 }

        // Horizontal slice around center.y and convex hull perimeter
        func slicePerimeterCM(of cloud: SCPointCloud) -> Float? {
            let centerY = cloud.centerOfMass().y
            let band: Float = 0.015
            let data = cloud.pointsData as Data
            let stride = SCPointCloud.pointStride()
            let posOffset = SCPointCloud.positionOffset()
            let compSize = SCPointCloud.positionComponentSize()
            let count = Int(cloud.pointCount)
            var pts: [SIMD2<Float>] = []
            data.withUnsafeBytes { rawBuf in
                guard let base = rawBuf.baseAddress else { return }
                for i in 0..<count {
                    let offset = i * Int(stride) + Int(posOffset)
                    let px = base.advanced(by: offset + 0 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee
                    let py = base.advanced(by: offset + 1 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee
                    let pz = base.advanced(by: offset + 2 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee
                    if abs(py - centerY) <= band { pts.append(SIMD2<Float>(px, pz)) }
                }
            }
            guard pts.count >= 3 else { return nil }
            // Graham scan
            let sorted = pts.sorted { (a,b) in (a.y == b.y) ? (a.x < b.x) : (a.y < b.y) }
            func cross(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Float {
                let ab = SIMD2<Float>(b.x - a.x, b.y - a.y)
                let ac = SIMD2<Float>(c.x - a.x, c.y - a.y)
                return ab.x * ac.y - ab.y * ac.x
            }
            var lower: [SIMD2<Float>] = []
            for p in sorted { while lower.count >= 2 && cross(lower[lower.count-2], lower[lower.count-1], p) <= 0 { _ = lower.popLast() }; lower.append(p) }
            var upper: [SIMD2<Float>] = []
            for p in sorted.reversed() { while upper.count >= 2 && cross(upper[upper.count-2], upper[upper.count-1], p) <= 0 { _ = upper.popLast() }; upper.append(p) }
            lower.removeLast(); upper.removeLast()
            let hull = lower + upper
            if hull.count < 2 { return nil }
            var perim: Float = 0
            for i in 0..<hull.count { perim += distance(hull[i], hull[(i+1)%hull.count]) }
            return mm(perim) / 10.0
        }

        // Axis-aligned bbox (x,z) in mm
        func bboxMM(of cloud: SCPointCloud) -> (width: Float, depth: Float)? {
            let data = cloud.pointsData as Data
            let stride = SCPointCloud.pointStride()
            let posOffset = SCPointCloud.positionOffset()
            let compSize = SCPointCloud.positionComponentSize()
            let count = Int(cloud.pointCount)
            var minX = Float.greatestFiniteMagnitude
            var maxX = -Float.greatestFiniteMagnitude
            var minZ = Float.greatestFiniteMagnitude
            var maxZ = -Float.greatestFiniteMagnitude
            var found = false
            data.withUnsafeBytes { rawBuf in
                guard let base = rawBuf.baseAddress else { return }
                for i in 0..<count {
                    let offset = i * Int(stride) + Int(posOffset)
                    let px = base.advanced(by: offset + 0 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee
                    let pz = base.advanced(by: offset + 2 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee
                    if !px.isFinite || !pz.isFinite { continue }
                    found = true
                    if px < minX { minX = px }; if px > maxX { maxX = px }
                    if pz < minZ { minZ = pz }; if pz > maxZ { maxZ = pz }
                }
            }
            guard found else { return nil }
            return (width: mm(maxX - minX), depth: mm(maxZ - minZ))
        }

        // Per-pose ear dims preferred from EarMetrics
        func ear(for pose: HeadScanningPose) -> ValidatedEarDimensions {
            if let em = scans[pose]?.earMetrics {
                return ValidatedEarDimensions(
                    height: ValidatedMeasurement(value: em.heightMM, confidence: em.confidence, validationStatus: .validated, alternativeValues: [], measurementSource: .directScan(poses: [pose])),
                    width: ValidatedMeasurement(value: em.widthMM, confidence: em.confidence, validationStatus: .validated, alternativeValues: [], measurementSource: .directScan(poses: [pose])),
                    protrusionAngle: ValidatedMeasurement(value: em.protrusionAngleDeg, confidence: em.confidence, validationStatus: .estimated, alternativeValues: [], measurementSource: .mlModel(modelName: "SCEarLandmarking", confidence: em.confidence)),
                    topToLobe: ValidatedMeasurement(value: em.topToLobeMM, confidence: em.confidence, validationStatus: .validated, alternativeValues: [], measurementSource: .directScan(poses: [pose]))
                )
            }
            let fallback = ValidatedMeasurement(value: 60.0, confidence: 0.3, validationStatus: .interpolated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["defaults"]))
            return ValidatedEarDimensions(height: fallback, width: fallback, protrusionAngle: ValidatedMeasurement(value: 40.0, confidence: 0.3, validationStatus: .interpolated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["defaults"])) , topToLobe: fallback)
        }

        // Compute
        let headCircCM: Float = {
            if let fused = fused, let cm = slicePerimeterCM(of: fused) { return cm }
            // Fallback to default cm if slice not available
            return 56.0
        }()

        let leftEar = ear(for: .leftProfile)
        let rightEar = ear(for: .rightProfile)
        // Use bbox of fused cloud for these linear measures
        var backWidthMM: Float = 160.0
        var depthMM: Float = 190.0
        if let fused = fused, let bb = bboxMM(of: fused) { backWidthMM = bb.width; depthMM = bb.depth }
        let occipitalMM: Float = depthMM * 0.25
        let neckCurveMM: Float = depthMM * 0.4

        return ScrumCapMeasurements(
            headCircumference: ValidatedMeasurement(value: headCircCM, confidence: 0.85, validationStatus: .validated, alternativeValues: [], measurementSource: .directScan(poses: Array(scans.keys))),
            earToEarOverTop: ValidatedMeasurement(value: headCircCM, confidence: 0.6, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["slice perimeter"])) ,
            foreheadToNeckBase: ValidatedMeasurement(value: depthMM, confidence: 0.6, validationStatus: .estimated, alternativeValues: [], measurementSource: .directScan(poses: Array(scans.keys))) ,
            leftEarDimensions: leftEar,
            rightEarDimensions: rightEar,
            earAsymmetryFactor: 0.1,
            occipitalProminence: ValidatedMeasurement(value: occipitalMM, confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .directScan(poses: Array(scans.keys))) ,
            neckCurveRadius: ValidatedMeasurement(value: neckCurveMM, confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .directScan(poses: Array(scans.keys))) ,
            backHeadWidth: ValidatedMeasurement(value: backWidthMM, confidence: 0.6, validationStatus: .estimated, alternativeValues: [], measurementSource: .directScan(poses: Array(scans.keys))) ,
            jawLineToEar: ValidatedMeasurement(value: 100.0, confidence: 0.3, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["defaults"])) ,
            chinToEarDistance: ValidatedMeasurement(value: 110.0, confidence: 0.3, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["defaults"]))
        )
    }
}
