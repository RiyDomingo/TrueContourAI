//
//  PoseDetectionService.swift
//  CyborgRugby
//
//  Dedicated pose detection and validation service
//

import UIKit
import Vision
import CoreML
import OSLog
import CoreMotion
import Foundation

@MainActor
protocol PoseDetectionServiceDelegate: AnyObject {
    func poseDetectionService(_ service: PoseDetectionService, didValidatePose pose: HeadScanningPose, isValid: Bool, confidence: Float)
    func poseDetectionService(_ service: PoseDetectionService, didUpdateStability isStable: Bool)
    func poseDetectionService(_ service: PoseDetectionService, didDetectPerfectPose pose: HeadScanningPose)
}

@MainActor
class PoseDetectionService: NSObject {
    
    // MARK: - Properties
    
    weak var delegate: PoseDetectionServiceDelegate?
    
    private let poseValidator: MLEnhancedPoseValidator
    private let motionManager = CMMotionManager()
    private let gatingConfig: ScanGatingConfig
    
    // Pose state tracking
    private var currentPose: HeadScanningPose = .frontFacing
    private var consecutiveValidCount: Int = 0
    private var isPerfectPose = false
    private var poseStartTime: Date?
    private var perfectPoseTimer: Timer?
    
    // Motion stability
    private var isMotionStable = false
    private let stabilityThreshold: Double = 0.1
    private var recentMotionReadings: [CMAcceleration] = []
    private let maxMotionReadings = 10
    
    // MARK: - Initialization
    
    init(gatingConfig: ScanGatingConfig = .resolved()) {
        self.gatingConfig = gatingConfig
        self.poseValidator = MLEnhancedPoseValidator()
        
        super.init()
        
        setupMotionTracking()
        poseValidator.startInitialization()
    }
    
    deinit {
        // Cannot access MainActor methods/properties from deinit in Swift 6
        // Motion manager and timer will be cleaned up by ARC
    }
    
    // MARK: - Public Methods
    
    func updateCurrentPose(_ pose: HeadScanningPose) {
        currentPose = pose
        consecutiveValidCount = 0
        isPerfectPose = false
        poseStartTime = Date()
        perfectPoseTimer?.invalidate()
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        Task {
            await validatePoseInFrame(pixelBuffer)
        }
    }
    
    func startMotionTracking() {
        guard motionManager.isDeviceMotionAvailable else {
            AppLog.scanning.warning("Device motion not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.processMotionUpdate(motion)
        }
        
        AppLog.scanning.info("Motion tracking started")
    }
    
    func stopMotionTracking() {
        motionManager.stopDeviceMotionUpdates()
        perfectPoseTimer?.invalidate()
        AppLog.scanning.info("Motion tracking stopped")
    }
    
    // MARK: - Private Methods
    
    private func setupMotionTracking() {
        // Motion tracking will be started when needed
    }
    
    private func validatePoseInFrame(_ pixelBuffer: CVPixelBuffer) async {
        let result = await poseValidator.validatePose(currentPose, in: pixelBuffer)
        
        await MainActor.run {
            processPoseValidationResult(result)
        }
    }
    
    private func processPoseValidationResult(_ result: PoseValidationResult) {
        let minConfidenceThreshold: Float = 0.8 // Default confidence threshold
        let isValid = result.isValid && result.confidence >= minConfidenceThreshold
        
        if isValid {
            consecutiveValidCount += 1
            
            if consecutiveValidCount >= gatingConfig.requiredConsecutiveValid && isMotionStable {
                if !isPerfectPose {
                    isPerfectPose = true
                    startPerfectPoseTimer()
                    delegate?.poseDetectionService(self, didDetectPerfectPose: currentPose)
                }
            }
        } else {
            consecutiveValidCount = 0
            isPerfectPose = false
            perfectPoseTimer?.invalidate()
        }
        
        delegate?.poseDetectionService(self, didValidatePose: currentPose, isValid: isValid, confidence: result.confidence)
    }
    
    private func processMotionUpdate(_ motion: CMDeviceMotion) {
        let acceleration = motion.userAcceleration
        recentMotionReadings.append(acceleration)
        
        // Keep only recent readings
        if recentMotionReadings.count > maxMotionReadings {
            recentMotionReadings.removeFirst()
        }
        
        // Calculate motion stability
        let wasStable = isMotionStable
        isMotionStable = calculateMotionStability()
        
        if wasStable != isMotionStable {
            delegate?.poseDetectionService(self, didUpdateStability: isMotionStable)
        }
    }
    
    private func calculateMotionStability() -> Bool {
        guard recentMotionReadings.count >= 5 else { return false }
        
        let recentReadings = recentMotionReadings.suffix(5)
        let averageAcceleration = recentReadings.reduce(CMAcceleration(x: 0, y: 0, z: 0)) { result, reading in
            CMAcceleration(
                x: result.x + reading.x / Double(recentReadings.count),
                y: result.y + reading.y / Double(recentReadings.count),
                z: result.z + reading.z / Double(recentReadings.count)
            )
        }
        
        let variance = recentReadings.reduce(0.0) { result, reading in
            let dx = reading.x - averageAcceleration.x
            let dy = reading.y - averageAcceleration.y
            let dz = reading.z - averageAcceleration.z
            return result + (dx * dx + dy * dy + dz * dz) / Double(recentReadings.count)
        }
        
        return sqrt(variance) < stabilityThreshold
    }
    
    private func startPerfectPoseTimer() {
        perfectPoseTimer?.invalidate()
        perfectPoseTimer = nil
        
        // Simplified: Just log immediately when perfect pose is detected
        // The original timer functionality can be restored once Swift compiler issues are resolved
        if isPerfectPose && isMotionStable {
            AppLog.scanning.info("Perfect pose detected: \(String(describing: self.currentPose))")
        }
    }
}

// Note: PoseValidationResult is defined in MLEnhancedPoseValidator.swift