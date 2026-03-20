import Foundation
import UIKit
import StandardCyborgFusion
import simd

final class PreviewFitUseCase {
    private let fitModelPackService = FitModelPackService()
    private let scanReader: PreviewScanReading

    init(scanReader: PreviewScanReading) {
        self.scanReader = scanReader
    }

    func runFit(
        mesh: SCMesh?,
        folderURL: URL?,
        manualEarLeftMeters: SIMD3<Float>?,
        manualEarRightMeters: SIMD3<Float>?,
        browPlaneDropFromTopFraction: Float
    ) -> Result<(PreviewFitResult, FitModelPackService.MeshData?), PreviewFailure> {
        let meshData: FitModelPackService.MeshData?
        if let mesh {
            meshData = FitModelPackService.extractMeshData(from: mesh)
        } else if let folderURL,
                  let objURL = scanReader.resolveOBJFromFolder(folderURL) {
            meshData = FitModelPackService.readOBJMeshData(from: objURL)
        } else {
            meshData = nil
        }

        guard let meshData else {
            return .failure(.fitFailed(L("scan.preview.fit.unavailable.message")))
        }

        let result = fitModelPackService.checkFromOBJMeshData(
            meshData: meshData,
            manualEarLeftMeters: manualEarLeftMeters,
            manualEarRightMeters: manualEarRightMeters,
            browPlaneDropFromTopFraction: browPlaneDropFromTopFraction,
            appVersion: Self.appVersionString(),
            deviceModel: UIDevice.current.model
        )

        guard let result else {
            return .failure(.fitFailed(L("scan.preview.fit.unavailable.message")))
        }

        var text = String(
            format: L("scan.preview.fit.results.format"),
            Int(result.fitData.head_circumference_brow_mm.rounded()),
            Int(result.fitData.head_width_max_mm.rounded()),
            Int(result.fitData.head_length_max_mm.rounded()),
            Int(result.fitData.occipital_offset_mm.rounded()),
            Int((result.fitData.quality_flags.scan_coverage_score * 100).rounded())
        )
        if result.fitData.ear_left_xyz_mm == nil || result.fitData.ear_right_xyz_mm == nil {
            text += "\n" + L("scan.preview.fit.results.missingEars")
        } else if !result.warnings.isEmpty {
            text += "\n" + result.warnings.joined(separator: " ")
        }

        return .success((
            PreviewFitResult(
                summaryText: text,
                fitCheckResult: result,
                meshDataAvailable: true
            ),
            meshData
        ))
    }

    private static func appVersionString() -> String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let short, let build {
            return "\(short) (\(build))"
        }
        return short ?? build ?? "unknown"
    }
}
