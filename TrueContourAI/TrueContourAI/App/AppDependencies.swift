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

    init(arguments: [String]) {
        self.init(processInfoArguments: Set(arguments))
    }

    init(processInfo: ProcessInfo) {
        self.init(processInfoArguments: Set(processInfo.arguments))
    }

    private init(processInfoArguments arguments: Set<String>) {
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
    let runtimeSettings: AppRuntimeSettings
    let earServiceFactory: () -> EarLandmarksService?

    init(
        environment: AppEnvironment = .current,
        scanRepository: ScanRepository? = nil,
        scanExporter: ScanExporterService? = nil,
        settingsStore: SettingsStore = SettingsStore(),
        earServiceFactory: (() -> EarLandmarksService?)? = nil
    ) {
        self.environment = environment
        let resolvedScansRootURL = AppDependencies.makeScansRootURL(environment: environment)
        self.scanRepository = scanRepository ?? AppDependencies.makeScanRepository(
            scansRootURL: resolvedScansRootURL,
            environment: environment
        )
        self.scanExporter = scanExporter ?? AppDependencies.makeScanExporter(
            scansRootURL: resolvedScansRootURL,
            environment: environment
        )
        self.settingsStore = settingsStore
        self.runtimeSettings = AppRuntimeSettings(settingsStore: settingsStore, environment: environment)
        self.earServiceFactory = earServiceFactory ?? AppDependencies.makeEarServiceFactory(environment: environment)
#if DEBUG
        ScanDiagnostics.reset()
#endif
    }

    private static func makeScansRootURL(environment: AppEnvironment) -> URL {
        guard environment.usesDedicatedScansRoot else {
            let documentsURL: URL
            if let resolvedDocumentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                documentsURL = resolvedDocumentsURL
            } else {
                let fallback = FileManager.default.temporaryDirectory
                Log.persistence.error("Document directory unavailable; using temporary directory for scans root: \(fallback.path, privacy: .public)")
                documentsURL = fallback
            }
            return documentsURL.appendingPathComponent("Scans", isDirectory: true)
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
        return testRoot
    }

    private static func makeScanRepository(scansRootURL: URL, environment: AppEnvironment) -> ScanRepository {
        let testSeedService: ScanTestSeedService?
        if environment.seedsScan || environment.seedsMissingSceneScan {
            testSeedService = ScanTestSeedService(
                scansRootURL: scansRootURL,
                environment: environment
            )
        } else {
            testSeedService = nil
        }

        let repository = ScanRepository(
            scansRootURL: scansRootURL,
            testSeedService: testSeedService
        )
        // Seed the dedicated UI-test scan root before Home's first async refresh begins so
        // the recent-scans surface is deterministic from the initial launch frame.
        if environment.isUITestMode {
            testSeedService?.seedIfNeeded()
        }
        return repository
    }

    private static func makeScanExporter(
        scansRootURL: URL,
        environment: AppEnvironment
    ) -> ScanExporterService {
        _ = environment
        return ScanExporterService(scansRootURL: scansRootURL)
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
    static let didChangeNotification = Notification.Name("ScanDiagnostics.didChange")

    struct ExportDiagnostics: Equatable {
        let hasSceneGLTF: Bool
        let hasHeadMeshOBJ: Bool
        let lastExportFolderName: String?

        var text: String {
            "gltf=\(hasSceneGLTF ? 1 : 0),obj=\(hasHeadMeshOBJ ? 1 : 0),folder=\(lastExportFolderName ?? "none")"
        }
    }

    struct ExportTimingDiagnostics: Equatable {
        let totalMs: Int
        let createFolderMs: Int
        let gltfWriteMs: Int
        let thumbnailWriteMs: Int?
        let objWriteMs: Int?
        let earArtifactsWriteMs: Int?
        let summaryWriteMs: Int?

        var text: String {
            var parts = [
                "expTotalMs=\(totalMs)",
                "mkdirMs=\(createFolderMs)",
                "gltfMs=\(gltfWriteMs)"
            ]
            if let thumbnailWriteMs { parts.append("thumbMs=\(thumbnailWriteMs)") }
            if let objWriteMs { parts.append("objMs=\(objWriteMs)") }
            if let earArtifactsWriteMs { parts.append("earMs=\(earArtifactsWriteMs)") }
            if let summaryWriteMs { parts.append("summaryMs=\(summaryWriteMs)") }
            return parts.joined(separator: ",")
        }
    }

    struct ExistingPreviewTimingDiagnostics: Equatable {
        let totalMs: Int
        let summaryLoadMs: Int
        let sceneLoadMs: Int?
        let earImageLoadMs: Int
        let skipsGLTF: Bool

        var text: String {
            var parts = [
                "openMs=\(totalMs)",
                "sumMs=\(summaryLoadMs)",
                "earImgMs=\(earImageLoadMs)",
                "skipGLTF=\(skipsGLTF ? 1 : 0)"
            ]
            if let sceneLoadMs {
                parts.append("sceneMs=\(sceneLoadMs)")
            }
            return parts.joined(separator: ",")
        }
    }

    struct Snapshot: Equatable {
        let scanStartTimestamp: TimeInterval?
        let finalizeCompletionTimestamp: TimeInterval?
        let hasSceneGLTF: Bool
        let hasHeadMeshOBJ: Bool
        let lastExportFolderName: String?
        let committedExportDiagnostics: ExportDiagnostics?
        let exportTimingDiagnostics: ExportTimingDiagnostics?
        let existingPreviewTimingDiagnostics: ExistingPreviewTimingDiagnostics?
    }

    private static let lock = NSLock()
    private static var scanStartTimestamp: TimeInterval?
    private static var finalizeCompletionTimestamp: TimeInterval?
    private static var hasSceneGLTF = false
    private static var hasHeadMeshOBJ = false
    private static var lastExportFolderName: String?
    private static var committedExportDiagnostics: ExportDiagnostics?
    private static var exportTimingDiagnostics: ExportTimingDiagnostics?
    private static var existingPreviewTimingDiagnostics: ExistingPreviewTimingDiagnostics?

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
        let diagnostics = ExportDiagnostics(
            hasSceneGLTF: hasGLTF,
            hasHeadMeshOBJ: hasOBJ,
            lastExportFolderName: folderURL.lastPathComponent
        )
        lock.lock()
        hasSceneGLTF = hasGLTF
        hasHeadMeshOBJ = hasOBJ
        lastExportFolderName = folderURL.lastPathComponent
        committedExportDiagnostics = diagnostics
        lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    static func recordExportTimings(_ diagnostics: ExportTimingDiagnostics) {
        lock.lock()
        exportTimingDiagnostics = diagnostics
        lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    static func recordExistingPreviewLoadTimings(_ diagnostics: ExistingPreviewTimingDiagnostics) {
        lock.lock()
        existingPreviewTimingDiagnostics = diagnostics
        lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    static func currentDiagnosticsText() -> String? {
        lock.lock()
        defer { lock.unlock() }
        var parts: [String] = []
        if let committedExportDiagnostics {
            parts.append(committedExportDiagnostics.text)
        }
        if let exportTimingDiagnostics {
            parts.append(exportTimingDiagnostics.text)
        }
        if let existingPreviewTimingDiagnostics {
            parts.append(existingPreviewTimingDiagnostics.text)
        }
        return parts.isEmpty ? nil : parts.joined(separator: ",")
    }

    static func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(
            scanStartTimestamp: scanStartTimestamp,
            finalizeCompletionTimestamp: finalizeCompletionTimestamp,
            hasSceneGLTF: hasSceneGLTF,
            hasHeadMeshOBJ: hasHeadMeshOBJ,
            lastExportFolderName: lastExportFolderName,
            committedExportDiagnostics: committedExportDiagnostics,
            exportTimingDiagnostics: exportTimingDiagnostics,
            existingPreviewTimingDiagnostics: existingPreviewTimingDiagnostics
        )
    }

    static func reset() {
        lock.lock()
        scanStartTimestamp = nil
        finalizeCompletionTimestamp = nil
        hasSceneGLTF = false
        hasHeadMeshOBJ = false
        lastExportFolderName = nil
        committedExportDiagnostics = nil
        exportTimingDiagnostics = nil
        existingPreviewTimingDiagnostics = nil
        lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }
}
#endif
