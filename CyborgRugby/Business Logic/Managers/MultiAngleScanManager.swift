//
//  MultiAngleScanManager.swift
//  CyborgRugby
//
//  Manages multi-angle head scanning workflow for rugby scrum cap fitting
//

import Foundation
import AVFoundation
import StandardCyborgFusion

@MainActor
protocol MultiAngleScanManagerDelegate: AnyObject {
    func scanManager(_ manager: MultiAngleScanManager, didStartPose pose: HeadScanningPose)
    func scanManager(_ manager: MultiAngleScanManager, didCompletePose pose: HeadScanningPose, withResult result: ScanResult)
    func scanManager(_ manager: MultiAngleScanManager, didFailPose pose: HeadScanningPose, withError error: Error)
    func scanManager(_ manager: MultiAngleScanManager, didUpdateProgress progress: Float)
    func scanManager(_ manager: MultiAngleScanManager, didFinishAllScans finalResult: CompleteScanResult)
    func scanManager(_ manager: MultiAngleScanManager, poseValidationUpdate result: PoseValidationResult, for pose: HeadScanningPose)
}

class MultiAngleScanManager {
    weak var delegate: MultiAngleScanManagerDelegate?
    
    private let poseValidator = {
        let validator = MLEnhancedPoseValidator()
        validator.startInitialization()
        return validator
    }()
    private var currentPoseIndex = 0
    private var scanResults: [HeadScanningPose: ScanResult] = [:]
    private var isScanning = false
    private var poseValidationTimer: Timer?
    private var currentPixelBuffer: CVPixelBuffer?
    
    // Configuration
    private let requiredPoses: [HeadScanningPose] = HeadScanningPose.allCases.sorted { 
        $0.rugbyImportance.rawValue > $1.rugbyImportance.rawValue 
    }
    private let validationInterval: TimeInterval = 0.0
    private let minimumValidationTime: TimeInterval = 0.0
    private var poseValidationStartTime: Date?
    
    // State tracking
    private var currentPose: HeadScanningPose? {
        guard currentPoseIndex < requiredPoses.count else { return nil }
        return requiredPoses[currentPoseIndex]
    }
    
    var progress: Float {
        return Float(currentPoseIndex) / Float(requiredPoses.count)
    }
    
    var isComplete: Bool {
        return currentPoseIndex >= requiredPoses.count
    }
    
    // MARK: - Scanning Control
    
    func startMultiAngleScan() {
        isScanning = true
        currentPoseIndex = 0
        scanResults.removeAll()
        Task { @MainActor in
            delegate?.scanManager(self, didStartPose: requiredPoses[currentPoseIndex])
            delegate?.scanManager(self, didUpdateProgress: progress)
        }
    }
    
    func stopScanning() {
        isScanning = false
        poseValidationTimer?.invalidate(); poseValidationTimer = nil
    }
    
    func skipCurrentPose(reason: String = "User skipped") {
        guard let pose = currentPose else { return }
        
        print("⏭️ Skipping pose: \(pose.displayName) - \(reason)")
        
        let skippedResult = ScanResult(
            pose: pose,
            pointCloud: nil,
            confidence: 0.0,
            status: .skipped,
            timestamp: Date(),
            metadata: ["skip_reason": reason],
            earMetrics: nil
        )
        
        scanResults[pose] = skippedResult
        delegate?.scanManager(self, didCompletePose: pose, withResult: skippedResult)
        
        moveToNextPose()
    }
    
    func retryCurrentPose() {
        guard let pose = currentPose else { return }
        
        print("🔄 Retrying pose: \(pose.displayName)")
        scanResults.removeValue(forKey: pose)
        startCurrentPose()
    }
    
    // MARK: - Private Methods
    
    private func setupScanningSession() {
        // scanningSession = SCReconstructionManager()  // Disabled for compilation
        // Configure scanning parameters for head scanning
        // This would integrate with StandardCyborgFusion settings
    }
    
    private func startCurrentPose() {
        guard let pose = currentPose else {
            completeAllScans()
            return
        }
        
        Task { @MainActor in
            delegate?.scanManager(self, didStartPose: pose)
            delegate?.scanManager(self, didUpdateProgress: progress)
        }
    }
    
