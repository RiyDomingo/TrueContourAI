//
//  EarMetrics.swift
//  CyborgRugby
//
//  Stores derived ear measurements for a pose.
//

import Foundation

struct EarMetrics {
    let heightMM: Float
    let widthMM: Float
    let protrusionAngleDeg: Float
    let topToLobeMM: Float
    let confidence: Float
    
    // MARK: - Validation
    
    var isValid: Bool {
        // All measurements should be positive
        guard heightMM > 0, widthMM > 0, topToLobeMM > 0 else { return false }
        
        // Confidence should be between 0 and 1
        guard confidence >= 0.0 && confidence <= 1.0 else { return false }
        
        // Realistic ear size bounds (adult human ears typically 50-70mm height)
        guard heightMM >= 20.0 && heightMM <= 100.0 else { return false }
        guard widthMM >= 15.0 && widthMM <= 80.0 else { return false }
        
        // Protrusion angle should be reasonable (-90 to 90 degrees)
        guard protrusionAngleDeg >= -90.0 && protrusionAngleDeg <= 90.0 else { return false }
        
        return true
    }
    
    init(heightMM: Float, widthMM: Float, protrusionAngleDeg: Float, topToLobeMM: Float, confidence: Float) {
        self.heightMM = max(0, heightMM)
        self.widthMM = max(0, widthMM)
        self.protrusionAngleDeg = max(-90, min(90, protrusionAngleDeg))
        self.topToLobeMM = max(0, topToLobeMM)
        self.confidence = max(0.0, min(1.0, confidence))
    }
}

