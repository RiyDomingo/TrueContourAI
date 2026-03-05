import XCTest
@testable import TrueContourAI

final class ScanPreviewCoordinatorExportTests: XCTestCase {

    private var tempDir: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        suiteName = "ScanPreviewCoordinatorExportTests.\(UUID().uuidString)"
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

    func testDebugExportSuccessSetsIdleAndEmitsToast() {
        let scanService = ScanService(scansRootURL: tempDir, defaults: defaults)
        let flowState = ScanFlowState()
        flowState.setPhase(.saving)

        var toasts: [String] = []
        var exportEvents: [ScanPreviewCoordinator.ExportResultEvent] = []
        var scansChanged = 0

        let coordinator = ScanPreviewCoordinator(
            presenter: UIViewController(),
            scanService: scanService,
            settingsStore: SettingsStore(defaults: defaults),
            scanFlowState: flowState,
            onToast: { toasts.append($0) },
            onExportResult: { exportEvents.append($0) }
        )
        coordinator.onScansChanged = { scansChanged += 1 }

        let folderURL = tempDir.appendingPathComponent("2026-01-01T00-00-00Z", isDirectory: true)
        coordinator.debug_handleExportResult(.success(folderURL: folderURL), isEarServiceUnavailable: false)

        XCTAssertEqual(flowState.phase, .idle)
        XCTAssertEqual(scansChanged, 1)
        XCTAssertTrue(
            toasts.contains(
                String(format: L("scan.preview.toast.savedWithFormats"), folderURL.lastPathComponent, "GLTF, OBJ")
            )
        )
        XCTAssertEqual(
            exportEvents.last,
            .success(folderName: folderURL.lastPathComponent, formatSummary: "GLTF, OBJ", earServiceUnavailable: false)
        )
    }

    func testDebugExportFailureSetsPreviewAndNoToast() {
        let scanService = ScanService(scansRootURL: tempDir, defaults: defaults)
        let flowState = ScanFlowState()
        flowState.setPhase(.saving)

        var toasts: [String] = []
        var exportEvents: [ScanPreviewCoordinator.ExportResultEvent] = []

        let coordinator = ScanPreviewCoordinator(
            presenter: UIViewController(),
            scanService: scanService,
            settingsStore: SettingsStore(defaults: defaults),
            scanFlowState: flowState,
            onToast: { toasts.append($0) },
            onExportResult: { exportEvents.append($0) }
        )

        coordinator.debug_handleExportResult(.failure("fail"), isEarServiceUnavailable: false)

        XCTAssertEqual(flowState.phase, .preview)
        XCTAssertTrue(toasts.isEmpty)
        XCTAssertEqual(exportEvents.last, .failure(message: "fail"))
    }

    func testDebugExportSuccessWithUnavailableEarEmitsWarningToast() {
        let scanService = ScanService(scansRootURL: tempDir, defaults: defaults)
        let flowState = ScanFlowState()
        flowState.setPhase(.saving)

        var toasts: [String] = []
        let coordinator = ScanPreviewCoordinator(
            presenter: UIViewController(),
            scanService: scanService,
            settingsStore: SettingsStore(defaults: defaults),
            scanFlowState: flowState,
            onToast: { toasts.append($0) }
        )

        let folderURL = tempDir.appendingPathComponent("2026-01-01T00-00-00Z", isDirectory: true)
        coordinator.debug_handleExportResult(.success(folderURL: folderURL), isEarServiceUnavailable: true)

        XCTAssertEqual(flowState.phase, .idle)
        XCTAssertTrue(toasts.contains(L("scan.preview.toast.earUnavailable")))
    }

    func testDebugSavePrecheckBlockedByQualityGate() {
        let coordinator = ScanPreviewCoordinator(
            presenter: UIViewController(),
            scanService: ScanService(scansRootURL: tempDir, defaults: defaults),
            settingsStore: SettingsStore(defaults: defaults),
            scanFlowState: ScanFlowState(),
            onToast: nil
        )

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

        XCTAssertEqual(coordinator.debug_savePrecheck(qualityReport: report, hasMesh: true), "blockedByQualityGate")
    }

    func testDebugSavePrecheckMeshNotReady() {
        let coordinator = ScanPreviewCoordinator(
            presenter: UIViewController(),
            scanService: ScanService(scansRootURL: tempDir, defaults: defaults),
            settingsStore: SettingsStore(defaults: defaults),
            scanFlowState: ScanFlowState(),
            onToast: nil
        )

        XCTAssertEqual(coordinator.debug_savePrecheck(qualityReport: nil, hasMesh: false), "meshNotReady")
    }

    func testDebugSavePrecheckBlocksWhenGLTFExportDisabled() {
        let settings = SettingsStore(defaults: defaults)
        settings.exportGLTF = false
        settings.exportOBJ = true
        let coordinator = ScanPreviewCoordinator(
            presenter: UIViewController(),
            scanService: ScanService(scansRootURL: tempDir, defaults: defaults),
            settingsStore: settings,
            scanFlowState: ScanFlowState(),
            onToast: nil
        )

        XCTAssertEqual(coordinator.debug_savePrecheck(qualityReport: nil, hasMesh: true), "gltfExportRequired")
    }

    func testDebugSavePrecheckReady() {
        let coordinator = ScanPreviewCoordinator(
            presenter: UIViewController(),
            scanService: ScanService(scansRootURL: tempDir, defaults: defaults),
            settingsStore: SettingsStore(defaults: defaults),
            scanFlowState: ScanFlowState(),
            onToast: nil
        )

        XCTAssertEqual(coordinator.debug_savePrecheck(qualityReport: nil, hasMesh: true), "ready")
    }

    func testDebugSavePrecheckPrioritizesQualityGateBeforeMeshReadiness() {
        let coordinator = ScanPreviewCoordinator(
            presenter: UIViewController(),
            scanService: ScanService(scansRootURL: tempDir, defaults: defaults),
            settingsStore: SettingsStore(defaults: defaults),
            scanFlowState: ScanFlowState(),
            onToast: nil
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
            coordinator.debug_savePrecheck(qualityReport: blocked, hasMesh: false),
            "blockedByQualityGate"
        )
    }

    func testPreviewExportFormatSummaryMatchesSettingsMatrix() {
        let matrix: [(includeGLTF: Bool, includeOBJ: Bool, expected: String)] = [
            (true, true, "GLTF, OBJ"),
            (true, false, "GLTF"),
            (false, true, "OBJ"),
            (false, false, L("scan.preview.exportFormat.none"))
        ]

        for entry in matrix {
            let flowState = ScanFlowState()
            flowState.setPhase(.saving)
            let settings = SettingsStore(defaults: defaults)
            settings.exportGLTF = entry.includeGLTF
            settings.exportOBJ = entry.includeOBJ

            var events: [ScanPreviewCoordinator.ExportResultEvent] = []
            let coordinator = ScanPreviewCoordinator(
                presenter: UIViewController(),
                scanService: ScanService(scansRootURL: tempDir, defaults: defaults),
                settingsStore: settings,
                scanFlowState: flowState,
                onToast: nil,
                onExportResult: { events.append($0) }
            )

            let folderURL = tempDir.appendingPathComponent("matrix-\(UUID().uuidString)", isDirectory: true)
            coordinator.debug_handleExportResult(.success(folderURL: folderURL), isEarServiceUnavailable: false)

            XCTAssertEqual(
                events.last,
                .success(folderName: folderURL.lastPathComponent, formatSummary: entry.expected, earServiceUnavailable: false)
            )
            XCTAssertEqual(flowState.phase, .idle)
        }
    }
}
