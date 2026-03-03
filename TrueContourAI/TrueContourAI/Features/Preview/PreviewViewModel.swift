import Foundation
import UIKit
import StandardCyborgFusion

final class PreviewViewModel {
    enum Phase {
        case idle
        case preview
        case saving
    }

    private(set) var phase: Phase = .preview
    private(set) var meshForExport: SCMesh?
    private(set) var scanQuality: ScanQuality?
    private(set) var verifiedEarImage: UIImage?
    private(set) var verifiedEarResult: EarLandmarksResult?
    private(set) var verifiedEarOverlay: UIImage?

    var hasVerifiedEar: Bool {
        verifiedEarImage != nil && verifiedEarResult != nil && verifiedEarOverlay != nil
    }

    func setScanQuality(_ quality: ScanQuality?) {
        scanQuality = quality
    }

    func setMeshForExport(_ mesh: SCMesh?) {
        meshForExport = mesh
    }

    func setPhase(_ phase: Phase) {
        self.phase = phase
    }

    func setVerifiedEar(image: UIImage, result: EarLandmarksResult, overlay: UIImage) {
        verifiedEarImage = image
        verifiedEarResult = result
        verifiedEarOverlay = overlay
    }

    func evaluateScanQuality(for pointCloud: SCPointCloud) -> ScanQuality {
        evaluateScanQuality(pointCount: Int(pointCloud.pointCount))
    }

    func evaluateScanQuality(pointCount: Int) -> ScanQuality {
        if pointCount >= 200_000 {
            return .init(
                title: L("scan.preview.quality.great"),
                color: DesignSystem.Colors.qualityGood,
                tip: L("scan.preview.quality.tip.great")
            )
        } else if pointCount >= 100_000 {
            return .init(
                title: L("scan.preview.quality.ok"),
                color: DesignSystem.Colors.qualityOk,
                tip: L("scan.preview.quality.tip.ok")
            )
        } else {
            return .init(
                title: L("scan.preview.quality.tryagain"),
                color: DesignSystem.Colors.qualityBad,
                tip: L("scan.preview.quality.tip.tryagain")
            )
        }
    }

    func clearVerification() {
        verifiedEarImage = nil
        verifiedEarResult = nil
        verifiedEarOverlay = nil
    }
}
