import XCTest
import UIKit
@testable import TrueContourAI

final class HomeCoordinatorTests: XCTestCase {

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

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        suiteName = "HomeCoordinatorTests.\(UUID().uuidString)"
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

    func testOpenLastScanWhenMissingPresentsAlert() {
        let presenter = TestPresenter()
        let scanService = ScanService(scansRootURL: tempDir, defaults: defaults)
        let settingsStore = SettingsStore(defaults: defaults)
        let flowState = ScanFlowState()
        let coordinator = HomeCoordinator(
            scanService: scanService,
            settingsStore: settingsStore,
            scanFlowState: flowState
        )

        coordinator.openLastScan(from: presenter)

        let alert = presenter.lastPresented as? UIAlertController
        XCTAssertNotNil(alert)
        XCTAssertEqual(alert?.title, L("scan.flow.noLast.title"))
    }

    func testOpenLastScanUsesStoredScanItemMetadata() throws {
        let presenter = TestPresenter()
        let scanService = ScanService(scansRootURL: tempDir, defaults: defaults)
        let settingsStore = SettingsStore(defaults: defaults)
        let flowState = ScanFlowState()
        let coordinator = HomeCoordinator(
            scanService: scanService,
            settingsStore: settingsStore,
            scanFlowState: flowState
        )
        let folder = tempDir.appendingPathComponent("sample", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let thumbnailURL = folder.appendingPathComponent("thumbnail.png")
        try Data([0x01]).write(to: thumbnailURL, options: [.atomic])
        let gltfURL = folder.appendingPathComponent("scene.gltf")
        try Data("{\"asset\":{\"version\":\"2.0\"}}".utf8).write(to: gltfURL, options: [.atomic])
        let date = Date(timeIntervalSince1970: 1234)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: folder.path)
        scanService.setLastScanFolder(folder)

        var openedItem: ScanService.ScanItem?
        coordinator.onOpenScan = { openedItem = $0 }

        coordinator.openLastScan(from: presenter)

        XCTAssertEqual(openedItem?.folderURL, folder)
        XCTAssertEqual(openedItem?.displayName, "sample")
        XCTAssertEqual(openedItem?.thumbnailURL, thumbnailURL)
        XCTAssertEqual(openedItem?.sceneGLTFURL, gltfURL)
        XCTAssertEqual(openedItem?.date, date)
    }

    func testPresentScanActionsIncludesExpectedOrderAndLabels() throws {
        let presenter = TestPresenter()
        let scanService = ScanService(scansRootURL: tempDir, defaults: defaults)
        let settingsStore = SettingsStore(defaults: defaults)
        let flowState = ScanFlowState()
        let coordinator = HomeCoordinator(
            scanService: scanService,
            settingsStore: settingsStore,
            scanFlowState: flowState
        )

        let folder = tempDir.appendingPathComponent("sample", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let item = ScanService.ScanItem(
            folderURL: folder,
            displayName: "sample",
            date: Date(),
            thumbnailURL: nil,
            sceneGLTFURL: nil
        )

        coordinator.presentScanActions(for: item, sourceView: presenter.view, from: presenter)
        let actionSheet = presenter.lastPresented as? UIAlertController

        XCTAssertNotNil(actionSheet)
        let titles = actionSheet?.actions.compactMap { $0.title } ?? []
        XCTAssertEqual(
            titles,
            [
                L("common.open"),
                L("common.details"),
                L("common.shareScanFolder"),
                L("common.shareObj"),
                L("common.rename"),
                L("common.delete"),
                L("common.cancel")
            ]
        )
    }

    func testPresentScansFolderShareShowsAlertWhenStorageUnavailable() throws {
        let presenter = TestPresenter()
        let badRoot = tempDir.appendingPathComponent("not-a-directory")
        try Data("x".utf8).write(to: badRoot, options: [.atomic])
        let scanService = ScanService(scansRootURL: badRoot, defaults: defaults)
        let settingsStore = SettingsStore(defaults: defaults)
        let flowState = ScanFlowState()
        let coordinator = HomeCoordinator(
            scanService: scanService,
            settingsStore: settingsStore,
            scanFlowState: flowState
        )

        coordinator.presentScansFolderShare(from: presenter, sourceView: presenter.view)

        let alert = presenter.lastPresented as? UIAlertController
        XCTAssertNotNil(alert)
        XCTAssertEqual(alert?.title, L("scan.storage.unavailable.title"))
    }
}
