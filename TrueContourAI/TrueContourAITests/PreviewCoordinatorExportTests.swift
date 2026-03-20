import XCTest
import UIKit
import SceneKit
import StandardCyborgFusion
@testable import TrueContourAI

final class PreviewCoordinatorExportTests: XCTestCase {
    private final class ScanExporterFake: ScanExporting {
        var result: ScanExportResult = .failure("unset")
        var lastScanFolderURL: URL?

        func exportScanFolder(
            mesh: SCMesh,
            scene: SCScene,
            thumbnail: UIImage?,
            earArtifacts: ScanEarArtifacts?,
            scanSummary: ScanSummary?,
            includeGLTF: Bool,
            includeOBJ: Bool
        ) -> ScanExportResult {
            result
        }

        func setLastScanFolder(_ folderURL: URL) {
            lastScanFolderURL = folderURL
        }
    }

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "PreviewCoordinatorExportTests.\(UUID().uuidString)"
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

    func testSavePrecheckBlocksWhenQualityGateRejectsScan() {
        let settings = SettingsStore(defaults: defaults)
        let useCase = PreviewExportUseCase(settingsStore: settings, scanExporter: ScanExporterFake())
        let report = ScanQualityReport(
            pointCount: 120_000,
            validPointCount: 60_000,
            widthMeters: 0.2,
            heightMeters: 0.2,
            depthMeters: 0.2,
            qualityScore: 0.4,
            isExportRecommended: false,
            advice: .rescanSlowly,
            reason: "low quality"
        )

        let input = useCase.makeEligibilityInput(meshAvailable: true, qualityReport: report)

        XCTAssertEqual(
            useCase.precheck(input),
            .qualityGateBlocked(reason: "low quality", advice: report.advice.message)
        )
    }

    func testSavePrecheckMeshNotReady() {
        let useCase = PreviewExportUseCase(
            settingsStore: SettingsStore(defaults: defaults),
            scanExporter: ScanExporterFake()
        )

        XCTAssertEqual(
            useCase.precheck(useCase.makeEligibilityInput(meshAvailable: false, qualityReport: nil)),
            .meshNotReady
        )
    }

    func testSavePrecheckBlocksWhenGLTFExportDisabled() {
        let settings = SettingsStore(defaults: defaults)
        settings.exportGLTF = false
        settings.exportOBJ = true
        let useCase = PreviewExportUseCase(settingsStore: settings, scanExporter: ScanExporterFake())

        XCTAssertEqual(
            useCase.precheck(useCase.makeEligibilityInput(meshAvailable: true, qualityReport: nil)),
            .gltfRequired
        )
    }

    func testSavePrecheckReady() {
        let useCase = PreviewExportUseCase(
            settingsStore: SettingsStore(defaults: defaults),
            scanExporter: ScanExporterFake()
        )

        XCTAssertNil(useCase.precheck(useCase.makeEligibilityInput(meshAvailable: true, qualityReport: nil)))
    }

    func testSavePrecheckPrioritizesMeshReadinessWhenQualityIsLow() {
        let useCase = PreviewExportUseCase(
            settingsStore: SettingsStore(defaults: defaults),
            scanExporter: ScanExporterFake()
        )
        let blocked = ScanQualityReport(
            pointCount: 100_000,
            validPointCount: 55_000,
            widthMeters: 0.2,
            heightMeters: 0.2,
            depthMeters: 0.2,
            qualityScore: 0.45,
            isExportRecommended: false,
            advice: .rescanSlowly,
            reason: "low quality"
        )

        XCTAssertEqual(
            useCase.precheck(useCase.makeEligibilityInput(meshAvailable: false, qualityReport: blocked)),
            .meshNotReady
        )
    }

    func testSavePrecheckAllowsLowQualityWhenGateDisabled() {
        let settings = SettingsStore(defaults: defaults)
        var config = settings.scanQualityConfig
        config.gateEnabled = false
        settings.scanQualityConfig = config
        let useCase = PreviewExportUseCase(settingsStore: settings, scanExporter: ScanExporterFake())
        let report = ScanQualityReport(
            pointCount: 120_000,
            validPointCount: 60_000,
            widthMeters: 0.2,
            heightMeters: 0.2,
            depthMeters: 0.2,
            qualityScore: 0.4,
            isExportRecommended: false,
            advice: .rescanSlowly,
            reason: "low quality"
        )

        XCTAssertNil(useCase.precheck(useCase.makeEligibilityInput(meshAvailable: true, qualityReport: report)))
    }

