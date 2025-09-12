//
//  EarFeatures.swift
//  CyborgRugby
//
//  Generic ear feature container from ML outputs.
//

import CoreGraphics

struct EarFeatures {
    let landmarks: [CGPoint]      // normalized [0,1] coordinates
    let boundingBox: CGRect?      // normalized [0,1] rect (x,y,w,h)
    let confidence: Float
    
    // MARK: - Validation
    
    var isValid: Bool {
        // Confidence should be between 0 and 1
        guard confidence >= 0.0 && confidence <= 1.0 else { return false }
        
        // All landmarks should be normalized coordinates (0-1)
        for point in landmarks {
            if point.x < 0 || point.x > 1 || point.y < 0 || point.y > 1 {
                return false
            }
        }
        
        // Bounding box should also be normalized if present
        if let bbox = boundingBox {
            if bbox.minX < 0 || bbox.maxX > 1 || bbox.minY < 0 || bbox.maxY > 1 {
                return false
            }
        }
        
        return true
    }
    
    init(landmarks: [CGPoint], boundingBox: CGRect? = nil, confidence: Float) {
        self.landmarks = landmarks
        self.boundingBox = boundingBox
        self.confidence = max(0.0, min(1.0, confidence)) // Clamp confidence to valid range
    }
}

