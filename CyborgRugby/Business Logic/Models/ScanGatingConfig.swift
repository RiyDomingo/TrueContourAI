//
//  ScanGatingConfig.swift
//  CyborgRugby
//
//  Configuration for pose stability gating thresholds.
//

import Foundation

struct ScanGatingConfig {
    let requiredConsecutiveValid: Int
    let requiredAssimilatedFrames: Int

    static let `default` = ScanGatingConfig(
        requiredConsecutiveValid: 5,
        requiredAssimilatedFrames: 60
    )

    static func resolved() -> ScanGatingConfig {
        #if DEBUG
        let defaults = UserDefaults.standard
        let valid = defaults.integer(forKey: "scan.requiredValid")
        let frames = defaults.integer(forKey: "scan.requiredFrames")
        let requiredValid = max(1, valid == 0 ? ScanGatingConfig.default.requiredConsecutiveValid : valid)
        let requiredFrames = max(1, frames == 0 ? ScanGatingConfig.default.requiredAssimilatedFrames : frames)
        return ScanGatingConfig(requiredConsecutiveValid: requiredValid,
                                requiredAssimilatedFrames: requiredFrames)
        #else
        return .default
        #endif
    }
}

