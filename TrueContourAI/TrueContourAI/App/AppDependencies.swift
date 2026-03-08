import Foundation

struct AppEnvironment {
    struct UITestConfiguration {
        let usesDedicatedScansRoot: Bool
        let resetsDedicatedScansRootOnLaunch: Bool
        let seedsScan: Bool
        let seedsMissingSceneScan: Bool
        let skipsGLTFPreview: Bool
        let forcesMissingFolder: Bool
        let forcesUnavailableTrueDepth: Bool
        let skipsEarML: Bool
        let isDeviceSmokeMode: Bool
        let disablesQualityGate: Bool
        let forcesQualityGateBlock: Bool
        let disablesOBJExport: Bool
        let requestsDisabledGLTFExport: Bool
    }

    enum RuntimeMode {
        case production
        case uiTests(UITestConfiguration)
    }

    let runtimeMode: RuntimeMode

    static let current = AppEnvironment(processInfo: .processInfo)

    init(processInfo: ProcessInfo) {
        let arguments = Set(processInfo.arguments)
        guard arguments.contains("-UITests") || arguments.contains("ui-test-scans-root") else {
            runtimeMode = .production
            return
        }

        runtimeMode = .uiTests(
            UITestConfiguration(
                usesDedicatedScansRoot: arguments.contains("ui-test-scans-root"),
                resetsDedicatedScansRootOnLaunch: arguments.contains("ui-test-reset-scans"),
                seedsScan: arguments.contains("ui-test-seed-scan"),
                seedsMissingSceneScan: arguments.contains("ui-test-seed-missing-scene"),
                skipsGLTFPreview: arguments.contains("ui-test-skip-gltf"),
                forcesMissingFolder: arguments.contains("ui-test-force-missing-folder"),
                forcesUnavailableTrueDepth: arguments.contains("ui-test-force-unavailable-truedepth"),
                skipsEarML: arguments.contains("ui-test-skip-ear-ml"),
                isDeviceSmokeMode: arguments.contains("ui-test-device-smoke"),
                disablesQualityGate: arguments.contains("ui-test-disable-quality-gate"),
                forcesQualityGateBlock: arguments.contains("ui-test-force-quality-gate-block"),
                disablesOBJExport: arguments.contains("ui-test-export-obj-off"),
                requestsDisabledGLTFExport: arguments.contains("ui-test-export-gltf-off")
            )
        )
    }

    var uiTests: UITestConfiguration? {
        guard case .uiTests(let configuration) = runtimeMode else { return nil }
        return configuration
    }

    var isUITestMode: Bool { uiTests != nil }
    var isDeviceSmokeMode: Bool { uiTests?.isDeviceSmokeMode == true }
    var usesDedicatedScansRoot: Bool { uiTests?.usesDedicatedScansRoot == true }
    var resetsDedicatedScansRootOnLaunch: Bool { uiTests?.resetsDedicatedScansRootOnLaunch == true }
    var seedsScan: Bool { uiTests?.seedsScan == true }
    var seedsMissingSceneScan: Bool { uiTests?.seedsMissingSceneScan == true }
    var skipsGLTFPreview: Bool { uiTests?.skipsGLTFPreview == true }
    var forcesMissingFolder: Bool { uiTests?.forcesMissingFolder == true }
    var forcesUnavailableTrueDepth: Bool { uiTests?.forcesUnavailableTrueDepth == true }
    var skipsEarML: Bool { uiTests?.skipsEarML == true }
    var disablesQualityGate: Bool { uiTests?.disablesQualityGate == true }
    var forcesQualityGateBlock: Bool { uiTests?.forcesQualityGateBlock == true }
    var disablesOBJExport: Bool { uiTests?.disablesOBJExport == true }
    var requestsDisabledGLTFExport: Bool { uiTests?.requestsDisabledGLTFExport == true }

    var toastDwellSeconds: TimeInterval {
        isDeviceSmokeMode ? 8.0 : 1.8
    }
}

struct AppDependencies {
    let environment: AppEnvironment
    let scanRepository: ScanRepository
    let scanExporter: ScanExporterService
    let settingsStore: SettingsStore
    let earServiceFactory: () -> EarLandmarksService?

    init(
        environment: AppEnvironment = .current,
        scanService: ScanService? = nil,
        scanRepository: ScanRepository? = nil,
        scanExporter: ScanExporterService? = nil,
        settingsStore: SettingsStore = SettingsStore(),
        earServiceFactory: (() -> EarLandmarksService?)? = nil
    ) {
        self.environment = environment
        let resolvedScanService = scanService ?? AppDependencies.makeScanService(environment: environment)
        self.scanRepository = scanRepository ?? AppDependencies.makeScanRepository(scanService: resolvedScanService, environment: environment)
        self.scanExporter = scanExporter ?? AppDependencies.makeScanExporter(scanService: resolvedScanService)
        self.settingsStore = settingsStore
        self.earServiceFactory = earServiceFactory ?? AppDependencies.makeEarServiceFactory(environment: environment)
        applyRuntimeOverrides()
    }

