import XCTest
import StandardCyborgFusion
import AVFoundation
import CoreMotion
import ObjectiveC.runtime
import StandardCyborgUI
@testable import TrueContourAI

@MainActor
final class ScanCoordinatorTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var settingsStore: SettingsStore!

    override func setUp() {
        super.setUp()
        suiteName = "ScanCoordinatorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        settingsStore = SettingsStore(defaults: defaults)
    }

    override func tearDown() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        settingsStore = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testUnavailableTrueDepthPresentsUnavailableAlert() {
        let presenter = CapturingPresenterViewController()
        let coordinator = ScanCoordinator(
            deviceCapabilityProvider: { false },
            scanningViewControllerFactory: { AppScanningViewController() },
            simulatorProvider: { false }
        )
        let flowState = ScanFlowState()

        coordinator.startScanFlow(
            from: presenter,
            delegate: ScanDelegateSpy(),
            scanFlowState: flowState,
            onPresented: { _ in XCTFail("Should not present scanning VC") }
        )

        let alert = presenter.lastPresented as? UIAlertController
        XCTAssertEqual(alert?.title, L("scan.start.unavailable.title"))
        XCTAssertEqual(flowState.phase, .idle)
    }

    func testScanAssemblerAppliesConfigurationToScanningViewController() {
        var processing = settingsStore.processingConfig
        processing.decimateRatio = 1.25
        processing.meshResolution = 5
        settingsStore.processingConfig = processing
        settingsStore.scanDurationSeconds = 20

        let dependencies = AppDependencies(
            environment: .current,
            settingsStore: settingsStore
        )
        let assembler = ScanAssembler(dependencies: dependencies)

        let scanVC = assembler.makeScanningViewController(
            reconstructionManagerFactory: { _, _, _ in ReconstructionManagerFake() },
            cameraManager: CameraManagerFake(),
            hapticEngine: HapticsFake(),
            backgroundWorkRunner: { work in work() }
        )

        let configuration = assembler.resolvedConfiguration(settingsStore: dependencies.runtimeSettings)

        XCTAssertEqual(scanVC.debug_viewConfiguration.autoFinishSeconds, 20)
        XCTAssertEqual(configuration.captureConfiguration.maxDepthResolution, 256)
        XCTAssertEqual(configuration.captureConfiguration.textureSaveInterval, 12)
        XCTAssertTrue(configuration.requiresManualFinish)
        XCTAssertTrue(configuration.texturedMeshEnabled)
    }

    func testDeniedCameraPresentsCameraAccessAlert() {
        let presenter = CapturingPresenterViewController()
        let coordinator = ScanCoordinator(
            deviceCapabilityProvider: { true },
            scanningViewControllerFactory: { AppScanningViewController() },
            simulatorProvider: { false },
            cameraAuthorizationStatusProvider: { .denied },
            cameraAccessRequester: { _ in XCTFail("Should not request camera access when denied") }
        )
        let flowState = ScanFlowState()

        coordinator.startScanFlow(
            from: presenter,
            delegate: ScanDelegateSpy(),
            scanFlowState: flowState,
            onPresented: { _ in XCTFail("Should not present scanning VC") }
        )

        let alert = presenter.lastPresented as? UIAlertController
        XCTAssertEqual(alert?.title, L("scan.start.cameraDenied.title"))
        XCTAssertEqual(alert?.message, L("scan.start.cameraDenied.message"))
        XCTAssertEqual(flowState.phase, .idle)
    }

    func testUndeterminedCameraRequestsAccessBeforeStarting() {
        let presenter = CapturingPresenterViewController()
        let scanVC = AppScanningViewController()
        var requestedAccess = false
        let coordinator = ScanCoordinator(
            deviceCapabilityProvider: { true },
            scanningViewControllerFactory: { scanVC },
            simulatorProvider: { false },
            cameraAuthorizationStatusProvider: { .notDetermined },
            cameraAccessRequester: { completion in
                requestedAccess = true
                completion(true)
            }
        )
        let flowState = ScanFlowState()
        let exp = expectation(description: "presented after authorization")

        coordinator.startScanFlow(
            from: presenter,
            delegate: ScanDelegateSpy(),
            scanFlowState: flowState,
            onPresented: { presented in
                XCTAssertTrue(requestedAccess)
                XCTAssertTrue(presented === scanVC)
                exp.fulfill()
            }
        )

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(flowState.phase, .scanning)
    }

    func testScanAssemblerUsesLowerResolutionForHighDecimation() {
        var config = settingsStore.processingConfig
        config.decimateRatio = 1.4
        config.meshResolution = 6
        settingsStore.processingConfig = config
        let assembler = makeAssembler()
        let configuration = assembler.resolvedConfiguration(settingsStore: settingsStore)
        XCTAssertEqual(configuration.captureConfiguration.maxDepthResolution, 256)
    }

    func testScanAssemblerUsesLowerResolutionForLowMeshResolution() {
        var config = settingsStore.processingConfig
        config.decimateRatio = 1.0
        config.meshResolution = 5
        settingsStore.processingConfig = config
        let assembler = makeAssembler()
        let configuration = assembler.resolvedConfiguration(settingsStore: settingsStore)
        XCTAssertEqual(configuration.captureConfiguration.maxDepthResolution, 256)
    }

    func testScanAssemblerUsesDefaultResolutionWhenConfigIsBalanced() {
        var config = settingsStore.processingConfig
        config.decimateRatio = 1.2
        config.meshResolution = 6
        settingsStore.processingConfig = config
        let assembler = makeAssembler()
        let configuration = assembler.resolvedConfiguration(settingsStore: settingsStore)
        XCTAssertEqual(configuration.captureConfiguration.maxDepthResolution, 320)
    }

    func testScanAssemblerColorBufferIntervalClampsToMinimum() {
        var config = settingsStore.processingConfig
        config.decimateRatio = 0.1
        settingsStore.processingConfig = config
        let assembler = makeAssembler()
        let configuration = assembler.resolvedConfiguration(settingsStore: settingsStore)
        XCTAssertEqual(configuration.captureConfiguration.textureSaveInterval, 4)
    }

    func testScanAssemblerColorBufferIntervalScalesAndClampsToMaximum() {
        var config = settingsStore.processingConfig
        config.decimateRatio = 3.0
        settingsStore.processingConfig = config
        let assembler = makeAssembler()
        let configuration = assembler.resolvedConfiguration(settingsStore: settingsStore)
        XCTAssertEqual(configuration.captureConfiguration.textureSaveInterval, 20)
    }

    private func makeAssembler() -> ScanAssembler {
        ScanAssembler(
            dependencies: AppDependencies(
                environment: .current,
                settingsStore: settingsStore
            )
        )
    }
}

private final class CapturingPresenterViewController: UIViewController {
    private(set) var lastPresented: UIViewController?

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        lastPresented = viewControllerToPresent
        completion?()
    }
}

private final class ScanDelegateSpy: NSObject, AppScanningViewControllerDelegate {
    func appScanningViewControllerDidCancel(_ controller: AppScanningViewController) {}

    func appScanningViewController(
        _ controller: AppScanningViewController,
        didCompleteScan payload: ScanPreviewInput
    ) {}

    func appScanningViewController(
        _ controller: AppScanningViewController,
        didScan pointCloud: SCPointCloud,
        meshTexturing: SCMeshTexturing
    ) {}
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

    func configureCaptureSession(maxResolution: Int) {}

    func startSession(_ completion: ((CameraManager.SessionSetupResult) -> Void)?) {
        completion?(.success)
    }

    func stopSession(_ completion: (() -> Void)?) {
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
