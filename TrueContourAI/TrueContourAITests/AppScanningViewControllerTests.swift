import XCTest
import AVFoundation
import CoreMotion
import StandardCyborgFusion
import StandardCyborgUI
@testable import TrueContourAI

@MainActor
final class AppScanningViewControllerTests: XCTestCase {
    func testStopScanningCancelPathTriggersDelegateCancel() {
        let reconstruction = ReconstructionManagerFake()
        let camera = CameraManagerFake()
        let haptics = HapticsFake()
        let delegate = ScanningDelegateSpy()

        let vc = makeController(reconstruction: reconstruction, camera: camera, haptics: haptics)
        vc.delegate = delegate
        vc.debug_setStateScanning()

        vc.debug_stopScanning(reason: .canceled)

        XCTAssertEqual(delegate.cancelCount, 1)
        XCTAssertEqual(delegate.scanCount, 0)
        XCTAssertEqual(reconstruction.resetCount, 1)
        XCTAssertEqual(haptics.cancelCount, 1)
    }

    func testStopScanningFinishPathFinalizesCallsDidScanAndResetsState() {
        let reconstruction = ReconstructionManagerFake()
        let camera = CameraManagerFake()
        let haptics = HapticsFake()
        let delegate = ScanningDelegateSpy()

        let vc = makeController(reconstruction: reconstruction, camera: camera, haptics: haptics)
        vc.delegate = delegate
        vc.debug_setStateScanning()

        vc.debug_stopScanning(reason: .finished)

        XCTAssertEqual(reconstruction.finalizeCount, 1)
        XCTAssertEqual(reconstruction.resetCount, 1)
        XCTAssertEqual(delegate.scanCount, 1)
        XCTAssertEqual(delegate.cancelCount, 0)
        XCTAssertEqual(camera.stopSessionCount, 1)
        XCTAssertEqual(haptics.finishCount, 1)

        vc.debug_stopScanning(reason: .canceled)
        XCTAssertEqual(delegate.cancelCount, 0)
    }

    func testReconstructionErrorPathCancelsFlow() {
        let reconstruction = ReconstructionManagerFake()
        let camera = CameraManagerFake()
        let haptics = HapticsFake()
        let delegate = ScanningDelegateSpy()

        let vc = makeController(reconstruction: reconstruction, camera: camera, haptics: haptics)
        vc.delegate = delegate
        vc.debug_setStateScanning()

        vc.debug_handleReconstructionError(TestError.synthetic)

        XCTAssertEqual(delegate.cancelCount, 1)
        XCTAssertEqual(delegate.scanCount, 0)
        XCTAssertEqual(reconstruction.resetCount, 1)
    }

    func testFinishWithoutCalibrationDoesNotCrashAndCallsDidScan() {
        let reconstruction = ReconstructionManagerFake()
        reconstruction.latestCameraCalibrationData = nil
        let camera = CameraManagerFake()
        let haptics = HapticsFake()
        let delegate = ScanningDelegateSpy()

        let vc = makeController(reconstruction: reconstruction, camera: camera, haptics: haptics)
        vc.delegate = delegate
        vc.debug_setStateScanning()

        vc.debug_stopScanning(reason: .finished)

        XCTAssertEqual(delegate.scanCount, 1)
        XCTAssertEqual(delegate.cancelCount, 0)
        XCTAssertEqual(reconstruction.finalizeCount, 1)
        XCTAssertEqual(reconstruction.resetCount, 1)
    }

    func testDoubleStopIsIdempotentAfterFinish() {
        let reconstruction = ReconstructionManagerFake()
        let camera = CameraManagerFake()
        let haptics = HapticsFake()
        let delegate = ScanningDelegateSpy()

        let vc = makeController(reconstruction: reconstruction, camera: camera, haptics: haptics)
        vc.delegate = delegate
        vc.debug_setStateScanning()

        vc.debug_stopScanning(reason: .finished)
        vc.debug_stopScanning(reason: .canceled)
        vc.debug_stopScanning(reason: .finished)

        XCTAssertEqual(delegate.scanCount, 1)
        XCTAssertEqual(delegate.cancelCount, 0)
        XCTAssertEqual(reconstruction.finalizeCount, 1)
        XCTAssertEqual(reconstruction.resetCount, 1)
    }

    func testViewWillDisappearDuringScanCancelsAndResets() {
        let reconstruction = ReconstructionManagerFake()
        let camera = CameraManagerFake()
        let haptics = HapticsFake()
        let delegate = ScanningDelegateSpy()

        let vc = makeController(reconstruction: reconstruction, camera: camera, haptics: haptics)
        vc.delegate = delegate
        vc.loadViewIfNeeded()
        vc.debug_setStateScanning()

        vc.debug_triggerViewWillDisappear()

        XCTAssertEqual(delegate.cancelCount, 1)
        XCTAssertEqual(delegate.scanCount, 0)
        XCTAssertEqual(reconstruction.resetCount, 1)
        XCTAssertEqual(camera.stopSessionCount, 1)
    }

    private func makeController(
        reconstruction: ReconstructionManaging,
        camera: CameraManaging,
        haptics: ScanningHapticFeedbackProviding
    ) -> AppScanningViewController {
        AppScanningViewController(
            reconstructionManagerFactory: { _, _, _ in reconstruction },
            cameraManager: camera,
            hapticEngine: haptics
        )
    }
}

private enum TestError: Error {
    case synthetic
}

private final class ScanningDelegateSpy: NSObject, AppScanningViewControllerDelegate {
    private(set) var cancelCount = 0
    private(set) var scanCount = 0

    func appScanningViewControllerDidCancel(_ controller: AppScanningViewController) {
        cancelCount += 1
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
    var latestCameraCalibrationData: AVCameraCalibrationData!
    var latestCameraCalibrationFrameWidth = 1
    var latestCameraCalibrationFrameHeight = 1

    private(set) var resetCount = 0
    private(set) var finalizeCount = 0

    func reset() {
        resetCount += 1
    }

    func finalize(_ completion: @escaping () -> Void) {
        finalizeCount += 1
        completion()
    }

    func buildPointCloud() -> SCPointCloud {
        placeholderPointCloud()
    }

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
        // Tests only assert callback flow and do not inspect point cloud contents.
        placeholderObject(SCPointCloud.self)
    }

    private func placeholderObject<T: AnyObject>(_ type: T.Type) -> T {
        unsafeBitCast(NSObject(), to: T.self)
    }
}

private final class CameraManagerFake: CameraManaging {
    weak var delegate: CameraManagerDelegate!
    private(set) var stopSessionCount = 0

    func configureCaptureSession(maxResolution: Int) {}

    func startSession(_ completion: ((CameraManager.SessionSetupResult) -> Void)?) {
        completion?(.success)
    }

    func stopSession(_ completion: (() -> Void)?) {
        stopSessionCount += 1
        completion?()
    }

    func focusOnTap(at location: CGPoint) {}
}

private final class HapticsFake: ScanningHapticFeedbackProviding {
    private(set) var finishCount = 0
    private(set) var cancelCount = 0

    func countdownCountedDown() {}
    func scanningBegan() {}

    func scanningFinished() {
        finishCount += 1
    }

    func scanningCanceled() {
        cancelCount += 1
    }
}