    private func applyRuntimeOverrides() {
        guard environment.isDeviceSmokeMode else { return }

        settingsStore.showPreScanChecklist = false
        if settingsStore.scanDurationSeconds <= 0 {
            settingsStore.scanDurationSeconds = 10
        }

        settingsStore.exportGLTF = true
        settingsStore.exportOBJ = !environment.disablesOBJExport
        if environment.requestsDisabledGLTFExport {
            settingsStore.exportGLTF = true
        }

        if environment.forcesQualityGateBlock {
            var quality = settingsStore.scanQualityConfig
            quality.gateEnabled = true
            quality.minValidPoints = max(quality.minValidPoints, 9_999_999)
            settingsStore.scanQualityConfig = quality
        } else if environment.disablesQualityGate {
            var quality = settingsStore.scanQualityConfig
            quality.gateEnabled = false
            settingsStore.scanQualityConfig = quality
        }

#if DEBUG
        ScanDiagnostics.reset()
#endif
    }

    private static func makeScanService(environment: AppEnvironment) -> ScanService {
        guard environment.usesDedicatedScansRoot else {
            return ScanService(environment: environment)
        }

        let documentsURL: URL
        if let resolvedDocumentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            documentsURL = resolvedDocumentsURL
        } else {
            let fallback = FileManager.default.temporaryDirectory
            Log.persistence.error("Document directory unavailable; using temporary directory for UI-test scans root: \(fallback.path, privacy: .public)")
            documentsURL = fallback
        }

        let testRoot = documentsURL.appendingPathComponent("UITestScans", isDirectory: true)
        if environment.resetsDedicatedScansRootOnLaunch {
            try? FileManager.default.removeItem(at: testRoot)
        }
        return ScanService(scansRootURL: testRoot, environment: environment)
    }

    private static func makeScanRepository(scanService: ScanService, environment: AppEnvironment) -> ScanRepository {
        let testSeedService: ScanTestSeedService?
        if environment.seedsScan || environment.seedsMissingSceneScan {
            testSeedService = ScanTestSeedService(
                scansRootURL: scanService.scansRootURL,
                environment: environment
            )
        } else {
            testSeedService = nil
        }

        return ScanRepository(
            scansRootURL: scanService.scansRootURL,
            testSeedService: testSeedService
        )
    }

    private static func makeScanExporter(scanService: ScanService) -> ScanExporterService {
        ScanExporterService(scanService: scanService)
    }

    private static func makeEarServiceFactory(environment: AppEnvironment) -> () -> EarLandmarksService? {
        if environment.skipsEarML {
            return { nil }
        }

        return {
            do { return try EarLandmarksService() }
            catch { return nil }
        }
    }
}

#if DEBUG
enum ScanDiagnostics {
    struct Snapshot: Equatable {
        let scanStartTimestamp: TimeInterval?
        let finalizeCompletionTimestamp: TimeInterval?
        let hasSceneGLTF: Bool
        let hasHeadMeshOBJ: Bool
        let lastExportFolderName: String?
    }

    private static let lock = NSLock()
    private static var scanStartTimestamp: TimeInterval?
    private static var finalizeCompletionTimestamp: TimeInterval?
    private static var hasSceneGLTF = false
    private static var hasHeadMeshOBJ = false
    private static var lastExportFolderName: String?

    static func recordScanStart(date: Date = Date()) {
        lock.lock()
        scanStartTimestamp = date.timeIntervalSince1970
        lock.unlock()
    }

    static func recordFinalizeCompletion(date: Date = Date()) {
        lock.lock()
        finalizeCompletionTimestamp = date.timeIntervalSince1970
        lock.unlock()
    }

    static func recordExportArtifacts(folderURL: URL) {
        let gltfURL = folderURL.appendingPathComponent("scene.gltf")
        let objURL = folderURL.appendingPathComponent("head_mesh.obj")
        let hasGLTF = FileManager.default.fileExists(atPath: gltfURL.path)
        let hasOBJ = FileManager.default.fileExists(atPath: objURL.path)
        lock.lock()
        hasSceneGLTF = hasGLTF
        hasHeadMeshOBJ = hasOBJ
        lastExportFolderName = folderURL.lastPathComponent
        lock.unlock()
    }

    static func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(
            scanStartTimestamp: scanStartTimestamp,
            finalizeCompletionTimestamp: finalizeCompletionTimestamp,
            hasSceneGLTF: hasSceneGLTF,
            hasHeadMeshOBJ: hasHeadMeshOBJ,
            lastExportFolderName: lastExportFolderName
        )
    }

    static func reset() {
        lock.lock()
        scanStartTimestamp = nil
        finalizeCompletionTimestamp = nil
        hasSceneGLTF = false
        hasHeadMeshOBJ = false
        lastExportFolderName = nil
        lock.unlock()
    }
}
#endif
