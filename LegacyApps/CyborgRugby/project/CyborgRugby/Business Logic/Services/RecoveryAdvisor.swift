//
//  RecoveryAdvisor.swift
//  CyborgRugby
//
//  Provides simple recovery suggestions based on validation confidence.
//

import Foundation

enum RecoveryAdvice: String {
    case improveLighting = "Lighting looks low. Move to a brighter area or face a light source."
    case reduceMovement = "Hold steady. Sit comfortably and keep your head still."
    case adjustAngleLeft = "Turn a bit more to the left and hold steady."
    case adjustAngleRight = "Turn a bit more to the right and hold steady."
    case tiltDown = "Tilt your head slightly down to show the back of your head."
}

struct RecoveryAdvisor {
    static func suggest(forPose pose: HeadScanningPose, confidence: Float) -> RecoveryAdvice {
        if confidence < 0.3 { return .improveLighting }
        switch pose {
        case .leftProfile: return .adjustAngleLeft
        case .rightProfile: return .adjustAngleRight
        case .lookingDown: return .tiltDown
        default: return .reduceMovement
        }
    }
}

