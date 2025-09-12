//
//  MultiAngleScanManagerDelegate.swift
//  CyborgRugby
//
//  Delegate protocol for multi-angle scan manager coordination
//

import Foundation

// MARK: - Protocol for Refactored Manager
@MainActor
protocol RefactoredMultiAngleScanManagerDelegate: AnyObject {
    func scanManager(_ manager: RefactoredMultiAngleScanManager, didStartPose pose: HeadScanningPose)
    func scanManager(_ manager: RefactoredMultiAngleScanManager, didCompletePose pose: HeadScanningPose, withResult result: ScanResult)
    func scanManager(_ manager: RefactoredMultiAngleScanManager, didFailPose pose: HeadScanningPose, withError error: Error)
    func scanManager(_ manager: RefactoredMultiAngleScanManager, didUpdateProgress progress: Float)
    func scanManager(_ manager: RefactoredMultiAngleScanManager, didFinishAllScans finalResult: CompleteScanResult)
    func scanManager(_ manager: RefactoredMultiAngleScanManager, poseValidationUpdate result: PoseValidationResult, for pose: HeadScanningPose)
}

// MARK: - Generic Protocol (for future flexibility)
@MainActor
protocol AnyScanManagerDelegate: AnyObject {
    func didStartPose(_ pose: HeadScanningPose)
    func didCompletePose(_ pose: HeadScanningPose, withResult result: ScanResult)
    func didFailPose(_ pose: HeadScanningPose, withError error: Error)
    func didUpdateProgress(_ progress: Float)
    func didFinishAllScans(_ finalResult: CompleteScanResult)
    func poseValidationUpdate(_ result: PoseValidationResult, for pose: HeadScanningPose)
}