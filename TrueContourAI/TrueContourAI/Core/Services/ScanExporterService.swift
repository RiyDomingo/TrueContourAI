import UIKit
import StandardCyborgFusion

final class ScanExporterService: ScanExporting {
    private let scanService: ScanService

    init(scanService: ScanService) {
        self.scanService = scanService
    }

    convenience init(
        scansRootURL: URL,
        defaults: UserDefaults = .standard
    ) {
        self.init(scanService: ScanService(scansRootURL: scansRootURL, defaults: defaults))
    }

    func exportScanFolder(
        mesh: SCMesh,
        scene: SCScene,
        thumbnail: UIImage?,
        earArtifacts: ScanService.EarArtifacts?,
        scanSummary: ScanService.ScanSummary?,
        includeGLTF: Bool,
        includeOBJ: Bool
    ) -> ScanService.ExportResult {
        scanService.exportScanFolder(
            mesh: mesh,
            scene: scene,
            thumbnail: thumbnail,
            earArtifacts: earArtifacts,
            scanSummary: scanSummary,
            includeGLTF: includeGLTF,
            includeOBJ: includeOBJ
        )
    }

    func setLastScanFolder(_ folderURL: URL) {
        scanService.setLastScanFolder(folderURL)
    }
}
