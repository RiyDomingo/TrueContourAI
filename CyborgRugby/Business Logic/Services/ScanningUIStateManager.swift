//
//  ScanningUIStateManager.swift
//  CyborgRugby
//
//  Manages UI state and updates during scanning process
//

import UIKit
import OSLog

@MainActor
protocol ScanningUIStateManagerDelegate: AnyObject {
    func stateManager(_ manager: ScanningUIStateManager, didUpdateUI state: ScanningUIState)
    func stateManager(_ manager: ScanningUIStateManager, shouldShowAchievement achievement: String)
}

@MainActor
class ScanningUIStateManager: ObservableObject {
    
    // MARK: - Properties
    
    weak var delegate: ScanningUIStateManagerDelegate?
    
    @Published private(set) var currentState: ScanningUIState = .idle
    @Published private(set) var currentPose: HeadScanningPose = .frontFacing
    @Published private(set) var completedPoses: Set<HeadScanningPose> = []
    @Published private(set) var scanningProgress: Float = 0.0
    @Published private(set) var elapsedTime: TimeInterval = 0.0
    
    private var scanStartTime: Date?
    private var poseStartTime: Date?
    private var timer: Timer?
    
    // UI feedback state
    private var isShowingPerfectPoseFeedback = false
    private var isShowingStabilityFeedback = false
    
    // MARK: - Public Methods
    
    func startScanning() {
        guard currentState == .idle else { return }
        
        scanStartTime = Date()
        poseStartTime = Date()
        updateState(.scanning)
        startTimer()
        
        AppLog.ui.info("Started scanning UI state")
    }
    
    func stopScanning() {
        guard currentState != .idle else { return }
        
        updateState(.idle)
        stopTimer()
        
        AppLog.ui.info("Stopped scanning UI state")
    }
    
    func updateCurrentPose(_ pose: HeadScanningPose) {
        currentPose = pose
        poseStartTime = Date()
        updateState(.waitingForValidPose)
        
        AppLog.ui.info("Updated current pose to: \(pose.rawValue)")
    }
    
    func completePose(_ pose: HeadScanningPose) {
        completedPoses.insert(pose)
        updateProgress()
        
        // Check if all required poses are completed
        let allPoses = Set(HeadScanningPose.allCases)
        if completedPoses == allPoses {
            updateState(.completed)
            stopTimer()
        } else {
            // Move to next pose
            let nextPose = getNextPose()
            updateCurrentPose(nextPose)
        }
        
        AppLog.ui.info("Completed pose: \(pose.rawValue), progress: \(self.scanningProgress)")
    }
    
    func updatePoseValidation(isValid: Bool, confidence: Float) {
        if isValid && confidence > 0.8 {
            updateState(.validPose)
        } else {
            updateState(.waitingForValidPose)
        }
    }
    
    func updateStability(isStable: Bool) {
        isShowingStabilityFeedback = !isStable
        
        if isStable && currentState == .validPose {
            updateState(.capturingPose)
        }
    }
    
    func showPerfectPoseFeedback() {
        isShowingPerfectPoseFeedback = true
        
        // Hide feedback after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isShowingPerfectPoseFeedback = false
        }
    }
    
    // MARK: - Private Methods
    
    private func updateState(_ newState: ScanningUIState) {
        let oldState = currentState
        currentState = newState
        
        AppLog.ui.debug("UI state changed: \(String(describing: oldState)) -> \(String(describing: newState))")
        delegate?.stateManager(self, didUpdateUI: newState)
    }
    
    private func updateProgress() {
        let totalPoses = HeadScanningPose.allCases.count
        self.scanningProgress = Float(self.completedPoses.count) / Float(totalPoses)
    }
    
    private func getNextPose() -> HeadScanningPose {
        let allPoses = HeadScanningPose.allCases
        let remainingPoses = allPoses.filter { !completedPoses.contains($0) }
        return remainingPoses.first ?? .frontFacing
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateElapsedTime() {
        guard let startTime = scanStartTime else { return }
        elapsedTime = Date().timeIntervalSince(startTime)
    }
}

// MARK: - Supporting Types

enum ScanningUIState: Equatable {
    case idle
    case scanning
    case waitingForValidPose
    case validPose
    case capturingPose
    case completed
    case error(String)
    
    var instruction: String {
        switch self {
        case .idle:
            return "Ready to start scanning"
        case .scanning:
            return "Position your head for scanning"
        case .waitingForValidPose:
            return "Adjust your head position"
        case .validPose:
            return "Hold steady..."
        case .capturingPose:
            return "Capturing pose data..."
        case .completed:
            return "Scan complete!"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var statusHint: String? {
        switch self {
        case .waitingForValidPose:
            return "Look straight ahead and center your face"
        case .validPose:
            return "Perfect! Hold this position"
        case .capturingPose:
            return "Stay still while capturing..."
        default:
            return nil
        }
    }
    
    var showProgressIndicators: Bool {
        switch self {
        case .scanning, .waitingForValidPose, .validPose, .capturingPose:
            return true
        default:
            return false
        }
    }
}