import XCTest
@testable import TrueContourAI

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: SettingsStore!

    override func setUp() {
        super.setUp()
        suiteName = "SettingsStoreTests.\(UUID().uuidString)"
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

    func testScanQualityConfigPersists() {
        var config = store.scanQualityConfig
        config.gateEnabled = false
        config.minValidPoints = 120_000
        config.minValidRatio = 0.7
        config.minQualityScore = 0.75
        config.minHeadDimensionMeters = 0.12
        config.maxHeadDimensionMeters = 0.45
        store.scanQualityConfig = config

        let loaded = store.scanQualityConfig
        XCTAssertEqual(loaded.gateEnabled, false)
        XCTAssertEqual(loaded.minValidPoints, 120_000)
        XCTAssertEqual(loaded.minValidRatio, 0.7, accuracy: 0.0001)
        XCTAssertEqual(loaded.minQualityScore, 0.75, accuracy: 0.0001)
        XCTAssertEqual(loaded.minHeadDimensionMeters, 0.12, accuracy: 0.0001)
        XCTAssertEqual(loaded.maxHeadDimensionMeters, 0.45, accuracy: 0.0001)
    }

    func testProcessingConfigPersists() {
        var config = store.processingConfig
        config.outlierSigma = 4.0
        config.decimateRatio = 1.25
        config.cropBelowNeck = false
        config.meshResolution = 7
        config.meshSmoothness = 4
        store.processingConfig = config

        let loaded = store.processingConfig
        XCTAssertEqual(loaded.outlierSigma, 4.0, accuracy: 0.0001)
        XCTAssertEqual(loaded.decimateRatio, 1.25, accuracy: 0.0001)
        XCTAssertEqual(loaded.cropBelowNeck, false)
        XCTAssertEqual(loaded.meshResolution, 7)
        XCTAssertEqual(loaded.meshSmoothness, 4)
    }

    func testResetToDefaultsResetsExtendedConfig() {
        var quality = store.scanQualityConfig
        quality.gateEnabled = false
        quality.minValidPoints = 120_000
        store.scanQualityConfig = quality

        var processing = store.processingConfig
        processing.decimateRatio = 1.25
        processing.meshResolution = 7
        store.processingConfig = processing

        store.resetToDefaults()

        XCTAssertEqual(store.scanQualityConfig.gateEnabled, SettingsStore.ScanQualityConfig.default.gateEnabled)
        XCTAssertEqual(store.scanQualityConfig.minValidPoints, SettingsStore.ScanQualityConfig.default.minValidPoints)
        XCTAssertEqual(store.processingConfig.decimateRatio, SettingsStore.ProcessingConfig.default.decimateRatio, accuracy: 0.0001)
        XCTAssertEqual(store.processingConfig.meshResolution, SettingsStore.ProcessingConfig.default.meshResolution)
    }

    func testHasAnyExportFormatEnabledReflectsCurrentSettings() {
        XCTAssertTrue(store.hasAnyExportFormatEnabled)

        store.exportGLTF = false
        XCTAssertTrue(store.hasAnyExportFormatEnabled)

        store.exportOBJ = false
        XCTAssertFalse(store.hasAnyExportFormatEnabled)
    }
}
