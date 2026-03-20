import AVFoundation
import CoreMotion
import ObjectiveC.runtime
import StandardCyborgUI
import XCTest
import StandardCyborgFusion
@testable import TrueContourAI

@MainActor
final class AppScanningViewControllerTests: XCTestCase {
    func testSheetProfileCompactsOnSmallHeight() {
        let profile = AppScanningViewController.debug_scanSheetProfile(height: 680, isPad: false)
        XCTAssertEqual(profile.collapsed, 168)
        XCTAssertEqual(profile.half, 236)
        XCTAssertEqual(profile.full, 300)
    }

    func testSheetProfileUsesPadPreset() {
        let profile = AppScanningViewController.debug_scanSheetProfile(height: 1024, isPad: true)
        XCTAssertEqual(profile.collapsed, 180)
        XCTAssertEqual(profile.half, 250)
        XCTAssertEqual(profile.full, 320)
    }

    func testViewDidAppearStartsCaptureSessionAndReachesReadyState() {
        let camera = CameraManagerFake()
        let vc = makeController(camera: camera, reconstruction: ReconstructionManagerFake())
        vc.loadViewIfNeeded()

        vc.beginAppearanceTransition(true, animated: false)
        vc.endAppearanceTransition()

        XCTAssertEqual(camera.startSessionCount, 1)
        guard case .ready = vc.debug_scanState() else {
            return XCTFail("Expected ready state after session start")
        }
    }

    func testFinishingRoutesCompletionPayloadToDelegate() {
        let camera = CameraManagerFake()
        let delegate = ScanningDelegateSpy()
        let vc = makeController(
            camera: camera,
            reconstruction: ReconstructionManagerFake(),
            autoFinishSeconds: 0,
            requiresManualFinish: true
        )
        vc.delegate = delegate
        vc.loadViewIfNeeded()

        vc.beginAppearanceTransition(true, animated: false)
        vc.endAppearanceTransition()
        vc.shutterTapped(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(2.6))
        vc.finishScanNow()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        XCTAssertEqual(delegate.completedPayloads.count, 1)
        XCTAssertEqual(delegate.scanCount, 1)
        XCTAssertEqual(camera.stopSessionCount, 1)
    }

    func testDismissRoutesCancelDelegate() {
        let delegate = ScanningDelegateSpy()
        let vc = makeController(camera: CameraManagerFake(), reconstruction: ReconstructionManagerFake())
        vc.delegate = delegate
        vc.loadViewIfNeeded()

        vc.beginAppearanceTransition(true, animated: false)
        vc.endAppearanceTransition()
        vc.perform(Selector(("dismissTapped")))

        XCTAssertEqual(delegate.cancelCount, 1)
    }

    func testDismissDuringCountdownRoutesCancelDelegate() {
        let camera = CameraManagerFake()
        let delegate = ScanningDelegateSpy()
        let vc = makeController(camera: camera, reconstruction: ReconstructionManagerFake())
        vc.delegate = delegate
        vc.loadViewIfNeeded()

        vc.beginAppearanceTransition(true, animated: false)
        vc.endAppearanceTransition()
        vc.shutterTapped(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        vc.perform(Selector(("dismissTapped")))

        XCTAssertEqual(delegate.cancelCount, 1)
    }

    private func makeController(
        camera: CameraManaging,
        reconstruction: ReconstructionManaging,
        autoFinishSeconds: Int = 0,
        requiresManualFinish: Bool = false
    ) -> AppScanningViewController {
        AppScanningViewController(
            reconstructionManagerFactory: { _, _, _ in reconstruction },
            cameraManager: camera,
            hapticEngine: HapticsFake(),
            autoFinishSeconds: autoFinishSeconds,
            requiresManualFinish: requiresManualFinish,
            backgroundWorkRunner: { work in work() }
        )
    }
}

private final class ScanningDelegateSpy: NSObject, AppScanningViewControllerDelegate {
    private(set) var cancelCount = 0
    private(set) var scanCount = 0
    private(set) var completedPayloads: [ScanPreviewInput] = []

    func appScanningViewControllerDidCancel(_ controller: AppScanningViewController) {
        cancelCount += 1
    }

    func appScanningViewController(_ controller: AppScanningViewController, didCompleteScan payload: ScanPreviewInput) {
        completedPayloads.append(payload)
    }

    func appScanningViewController(
        _ controller: AppScanningViewController,
        didScan pointCloud: SCPointCloud,
        meshTexturing: SCMeshTexturing
    ) {
        scanCount += 1
    }
}

private final class ReconstructionManagerFake: ReconstructionManaging {
    weak var delegate: SCReconstructionManagerDelegate?
    var includesColorBuffersInMetadata = false
    var latestCameraCalibrationData: AVCameraCalibrationData?
    var latestCameraCalibrationFrameWidth = 1
    var latestCameraCalibrationFrameHeight = 1

    func reset() {}
    func finalize(_ completion: @escaping () -> Void) { completion() }
    func buildPointCloud() -> SCPointCloud { placeholderPointCloud() }
    func buildPointCloudSnapshot() -> SCPointCloud? { placeholderPointCloud() }

    func reconstructSingleDepthBuffer(
        _ depthBuffer: CVPixelBuffer,
        colorBuffer: CVPixelBuffer?,
        with calibrationData: AVCameraCalibrationData,
        smoothingPoints: Bool
    ) -> SCPointCloud {
        placeholderPointCloud()
    }

    func accumulate(depthBuffer: CVPixelBuffer, colorBuffer: CVPixelBuffer, calibrationData: AVCameraCalibrationData) {}
    func accumulateDeviceMotion(_ motion: CMDeviceMotion) {}

    private func placeholderPointCloud() -> SCPointCloud {
        guard let placeholder = class_createInstance(SCPointCloud.self, 0) as? SCPointCloud else {
            fatalError("Failed to allocate SCPointCloud placeholder")
        }
        return placeholder
    }
}

private final class CameraManagerFake: CameraManaging {
    weak var delegate: CameraManagerDelegate?
    var isSessionRunning = true
    var diagnosticsSnapshot = CameraDiagnosticsSnapshot()
    private(set) var startSessionCount = 0
    private(set) var stopSessionCount = 0

    func configureCaptureSession(maxResolution: Int) {}

    func startSession(_ completion: ((CameraManager.SessionSetupResult) -> Void)?) {
        startSessionCount += 1
        completion?(.success)
    }

    func stopSession(_ completion: (() -> Void)?) {
        stopSessionCount += 1
        completion?()
    }

    func focusOnTap(at location: CGPoint) {}
}

private final class HapticsFake: ScanningHapticFeedbackProviding {
    func countdownCountedDown() {}
    func scanningBegan() {}
    func scanningFinished() {}
    func scanningCanceled() {}
}
