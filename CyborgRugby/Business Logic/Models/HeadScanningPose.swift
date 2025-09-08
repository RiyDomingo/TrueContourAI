//
//  HeadScanningPose.swift
//  CyborgRugby
//
//  Rugby-specific head scanning poses for scrum cap fitting
//

import Foundation

enum HeadScanningPose: String, CaseIterable {
    case frontFacing = "front_facing"
    case leftProfile = "left_profile"
    case rightProfile = "right_profile"
    case lookingDown = "looking_down"
    case leftThreeQuarter = "left_three_quarter"
    case rightThreeQuarter = "right_three_quarter"
    case chinUp = "chin_up"
    
    var displayName: String {
        switch self {
        case .frontFacing: return "Front View"
        case .leftProfile: return "Left Profile"
        case .rightProfile: return "Right Profile"
        case .lookingDown: return "Looking Down"
        case .leftThreeQuarter: return "Left Back View"
        case .rightThreeQuarter: return "Right Back View"
        case .chinUp: return "Chin Up"
        }
    }
    
    var instructions: String {
        switch self {
        case .frontFacing:
            return "Look straight at the camera, keep your head still"
        case .leftProfile:
            return "Turn your head 90° to the left, hold steady"
        case .rightProfile:
            return "Turn your head 90° to the right, hold steady"
        case .lookingDown:
            return "Tilt your head down 30° - like reading a book in your lap"
        case .leftThreeQuarter:
            return "Turn head 45° left and tilt down slightly"
        case .rightThreeQuarter:
            return "Turn head 45° right and tilt down slightly"
        case .chinUp:
            return "Lift your chin up 15° - like looking at the ceiling"
        }
    }
    
    var detailedGuidance: String {
        switch self {
        case .lookingDown:
            return """
            This captures the back of your head - critical for scrum cap fit.
            1. Sit comfortably with good posture
            2. Slowly tilt your head down until you feel a stretch in your neck
            3. Hold this position steady for 10 seconds
            4. Try to keep your shoulders level
            """
        case .leftProfile:
            return """
            This captures your left ear for protection fitting.
            1. Turn your head exactly 90 degrees to the left
            2. Your left ear should face the camera directly
            3. Keep your head level - don't tilt up or down
            4. Hold steady while we scan
            """
        case .rightProfile:
            return """
            This captures your right ear for protection fitting.
            1. Turn your head exactly 90 degrees to the right
            2. Your right ear should face the camera directly
            3. Keep your head level - don't tilt up or down
            4. Hold steady while we scan
            """
        default:
            return instructions
        }
    }
    
    var scanDuration: TimeInterval {
        switch self {
        case .frontFacing, .leftProfile, .rightProfile:
            return 8.0
        case .lookingDown:
            return 12.0  // Extra time for difficult pose
        case .leftThreeQuarter, .rightThreeQuarter:
            return 6.0
        case .chinUp:
            return 4.0
        }
    }
    
    var difficultyLevel: ScanDifficulty {
        switch self {
        case .frontFacing, .chinUp:
            return .easy
        case .leftProfile, .rightProfile:
            return .medium
        case .leftThreeQuarter, .rightThreeQuarter:
            return .medium
        case .lookingDown:
            return .hard
        }
    }
    
    // ML Model requirements for each pose
    var requiredMLModels: [MLModelType] {
        switch self {
        case .frontFacing:
            return [.earLandmarking, .earTracking] // Both ears visible
        case .leftProfile:
            return [.earLandmarking, .earTracking] // Left ear detailed analysis
        case .rightProfile:
            return [.earLandmarking, .earTracking] // Right ear detailed analysis
        case .leftThreeQuarter, .rightThreeQuarter:
            return [.earTracking] // Ear edge detection
        case .lookingDown, .chinUp:
            return [] // No ear models needed for these poses
        }
    }
    
    // Rugby-specific importance for scrum cap fitting
    var rugbyImportance: RugbyImportance {
        switch self {
        case .frontFacing, .leftProfile, .rightProfile:
            return .critical    // Essential for ear protection
        case .lookingDown:
            return .critical    // Essential for back head coverage
        case .leftThreeQuarter, .rightThreeQuarter:
            return .important   // Important for complete coverage
        case .chinUp:
            return .optional    // Nice to have for chin strap fit
        }
    }
}

enum ScanDifficulty: Int {
    case easy = 1
    case medium = 2
    case hard = 3
    
    var description: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium" 
        case .hard: return "Challenging"
        }
    }
}

enum MLModelType: String {
    case earLandmarking = "SCEarLandmarking"
    case earTracking = "SCEarTracking"
    case footTracking = "SCFootTrackingModel" // Available but not used
    
    var modelFileName: String {
        switch self {
        case .earLandmarking: return "SCEarLandmarking.mlmodel"
        case .earTracking: return "SCEarTrackingModel.mlmodel"
        case .footTracking: return "SCFootTrackingModel.mlmodel"
        }
    }
}

enum RugbyImportance: Int {
    case optional = 1
    case important = 2
    case critical = 3
    
    var description: String {
        switch self {
        case .optional: return "Optional"
        case .important: return "Important"
        case .critical: return "Critical"
        }
    }
    
    var color: String {
        switch self {
        case .optional: return "systemGray"
        case .important: return "systemOrange"
        case .critical: return "systemRed"
        }
    }
}