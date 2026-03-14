import Foundation
import UIKit
import StandardCyborgFusion
import simd

final class PreviewSessionState {
    var currentPreviewedFolderURL: URL?
}

final class PreviewViewModel {
    enum EarVerificationImageSource: String {
        case bestCaptureFrame
        case latestCaptureFallback
        case previewSnapshotFallback
    }

    enum Phase {
        case idle
        case preview
        case saving
    }

    private(set) var phase: Phase = .preview
    private(set) var sessionID = UUID()
    private(set) var sessionMetrics: ScanFlowState.ScanSessionMetrics?
    private(set) var qualityReport: ScanQualityReport?
    private(set) var measurementSummary: LocalMeasurementGenerationService.ResultSummary?
    private(set) var meshForExport: SCMesh?
    private(set) var scanQuality: ScanQuality?
    private(set) var verifiedEarImage: UIImage?
    private(set) var verifiedEarResult: EarLandmarksResult?
    private(set) var verifiedEarOverlay: UIImage?
    private(set) var verifiedEarCropOverlay: UIImage?
    private(set) var preservedEarVerificationImage: UIImage?
    private(set) var preservedEarVerificationSelectionMetadata: EarVerificationSelectionMetadata?
    private(set) var earVerificationImageSource: EarVerificationImageSource?
    private(set) var latestFitCheckResult: FitModelCheckResult?
    private(set) var latestFitMeshData: FitModelPackService.MeshData?
    private(set) var manualEarLeftMeters: SIMD3<Float>?
    private(set) var manualEarRightMeters: SIMD3<Float>?
    private(set) var browPlaneDropFromTopFraction: Float = 0.25
    private(set) var showsAdvancedBrowControls = false
    private(set) var showsFitPanel = false
    private(set) var isMeshingActive = false

    enum FitEarPickState {
        case none
        case pickLeft
        case pickRight
    }

    private(set) var fitEarPickState: FitEarPickState = .none

    var hasVerifiedEar: Bool {
        verifiedEarImage != nil && verifiedEarResult != nil && verifiedEarOverlay != nil
    }

    @discardableResult
    func beginExistingScanSession() -> UUID {
        let sessionID = UUID()
        self.sessionID = sessionID
        sessionMetrics = nil
        qualityReport = nil
        measurementSummary = nil
        meshForExport = nil
        scanQuality = nil
        clearVerification()
        resetFitState()
        phase = .preview
        return sessionID
    }

    func setScanQuality(_ quality: ScanQuality?) {
        scanQuality = quality
    }

    @discardableResult
    func beginPreviewSession(
        sessionMetrics: ScanFlowState.ScanSessionMetrics?,
        preservedEarVerificationImage: UIImage? = nil,
        preservedEarVerificationSelectionMetadata: EarVerificationSelectionMetadata? = nil
    ) -> UUID {
        let sessionID = UUID()
        self.sessionID = sessionID
        self.sessionMetrics = sessionMetrics
        self.preservedEarVerificationImage = preservedEarVerificationImage
        self.preservedEarVerificationSelectionMetadata = preservedEarVerificationSelectionMetadata
        self.earVerificationImageSource = nil
        qualityReport = nil
        measurementSummary = nil
        meshForExport = nil
        scanQuality = nil
        clearVerification()
        resetFitState()
        phase = .preview
        return sessionID
    }

    func invalidateSession() {
        sessionID = UUID()
    }

    func isCurrentSession(_ sessionID: UUID) -> Bool {
        self.sessionID == sessionID
    }

    func setQualityReport(_ report: ScanQualityReport) {
        qualityReport = report
        scanQuality = evaluateScanQuality(report: report)
    }

    func setMeasurementSummary(_ summary: LocalMeasurementGenerationService.ResultSummary?) {
        measurementSummary = summary
    }

    func setMeshForExport(_ mesh: SCMesh?) {
        meshForExport = mesh
    }

    func setMeshingActive(_ isActive: Bool) {
        isMeshingActive = isActive
    }

    func setFitPanelExpanded(_ isExpanded: Bool) {
        showsFitPanel = isExpanded
    }

    func toggleFitPanelExpanded() {
        showsFitPanel.toggle()
    }

    func setAdvancedBrowControlsVisible(_ isVisible: Bool) {
        showsAdvancedBrowControls = isVisible
    }

    func toggleAdvancedBrowControlsVisible() {
        showsAdvancedBrowControls.toggle()
    }

    func setBrowPlaneDropFromTopFraction(_ value: Float) {
        browPlaneDropFromTopFraction = min(0.30, max(0.20, value))
    }

    func setFitCheckResult(_ result: FitModelCheckResult?) {
        latestFitCheckResult = result
    }

    func setFitMeshData(_ meshData: FitModelPackService.MeshData?) {
        latestFitMeshData = meshData
    }

    func beginFitEarPicking() {
        fitEarPickState = .pickLeft
    }

    func setNextFitEarPickState(_ state: FitEarPickState) {
        fitEarPickState = state
    }

    func setManualLeftEar(_ point: SIMD3<Float>?) {
        manualEarLeftMeters = point
    }

    func setManualRightEar(_ point: SIMD3<Float>?) {
        manualEarRightMeters = point
    }

    func setPhase(_ phase: Phase) {
        self.phase = phase
    }

    func setVerifiedEar(image: UIImage, result: EarLandmarksResult, overlay: UIImage, cropOverlay: UIImage) {
        verifiedEarImage = image
        verifiedEarResult = result
        verifiedEarOverlay = overlay
        verifiedEarCropOverlay = cropOverlay
    }

    func setEarVerificationImageSource(_ source: EarVerificationImageSource) {
        earVerificationImageSource = source
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
        verifiedEarCropOverlay = nil
        earVerificationImageSource = nil
    }

    func clearPreviewArtifacts() {
        invalidateSession()
        sessionMetrics = nil
        qualityReport = nil
        measurementSummary = nil
        meshForExport = nil
        scanQuality = nil
        preservedEarVerificationImage = nil
        preservedEarVerificationSelectionMetadata = nil
        clearVerification()
        resetFitState()
        phase = .idle
    }

    private func resetFitState() {
        latestFitCheckResult = nil
        latestFitMeshData = nil
        manualEarLeftMeters = nil
        manualEarRightMeters = nil
        fitEarPickState = .none
        browPlaneDropFromTopFraction = 0.25
        showsAdvancedBrowControls = false
        showsFitPanel = false
        isMeshingActive = false
    }
}
