import AVFoundation
import QuartzCore
import StandardCyborgUI
import UIKit

protocol ScanCaptureServicing: AnyObject {
    var onEvent: ((ScanCaptureEvent) -> Void)? { get set }
    var diagnosticsSnapshot: CameraDiagnosticsSnapshot { get }
    var isSessionRunning: Bool { get }

    func startSession()
    func stopSession(completion: (() -> Void)?)
    func focus(at location: CGPoint)
}

final class ScanCaptureService: NSObject, ScanCaptureServicing, CameraManagerDelegate {
    var onEvent: ((ScanCaptureEvent) -> Void)?

    var diagnosticsSnapshot: CameraDiagnosticsSnapshot { cameraManager.diagnosticsSnapshot }
    var isSessionRunning: Bool { cameraManager.isSessionRunning }

    private let cameraManager: CameraManaging
    private let orientationProvider: () -> UIInterfaceOrientation
    init(
        cameraManager: CameraManaging,
        configuration: ScanCaptureConfiguration,
        orientationProvider: @escaping () -> UIInterfaceOrientation
    ) {
        self.cameraManager = cameraManager
        self.orientationProvider = orientationProvider
        super.init()
        cameraManager.delegate = self
        cameraManager.configureCaptureSession(maxResolution: configuration.maxDepthResolution)
    }

    func startSession() {
        cameraManager.startSession { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.onEvent?(.started)
            case .notAuthorized:
                self.onEvent?(.authorizationDenied)
            case .configurationFailed:
                self.onEvent?(.configurationFailed(L("scan.start.cameraUnavailable.message")))
            @unknown default:
                self.onEvent?(.configurationFailed(L("scan.start.cameraUnavailable.message")))
            }
        }
    }

    func stopSession(completion: (() -> Void)?) {
        cameraManager.stopSession { [weak self] in
            self?.onEvent?(.stopped)
            completion?()
        }
    }

    func focus(at location: CGPoint) {
        cameraManager.focusOnTap(at: location)
    }

    @objc func cameraDidOutput(colorBuffer: CVPixelBuffer, depthBuffer: CVPixelBuffer, depthCalibrationData: AVCameraCalibrationData) {
        let intrinsics = depthCalibrationData.intrinsicMatrix
        onEvent?(
            .frame(
                ScanFramePayload(
                    colorBuffer: colorBuffer,
                    depthBuffer: depthBuffer,
                    timestamp: CACurrentMediaTime(),
                    intrinsics: intrinsics,
                    orientation: orientationProvider(),
                    calibrationData: depthCalibrationData
                )
            )
        )
    }
}
