import XCTest
import UIKit
@testable import TrueContourAI

final class ScanPreviewCoordinatorTests: XCTestCase {

    private final class TestPresenter: UIViewController {
        var lastPresented: UIViewController?

        override func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
            lastPresented = viewControllerToPresent
            completion?()
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

        coordinator.presentExistingScan(item)

        let alert = presenter.lastPresented as? UIAlertController
        XCTAssertNotNil(alert)
        XCTAssertEqual(alert?.title, L("scan.preview.missingScene.title"))
    }
}
