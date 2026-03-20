import Foundation
import UIKit
import StandardCyborgFusion
import simd

final class PreviewSessionState {
    var currentPreviewedFolderURL: URL?
}

final class PreviewStore {
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

    enum FitEarPickState {
        case none
        case pickLeft
        case pickRight
    }

    private let settingsStore: SettingsStore
    private(set) var phase: Phase = .preview

    private(set) var state: PreviewState = .loading {
        didSet { emitStateChange() }
    }

    var onStateChange: ((PreviewState) -> Void)?
    var onEffect: ((PreviewEffect) -> Void)?

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
    private(set) var latestFitSummaryText: String?
    private(set) var manualEarLeftMeters: SIMD3<Float>?
    private(set) var manualEarRightMeters: SIMD3<Float>?
    private(set) var browPlaneDropFromTopFraction: Float = 0.25
    private(set) var showsAdvancedBrowControls = false
    private(set) var showsFitPanel = false
    private(set) var isMeshingActive = false
    private(set) var fitEarPickState: FitEarPickState = .none
    private(set) var currentLoadedScan: PreviewLoadedScan?

    init(settingsStore: SettingsStore = SettingsStore()) {
        self.settingsStore = settingsStore
        state = .loading
    }

    var hasVerifiedEar: Bool {
        verifiedEarImage != nil && verifiedEarResult != nil && verifiedEarOverlay != nil
    }

    func send(_ action: PreviewAction) {
        switch action {
        case .viewDidLoad:
            phase = .preview
            state = .loading
        case .existingScanLoaded(let loaded):
            currentLoadedScan = loaded
            phase = .preview
            state = .ready(makeViewData())
        case .postScanLoaded:
            phase = .preview
            state = .meshing(makeViewData())
        case .saveTapped:
            phase = .saving
            state = .saving(makeViewData(statusText: L("scan.preview.exporting"), spinner: true, saveEnabled: false, shareEnabled: false, verifyEnabled: false))
        case .shareTapped:
            emitEffect(.hapticPrimary)
        case .closeTapped:
            emitEffect(.route(.dismiss))
        case .verifyEarTapped:
            emitEffect(.hapticPrimary)
        case .fitTapped:
            emitEffect(.hapticPrimary)
        case .fitEarPointSelected(let point):
            handleFitEarPointSelection(point)
        case .exportCompleted(let result):
            handleExportCompleted(result)
        case .earVerificationCompleted(let result):
            handleEarVerificationCompleted(result)
        case .fitCompleted(let result):
            handleFitCompleted(result)
        }
    }

    @discardableResult
    func beginExistingScanSession(
        preservedEarVerificationImage: UIImage? = nil,
        preservedEarVerificationSelectionMetadata: EarVerificationSelectionMetadata? = nil
    ) -> UUID {
        let sessionID = UUID()
        self.sessionID = sessionID
        self.preservedEarVerificationImage = preservedEarVerificationImage
        self.preservedEarVerificationSelectionMetadata = preservedEarVerificationSelectionMetadata
        sessionMetrics = nil
        currentLoadedScan = nil
        resetSessionArtifacts()
        phase = .preview
        state = .loading
        return sessionID
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
        currentLoadedScan = nil
        resetSessionArtifacts()
        phase = .preview
        state = .loading
        return sessionID
    }

    func invalidateSession() {
        sessionID = UUID()
    }

    func isCurrentSession(_ sessionID: UUID) -> Bool {
        self.sessionID == sessionID
    }

    func clearPreviewArtifacts() {
        invalidateSession()
        sessionMetrics = nil
        currentLoadedScan = nil
        preservedEarVerificationImage = nil
        preservedEarVerificationSelectionMetadata = nil
        resetSessionArtifacts()
        phase = .idle
        state = .loading
    }

    func setPhase(_ phase: Phase) {
        self.phase = phase
        switch phase {
        case .idle:
            state = .loading
        case .preview:
            refreshState()
        case .saving:
            state = .saving(makeViewData(statusText: L("scan.preview.exporting"), spinner: true, saveEnabled: false, shareEnabled: false, verifyEnabled: false))
        }
    }

