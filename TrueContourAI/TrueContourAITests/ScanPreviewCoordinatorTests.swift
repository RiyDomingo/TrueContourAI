import XCTest
import UIKit
import StandardCyborgFusion
import StandardCyborgUI
@testable import TrueContourAI

@MainActor
final class ScanPreviewCoordinatorTests: XCTestCase {
    @MainActor
    private final class PreviewSaveExportSurfaceFake: PreviewSaveExportSurface {
        let hostView = UIView()
        let leftActionButton = UIButton(type: .system)
        let rightActionButton = UIButton(type: .system)
    }

    private final class TestPresenter: UIViewController {
        var lastPresented: UIViewController?
        var onPresent: (() -> Void)?

        override func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
            lastPresented = viewControllerToPresent
            viewControllerToPresent.loadViewIfNeeded()
            completion?()
            onPresent?()
        }
    }

    private final class PreviewScanReaderFake: PreviewScanReading, ScanExporting {
        var scansRootURL: URL
        var summary: ScanSummary?
        var scene: SCScene?
        var earImage: UIImage?
        var lastScanFolderURL: URL?

        init(scansRootURL: URL) {
            self.scansRootURL = scansRootURL
        }

        func resolveScanSummary(from folder: URL) -> ScanSummary? { summary }
        func sceneForScan(_ item: ScanItem) -> SCScene? { scene }
        func resolveEarVerificationImage(from folder: URL) -> UIImage? { earImage }
        func resolveLastScanItem() -> ScanItem? { nil }
        func resolveLastScanFolderURL() -> URL? { lastScanFolderURL }
        func shareItems(for folderURL: URL) -> [Any] { [folderURL] }
        func shareItemsForScansRoot() -> [Any] { [scansRootURL] }
        func resolveOBJFromFolder(_ folder: URL) -> URL? { nil }
        func exportScanFolder(
            mesh: SCMesh,
            scene: SCScene,
            thumbnail: UIImage?,
            earArtifacts: ScanEarArtifacts?,
            scanSummary: ScanSummary?,
            includeGLTF: Bool,
            includeOBJ: Bool
        ) -> ScanExportResult {
            .failure("unused")
        }

        func setLastScanFolder(_ folderURL: URL) {
            lastScanFolderURL = folderURL
        }
    }

    private var tempDir: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    private func makeRepository() -> ScanRepository {
        ScanRepository(scansRootURL: tempDir, defaults: defaults)
    }

    private func makeExporter() -> ScanExporterService {
        ScanExporterService(scansRootURL: tempDir, defaults: defaults)
    }

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        suiteName = "ScanPreviewCoordinatorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        tempDir = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testPresentExistingScanMissingScenePresentsAlert() {
        let presenter = TestPresenter()
        let scanRepository = makeRepository()
        let scanExporter = makeExporter()
        let settingsStore = SettingsStore(defaults: defaults)
        let flowState = ScanFlowState()
        let coordinator = ScanPreviewCoordinator(
            presenter: presenter,
            scanService: scanRepository,
            settingsStore: settingsStore,
            scanFlowState: flowState,
            scanExporter: scanExporter,
            onToast: nil
        )

        let scanFolder = tempDir.appendingPathComponent("scan-missing-scene", isDirectory: true)
        try? FileManager.default.createDirectory(at: scanFolder, withIntermediateDirectories: true)
        let item = ScanItem(
            folderURL: scanFolder,
            displayName: "scan-missing-scene",
            date: Date(),
            thumbnailURL: nil,
            sceneGLTFURL: nil
        )

        let presentExpectation = expectation(description: "missing scene alert presented")
        presenter.onPresent = { presentExpectation.fulfill() }

        coordinator.presentExistingScan(item)

        wait(for: [presentExpectation], timeout: 2.0)

        let alert = presenter.lastPresented as? UIAlertController
        XCTAssertNotNil(alert)
        XCTAssertEqual(alert?.title, L("scan.preview.missingScene.title"))
    }

    func testPresentExistingScanConfiguresPreviewUIAfterAsyncLoad() {
        let presenter = TestPresenter()
        let scanReader = PreviewScanReaderFake(scansRootURL: tempDir)
        scanReader.summary = ScanSummary(
            startedAt: Date(),
            finishedAt: Date(),
            durationSeconds: 10,
            overallConfidence: 0.82,
            pointCountEstimate: 120_000,
            hadEarVerification: false,
            processingProfile: nil,
            derivedMeasurements: nil
        )
        scanReader.scene = SCScene(pointCloud: nil, mesh: nil)

        let coordinator = ScanPreviewCoordinator(
            presenter: presenter,
            scanService: scanReader,
            settingsStore: SettingsStore(defaults: defaults),
            scanFlowState: ScanFlowState(),
            scanExporter: scanReader,
            onToast: nil
        )

        let item = ScanItem(
            folderURL: tempDir.appendingPathComponent("seed", isDirectory: true),
            displayName: "seed",
            date: Date(),
            thumbnailURL: nil,
            sceneGLTFURL: tempDir.appendingPathComponent("seed/scene.gltf")
        )

        let presentExpectation = expectation(description: "existing preview presented")
        presenter.onPresent = { presentExpectation.fulfill() }

        coordinator.presentExistingScan(item)

        wait(for: [presentExpectation], timeout: 2.0)

        let previewVC = presenter.lastPresented as? ScenePreviewViewController
        XCTAssertNotNil(previewVC)
        XCTAssertEqual(previewVC?.leftButton.accessibilityIdentifier, "previewCloseButton")
        XCTAssertNotNil(findView(withAccessibilityIdentifier: "verifyEarButton", in: previewVC?.view))
    }

    func testSaveExportViewStateTransitionsThroughMeshingAndReady() {
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
