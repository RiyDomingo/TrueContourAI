//
//  ScanResults.swift
//  CyborgRugby
//
//  Data models for scan results and completion status
//

import Foundation
import StandardCyborgFusion

enum ScanStatus: Equatable {
    case completed
    case inProgress
    case failed(Error)
    case cancelled
    case skipped
    
    static func == (lhs: ScanStatus, rhs: ScanStatus) -> Bool {
        switch (lhs, rhs) {
        case (.completed, .completed),
             (.inProgress, .inProgress),
             (.cancelled, .cancelled),
             (.skipped, .skipped):
            return true
        case (.failed, .failed):
            // For failed cases, we consider them equal regardless of the specific error
            // This is a simplification - in practice you might want to compare error types
            return true
        default:
            return false
        }
    }
}

struct ScanResult {
    let pose: HeadScanningPose
    let pointCloud: SCPointCloud?
    let confidence: Float
    let status: ScanStatus
    let timestamp: Date
    let metadata: [String: String]
    let earMetrics: EarMetrics?
}

struct CompleteScanResult {
    let individualScans: [HeadScanningPose: ScanResult]
    let overallQuality: Float
    let timestamp: Date
    let totalScanTime: TimeInterval
    let successfulPoses: Int
    let rugbyFitnessMeasurements: ScrumCapMeasurements
    
    var completionRate: Float {
        let totalPoses = Float(HeadScanningPose.allCases.count)
        return Float(successfulPoses) / totalPoses
    }
    
    var isSuccessful: Bool {
        return completionRate >= 0.7 && overallQuality >= 0.8
    }
    
    var qualityDescription: String {
        switch overallQuality {
        case 0.9...1.0:
            return "Excellent"
        case 0.8..<0.9:
            return "Very Good"
        case 0.7..<0.8:
            return "Good"
        case 0.6..<0.7:
            return "Fair"
        case 0.5..<0.6:
            return "Poor"
        default:
            return "Very Poor"
        }
    }
    
    var debugDescription: String {
        return """
        CompleteScanResult:
        - Completion Rate: \(Int(completionRate * 100))%
        - Overall Quality: \(Int(overallQuality * 100))%
        - Successful Poses: \(successfulPoses)/\(HeadScanningPose.allCases.count)
        - Scan Time: \(String(format: "%.1f", totalScanTime))s
        """
    }
}