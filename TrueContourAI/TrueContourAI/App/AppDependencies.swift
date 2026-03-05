import Foundation

struct AppDependencies {
    let scanService: ScanService
    let settingsStore: SettingsStore
    let earServiceFactory: () -> EarLandmarksService?

    init(
        scanService: ScanService = AppDependencies.makeScanService(),
        settingsStore: SettingsStore = SettingsStore(),
        earServiceFactory: (() -> EarLandmarksService?)? = nil
    ) {
        self.scanService = scanService
        self.settingsStore = settingsStore
        self.earServiceFactory = earServiceFactory ?? AppDependencies.makeEarServiceFactory()

        let args = ProcessInfo.processInfo.arguments
        if args.contains("ui-test-device-smoke") {
            // Device smoke mode should launch directly into scanning flow.
            self.settingsStore.showPreScanChecklist = false
            if self.settingsStore.scanDurationSeconds <= 0 {
                self.settingsStore.scanDurationSeconds = 10
            }
            self.settingsStore.exportGLTF = true
            self.settingsStore.exportOBJ = true
            if args.contains("ui-test-export-gltf-off") {
                self.settingsStore.exportGLTF = false
            }
            if args.contains("ui-test-export-obj-off") {
                self.settingsStore.exportOBJ = false
            }
            if !self.settingsStore.exportGLTF {
                self.settingsStore.exportGLTF = true
            }
            if args.contains("ui-test-force-quality-gate-block") {
                var quality = self.settingsStore.scanQualityConfig
                quality.gateEnabled = true
                quality.minValidPoints = max(quality.minValidPoints, 9_999_999)
                self.settingsStore.scanQualityConfig = quality
            } else if args.contains("ui-test-disable-quality-gate") {
                var quality = self.settingsStore.scanQualityConfig
                quality.gateEnabled = false
                self.settingsStore.scanQualityConfig = quality
            }
#if DEBUG
            ScanDiagnostics.reset()
#endif
        }
    }

    private static func makeScanService() -> ScanService {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("ui-test-scans-root") else {
            return ScanService()
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
        if args.contains("ui-test-reset-scans") {
            try? FileManager.default.removeItem(at: testRoot)
        }
        return ScanService(scansRootURL: testRoot)
    }

    private static func makeEarServiceFactory() -> () -> EarLandmarksService? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("ui-test-skip-ear-ml") {
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
