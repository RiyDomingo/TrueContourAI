import XCTest
import AVFoundation
import CoreMotion
import ObjectiveC.runtime
import StandardCyborgFusion
import StandardCyborgUI
@testable import TrueContourAI

@MainActor
final class AppScanningViewControllerTests: XCTestCase {
    func testIdlePromptStepDoesNotAdvanceWhileScanning() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )
        vc.loadViewIfNeeded()
        vc.debug_setStateDefault()

        XCTAssertTrue(vc.debug_applyNextIdlePromptStep())
        let idleText = vc.debug_guidanceText()
        XCTAssertFalse(idleText?.isEmpty ?? true)

        vc.debug_setStateScanning()
        XCTAssertFalse(vc.debug_applyNextIdlePromptStep())
        XCTAssertEqual(vc.debug_guidanceText(), idleText)
    }

    func testCriticalGuidancePreemptsWithoutCooldownDelay() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )
        vc.loadViewIfNeeded()
        vc.debug_setStateScanning()

        XCTAssertTrue(vc.debug_emitGuidance(named: "start", force: true))
        XCTAssertTrue(vc.debug_emitGuidance(named: "trackingLost"))
        XCTAssertEqual(vc.debug_statusChipText(), "Lost")
    }

    func testGuidanceHysteresisHoldsTransitionsUntilWindowElapsed() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )
        vc.loadViewIfNeeded()
        vc.debug_setStateScanning()

        XCTAssertTrue(vc.debug_emitGuidance(named: "start", force: true))
        XCTAssertFalse(vc.debug_emitGuidance(named: "moveSlower"))
        advance(seconds: 0.65)
        XCTAssertTrue(vc.debug_emitGuidance(named: "moveSlower"))
        XCTAssertEqual(vc.debug_statusChipText(), "Caution")

        XCTAssertFalse(vc.debug_emitGuidance(named: "goodTracking"))
        advance(seconds: 4.2)
        XCTAssertFalse(vc.debug_emitGuidance(named: "goodTracking"))
        advance(seconds: 0.9)
        XCTAssertTrue(vc.debug_emitGuidance(named: "goodTracking"))
        XCTAssertEqual(vc.debug_statusChipText(), "Good")
    }

    func testMotionGuidanceUsesMoveSlowerRatherThanDistanceWarning() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )
        vc.loadViewIfNeeded()
        vc.debug_setStateScanning()

        XCTAssertTrue(vc.debug_handleMotionGuidance(forMagnitudes: [0.20, 0.22, 0.24]))
        XCTAssertEqual(vc.debug_guidanceText(), L("scanning.guidance.short.motion"))
    }

    func testSubthresholdMotionDoesNotEmitWarningGuidance() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )
        vc.loadViewIfNeeded()
        vc.debug_setStateScanning()
        let initialGuidance = vc.debug_guidanceText()

        XCTAssertFalse(vc.debug_handleMotionGuidance(forMagnitudes: [0.04, 0.08, 0.10]))
        XCTAssertEqual(vc.debug_guidanceText(), initialGuidance)
    }

    func testProgressTextStaysModeConsistentPerRun() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )
        vc.loadViewIfNeeded()
        vc.debug_setStateScanning()

        vc.debug_setAutoFinishForProgress(seconds: 20, remaining: 18)
        vc.debug_updateCaptureProgress()
        XCTAssertTrue(vc.debug_progressLabelText()?.contains("2 / 20") == true)

        vc.debug_setAutoFinishForProgress(seconds: 0, remaining: 0)
        vc.debug_setAssimilatedFramesForProgress(12)
        vc.debug_updateCaptureProgress()
        XCTAssertEqual(vc.debug_progressLabelText(), L("scanning.progress.capturing"))
    }

    func testProgressUpdatesAreThrottled() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )
        vc.loadViewIfNeeded()
        vc.debug_setStateScanning()

        vc.debug_setAutoFinishForProgress(seconds: 20, remaining: 18)
        vc.debug_updateCaptureProgress()
        let initialText = vc.debug_progressLabelText()

        vc.debug_setAutoFinishForProgress(seconds: 20, remaining: 10)
        vc.debug_setLastProgressUpdate(Date())
        vc.debug_updateCaptureProgress()

        XCTAssertEqual(vc.debug_progressLabelText(), initialText)
    }

    func testProgressUpdatesResumeAfterThrottleWindowElapses() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )
        vc.loadViewIfNeeded()
        vc.debug_setStateScanning()

        vc.debug_setAutoFinishForProgress(seconds: 20, remaining: 18)
        vc.debug_updateCaptureProgress()
        let initialText = vc.debug_progressLabelText()

        vc.debug_setAutoFinishForProgress(seconds: 20, remaining: 10)
        vc.debug_setLastProgressUpdate(Date(timeIntervalSinceNow: -1))
        vc.debug_updateCaptureProgress()

        XCTAssertNotEqual(vc.debug_progressLabelText(), initialText)
        XCTAssertTrue(vc.debug_progressLabelText()?.contains("10 / 20") == true)
    }

    func testCountdownVisibilityIsIndependentFromActiveGuidance() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )
        vc.loadViewIfNeeded()

        vc.debug_setStateCountdown(seconds: 2)
        XCTAssertFalse(vc.debug_countdownHidden())
        XCTAssertTrue(vc.debug_statusChipHidden())
        XCTAssertTrue(vc.debug_progressHidden())

        vc.debug_setStateScanning()
        XCTAssertTrue(vc.debug_countdownHidden())
        XCTAssertTrue(vc.debug_emitGuidance(named: "goodTracking", force: true))
        XCTAssertFalse(vc.debug_statusChipHidden())
        XCTAssertTrue(vc.debug_progressHidden())
    }

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
        XCTAssertEqual(delegate.completedPayloads.count, 1)
        XCTAssertNil(delegate.completedPayloads[0].earVerificationImage)
        XCTAssertNil(delegate.completedPayloads[0].earVerificationSelectionMetadata)
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
        XCTAssertEqual(delegate.completedPayloads.count, 1)
        XCTAssertNil(delegate.completedPayloads[0].earVerificationImage)
        XCTAssertNil(delegate.completedPayloads[0].earVerificationSelectionMetadata)
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
        XCTAssertEqual(delegate.completedPayloads.count, 1)
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

    func testShutterTapIgnoresInputWhenCameraSessionIsNotRunning() {
        let reconstruction = ReconstructionManagerFake()
        let camera = CameraManagerFake()
        camera.isSessionRunning = false
        let haptics = HapticsFake()
        let delegate = ScanningDelegateSpy()

        let vc = makeController(reconstruction: reconstruction, camera: camera, haptics: haptics)
        vc.delegate = delegate
        vc.debug_setStateScanning()

        vc.shutterTapped(nil)

        XCTAssertEqual(delegate.scanCount, 0)
        XCTAssertEqual(camera.stopSessionCount, 0)
        XCTAssertEqual(haptics.finishCount, 0)
    }

    func testCriticalThermalStateStopsActiveScanBeforeDismissalAlert() {
        let reconstruction = ReconstructionManagerFake()
        let camera = CameraManagerFake()
        let haptics = HapticsFake()
        let delegate = ScanningDelegateSpy()

        let vc = makeController(reconstruction: reconstruction, camera: camera, haptics: haptics)
        vc.delegate = delegate
        vc.loadViewIfNeeded()
        vc.debug_setStateScanning()

        vc.debug_handleCriticalThermalState()

        XCTAssertEqual(reconstruction.finalizeCount, 1)
        XCTAssertEqual(reconstruction.resetCount, 1)
        XCTAssertEqual(delegate.scanCount, 1)
        XCTAssertEqual(camera.stopSessionCount, 1)
        XCTAssertEqual(haptics.finishCount, 1)
    }

    func testDistanceInstabilityGuidanceIsEmittedForTranslationVariance() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )
        vc.loadViewIfNeeded()
        vc.debug_setStateScanning()

        for translation in [0.35 as Float, 0.36, 0.34, 0.45, 0.33, 0.46, 0.34, 0.47] {
            var matrix = matrix_identity_float4x4
            matrix.columns.3.z = translation
            vc.debug_updateDistanceGuidance(with: matrix)
        }

        XCTAssertEqual(vc.debug_guidanceText(), L("scanning.guidance.short.distance"))
    }

    func testDistanceInstabilityGuidanceDoesNotFireForSmallVariance() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )
        vc.loadViewIfNeeded()
        vc.debug_setStateScanning()
        let initialGuidance = vc.debug_guidanceText()

        for translation in [0.35 as Float, 0.355, 0.352, 0.358, 0.351, 0.357, 0.354, 0.356] {
            var matrix = matrix_identity_float4x4
            matrix.columns.3.z = translation
            vc.debug_updateDistanceGuidance(with: matrix)
        }

        XCTAssertEqual(vc.debug_guidanceText(), initialGuidance)
    }

    func testMotionMagnitudeUsesRollingAverage() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )

        let average = vc.debug_smoothedMotionMagnitude([0.10, 0.12, 0.30])
        XCTAssertGreaterThan(average, 0.10)
        XCTAssertLessThan(average, 0.30)
    }

    func testDeveloperDiagnosticsIncludePerformanceMetrics() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )
        vc.developerModeEnabled = true
        vc.debug_recordCameraMetric(duration: 0.010, budget: 0.005)
        vc.debug_recordDrawMetric(duration: 0.006, budget: 0.005)
        vc.debug_recordReconstructionMetric(duration: 0.008, budget: 0.005)

        let diagnostics = vc.debug_developerDiagnosticsText(baseDiagnostics: "Frames: 12 · Progress: 24%")
        XCTAssertTrue(diagnostics.contains("camera"))
        XCTAssertTrue(diagnostics.contains("draw"))
        XCTAssertTrue(diagnostics.contains("recon"))
        XCTAssertTrue(diagnostics.contains("ovr="))
    }

    func testDeveloperDiagnosticsRemainBaseTextWhenDeveloperModeDisabled() {
        let vc = makeController(
            reconstruction: ReconstructionManagerFake(),
            camera: CameraManagerFake(),
            haptics: HapticsFake()
        )
        vc.debug_recordCameraMetric(duration: 0.010, budget: 0.005)
        vc.debug_recordReconstructionMetric(duration: 0.008, budget: 0.005)

        XCTAssertEqual(
            vc.debug_developerDiagnosticsText(baseDiagnostics: "Frames: 12 · Progress: 24%"),
            "Frames: 12 · Progress: 24%"
        )
    }


    func testScanSheetProfileCompactsOnSmallHeight() {
        let profile = AppScanningViewController.debug_scanSheetProfile(height: 680, isPad: false)
        XCTAssertEqual(profile.collapsed, 168)
        XCTAssertEqual(profile.half, 236)
        XCTAssertEqual(profile.full, 300)
    }

    func testScanSheetProfileUsesLargerPresetOnPad() {
        let profile = AppScanningViewController.debug_scanSheetProfile(height: 1024, isPad: true)
        XCTAssertEqual(profile.collapsed, 180)
        XCTAssertEqual(profile.half, 250)
        XCTAssertEqual(profile.full, 320)
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

    private func advance(seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}

private enum TestError: Error {
    case synthetic
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
        guard let placeholder = class_createInstance(SCPointCloud.self, 0) as? SCPointCloud else {
            fatalError("Failed to allocate SCPointCloud test placeholder")
        }
        return placeholder
    }
}

private final class CameraManagerFake: CameraManaging {
    weak var delegate: CameraManagerDelegate!
    var isSessionRunning = true
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