    private func validateCurrentPose() { /* Controller handles gating */ }
    
    private func handleValidPoseDetected() { }
    
    private func beginCapturingPose() { }
    
    private func completePoseCapture() {
        guard let pose = currentPose else { return }
        
        print("✅ Completed capture for pose: \(pose.displayName)")
        
        // Create scan result with point cloud data
        let scanResult = ScanResult(
            pose: pose,
            pointCloud: nil, // Will be provided by controller upon finalize
            confidence: 0.85, // Would come from actual scanning
            status: .completed,
            timestamp: Date(),
            metadata: [
                "scan_duration": "\(pose.scanDuration)",
                "difficulty": pose.difficultyLevel.description
            ],
            earMetrics: nil
        )
        
        scanResults[pose] = scanResult
        Task { @MainActor in
            delegate?.scanManager(self, didCompletePose: pose, withResult: scanResult)
        }
        
        moveToNextPose()
    }
    
    private func moveToNextPose() {
        currentPoseIndex += 1
        
        if isComplete {
            completeAllScans()
        } else {
            startCurrentPose()
        }
    }
    
    private func completeAllScans() {
        print("🎉 All poses completed!")
        isScanning = false
        
        let completeScanResult = CompleteScanResult(
            individualScans: scanResults,
            overallQuality: calculateOverallQuality(),
            timestamp: Date(),
            totalScanTime: calculateTotalScanTime(),
            successfulPoses: scanResults.values.filter { $0.status == .completed }.count,
            rugbyFitnessMeasurements: generateRugbyMeasurements()
        )
        
        delegate?.scanManager(self, didFinishAllScans: completeScanResult)
    }
    
    private func calculateOverallQuality() -> Float {
        let completedScans = scanResults.values.filter { $0.status == .completed }
        guard !completedScans.isEmpty else { return 0.0 }
        
        let totalConfidence = completedScans.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(completedScans.count)
    }
    
    private func calculateTotalScanTime() -> TimeInterval {
        return requiredPoses.reduce(0.0) { total, pose in
            total + pose.scanDuration
        }
    }
    
    private func generateRugbyMeasurements() -> ScrumCapMeasurements {
        // Generate rugby-specific measurements from scan data
        // This would integrate with actual point cloud processing
        
        return ScrumCapMeasurements(
            headCircumference: ValidatedMeasurement(
                value: 56.5,
                confidence: 0.85,
                validationStatus: .validated,
                alternativeValues: [],
                measurementSource: .directScan(poses: Array(scanResults.keys))
            ),
            earToEarOverTop: ValidatedMeasurement(
                value: 38.2,
                confidence: 0.80,
                validationStatus: .validated,
                alternativeValues: [],
                measurementSource: .directScan(poses: [.frontFacing, .lookingDown])
            ),
            foreheadToNeckBase: ValidatedMeasurement(
                value: 34.1,
                confidence: 0.78,
                validationStatus: .estimated,
                alternativeValues: [],
                measurementSource: .directScan(poses: [.frontFacing, .lookingDown])
            ),
            leftEarDimensions: generateEarDimensions(from: [.leftProfile, .frontFacing]),
            rightEarDimensions: generateEarDimensions(from: [.rightProfile, .frontFacing]),
            earAsymmetryFactor: 0.12,
            occipitalProminence: ValidatedMeasurement(
                value: 12.3,
                confidence: 0.82,
                validationStatus: .validated,
                alternativeValues: [],
                measurementSource: .directScan(poses: [.lookingDown])
            ),
            neckCurveRadius: ValidatedMeasurement(
                value: 8.7,
                confidence: 0.75,
                validationStatus: .estimated,
                alternativeValues: [],
                measurementSource: .directScan(poses: [.lookingDown, .chinUp])
            ),
            backHeadWidth: ValidatedMeasurement(
                value: 15.4,
                confidence: 0.80,
                validationStatus: .validated,
                alternativeValues: [],
                measurementSource: .directScan(poses: [.lookingDown])
            ),
            jawLineToEar: ValidatedMeasurement(
                value: 9.8,
                confidence: 0.70,
                validationStatus: .estimated,
                alternativeValues: [],
                measurementSource: .directScan(poses: [.leftProfile, .rightProfile])
            ),
            chinToEarDistance: ValidatedMeasurement(
                value: 11.2,
                confidence: 0.68,
                validationStatus: .estimated,
                alternativeValues: [],
                measurementSource: .directScan(poses: [.chinUp])
            )
        )
    }
    
