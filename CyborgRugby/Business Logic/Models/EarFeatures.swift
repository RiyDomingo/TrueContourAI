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
}