    func testPreviewExportFormatSummaryMatchesSettingsMatrix() {
        let matrix: [(includeGLTF: Bool, includeOBJ: Bool, expected: String)] = [
            (true, true, "GLTF, OBJ"),
            (true, false, "GLTF"),
            (false, true, "OBJ"),
            (false, false, L("scan.preview.exportFormat.none"))
        ]

        for entry in matrix {
            let settings = SettingsStore(defaults: defaults)
            settings.exportGLTF = entry.includeGLTF
            settings.exportOBJ = entry.includeOBJ

            let useCase = PreviewExportUseCase(settingsStore: settings, scanExporter: ScanExporterFake())
            XCTAssertEqual(useCase.exportFormatSummary(), entry.expected)
        }
    }

    func testPreviewExportFormatSummaryUsesRuntimeOverrideMatrixWithoutMutatingPersistedSettings() {
        let persisted = SettingsStore(defaults: defaults)
        persisted.exportGLTF = true
        persisted.exportOBJ = true

        let runtime = AppRuntimeSettings(
            settingsStore: persisted,
            environment: AppEnvironment(arguments: [
                "TrueContourAI",
                "-UITests",
                "ui-test-device-smoke",
                "ui-test-export-obj-off"
            ])
        )

        let useCase = PreviewExportUseCase(settingsStore: runtime, scanExporter: ScanExporterFake())

        XCTAssertEqual(useCase.exportFormatSummary(), "GLTF")
        XCTAssertTrue(persisted.exportOBJ)
    }

    func testPreviewSavePrecheckUsesRuntimeOverrideToKeepGLTFRequired() {
        let persisted = SettingsStore(defaults: defaults)
        persisted.exportGLTF = true
        persisted.exportOBJ = true

        let runtime = AppRuntimeSettings(
            settingsStore: persisted,
            environment: AppEnvironment(arguments: [
                "TrueContourAI",
                "-UITests",
                "ui-test-device-smoke",
                "ui-test-export-gltf-off"
            ])
        )

        let useCase = PreviewExportUseCase(settingsStore: runtime, scanExporter: ScanExporterFake())

        XCTAssertNil(useCase.precheck(useCase.makeEligibilityInput(meshAvailable: true, qualityReport: nil)))
        XCTAssertTrue(persisted.exportGLTF)
    }

    func testPreviewSavePrecheckUsesForcedQualityGateOverride() {
        let persisted = SettingsStore(defaults: defaults)
        var config = persisted.scanQualityConfig
        config.gateEnabled = false
        persisted.scanQualityConfig = config

        let runtime = AppRuntimeSettings(
            settingsStore: persisted,
            environment: AppEnvironment(arguments: [
                "TrueContourAI",
                "-UITests",
                "ui-test-force-quality-gate-block"
            ])
        )
        let useCase = PreviewExportUseCase(settingsStore: runtime, scanExporter: ScanExporterFake())
        let report = ScanQualityReport(
            pointCount: 120_000,
            validPointCount: 60_000,
            widthMeters: 0.2,
            heightMeters: 0.2,
            depthMeters: 0.2,
            qualityScore: 0.4,
            isExportRecommended: false,
            advice: .rescanSlowly,
            reason: "forced block"
        )

        XCTAssertEqual(
            useCase.precheck(useCase.makeEligibilityInput(meshAvailable: true, qualityReport: report)),
            .qualityGateBlocked(reason: "forced block", advice: report.advice.message)
        )
        XCTAssertFalse(persisted.scanQualityConfig.gateEnabled)
    }

    func testPreviewStoreSaveSuccessEmitsReturnHomeRoute() {
        let store = PreviewStore(settingsStore: SettingsStore(defaults: defaults))
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        let result = SavedScanResult(
            folderURL: URL(fileURLWithPath: "/tmp/saved"),
            folderName: "saved",
            formatSummary: "GLTF, OBJ",
            earServiceUnavailable: false
        )

        store.send(.exportCompleted(.success(result)))

        XCTAssertEqual(store.phase, .idle)
        XCTAssertEqual(store.state, .saved(result))
        XCTAssertEqual(effects.count, 1)
        if case .route(.returnHomeAfterSave(let saved))? = effects.first {
            XCTAssertEqual(saved, result)
        } else {
            XCTFail("Expected return-home route effect")
        }
    }

    func testPreviewStoreSaveFailureReturnsToReadyAndEmitsAlert() {
        let store = PreviewStore(settingsStore: SettingsStore(defaults: defaults))
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.exportCompleted(.failure(.exportFailed("boom"))))

        XCTAssertEqual(store.phase, .preview)
        if case .ready = store.state {
        } else {
            XCTFail("Expected ready state after export failure")
        }
        if case .alert(let title, _, let identifier)? = effects.first {
            XCTAssertEqual(title, L("scan.preview.exportFailed.title"))
            XCTAssertEqual(identifier, "exportFailedAlert")
        } else {
            XCTFail("Expected export failure alert")
        }
    }
}