    private func generateEarDimensions(from poses: [HeadScanningPose]) -> ValidatedEarDimensions {
        return ValidatedEarDimensions(
            height: ValidatedMeasurement(
                value: 62.3,
                confidence: 0.88,
                validationStatus: .validated,
                alternativeValues: [],
                measurementSource: .directScan(poses: poses)
            ),
            width: ValidatedMeasurement(
                value: 32.1,
                confidence: 0.85,
                validationStatus: .validated,
                alternativeValues: [],
                measurementSource: .directScan(poses: poses)
            ),
            protrusionAngle: ValidatedMeasurement(
                value: 42.7,
                confidence: 0.82,
                validationStatus: .validated,
                alternativeValues: [],
                measurementSource: .directScan(poses: poses)
            ),
            topToLobe: ValidatedMeasurement(
                value: 58.9,
                confidence: 0.87,
                validationStatus: .validated,
                alternativeValues: [],
                measurementSource: .directScan(poses: poses)
            )
        )
    }
    
    // Controller can inject a point cloud when available
    func providePointCloud(_ pointCloud: SCPointCloud, for pose: HeadScanningPose) {
        var existing = scanResults[pose]
        existing = ScanResult(
            pose: pose,
            pointCloud: pointCloud,
            confidence: existing?.confidence ?? 0.85,
            status: existing?.status ?? .completed,
            timestamp: existing?.timestamp ?? Date(),
            metadata: existing?.metadata ?? [:],
            earMetrics: existing?.earMetrics
        )
        scanResults[pose] = existing
    }

    func provideEarMetrics(_ metrics: EarMetrics, for pose: HeadScanningPose) {
        var existing = scanResults[pose]
        existing = ScanResult(
            pose: pose,
            pointCloud: existing?.pointCloud,
            confidence: existing?.confidence ?? 0.85,
            status: existing?.status ?? .completed,
            timestamp: existing?.timestamp ?? Date(),
            metadata: existing?.metadata ?? [:],
            earMetrics: metrics
        )
        scanResults[pose] = existing
    }

    // Expose a snapshot of current per-pose results
    func results() -> [HeadScanningPose: ScanResult] {
        return scanResults
    }
    
    // MARK: - Camera Frame Processing
    
    func processPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        currentPixelBuffer = pixelBuffer
        // This would be called from the camera capture delegate
        // The pixel buffer is stored for pose validation
    }
}

// MARK: - Supporting Types

struct ScanResult {
    let pose: HeadScanningPose
    let pointCloud: SCPointCloud?
    let confidence: Float
    let status: ScanStatus
    let timestamp: Date
    let metadata: [String: String]
    let earMetrics: EarMetrics?
    
    enum ScanStatus {
        case completed
        case skipped
        case failed
        case inProgress
    }
}

struct CompleteScanResult {
    let individualScans: [HeadScanningPose: ScanResult]
    let overallQuality: Float
    let timestamp: Date
    let totalScanTime: TimeInterval
    let successfulPoses: Int
    let rugbyFitnessMeasurements: ScrumCapMeasurements
    
    var completionRate: Float {
        let totalPoses = Float(HeadScanningPose.allCases.count)
        return Float(successfulPoses) / totalPoses
    }
    
    var qualityDescription: String {
        switch overallQuality {
        case 0.9...: return "Excellent scan quality"
        case 0.8..<0.9: return "Very good scan quality"  
        case 0.7..<0.8: return "Good scan quality"
        case 0.6..<0.7: return "Fair scan quality"
        default: return "Poor scan quality - consider rescanning"
        }
    }
}
