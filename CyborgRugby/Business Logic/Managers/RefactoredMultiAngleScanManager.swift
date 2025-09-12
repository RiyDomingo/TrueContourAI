//
//  RefactoredMultiAngleScanManager.swift
//  CyborgRugby
//
//  Refactored multi-angle scan manager using service-oriented architecture
//

import Foundation
import AVFoundation
import StandardCyborgFusion
import Metal
import OSLog

@MainActor
class RefactoredMultiAngleScanManager {
    
    // MARK: - Properties
    
    weak var delegate: RefactoredMultiAngleScanManagerDelegate?
    
    private let scanOrchestrator: ScanOrchestrationService
    
    // MARK: - Computed Properties
    
    var isScanning: Bool {
        return scanOrchestrator.isActive
    }
    
    var progress: Float {
        return scanOrchestrator.scanProgressService.progress
    }
    
    var isComplete: Bool {
        return scanOrchestrator.scanProgressService.isComplete
    }
    
    var currentPhase: ScanPhase {
        return scanOrchestrator.currentPhase
    }
    
    // MARK: - Initialization
    
    init(metalDevice: MTLDevice) {
        self.scanOrchestrator = ScanOrchestrationService(metalDevice: metalDevice)
        setupOrchestrator()
    }
    
    // MARK: - Public Methods
    
    func startMultiAngleScan() {
        scanOrchestrator.startMultiAngleScan()
    }
    
    func stopScanning() {
        scanOrchestrator.stopScanning()
    }
    
    func skipCurrentPose(reason: String = "User skipped") {
        scanOrchestrator.skipCurrentPose(reason: reason)
    }
    
    func retryCurrentPose() {
        scanOrchestrator.retryCurrentPose()
    }
    
    func processPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        scanOrchestrator.processFrame(pixelBuffer)
    }
    
    func processDepthFrame(_ depthData: AVDepthData, colorBuffer: CVPixelBuffer? = nil) {
        scanOrchestrator.processDepthFrame(depthData, colorBuffer: colorBuffer)
    }
    
    // MARK: - Legacy Compatibility Methods
    // These methods maintain compatibility with existing code
    
    func providePointCloud(_ pointCloud: SCPointCloud, for pose: HeadScanningPose) {
        // This functionality is now handled internally by the reconstruction service
        AppLog.scan.info("Point cloud provided for pose: \(pose.displayName)")
    }
    
    func provideEarMetrics(_ metrics: EarMetrics, for pose: HeadScanningPose) {
        // This functionality is now handled by the measurement generation service
        AppLog.scan.info("Ear metrics provided for pose: \(pose.displayName)")
    }
    
    func results() -> [HeadScanningPose: ScanResult] {
        return scanOrchestrator.scanProgressService.scanResults
    }
    
    // MARK: - Private Methods
    
    private func setupOrchestrator() {
        scanOrchestrator.delegate = self
    }
}

// MARK: - ScanOrchestrationServiceDelegate

extension RefactoredMultiAngleScanManager: ScanOrchestrationServiceDelegate {
    
    func scanOrchestrator(_ orchestrator: ScanOrchestrationService, didStartPose pose: HeadScanningPose) {
        delegate?.scanManager(self, didStartPose: pose)
    }
    
    func scanOrchestrator(_ orchestrator: ScanOrchestrationService, didCompletePose pose: HeadScanningPose, withResult result: ScanResult) {
        delegate?.scanManager(self, didCompletePose: pose, withResult: result)
    }
    
    func scanOrchestrator(_ orchestrator: ScanOrchestrationService, didFailPose pose: HeadScanningPose, withError error: Error) {
        delegate?.scanManager(self, didFailPose: pose, withError: error)
    }
    
    func scanOrchestrator(_ orchestrator: ScanOrchestrationService, didUpdateProgress progress: Float) {
        delegate?.scanManager(self, didUpdateProgress: progress)
    }
    
    func scanOrchestrator(_ orchestrator: ScanOrchestrationService, didFinishAllScans finalResult: CompleteScanResult) {
        delegate?.scanManager(self, didFinishAllScans: finalResult)
    }
    
    func scanOrchestrator(_ orchestrator: ScanOrchestrationService, poseValidationUpdate result: PoseValidationResult, for pose: HeadScanningPose) {
        delegate?.scanManager(self, poseValidationUpdate: result, for: pose)
    }
}

// MARK: - Factory Method for Easy Migration

extension RefactoredMultiAngleScanManager {
    
    /// Creates a refactored multi-angle scan manager that can be used as a drop-in replacement
    /// for the legacy MultiAngleScanManager
    static func createCompatible(with metalDevice: MTLDevice) -> RefactoredMultiAngleScanManager {
        let manager = RefactoredMultiAngleScanManager(metalDevice: metalDevice)
        AppLog.scan.info("Created refactored multi-angle scan manager")
        return manager
    }
}
