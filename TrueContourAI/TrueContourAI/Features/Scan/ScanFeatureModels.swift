import AVFoundation
import CoreGraphics
import SceneKit
import simd
import StandardCyborgFusion
import UIKit

enum ScanState: Equatable {
    case idle
    case requestingPermission
    case unavailable(ScanUnavailableViewData)
    case ready(ScanReadyViewData)
    case countdown(ScanCapturingViewData)
    case capturing(ScanCapturingViewData)
    case finishing(ScanCapturingViewData)
    case completed(ScanPreviewInput)
    case failed(ScanFailureViewData)

    static func == (lhs: ScanState, rhs: ScanState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.requestingPermission, .requestingPermission):
            return true
        case let (.unavailable(lhs), .unavailable(rhs)):
            return lhs == rhs
        case let (.ready(lhs), .ready(rhs)):
            return lhs == rhs
        case let (.countdown(lhs), .countdown(rhs)),
             let (.capturing(lhs), .capturing(rhs)),
             let (.finishing(lhs), .finishing(rhs)):
            return lhs == rhs
        case let (.failed(lhs), .failed(rhs)):
            return lhs == rhs
        case let (.completed(lhs), .completed(rhs)):
            return lhs.pointCloud === rhs.pointCloud &&
                lhs.meshTexturing === rhs.meshTexturing &&
                lhs.earVerificationImage === rhs.earVerificationImage &&
                lhs.earVerificationSelectionMetadata?.source == rhs.earVerificationSelectionMetadata?.source &&
                lhs.earVerificationSelectionMetadata?.frameIndex == rhs.earVerificationSelectionMetadata?.frameIndex
        default:
            return false
        }
    }
}

struct ScanReadyViewData: Equatable {
    let promptText: String
    let focusHintText: String?
    let finishButtonVisible: Bool
    let finishButtonEnabled: Bool
    let dismissButtonEnabled: Bool
    let developerDiagnosticsText: String?
}

struct ScanCapturingViewData: Equatable {
    let promptText: String
    let guidanceChipText: String?
    let guidanceChipStyle: GuidanceChipStyle
    let focusHintText: String?
    let progressText: String?
    let progressFraction: Float?
    let countdownText: String?
    let finishButtonVisible: Bool
    let finishButtonEnabled: Bool
    let dismissButtonEnabled: Bool
    let developerDiagnosticsText: String?
    let thermalWarningVisible: Bool
}

struct ScanUnavailableViewData: Equatable {
    let title: String
    let message: String
}

struct ScanFailureViewData: Equatable {
    let title: String
    let message: String
    let allowsRetry: Bool
}

enum GuidanceChipStyle: Equatable {
    case neutral
    case caution
    case warning
    case good
}

enum ScanAction {
    case viewDidAppear
    case viewWillDisappear
    case startSession
    case dismissTapped
    case finishTapped
    case focusRequested(CGPoint)
    case countdownTick(Int)
    case captureEvent(ScanCaptureEvent)
    case runtimeEvent(ScanRuntimeEvent)
}

enum ScanEffect: Equatable {
    case alert(title: String, message: String, identifier: String)
    case dismiss
    case hapticPrimary
}

enum ScanCaptureEvent {
    case started
    case authorizationDenied
    case configurationFailed(String)
    case interrupted
    case resumed
    case frame(ScanFramePayload)
    case stopped
}

enum ScanRuntimeEvent {
    case sessionReady
    case guidance(ScanGuidanceSignal)
    case progress(ScanProgressSnapshot)
    case thermalWarning
    case thermalShutdown
    case completed(ScanPreviewInput)
    case failed(ScanFailure)
}

struct ScanFramePayload {
    let colorBuffer: CVPixelBuffer
    let depthBuffer: CVPixelBuffer
    let timestamp: TimeInterval
    let intrinsics: simd_float3x3?
    let orientation: UIInterfaceOrientation
    let calibrationData: AVCameraCalibrationData
}

struct ScanGuidanceSignal: Equatable {
    let promptText: String
    let chipText: String?
    let chipStyle: GuidanceChipStyle
    let focusHintText: String?
}

struct ScanProgressSnapshot: Equatable {
    let capturedSeconds: Int
    let targetSeconds: Int
    let progressFraction: Float
    let manualFinishAllowed: Bool
    let developerDiagnosticsText: String?
}

enum ScanFailure: Error, Equatable {
    case captureConfigurationFailed(String)
    case cameraAccessDenied
    case thermalShutdown
    case reconstructionFailed(String)
    case canceled
}

struct ScanCaptureConfiguration: Equatable {
    let maxDepthResolution: Int
    let textureSaveInterval: Int
    let developerModeEnabled: Bool
}

struct ScanRuntimeConfiguration: Equatable {
    let processingConfig: SettingsStore.ProcessingConfig
    let texturedMeshEnabled: Bool
    let textureSaveInterval: Int

    static func == (lhs: ScanRuntimeConfiguration, rhs: ScanRuntimeConfiguration) -> Bool {
        lhs.processingConfig.outlierSigma == rhs.processingConfig.outlierSigma &&
            lhs.processingConfig.decimateRatio == rhs.processingConfig.decimateRatio &&
            lhs.processingConfig.cropBelowNeck == rhs.processingConfig.cropBelowNeck &&
            lhs.processingConfig.meshResolution == rhs.processingConfig.meshResolution &&
            lhs.processingConfig.meshSmoothness == rhs.processingConfig.meshSmoothness &&
            lhs.texturedMeshEnabled == rhs.texturedMeshEnabled &&
            lhs.textureSaveInterval == rhs.textureSaveInterval
    }
}

struct ScanRenderFrame {
    let colorBuffer: CVPixelBuffer
    let pointCloud: SCPointCloud?
    let calibrationData: AVCameraCalibrationData
    let viewMatrix: simd_float4x4
}

struct ScanRuntimeDiagnosticsSnapshot {
    let succeededCount: Int
    let lostTrackingCount: Int
    let droppedFrameCount: Int
}

final class ScanInterfaceOrientationSource {
    var current: UIInterfaceOrientation = .portrait
}
