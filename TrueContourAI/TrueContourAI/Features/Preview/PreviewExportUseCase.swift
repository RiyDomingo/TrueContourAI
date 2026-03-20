import Foundation
import UIKit
import StandardCyborgFusion

final class PreviewExportUseCase {
    private let settingsStore: SettingsStore
    private let scanExporter: ScanExporting

    init(
        settingsStore: SettingsStore,
        scanExporter: ScanExporting
    ) {
        self.settingsStore = settingsStore
        self.scanExporter = scanExporter
    }

    func makeEligibilityInput(
        meshAvailable: Bool,
        qualityReport: ScanQualityReport?
    ) -> PreviewExportEligibilityInput {
        PreviewExportEligibilityInput(
            meshAvailable: meshAvailable,
            qualityReport: qualityReport,
            exportGLTF: settingsStore.exportGLTF,
            exportOBJ: settingsStore.exportOBJ,
            qualityGateEnabled: settingsStore.scanQualityConfig.gateEnabled
        )
    }

    func precheck(_ input: PreviewExportEligibilityInput) -> PreviewBlockReason? {
        guard input.exportGLTF else {
            return .gltfRequired
        }
        guard input.meshAvailable else {
            return .meshNotReady
        }
        if input.qualityGateEnabled,
           let qualityReport = input.qualityReport,
           !qualityReport.isExportRecommended {
            return .qualityGateBlocked(reason: qualityReport.reason, advice: qualityReport.advice.message)
        }
        return nil
    }

    func exportFormatSummary() -> String {
        var formats: [String] = []
        if settingsStore.exportGLTF { formats.append(L("scan.preview.exportFormat.gltf")) }
        if settingsStore.exportOBJ { formats.append(L("scan.preview.exportFormat.obj")) }
        if formats.isEmpty { return L("scan.preview.exportFormat.none") }
        return formats.joined(separator: ", ")
    }

    func makeExportSnapshot(
        store: PreviewStore,
        sceneSnapshot: PreviewSceneSnapshot
    ) -> PreviewExportSnapshot? {
        guard let mesh = store.meshForExport else { return nil }
        return PreviewExportSnapshot(
            mesh: mesh,
            sceneSnapshot: sceneSnapshot,
            earArtifacts: store.makeEarArtifacts(),
            scanSummary: ScanSummaryBuilder.build(
                settingsStore: settingsStore,
                metrics: store.sessionMetrics,
                qualityReport: store.qualityReport,
                measurementSummary: store.measurementSummary,
                hadEarVerification: store.hasVerifiedEar
            ),
            exportGLTF: settingsStore.exportGLTF,
            exportOBJ: settingsStore.exportOBJ
        )
    }

    func makeExportRequest(from snapshot: PreviewExportSnapshot) -> PreviewExportRequest {
        PreviewExportRequest(
            mesh: snapshot.mesh,
            scene: snapshot.sceneSnapshot.scene,
            thumbnail: snapshot.sceneSnapshot.renderedImage,
            earArtifacts: snapshot.earArtifacts,
            scanSummary: snapshot.scanSummary,
            includeGLTF: snapshot.exportGLTF,
            includeOBJ: snapshot.exportOBJ
        )
    }

    func export(
        snapshot: PreviewExportSnapshot,
        earServiceUnavailable: Bool,
        completion: @escaping (Result<SavedScanResult, PreviewFailure>) -> Void
    ) {
        let request = makeExportRequest(from: snapshot)
        let formatSummary = exportFormatSummary()

        PreviewQoSQueues.export.async { [scanExporter] in
            let exportResult = scanExporter.exportScanFolder(
                mesh: request.mesh,
                scene: request.scene,
                thumbnail: request.thumbnail,
                earArtifacts: request.earArtifacts,
                scanSummary: request.scanSummary,
                includeGLTF: request.includeGLTF,
                includeOBJ: request.includeOBJ
            )

            DispatchQueue.main.async {
                switch exportResult {
                case .success(let folderURL):
                    scanExporter.setLastScanFolder(folderURL)
                    completion(.success(
                        SavedScanResult(
                            folderURL: folderURL,
                            folderName: folderURL.lastPathComponent,
                            formatSummary: formatSummary,
                            earServiceUnavailable: earServiceUnavailable && snapshot.earArtifacts == nil
                        )
                    ))
                case .failure(let message):
                    completion(.failure(.exportFailed(message)))
                }
            }
        }
    }
}
