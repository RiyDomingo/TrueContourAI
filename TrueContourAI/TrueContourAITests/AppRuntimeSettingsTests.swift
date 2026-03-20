import XCTest
@testable import TrueContourAI

final class AppRuntimeSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppRuntimeSettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDeviceSmokeOverridesDoNotMutatePersistedSettings() {
        let store = SettingsStore(defaults: defaults)
        store.showPreScanChecklist = true
        store.scanDurationSeconds = 10
        store.exportGLTF = false
        store.exportOBJ = true

        let runtime = AppRuntimeSettings(
            settingsStore: store,
            environment: AppEnvironment(arguments: [
                "TrueContourAI",
                "-UITests",
                "ui-test-device-smoke",
                "ui-test-export-obj-off"
            ])
        )

        XCTAssertFalse(runtime.showPreScanChecklist)
        XCTAssertEqual(runtime.scanDurationSeconds, 30)
        XCTAssertTrue(runtime.exportGLTF)
        XCTAssertFalse(runtime.exportOBJ)

        XCTAssertTrue(store.showPreScanChecklist)
        XCTAssertEqual(store.scanDurationSeconds, 10)
        XCTAssertFalse(store.exportGLTF)
        XCTAssertTrue(store.exportOBJ)
    }

    func testQualityGateOverridesApplyEphemerally() {
        let store = SettingsStore(defaults: defaults)
        var quality = store.scanQualityConfig
        quality.gateEnabled = true
        quality.minValidPoints = 90_000
        store.scanQualityConfig = quality

        let disabledRuntime = AppRuntimeSettings(
            settingsStore: store,
            environment: AppEnvironment(arguments: [
                "TrueContourAI",
                "-UITests",
                "ui-test-disable-quality-gate"
            ])
        )
        XCTAssertFalse(disabledRuntime.scanQualityConfig.gateEnabled)
        XCTAssertTrue(store.scanQualityConfig.gateEnabled)

        let forcedRuntime = AppRuntimeSettings(
            settingsStore: store,
            environment: AppEnvironment(arguments: [
                "TrueContourAI",
                "-UITests",
                "ui-test-force-quality-gate-block"
            ])
        )
        XCTAssertTrue(forcedRuntime.scanQualityConfig.gateEnabled)
        XCTAssertEqual(forcedRuntime.scanQualityConfig.minValidPoints, 9_999_999)
        XCTAssertEqual(store.scanQualityConfig.minValidPoints, 90_000)
    }

    func testDeviceSmokeGLTFDisableArgumentIsIgnoredEphemerally() {
        let store = SettingsStore(defaults: defaults)
        store.exportGLTF = true
        store.exportOBJ = true

        let runtime = AppRuntimeSettings(
            settingsStore: store,
            environment: AppEnvironment(arguments: [
                "TrueContourAI",
                "-UITests",
                "ui-test-device-smoke",
                "ui-test-export-gltf-off"
            ])
        )

        XCTAssertTrue(runtime.exportGLTF)
        XCTAssertTrue(runtime.exportOBJ)
        XCTAssertTrue(store.exportGLTF)
        XCTAssertTrue(store.exportOBJ)
    }

    func testDeviceSmokeExportObjectDisableDoesNotChangePersistedExportMatrix() {
        let store = SettingsStore(defaults: defaults)
        store.exportGLTF = true
        store.exportOBJ = true

        let runtime = AppRuntimeSettings(
            settingsStore: store,
            environment: AppEnvironment(arguments: [
                "TrueContourAI",
                "-UITests",
                "ui-test-device-smoke",
                "ui-test-export-obj-off"
            ])
        )

        XCTAssertTrue(runtime.exportGLTF)
        XCTAssertFalse(runtime.exportOBJ)
        XCTAssertTrue(store.exportGLTF)
        XCTAssertTrue(store.exportOBJ)
    }
}
