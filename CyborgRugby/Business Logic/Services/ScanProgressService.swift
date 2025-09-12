//
//  ScanProgressService.swift
//  CyborgRugby
//
//  Manages scan progress and pose sequence coordination
//

import Foundation
import OSLog

@MainActor
protocol ScanProgressServiceDelegate: AnyObject {
    func scanProgressService(_ service: ScanProgressService, didStartPose pose: HeadScanningPose)
    func scanProgressService(_ service: ScanProgressService, didCompletePose pose: HeadScanningPose, withResult result: ScanResult)
    func scanProgressService(_ service: ScanProgressService, didFailPose pose: HeadScanningPose, withError error: Error)
    func scanProgressService(_ service: ScanProgressService, didUpdateProgress progress: Float)
    func scanProgressService(_ service: ScanProgressService, didCompleteAllScans results: [HeadScanningPose: ScanResult])
}

@MainActor
class ScanProgressService: ObservableObject {
    
    // MARK: - Properties
    
    weak var delegate: ScanProgressServiceDelegate?
    
    @Published private(set) var currentPoseIndex: Int = 0
    @Published private(set) var scanResults: [HeadScanningPose: ScanResult] = [:]
    @Published private(set) var isScanning: Bool = false
    
    private let requiredPoses: [HeadScanningPose]
    private var scanStartTime: Date?
    
    // MARK: - Computed Properties
    
    var currentPose: HeadScanningPose? {
        guard currentPoseIndex < requiredPoses.count else { return nil }
        return requiredPoses[currentPoseIndex]
    }
    
    var progress: Float {
        guard !requiredPoses.isEmpty else { return 0.0 }
        return Float(currentPoseIndex) / Float(requiredPoses.count)
    }
    
    var isComplete: Bool {
        return currentPoseIndex >= requiredPoses.count
    }
    
    var completedPoses: [HeadScanningPose] {
        return scanResults.keys.filter { scanResults[$0]?.status == .completed }.sorted { pose1, pose2 in
            requiredPoses.firstIndex(of: pose1) ?? 0 < requiredPoses.firstIndex(of: pose2) ?? 0
        }
    }
    
    // MARK: - Initialization
    
    init(requiredPoses: [HeadScanningPose]? = nil) {
        self.requiredPoses = requiredPoses ?? HeadScanningPose.allCases.sorted { 
            $0.rugbyImportance.rawValue > $1.rugbyImportance.rawValue 
        }
    }
    
    // MARK: - Public Methods
    
    func startScanSequence() {
        guard !isScanning else {
            AppLog.scan.warning("Attempted to start scan sequence while already scanning")
            return
        }
        
        isScanning = true
        currentPoseIndex = 0
        scanResults.removeAll()
        scanStartTime = Date()
        
        AppLog.scan.info("Starting scan sequence with \(self.requiredPoses.count) poses")
        
        if let firstPose = currentPose {
            delegate?.scanProgressService(self, didStartPose: firstPose)
            delegate?.scanProgressService(self, didUpdateProgress: progress)
        }
    }
    
    func stopScanSequence() {
        guard isScanning else { return }
        
        isScanning = false
        AppLog.scan.info("Stopped scan sequence at pose \(self.currentPoseIndex)/\(self.requiredPoses.count)")
    }
    
    func skipCurrentPose(reason: String = "User skipped") {
        guard let pose = currentPose, isScanning else {
            AppLog.scan.warning("Attempted to skip pose but no current pose or not scanning")
            return
        }
        
        AppLog.scan.info("Skipping pose: \(pose.displayName) - \(reason)")
        
        let skippedResult = ScanResult(
            pose: pose,
            pointCloud: nil,
            confidence: 0.0,
            status: .skipped,
            timestamp: Date(),
            metadata: ["skip_reason": reason],
            earMetrics: nil
        )
        
        completePose(with: skippedResult)
    }
    
    func retryCurrentPose() {
        guard let pose = currentPose, isScanning else {
            AppLog.scan.warning("Attempted to retry pose but no current pose or not scanning")
            return
        }
        
        AppLog.scan.info("Retrying pose: \(pose.displayName)")
        scanResults.removeValue(forKey: pose)
        
        delegate?.scanProgressService(self, didStartPose: pose)
        delegate?.scanProgressService(self, didUpdateProgress: progress)
    }
    
    func completePose(with result: ScanResult) {
        guard isScanning, let pose = currentPose else {
            AppLog.scan.warning("Attempted to complete pose but not scanning or no current pose")
            return
        }
        
        scanResults[pose] = result
        delegate?.scanProgressService(self, didCompletePose: pose, withResult: result)
        
        AppLog.scan.info("Completed pose: \(pose.displayName) with status: \(String(describing: result.status))")
        
        moveToNextPose()
    }
    
    func failCurrentPose(with error: Error) {
        guard let pose = currentPose, isScanning else {
            AppLog.scan.warning("Attempted to fail pose but no current pose or not scanning")
            return
        }
        
        let failedResult = ScanResult(
            pose: pose,
            pointCloud: nil,
            confidence: 0.0,
            status: .failed(error),
            timestamp: Date(),
            metadata: ["error": error.localizedDescription],
            earMetrics: nil
        )
        
        scanResults[pose] = failedResult
        delegate?.scanProgressService(self, didFailPose: pose, withError: error)
        
        AppLog.scan.error("Failed pose: \(pose.displayName) - \(error.localizedDescription)")
        
        // Continue to next pose even if current failed
        moveToNextPose()
    }
    
    func updateScanResult(_ result: ScanResult, for pose: HeadScanningPose) {
        guard scanResults[pose] != nil else {
            AppLog.scan.warning("Attempted to update result for pose that hasn't started: \(pose.displayName)")
            return
        }
        
        scanResults[pose] = result
        AppLog.scan.debug("Updated scan result for pose: \(pose.displayName)")
    }
    
    // MARK: - Private Methods
    
    private func moveToNextPose() {
        currentPoseIndex += 1
        
        if isComplete {
            completeAllScans()
        } else if let nextPose = currentPose {
            delegate?.scanProgressService(self, didStartPose: nextPose)
            delegate?.scanProgressService(self, didUpdateProgress: progress)
        }
    }
    
    private func completeAllScans() {
        AppLog.scan.info("All poses completed! Successful: \(self.completedPoses.count)/\(self.requiredPoses.count)")
        
        isScanning = false
        delegate?.scanProgressService(self, didCompleteAllScans: scanResults)
    }
    
    // MARK: - Utility Methods
    
    func calculateOverallQuality() -> Float {
        let completedScans = scanResults.values.filter { $0.status == .completed }
        guard !completedScans.isEmpty else { return 0.0 }
        
        let totalConfidence: Float = completedScans.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(completedScans.count)
    }
    
    func calculateTotalScanTime() -> TimeInterval {
        guard let startTime = scanStartTime else { return 0.0 }
        return Date().timeIntervalSince(startTime)
    }
    
    func getSuccessfulPoses() -> Int {
        return scanResults.values.filter { $0.status == .completed }.count
    }
}

// MARK: - Supporting Types

extension ScanProgressService {
    
    enum ScanError: LocalizedError {
        case noCurrentPose
        case notScanning
        case invalidPoseIndex
        
        var errorDescription: String? {
            switch self {
            case .noCurrentPose:
                return "No current pose available"
            case .notScanning:
                return "Scan sequence is not active"
            case .invalidPoseIndex:
                return "Invalid pose index"
            }
        }
    }
}