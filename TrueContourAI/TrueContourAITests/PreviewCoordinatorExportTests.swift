import XCTest
import UIKit
import SceneKit
import ObjectiveC.runtime
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

    func testMakeExportSnapshotIncludesVerifiedEarArtifactsAndSummaryFlag() {
        let settings = SettingsStore(defaults: defaults)
        let useCase = PreviewExportUseCase(settingsStore: settings, scanExporter: ScanExporterFake())
        let store = PreviewStore(settingsStore: settings)
        _ = store.beginPreviewSession(
            sessionMetrics: .init(
                startedAt: Date(timeIntervalSince1970: 100),
                finishedAt: Date(timeIntervalSince1970: 130),
                durationSeconds: 30
            )
        )
        store.setMeshForExport(makeMeshPlaceholder())
        store.setMeasurementSummary(
            .init(
                sliceHeightNormalized: 0.62,
                circumferenceMm: 560,
                widthMm: 150,
                depthMm: 190,
                confidence: 0.8,
                status: "validated"
            )
        )
        store.setVerifiedEar(
            image: UIImage(),
            result: EarLandmarksResult(
                confidence: 0.9,
                earBoundingBox: .init(x: 0, y: 0, w: 1, h: 1),
                landmarks: [],
                usedLeftEarMirroringHeuristic: false
            ),
            overlay: UIImage(),
            cropOverlay: UIImage()
        )

        let snapshot = useCase.makeExportSnapshot(
            store: store,
            sceneSnapshot: .init(scene: makeScenePlaceholder(), renderedImage: UIImage())
        )

        XCTAssertNotNil(snapshot)
        XCTAssertNotNil(snapshot?.earArtifacts)
        XCTAssertEqual(snapshot?.scanSummary?.hadEarVerification, true)
        XCTAssertEqual(snapshot?.scanSummary?.durationSeconds, 30)
        XCTAssertEqual(snapshot?.exportGLTF, true)
        XCTAssertEqual(snapshot?.exportOBJ, true)
    }

    func testExportSuccessPersistsLastScanFolderAndReturnsSavedResult() {
        let exporter = ScanExporterFake()
        let savedFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        exporter.result = .success(folderURL: savedFolder)
        let settings = SettingsStore(defaults: defaults)
        settings.exportOBJ = false
        let useCase = PreviewExportUseCase(settingsStore: settings, scanExporter: exporter)
        let expectation = expectation(description: "export completion")

        useCase.export(
            snapshot: .init(
                mesh: makeMeshPlaceholder(),
                sceneSnapshot: .init(scene: makeScenePlaceholder(), renderedImage: UIImage()),
                earArtifacts: nil,
                scanSummary: nil,
                exportGLTF: true,
                exportOBJ: false
            ),
            earServiceUnavailable: true
        ) { result in
            switch result {
            case .success(let saved):
                XCTAssertEqual(saved.folderURL, savedFolder)
                XCTAssertEqual(saved.folderName, savedFolder.lastPathComponent)
                XCTAssertEqual(saved.formatSummary, "GLTF")
                XCTAssertTrue(saved.earServiceUnavailable)
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(exporter.lastScanFolderURL, savedFolder)
    }

    func testExportFailureDoesNotPersistLastScanFolder() {
        let exporter = ScanExporterFake()
        exporter.result = .failure("disk full")
        let useCase = PreviewExportUseCase(settingsStore: SettingsStore(defaults: defaults), scanExporter: exporter)
        let expectation = expectation(description: "export failure completion")

        useCase.export(
            snapshot: .init(
                mesh: makeMeshPlaceholder(),
                sceneSnapshot: .init(scene: makeScenePlaceholder(), renderedImage: UIImage()),
                earArtifacts: nil,
                scanSummary: nil,
                exportGLTF: true,
                exportOBJ: true
            ),
            earServiceUnavailable: false
        ) { result in
            switch result {
            case .success(let saved):
                XCTFail("Expected failure, got \(saved)")
            case .failure(let error):
                XCTAssertEqual(error, .exportFailed("disk full"))
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertNil(exporter.lastScanFolderURL)
    }

    func testPreviewFitUseCaseFlagsMissingEarDataForManualPicking() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let repository = ScanRepository(scansRootURL: tempDir, defaults: defaults)
        let useCase = PreviewFitUseCase(scanReader: repository)

        let missingEarResult = PreviewFitResult(
            summaryText: "summary",
            fitCheckResult: FitModelCheckResult(
                fitData: .init(
                    head_circumference_brow_mm: 560,
                    head_width_max_mm: 150,
                    head_length_max_mm: 190,
                    ear_to_ear_over_top_mm: 320,
                    ear_left_xyz_mm: nil,
                    ear_right_xyz_mm: FitPoint3MM(SIMD3<Float>(1, 2, 3)),
                    occipital_offset_mm: 12,
                    quality_flags: .init(
                        holes_detected: false,
                        mesh_closed: true,
                        triangle_count: 2000,
                        scan_coverage_score: 0.8,
                        confidence_score: 0.9
                    )
                ),
                metadata: .init(
                    units: "mm",
                    coordinate_frame: "head",
                    up_axis: "y",
                    scale_factor_used: 1,
                    timestamp_iso8601: "2026-03-20T12:00:00Z",
                    app_version: "1.0",
                    device_model: "iPhone",
                    brow_plane_drop_from_top_fraction: 0.25,
                    axis_sign_convention: "rhs"
                ),
                warnings: []
            ),
            meshDataAvailable: true
        )

        XCTAssertTrue(useCase.shouldPromptForManualEarPicking(missingEarResult))
    }

    func testPreviewEarVerificationUseCaseBuildsSnapshotFallbackRequest() {
        let useCase = PreviewEarVerificationUseCase()
        let snapshot = UIImage()

        let request = useCase.makeRequest(
            preservedImage: nil,
            preservedSelectionMetadata: nil,
            previewSnapshot: snapshot
        )

        XCTAssertTrue(request.verificationImage === snapshot)
        XCTAssertEqual(request.source, .previewSnapshotFallback)
        XCTAssertNil(request.selectionMetadata)
    }

    private func makeMeshPlaceholder() -> SCMesh {
        class_createInstance(SCMesh.self, 0) as! SCMesh
    }

    private func makeScenePlaceholder() -> SCScene {
        class_createInstance(SCScene.self, 0) as! SCScene
    }
}
