import XCTest
import UIKit
import StandardCyborgFusion
@testable import TrueContourAI

@MainActor
final class PreviewCoordinatorTests: XCTestCase {
    private final class TestPresenter: UIViewController {
        var lastPresented: UIViewController?
        var onPresent: (() -> Void)?

        override func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
            lastPresented = viewControllerToPresent
            completion?()
            onPresent?()
        }
    }

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        suiteName = "PreviewCoordinatorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        defaults = nil
        suiteName = nil
        tempDir = nil
        super.tearDown()
    }

    func testPresentExistingScanUsesFactoryInputAndPresentsPreviewViewController() {
        let presenter = TestPresenter()
        let flowState = ScanFlowState()
        let repository = ScanRepository(scansRootURL: tempDir, defaults: defaults)
        let exporter = ScanExporterService(scansRootURL: tempDir, defaults: defaults)
        let settingsStore = SettingsStore(defaults: defaults)
        var capturedInput: PreviewViewController.Input?

        let coordinator = PreviewCoordinator(
            presenter: presenter,
            scanFlowState: flowState,
            previewViewControllerFactory: { input in
                capturedInput = input
                return PreviewViewController(
                    input: input,
                    scanReader: repository,
                    settingsStore: settingsStore,
                    scanFlowState: flowState,
                    previewSessionState: PreviewSessionState(),
                    environment: .current,
                    scanExporter: exporter
                )
            }
        )

        let item = ScanItem(
            folderURL: tempDir.appendingPathComponent("existing", isDirectory: true),
            displayName: "existing",
            date: Date(),
            thumbnailURL: nil,
            sceneGLTFURL: tempDir.appendingPathComponent("existing/scene.gltf")
        )

        coordinator.presentExistingScan(item)

        guard case .existingScan(let capturedItem)? = capturedInput else {
            return XCTFail("Expected existing-scan input")
        }
        XCTAssertEqual(capturedItem.folderURL, item.folderURL)
        XCTAssertTrue(presenter.lastPresented is PreviewViewController)
    }

    func testPresentPreviewAfterScanDismissesScanningAndPresentsPreviewViewController() {
        let presenter = TestPresenter()
        let flowState = ScanFlowState()
        let repository = ScanRepository(scansRootURL: tempDir, defaults: defaults)
        let exporter = ScanExporterService(scansRootURL: tempDir, defaults: defaults)
        let settingsStore = SettingsStore(defaults: defaults)
        var dismissed = false
        var capturedInput: PreviewViewController.Input?

        final class DismissingScanningViewController: UIViewController {
            var onDismiss: (() -> Void)?
            override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
                onDismiss?()
                completion?()
            }
        }

        let dismissingScanningVC = DismissingScanningViewController()
        dismissingScanningVC.onDismiss = { dismissed = true }

        let coordinator = PreviewCoordinator(
            presenter: presenter,
            scanFlowState: flowState,
            previewViewControllerFactory: { input in
                capturedInput = input
                return PreviewViewController(
                    input: input,
                    scanReader: repository,
                    settingsStore: settingsStore,
                    scanFlowState: flowState,
                    previewSessionState: PreviewSessionState(),
                    environment: .current,
                    scanExporter: exporter
                )
            }
        )

        guard let pointCloud = class_createInstance(SCPointCloud.self, 0) as? SCPointCloud else {
            return XCTFail("Failed to allocate SCPointCloud placeholder")
        }

        let payload = ScanPreviewInput(
            pointCloud: pointCloud,
            meshTexturing: SCMeshTexturing(),
            earVerificationImage: nil,
            earVerificationSelectionMetadata: nil
        )

        coordinator.presentPreviewAfterScan(
            from: dismissingScanningVC,
            payload: payload,
            sessionMetrics: nil
        )

        XCTAssertTrue(dismissed)
        guard case .postScan(let capturedPayload, nil)? = capturedInput else {
            return XCTFail("Expected post-scan input")
        }
        XCTAssertTrue(capturedPayload.pointCloud === payload.pointCloud)
        XCTAssertTrue(presenter.lastPresented is PreviewViewController)
    }

    func testSaveExportViewStateTransitionsThroughMeshingAndReady() {
        @MainActor
        final class PreviewSaveExportSurfaceFake: PreviewSaveExportSurface {
            let hostView = UIView()
            let leftActionButton = UIButton(type: .system)
            let rightActionButton = UIButton(type: .system)
        }

        let previewSurface = PreviewSaveExportSurfaceFake()
        let stateController = SaveExportViewStateController()

        stateController.configure(surface: previewSurface)
        XCTAssertEqual(accessibilityValue(in: previewSurface.hostView, identifier: "previewSaveStateView"), "idle")
        XCTAssertFalse(previewSurface.rightActionButton.isEnabled)

        stateController.markSaveMeshing()
        stateController.setMeshingStatusText(L("scan.preview.meshing"))
        stateController.setMeshingSpinnerActive(true)
        XCTAssertEqual(accessibilityValue(in: previewSurface.hostView, identifier: "previewSaveStateView"), "meshing")
        XCTAssertFalse(previewSurface.rightActionButton.isEnabled)

        stateController.markSaveReady()
        XCTAssertEqual(accessibilityValue(in: previewSurface.hostView, identifier: "previewSaveStateView"), "ready")
        XCTAssertTrue(previewSurface.rightActionButton.isEnabled)

        stateController.markSaveBlocked()
        XCTAssertEqual(accessibilityValue(in: previewSurface.hostView, identifier: "previewSaveStateView"), "blocked")
        XCTAssertTrue(previewSurface.rightActionButton.isEnabled)
    }

    private func findView(withAccessibilityIdentifier identifier: String, in view: UIView?) -> UIView? {
        guard let view else { return nil }
        if view.accessibilityIdentifier == identifier {
            return view
        }
        for subview in view.subviews {
            if let found = findView(withAccessibilityIdentifier: identifier, in: subview) {
                return found
            }
        }
        return nil
    }

    private func accessibilityValue(in hostView: UIView, identifier: String) -> String? {
        findView(withAccessibilityIdentifier: identifier, in: hostView)?.accessibilityValue
    }
}