    func setQualityReport(_ report: ScanQualityReport) {
        qualityReport = report
        scanQuality = evaluateScanQuality(report: report)
        refreshState()
    }

    func setMeasurementSummary(_ summary: LocalMeasurementGenerationService.ResultSummary?) {
        measurementSummary = summary
        refreshState()
    }

    func setMeshForExport(_ mesh: SCMesh?) {
        meshForExport = mesh
        refreshState()
    }

    func setMeshingActive(_ isActive: Bool) {
        isMeshingActive = isActive
        refreshState()
    }

    func setFitPanelExpanded(_ isExpanded: Bool) {
        showsFitPanel = isExpanded
        refreshState()
    }

    func toggleFitPanelExpanded() {
        showsFitPanel.toggle()
        refreshState()
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

    func setFitResult(_ result: PreviewFitResult) {
        latestFitSummaryText = result.summaryText
        latestFitCheckResult = result.fitCheckResult
        refreshState()
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

    func setVerifiedEar(image: UIImage, result: EarLandmarksResult, overlay: UIImage, cropOverlay: UIImage) {
        verifiedEarImage = image
        verifiedEarResult = result
        verifiedEarOverlay = overlay
        verifiedEarCropOverlay = cropOverlay
        refreshState()
    }

    func setEarVerificationImageSource(_ source: EarVerificationImageSource) {
        earVerificationImageSource = source
    }

    func makeEarArtifacts() -> ScanEarArtifacts? {
        guard let earImage = verifiedEarImage,
              let earResult = verifiedEarResult,
              let earOverlay = verifiedEarOverlay,
              let earCropOverlay = verifiedEarCropOverlay else {
            return nil
        }
        return .init(
            earImage: earImage,
            earResult: earResult,
            earOverlay: earOverlay,
            earCropOverlay: earCropOverlay
        )
    }

    func blockSave(reason: PreviewBlockReason) {
        state = .blocked(reason, makeViewData())
    }

    func restoreReadyState() {
        refreshState()
    }

    func presentShare(items: [Any], sourceRect: CGRect?) {
        emitEffect(.route(.presentShare(items: items, sourceRect: sourceRect)))
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

    private func resetSessionArtifacts() {
        qualityReport = nil
        measurementSummary = nil
        meshForExport = nil
        scanQuality = nil
        clearVerification()
        resetFitState()
    }

    private func resetFitState() {
        latestFitCheckResult = nil
        latestFitMeshData = nil
        latestFitSummaryText = nil
        manualEarLeftMeters = nil
        manualEarRightMeters = nil
        fitEarPickState = .none
        browPlaneDropFromTopFraction = 0.25
        showsAdvancedBrowControls = false
        showsFitPanel = false
        isMeshingActive = false
    }

    func clearVerification() {
        verifiedEarImage = nil
        verifiedEarResult = nil
        verifiedEarOverlay = nil
        verifiedEarCropOverlay = nil
        earVerificationImageSource = nil
    }

    private func handleExportCompleted(_ result: Result<SavedScanResult, PreviewFailure>) {
        switch result {
        case .success(let saved):
            phase = .idle
            state = .saved(saved)
            emitEffect(.route(.returnHomeAfterSave(saved)))
        case .failure(let failure):
            phase = .preview
            let viewData = makeViewData()
            state = .failed(failure, viewData)
            state = .ready(viewData)
            if case .exportFailed(let message) = failure {
                emitEffect(.alert(
                    title: L("scan.preview.exportFailed.title"),
                    message: String(format: L("scan.preview.exportFailed.message"), message),
                    identifier: "exportFailedAlert"
                ))
            }
        }
    }

    private func handleEarVerificationCompleted(_ result: Result<PreviewEarVerificationResult, PreviewFailure>) {
        switch result {
        case .success(let verification):
            setVerifiedEar(
                image: verification.earImage,
                result: verification.earResult,
                overlay: verification.earOverlay,
                cropOverlay: verification.earCropOverlay
            )
            emitEffect(.alert(
                title: L("scan.preview.verified.alert.title"),
                message: L("scan.preview.verified.alert.message"),
                identifier: "earVerifiedAlert"
            ))
        case .failure(let failure):
            if case .verificationFailed(let message) = failure {
                emitEffect(.alert(
                    title: L("scan.preview.verifyFailed.title"),
                    message: message,
                    identifier: "earVerifyFailedAlert"
                ))
            }
            refreshState()
        }
    }

    private func handleFitCompleted(_ result: Result<PreviewFitResult, PreviewFailure>) {
        switch result {
        case .success(let fitResult):
            setFitResult(fitResult)
            if !fitResult.summaryText.isEmpty {
                emitEffect(.toast(fitResult.summaryText))
            }
        case .failure(let failure):
            if case .fitFailed(let message) = failure {
                emitEffect(.alert(
                    title: L("scan.preview.fit.unavailable.title"),
                    message: message,
                    identifier: "fitUnavailableAlert"
                ))
            }
        }
    }

    private func handleFitEarPointSelection(_ point: SIMD3<Float>) {
        switch fitEarPickState {
        case .pickLeft:
            manualEarLeftMeters = point
            fitEarPickState = .pickRight
            emitEffect(.toast(L("scan.preview.fit.pick.right")))
        case .pickRight:
            manualEarRightMeters = point
            fitEarPickState = .none
        case .none:
            break
        }
    }

    private func refreshState() {
        phase = .preview
        state = isMeshingActive ? .meshing(makeViewData()) : .ready(makeViewData())
    }

    private func makeViewData(
        statusText: String? = nil,
        spinner: Bool? = nil,
        saveEnabled: Bool? = nil,
        shareEnabled: Bool? = nil,
        verifyEnabled: Bool? = nil
    ) -> PreviewViewData {
        let measurementText = measurementSummary.map {
            String(
                format: L("scan.preview.fit.results.format"),
                Int($0.circumferenceMm.rounded()),
                Int($0.widthMm.rounded()),
                Int($0.depthMm.rounded()),
                0,
                Int(($0.confidence * 100).rounded())
            )
        }
        let qualityToken: PreviewColorToken?
        switch scanQuality?.title {
        case L("scan.preview.quality.great"):
            qualityToken = .good
        case L("scan.preview.quality.ok"):
            qualityToken = .ok
        case .some:
            qualityToken = .bad
        case .none:
            qualityToken = nil
        }

        let formatSummary = exportFormatSummary()
        let canSave = meshForExport != nil && settingsStore.exportGLTF && !isMeshingActive
        return PreviewViewData(
            qualityTitle: scanQuality?.title,
            qualityColorToken: qualityToken,
            qualityTipText: scanQuality?.tip,
            measurementSummaryText: measurementText ?? latestFitSummaryText,
            meshingStatusText: statusText ?? (isMeshingActive ? L("scan.preview.meshing") : L("scan.preview.readyToSave")),
            meshingSpinnerVisible: spinner ?? isMeshingActive,
            saveButtonEnabled: saveEnabled ?? canSave,
            shareButtonEnabled: shareEnabled ?? true,
            verifyEarButtonEnabled: verifyEnabled ?? true,
            fitPanelVisible: settingsStore.developerModeEnabled,
            fitPanelExpanded: showsFitPanel,
            exportFormatSummary: formatSummary,
            earVerified: hasVerifiedEar
        )
    }

    private func exportFormatSummary() -> String {
        var formats: [String] = []
        if settingsStore.exportGLTF { formats.append(L("scan.preview.exportFormat.gltf")) }
        if settingsStore.exportOBJ { formats.append(L("scan.preview.exportFormat.obj")) }
        if formats.isEmpty { return L("scan.preview.exportFormat.none") }
        return formats.joined(separator: ", ")
    }

    private func emitStateChange() {
        if Thread.isMainThread {
            onStateChange?(state)
        } else {
            DispatchQueue.main.async { [weak self, state] in
                self?.onStateChange?(state)
            }
        }
    }

    private func emitEffect(_ effect: PreviewEffect) {
        if Thread.isMainThread {
            onEffect?(effect)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onEffect?(effect)
            }
        }
    }
}
