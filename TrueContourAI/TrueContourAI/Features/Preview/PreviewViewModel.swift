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

    func evaluateScanQuality(report: ScanQualityReport) -> ScanQuality {
        if report.isExportRecommended && report.qualityScore >= 0.8 {
            return .init(
                title: L("scan.preview.quality.great"),
                color: DesignSystem.Colors.qualityGood,
                tip: L("scan.preview.quality.tip.great")
            )
        } else if report.isExportRecommended && report.qualityScore >= 0.6 {
            return .init(
                title: L("scan.preview.quality.ok"),
                color: DesignSystem.Colors.qualityOk,
                tip: L("scan.preview.quality.tip.ok")
            )
        }

        return .init(
            title: L("scan.preview.quality.tryagain"),
            color: DesignSystem.Colors.qualityBad,
            tip: L("scan.preview.quality.tip.tryagain")
        )
    }

    func evaluateScanQuality(for pointCloud: SCPointCloud) -> ScanQuality {
        evaluateScanQuality(pointCount: Int(pointCloud.pointCount))
    }

    func evaluateScanQuality(pointCount: Int) -> ScanQuality {
        let approximateReport = ScanQualityReport(
            pointCount: pointCount,
            validPointCount: pointCount,
            widthMeters: 0,
            heightMeters: 0,
            depthMeters: 0,
            qualityScore: pointCount >= 200_000 ? 0.85 : (pointCount >= 100_000 ? 0.65 : 0.45),
            isExportRecommended: pointCount >= 100_000,
            advice: .rescanSlowly,
            reason: ""
        )
        return evaluateScanQuality(report: approximateReport)
    }

    func clearVerification() {
        verifiedEarImage = nil
        verifiedEarResult = nil
        verifiedEarOverlay = nil
    }
}
