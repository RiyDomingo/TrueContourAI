import XCTest
@testable import TrueContourAI

@MainActor
final class SettingsViewControllerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: SettingsStore!

    override func setUp() {
        super.setUp()
        suiteName = "SettingsViewControllerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SettingsStore(defaults: defaults)
    }

    override func tearDown() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        store = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRefreshStorageUsageTransitionsFromCalculatingToResolvedText() {
        let service = SettingsScanServiceFake()
        let vc = SettingsViewController(store: store, storageUseCase: SettingsStorageUseCase(scanService: service))
        vc.loadViewIfNeeded()

        vc.debug_refreshStorageUsage()
        XCTAssertEqual(vc.debug_storageUsageText(), L("settings.calculating"))

        let exp = expectation(description: "resolved")
        waitUntil(timeout: 6.0) {
            let text = vc.debug_storageUsageText()
            if text != L("settings.calculating") {
                exp.fulfill()
                return true
            }
            return false
        }

        wait(for: [exp], timeout: 8.0)
    }

    func testDeleteAllSuccessTriggersOnScansChanged() {
        let service = SettingsScanServiceFake()
        service.deleteAllResult = .success(())
        let vc = SettingsViewController(store: store, storageUseCase: SettingsStorageUseCase(scanService: service))
        vc.loadViewIfNeeded()

        var changedCount = 0
        vc.onScansChanged = { changedCount += 1 }

        vc.debug_deleteAllScansConfirmed()

        XCTAssertEqual(changedCount, 0)
        waitUntil(timeout: 2.0) { changedCount == 1 }
        XCTAssertEqual(changedCount, 1)
        XCTAssertEqual(service.deleteAllCallCount, 1)
        XCTAssertFalse(service.deleteAllExecutedOnMainThread)
    }

    func testDeleteAllFailurePresentsErrorAlert() {
        let service = SettingsScanServiceFake()
        service.deleteAllResult = .failure(NSError(domain: "SettingsTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"]))

        let vc = SettingsViewController(store: store, storageUseCase: SettingsStorageUseCase(scanService: service))
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = vc
            window.makeKeyAndVisible()
        }
        vc.loadViewIfNeeded()

        vc.debug_deleteAllScansConfirmed()
        waitUntil(timeout: 2.0) {
            (vc.presentedViewController as? UIAlertController)?.title == L("settings.delete.failed")
        }

        let alert = vc.presentedViewController as? UIAlertController
        XCTAssertEqual(alert?.title, L("settings.delete.failed"))
        XCTAssertEqual(alert?.message, "boom")
        XCTAssertFalse(service.deleteAllExecutedOnMainThread)
    }

    func testSettingsSectionsUseGeneralExportAdvancedStorageLayout() {
        let service = SettingsScanServiceFake()
        let vc = SettingsViewController(store: store, storageUseCase: SettingsStorageUseCase(scanService: service))
        vc.loadViewIfNeeded()

        guard let table = vc.tableView else {
            XCTFail("Expected tableView to be initialized")
            return
        }
        XCTAssertEqual(vc.numberOfSections(in: table), 4)

        XCTAssertEqual(vc.tableView(table, titleForHeaderInSection: 0), L("settings.section.general"))
        XCTAssertEqual(vc.tableView(table, numberOfRowsInSection: 0), 3)

        XCTAssertEqual(vc.tableView(table, titleForHeaderInSection: 1), L("settings.section.export"))
        XCTAssertEqual(vc.tableView(table, numberOfRowsInSection: 1), 2)

        XCTAssertEqual(vc.tableView(table, titleForHeaderInSection: 2), L("settings.section.advanced"))
        XCTAssertEqual(vc.tableView(table, numberOfRowsInSection: 2), 6)

        XCTAssertEqual(vc.tableView(table, titleForHeaderInSection: 3), L("settings.section.storage"))
        XCTAssertEqual(vc.tableView(table, numberOfRowsInSection: 3), 4)
    }

    func testDisablingGLTFExportIsPrevented() {
        store.exportGLTF = true
        store.exportOBJ = false
        let service = SettingsScanServiceFake()
        let vc = SettingsViewController(store: store, storageUseCase: SettingsStorageUseCase(scanService: service))
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = vc
            window.makeKeyAndVisible()
        }
        vc.loadViewIfNeeded()

        let exportGLTFIndexPath = IndexPath(row: 0, section: 1)
        let cell = vc.tableView(vc.tableView, cellForRowAt: exportGLTFIndexPath)
        guard let toggle = cell.accessoryView as? UISwitch else {
            XCTFail("Expected export GLTF toggle")
            return
        }

        toggle.tag = 100
        toggle.setOn(false, animated: false)
        vc.perform(NSSelectorFromString("toggleChanged:"), with: toggle)

        XCTAssertTrue(store.exportGLTF)
        XCTAssertTrue(toggle.isOn)
        let alert = vc.presentedViewController as? UIAlertController
        XCTAssertEqual(alert?.title, L("settings.export.minimum.title"))
        XCTAssertEqual(alert?.message, L("settings.export.minimum.message"))
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }
}

final class SettingsScanServiceFake: SettingsScanServicing {
    var scansRootURL: URL
    var ensureResult: Result<Void, Error>
    var deleteAllResult: Result<Void, Error>
    private(set) var deleteAllCallCount = 0
    private(set) var deleteAllExecutedOnMainThread = false

    init() {
        scansRootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: scansRootURL, withIntermediateDirectories: true)
        ensureResult = .success(())
        deleteAllResult = .success(())
    }

    func ensureScansRootFolder() -> Result<Void, Error> {
        ensureResult
    }

    func deleteAllScans() -> Result<Void, Error> {
        deleteAllCallCount += 1
        deleteAllExecutedOnMainThread = Thread.isMainThread
        return deleteAllResult
    }
}
