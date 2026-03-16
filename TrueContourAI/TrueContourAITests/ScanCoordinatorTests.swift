import XCTest
import StandardCyborgFusion
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
            settingsStore: settingsStore,
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

    func testStartScanFlowAppliesConfigurationToScanningViewController() {
        var processing = settingsStore.processingConfig
        processing.decimateRatio = 1.25
        processing.meshResolution = 5
        settingsStore.processingConfig = processing
        settingsStore.scanDurationSeconds = 20

        let presenter = CapturingPresenterViewController()
        let scanVC = AppScanningViewController()
        let coordinator = ScanCoordinator(
            settingsStore: settingsStore,
            deviceCapabilityProvider: { true },
            scanningViewControllerFactory: { scanVC },
            simulatorProvider: { false },
            cameraAuthorizationStatusProvider: { .authorized }
        )

        let flowState = ScanFlowState()
        let exp = expectation(description: "presented")

        coordinator.startScanFlow(
            from: presenter,
            delegate: ScanDelegateSpy(),
            scanFlowState: flowState,
            onPresented: { presented in
                XCTAssertTrue(presented === scanVC)
                XCTAssertEqual(presented.autoFinishSeconds, 20)
                XCTAssertTrue(presented.requiresManualFinish)
                XCTAssertTrue(presented.generatesTexturedMeshes)
                XCTAssertEqual(presented.maxDepthResolution, 256)
                XCTAssertEqual(presented.texturedMeshColorBufferSaveInterval, 10)
                exp.fulfill()
            }
        )

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(flowState.phase, .scanning)
    }

    func testDeniedCameraPresentsCameraAccessAlert() {
        let presenter = CapturingPresenterViewController()
        let coordinator = ScanCoordinator(
            settingsStore: settingsStore,
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
            settingsStore: settingsStore,
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

    func testSuggestedDepthResolutionUsesLowerResolutionForHighDecimation() {
        var config = settingsStore.processingConfig
        config.decimateRatio = 1.4
        config.meshResolution = 6
        let coordinator = ScanCoordinator(settingsStore: settingsStore)
        XCTAssertEqual(coordinator.debug_suggestedDepthResolution(for: config), 256)
    }

    func testSuggestedDepthResolutionUsesLowerResolutionForLowMeshResolution() {
        var config = settingsStore.processingConfig
        config.decimateRatio = 1.0
        config.meshResolution = 5
        let coordinator = ScanCoordinator(settingsStore: settingsStore)
        XCTAssertEqual(coordinator.debug_suggestedDepthResolution(for: config), 256)
    }

    func testSuggestedDepthResolutionUsesDefaultWhenConfigIsBalanced() {
        var config = settingsStore.processingConfig
        config.decimateRatio = 1.2
        config.meshResolution = 6
        let coordinator = ScanCoordinator(settingsStore: settingsStore)
        XCTAssertEqual(coordinator.debug_suggestedDepthResolution(for: config), 320)
    }

    func testSuggestedColorBufferIntervalClampsToMinimum() {
        var config = settingsStore.processingConfig
        config.decimateRatio = 0.1
        let coordinator = ScanCoordinator(settingsStore: settingsStore)
        XCTAssertEqual(coordinator.debug_suggestedColorBufferInterval(for: config), 4)
    }

    func testSuggestedColorBufferIntervalScalesAndClampsToMaximum() {
        var config = settingsStore.processingConfig
        config.decimateRatio = 3.0
        let coordinator = ScanCoordinator(settingsStore: settingsStore)
        XCTAssertEqual(coordinator.debug_suggestedColorBufferInterval(for: config), 16)
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
