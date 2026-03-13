import Foundation

final class HomeScanSessionController {
    private let environment: AppEnvironment
    private var scanStartTime: CFAbsoluteTime?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func recordScanStarted() {
        scanStartTime = CFAbsoluteTimeGetCurrent()
        Log.scan.info("Scan started")
#if DEBUG
        ScanDiagnostics.recordScanStart()
#endif
    }

    func recordScanCompleted() {
        if let start = scanStartTime {
            let duration = CFAbsoluteTimeGetCurrent() - start
            Log.scan.info("Scan completed in \(duration, privacy: .public)s")
        } else {
            Log.scan.info("Scan completed (duration unavailable)")
        }
        scanStartTime = nil
#if DEBUG
        ScanDiagnostics.recordFinalizeCompletion()
#endif
    }

    func recordScanCanceled() {
        if let start = scanStartTime {
            let duration = CFAbsoluteTimeGetCurrent() - start
            Log.scan.info("Scan canceled after \(duration, privacy: .public)s")
        } else {
            Log.scan.info("Scan canceled (duration unavailable)")
        }
        scanStartTime = nil
    }

#if DEBUG
    func deviceSmokeDiagnosticsText() -> String? {
        guard environment.isDeviceSmokeMode else { return nil }

        if let diagnosticsText = ScanDiagnostics.currentDiagnosticsText() {
            return diagnosticsText
        }

        let snapshot = ScanDiagnostics.snapshot()
        guard snapshot.lastExportFolderName != nil || snapshot.scanStartTimestamp != nil || snapshot.finalizeCompletionTimestamp != nil else {
            return nil
        }

        return "gltf=\(snapshot.hasSceneGLTF ? 1 : 0),obj=\(snapshot.hasHeadMeshOBJ ? 1 : 0),folder=\(snapshot.lastExportFolderName ?? "none")"
    }

    func scanStartTimeForTesting() -> CFAbsoluteTime? {
        scanStartTime
    }
#endif
}
