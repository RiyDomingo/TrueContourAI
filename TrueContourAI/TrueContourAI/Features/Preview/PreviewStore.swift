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

    private struct SessionContext {
        var id = UUID()
        var metrics: ScanFlowState.ScanSessionMetrics?
        var loadedScan: PreviewLoadedScan?
    }

    private struct VerificationState {
        var verifiedEarImage: UIImage?
        var verifiedEarResult: EarLandmarksResult?
        var verifiedEarOverlay: UIImage?
        var verifiedEarCropOverlay: UIImage?
        var preservedImage: UIImage?
        var preservedSelectionMetadata: EarVerificationSelectionMetadata?
        var imageSource: EarVerificationImageSource?

        var hasVerifiedEar: Bool {
            verifiedEarImage != nil && verifiedEarResult != nil && verifiedEarOverlay != nil
        }

        mutating func clearVerified() {
            verifiedEarImage = nil
            verifiedEarResult = nil
            verifiedEarOverlay = nil
            verifiedEarCropOverlay = nil
            imageSource = nil
        }
    }

    private struct FitState {
        var latestCheckResult: FitModelCheckResult?
        var latestMeshData: FitModelPackService.MeshData?
        var latestSummaryText: String?
        var manualLeftEarMeters: SIMD3<Float>?
        var manualRightEarMeters: SIMD3<Float>?
        var browPlaneDropFromTopFraction: Float = 0.25
        var showsAdvancedBrowControls = false
        var showsPanel = false
        var earPickState: FitEarPickState = .none

        mutating func reset() {
            latestCheckResult = nil
            latestMeshData = nil
            latestSummaryText = nil
            manualLeftEarMeters = nil
            manualRightEarMeters = nil
            browPlaneDropFromTopFraction = 0.25
            showsAdvancedBrowControls = false
            showsPanel = false
            earPickState = .none
        }
    }

    private struct RenderState {
        var qualityReport: ScanQualityReport?
        var measurementSummary: LocalMeasurementGenerationService.ResultSummary?
        var meshForExport: SCMesh?
        var scanQuality: ScanQuality?
        var isMeshingActive = false
        var meshingProgressFraction: Float?

        mutating func reset() {
            qualityReport = nil
            measurementSummary = nil
            meshForExport = nil
            scanQuality = nil
            isMeshingActive = false
            meshingProgressFraction = nil
        }
    }

    private struct ViewDataOverrides {
        var statusText: String?
        var spinner: Bool?
        var saveEnabled: Bool?
        var shareEnabled: Bool?
        var verifyEnabled: Bool?
    }

    private enum EffectFactory {
        static func missingShareFolder() -> PreviewEffect {
            .alert(
                title: L("scan.preview.missingFolder.title"),
                message: L("scan.preview.missingFolder.message"),
                identifier: "missingFolderAlert"
            )
        }

        static func earServiceUnavailable() -> PreviewEffect {
            .alert(
                title: L("scan.preview.earUnavailable.title"),
                message: L("scan.preview.earUnavailable.message"),
                identifier: "earUnavailableAlert"
            )
        }

        static func exportFailure(message: String, identifier: String) -> PreviewEffect {
            .alert(
                title: L("scan.preview.exportFailed.title"),
                message: String(format: L("scan.preview.exportFailed.message"), message),
                identifier: identifier
            )
        }

        static func loadFailure(message: String) -> PreviewEffect {
            .alertThenRoute(
                title: L("scan.preview.missingScene.title"),
                message: message,
                identifier: "missingSceneAlert",
                route: .dismiss
            )
        }

        static func blockedSave(_ reason: PreviewBlockReason) -> PreviewEffect {
            switch reason {
            case .gltfRequired:
                return .alert(
                    title: L("settings.export.minimum.title"),
                    message: L("settings.export.minimum.message"),
                    identifier: "exportFormatsDisabledAlert"
                )
            case .meshNotReady:
                return .alert(
                    title: L("scan.preview.meshNotReady.title"),
                    message: L("scan.preview.meshNotReady.message"),
                    identifier: "meshNotReadyAlert"
                )
            case .qualityGateBlocked(let reason, let advice):
                return .alert(
                    title: L("scan.quality.gate.title"),
                    message: String(format: L("scan.quality.gate.message"), reason, advice),
                    identifier: "qualityGateAlert"
                )
            case .exportUnavailable:
                return exportFailure(
                    message: L("scan.preview.exportUnavailable.message"),
                    identifier: "exportUnavailableAlert"
                )
            }
        }

        static func earVerificationFailure(message: String) -> PreviewEffect {
            let isNoEarFailure = message == L("scan.preview.noEar.message")
            return .alert(
                title: isNoEarFailure ? L("scan.preview.noEar.title") : L("scan.preview.verifyFailed.title"),
                message: message,
                identifier: isNoEarFailure ? "noEarAlert" : "earVerifyFailedAlert"
            )
        }

        static func fitFailure(message: String) -> PreviewEffect {
            .alert(
                title: L("scan.preview.fit.unavailable.title"),
                message: message,
                identifier: "fitUnavailableAlert"
            )
        }

        static func earVerified() -> PreviewEffect {
            .alert(
                title: L("scan.preview.verified.alert.title"),
                message: L("scan.preview.verified.alert.message"),
                identifier: "earVerifiedAlert"
            )
        }

        static func meshingTimeout() -> PreviewEffect {
            .alert(
                title: L("scan.preview.meshNotReady.title"),
                message: L("scan.preview.meshNotReady.message"),
                identifier: "meshTimeoutAlert"
            )
        }
    }

    private enum SaveEligibility {
        static func canSave(render: RenderState, settings: any AppSettingsReading) -> Bool {
            render.meshForExport != nil && settings.exportGLTF && !render.isMeshingActive
        }

        static func exportFormatSummary(settings: any AppSettingsReading) -> String {
            var formats: [String] = []
            if settings.exportGLTF { formats.append(L("scan.preview.exportFormat.gltf")) }
            if settings.exportOBJ { formats.append(L("scan.preview.exportFormat.obj")) }
            if formats.isEmpty { return L("scan.preview.exportFormat.none") }
            return formats.joined(separator: ", ")
        }
    }

    private enum VerificationFactory {
        static func makeArtifacts(from verification: VerificationState) -> ScanEarArtifacts? {
            guard let earImage = verification.verifiedEarImage,
                  let earResult = verification.verifiedEarResult,
                  let earOverlay = verification.verifiedEarOverlay,
                  let earCropOverlay = verification.verifiedEarCropOverlay else {
                return nil
            }
            return .init(
                earImage: earImage,
                earResult: earResult,
                earOverlay: earOverlay,
                earCropOverlay: earCropOverlay
            )
        }

        static func makeRequest(from verification: VerificationState, previewSnapshot: UIImage) -> PreviewEarVerificationRequest {
            let source: EarVerificationImageSource =
                verification.preservedSelectionMetadata.map {
                    switch $0.source {
                    case .bestCaptureFrame:
                        return .bestCaptureFrame
                    case .latestCaptureFallback:
                        return .latestCaptureFallback
                    }
                } ?? (verification.preservedImage != nil ? .latestCaptureFallback : .previewSnapshotFallback)

            return PreviewEarVerificationRequest(
                verificationImage: verification.preservedImage ?? previewSnapshot,
                source: source,
                selectionMetadata: verification.preservedSelectionMetadata
            )
        }
    }

    private enum QualityEvaluator {
        static func scanQuality(report: ScanQualityReport) -> ScanQuality {
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

        static func approximateScanQuality(pointCount: Int) -> ScanQuality {
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
            return scanQuality(report: approximateReport)
        }
    }

    private struct ViewDataFactory {
        static func make(
            render: RenderState,
            fit: FitState,
            verification: VerificationState,
            settings: any AppSettingsReading,
            overrides: ViewDataOverrides = .init()
        ) -> PreviewViewData {
            PreviewViewData(
                qualityTitle: render.scanQuality?.title,
                qualityColorToken: qualityToken(for: render.scanQuality),
                qualityTipText: render.scanQuality?.tip,
                measurementSummaryText: measurementSummaryText(render: render, fit: fit),
                meshingStatusText: meshingStatusText(render: render, override: overrides.statusText),
                meshingSpinnerVisible: overrides.spinner ?? render.isMeshingActive,
                saveButtonEnabled: overrides.saveEnabled ?? SaveEligibility.canSave(render: render, settings: settings),
                shareButtonEnabled: overrides.shareEnabled ?? true,
                verifyEarButtonEnabled: overrides.verifyEnabled ?? true,
                fitPanelVisible: settings.developerModeEnabled,
                fitPanelExpanded: fit.showsPanel,
                exportFormatSummary: SaveEligibility.exportFormatSummary(settings: settings),
                earVerified: verification.hasVerifiedEar
            )
        }

        private static func measurementSummaryText(render: RenderState, fit: FitState) -> String? {
            render.measurementSummary.map {
                String(
                    format: L("scan.preview.fit.results.format"),
                    Int($0.circumferenceMm.rounded()),
                    Int($0.widthMm.rounded()),
                    Int($0.depthMm.rounded()),
                    0,
                    Int(($0.confidence * 100).rounded())
                )
            } ?? fit.latestSummaryText
        }

        private static func qualityToken(for quality: ScanQuality?) -> PreviewColorToken? {
            switch quality?.title {
            case L("scan.preview.quality.great"):
                return .good
            case L("scan.preview.quality.ok"):
                return .ok
            case .some:
                return .bad
            case .none:
                return nil
            }
        }

        private static func meshingStatusText(render: RenderState, override: String?) -> String {
            if let override {
                return override
            }
            if render.isMeshingActive, let meshingProgressFraction = render.meshingProgressFraction {
                return String(
                    format: L("scan.preview.meshing.progressFormat"),
                    meshingProgressFraction * 100
                )
            }
            if render.isMeshingActive {
                return L("scan.preview.meshing")
            }
            return L("scan.preview.readyToSave")
        }
    }

    private let settingsStore: any AppSettingsReading
    private(set) var phase: Phase = .preview

    private(set) var state: PreviewState = .loading {
        didSet { emitStateChange() }
    }

    var onStateChange: ((PreviewState) -> Void)?
    var onEffect: ((PreviewEffect) -> Void)?

    private var session = SessionContext()
    private var verification = VerificationState()
    private var fit = FitState()
    private var render = RenderState()

    init(settingsStore: any AppSettingsReading = SettingsStore()) {
        self.settingsStore = settingsStore
        state = .loading
    }

    var hasVerifiedEar: Bool {
        verification.hasVerifiedEar
    }

    var sessionID: UUID { session.id }
    var sessionMetrics: ScanFlowState.ScanSessionMetrics? { session.metrics }
    var qualityReport: ScanQualityReport? { render.qualityReport }
    var measurementSummary: LocalMeasurementGenerationService.ResultSummary? { render.measurementSummary }
    var meshForExport: SCMesh? { render.meshForExport }
    var scanQuality: ScanQuality? { render.scanQuality }
    var verifiedEarImage: UIImage? { verification.verifiedEarImage }
    var verifiedEarResult: EarLandmarksResult? { verification.verifiedEarResult }
    var verifiedEarOverlay: UIImage? { verification.verifiedEarOverlay }
    var verifiedEarCropOverlay: UIImage? { verification.verifiedEarCropOverlay }
    var preservedEarVerificationImage: UIImage? { verification.preservedImage }
    var preservedEarVerificationSelectionMetadata: EarVerificationSelectionMetadata? { verification.preservedSelectionMetadata }
    var earVerificationImageSource: EarVerificationImageSource? { verification.imageSource }
    var latestFitCheckResult: FitModelCheckResult? { fit.latestCheckResult }
    var latestFitMeshData: FitModelPackService.MeshData? { fit.latestMeshData }
    var latestFitSummaryText: String? { fit.latestSummaryText }
    var manualEarLeftMeters: SIMD3<Float>? { fit.manualLeftEarMeters }
    var manualEarRightMeters: SIMD3<Float>? { fit.manualRightEarMeters }
    var browPlaneDropFromTopFraction: Float { fit.browPlaneDropFromTopFraction }
    var showsAdvancedBrowControls: Bool { fit.showsAdvancedBrowControls }
    var showsFitPanel: Bool { fit.showsPanel }
    var isMeshingActive: Bool { render.isMeshingActive }
    var fitEarPickState: FitEarPickState { fit.earPickState }
    var currentLoadedScan: PreviewLoadedScan? { session.loadedScan }
    var meshingProgressFraction: Float? { render.meshingProgressFraction }

    func send(_ action: PreviewAction) {
        switch action {
        case .viewDidLoad:
            phase = .preview
            state = .loading
        case .existingScanLoaded(let loaded):
            session.loadedScan = loaded
            transitionToPreviewReady()
        case .existingScanLoadFailed(let failure):
            handleLoadFailure(failure)
        case .postScanLoaded:
            render.meshingProgressFraction = nil
            evaluatePostScanQuality(from: action)
            render.isMeshingActive = true
            transitionToPreviewMeshing()
        case .saveTapped:
            transitionToSaving()
        case .saveBlocked(let reason):
            handleSaveBlocked(reason)
        case .saveInvocationFailed(let reason):
            handleSaveInvocationFailed(reason)
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
        case .meshingProgressUpdated(let progress):
            render.meshingProgressFraction = max(0, min(1, progress))
            refreshState()
        case .meshingTimedOut:
            handleMeshingTimeout()
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
        beginSession(
            metrics: nil,
            preservedEarVerificationImage: preservedEarVerificationImage,
            preservedEarVerificationSelectionMetadata: preservedEarVerificationSelectionMetadata
        )
    }

    @discardableResult
    func beginPreviewSession(
        sessionMetrics: ScanFlowState.ScanSessionMetrics?,
        preservedEarVerificationImage: UIImage? = nil,
        preservedEarVerificationSelectionMetadata: EarVerificationSelectionMetadata? = nil
    ) -> UUID {
        beginSession(
            metrics: sessionMetrics,
            preservedEarVerificationImage: preservedEarVerificationImage,
            preservedEarVerificationSelectionMetadata: preservedEarVerificationSelectionMetadata
        )
    }

    private func beginSession(
        metrics: ScanFlowState.ScanSessionMetrics?,
        preservedEarVerificationImage: UIImage?,
        preservedEarVerificationSelectionMetadata: EarVerificationSelectionMetadata?
    ) -> UUID {
        let sessionID = UUID()
        session.id = sessionID
        session.metrics = metrics
        verification.preservedImage = preservedEarVerificationImage
        verification.preservedSelectionMetadata = preservedEarVerificationSelectionMetadata
        session.loadedScan = nil
        resetSessionArtifacts()
        phase = .preview
        state = .loading
        return sessionID
    }

    func invalidateSession() {
        session.id = UUID()
    }

    func isCurrentSession(_ sessionID: UUID) -> Bool {
        session.id == sessionID
    }

    func clearPreviewArtifacts() {
        invalidateSession()
        session.metrics = nil
        session.loadedScan = nil
        verification.preservedImage = nil
        verification.preservedSelectionMetadata = nil
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
            transitionToCurrentPreviewState()
        case .saving:
            transitionToSaving()
        }
    }

    func setQualityReport(_ report: ScanQualityReport) {
        render.qualityReport = report
        render.scanQuality = evaluateScanQuality(report: report)
        refreshState()
    }

    func setMeasurementSummary(_ summary: LocalMeasurementGenerationService.ResultSummary?) {
        render.measurementSummary = summary
        refreshState()
    }

    func setMeshForExport(_ mesh: SCMesh?) {
        render.meshForExport = mesh
        refreshState()
    }

    func setMeshingActive(_ isActive: Bool) {
        render.isMeshingActive = isActive
        if !isActive {
            render.meshingProgressFraction = nil
        }
        refreshState()
    }

    func setFitPanelExpanded(_ isExpanded: Bool) {
        fit.showsPanel = isExpanded
        refreshState()
    }

    func toggleFitPanelExpanded() {
        fit.showsPanel.toggle()
        refreshState()
    }

    func setAdvancedBrowControlsVisible(_ isVisible: Bool) {
        fit.showsAdvancedBrowControls = isVisible
    }

    func toggleAdvancedBrowControlsVisible() {
        fit.showsAdvancedBrowControls.toggle()
    }

    func setBrowPlaneDropFromTopFraction(_ value: Float) {
        fit.browPlaneDropFromTopFraction = min(0.30, max(0.20, value))
    }

    func setFitResult(_ result: PreviewFitResult) {
        fit.latestSummaryText = result.summaryText
        fit.latestCheckResult = result.fitCheckResult
        refreshState()
    }

    func setFitMeshData(_ meshData: FitModelPackService.MeshData?) {
        fit.latestMeshData = meshData
    }

    func beginFitEarPicking() {
        fit.earPickState = .pickLeft
    }

    func setNextFitEarPickState(_ state: FitEarPickState) {
        fit.earPickState = state
    }

    func setManualLeftEar(_ point: SIMD3<Float>?) {
        fit.manualLeftEarMeters = point
    }

    func setManualRightEar(_ point: SIMD3<Float>?) {
        fit.manualRightEarMeters = point
    }

    func setVerifiedEar(image: UIImage, result: EarLandmarksResult, overlay: UIImage, cropOverlay: UIImage) {
        verification.verifiedEarImage = image
        verification.verifiedEarResult = result
        verification.verifiedEarOverlay = overlay
        verification.verifiedEarCropOverlay = cropOverlay
        refreshState()
    }

    func setEarVerificationImageSource(_ source: EarVerificationImageSource) {
        verification.imageSource = source
    }

    func makeEarArtifacts() -> ScanEarArtifacts? {
        VerificationFactory.makeArtifacts(from: verification)
    }

    func presentShare(items: [Any], sourceRect: CGRect?) {
        emitEffect(.route(.presentShare(items: items, sourceRect: sourceRect)))
    }

    func presentMissingShareFolderAlert() {
        emitEffect(EffectFactory.missingShareFolder())
    }

    func presentEarServiceUnavailable() {
        emitEffect(EffectFactory.earServiceUnavailable())
    }

    func presentFitExportFailure(message: String) {
        emitEffect(.alert(
            title: L("scan.preview.fit.export.failed.title"),
            message: String(format: L("scan.preview.fit.export.failed.message"), message),
            identifier: "fitExportFailedAlert"
        ))
    }

    func makeEarVerificationRequest(previewSnapshot: UIImage) -> PreviewEarVerificationRequest {
        VerificationFactory.makeRequest(from: verification, previewSnapshot: previewSnapshot)
    }

    func evaluateScanQuality(report: ScanQualityReport) -> ScanQuality {
        QualityEvaluator.scanQuality(report: report)
    }

    func evaluateScanQuality(pointCount: Int) -> ScanQuality {
        QualityEvaluator.approximateScanQuality(pointCount: pointCount)
    }

    private func resetSessionArtifacts() {
        render.reset()
        clearVerification()
        fit.reset()
    }

    func clearVerification() {
        verification.clearVerified()
    }

    private func handleExportCompleted(_ result: Result<SavedScanResult, PreviewFailure>) {
        switch result {
        case .success(let saved):
            phase = .idle
            state = .saved(saved)
            emitEffect(.route(.returnHomeAfterSave(saved)))
        case .failure(let failure):
            _ = failThenReady(failure)
            if case .exportFailed(let message) = failure {
                emitEffect(EffectFactory.exportFailure(message: message, identifier: "exportFailedAlert"))
            }
        }
    }

    private func handleLoadFailure(_ failure: PreviewFailure) {
        _ = failThenReady(failure, restoreReady: false)
        switch failure {
        case .loadFailed(let message):
            emitEffect(EffectFactory.loadFailure(message: message))
        case .exportFailed(let message), .verificationFailed(let message), .fitFailed(let message):
            emitEffect(EffectFactory.exportFailure(message: message, identifier: "previewLoadFailedAlert"))
        }
    }

    private func handleSaveBlocked(_ reason: PreviewBlockReason) {
        _ = blockThenReady(reason)
        emitEffect(EffectFactory.blockedSave(reason))
    }

    private func handleSaveInvocationFailed(_ reason: String) {
        _ = failThenReady(.exportFailed(reason))
        emitEffect(EffectFactory.exportFailure(message: reason, identifier: "exportInvocationAlert"))
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
            emitEffect(EffectFactory.earVerified())
        case .failure(let failure):
            if case .verificationFailed(let message) = failure {
                emitEffect(EffectFactory.earVerificationFailure(message: message))
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
                emitEffect(EffectFactory.fitFailure(message: message))
            }
        }
    }

    private func handleFitEarPointSelection(_ point: SIMD3<Float>) {
        switch fitEarPickState {
        case .pickLeft:
            fit.manualLeftEarMeters = point
            fit.earPickState = .pickRight
            emitEffect(.toast(L("scan.preview.fit.pick.right")))
        case .pickRight:
            fit.manualRightEarMeters = point
            fit.earPickState = .none
        case .none:
            break
        }
    }

    private func handleMeshingTimeout() {
        guard phase == .preview, render.meshForExport == nil else { return }
        emitEffect(EffectFactory.meshingTimeout())
    }

    private func evaluatePostScanQuality(from action: PreviewAction) {
        guard case .postScanLoaded(let payload) = action else { return }
        let qualityConfig = settingsStore.scanQualityConfig
        let qualityReport = ScanQualityValidator.evaluate(
            pointCloud: payload.pointCloud,
            config: .init(
                gateEnabled: qualityConfig.gateEnabled,
                minValidPoints: qualityConfig.minValidPoints,
                minValidRatio: qualityConfig.minValidRatio,
                minQualityScore: qualityConfig.minQualityScore,
                minHeadDimensionMeters: qualityConfig.minHeadDimensionMeters,
                maxHeadDimensionMeters: qualityConfig.maxHeadDimensionMeters
            )
        )
        setQualityReport(qualityReport)
        Log.scanning.info(
            """
            Scan quality report: raw=\(qualityReport.pointCount, privacy: .public) \
            valid=\(qualityReport.validPointCount, privacy: .public) \
            bounds=\(qualityReport.widthMeters, privacy: .public)x\(qualityReport.heightMeters, privacy: .public)x\(qualityReport.depthMeters, privacy: .public) \
            score=\(qualityReport.qualityScore, privacy: .public) \
            exportable=\(qualityReport.isExportRecommended, privacy: .public)
            """
        )
    }

    private func refreshState() {
        transitionToCurrentPreviewState()
    }

    @discardableResult
    private func blockThenReady(_ reason: PreviewBlockReason) -> PreviewViewData {
        phase = .preview
        let readyViewData = makeViewData()
        state = .blocked(reason, readyViewData)
        state = .ready(readyViewData)
        return readyViewData
    }

    @discardableResult
    private func failThenReady(_ failure: PreviewFailure, restoreReady: Bool = true) -> PreviewViewData {
        phase = .preview
        let viewData = makeViewData()
        state = .failed(failure, viewData)
        if restoreReady {
            state = .ready(viewData)
        }
        return viewData
    }

    private func transitionToCurrentPreviewState() {
        phase = .preview
        state = render.isMeshingActive ? .meshing(makeViewData()) : .ready(makeViewData())
    }

    private func transitionToPreviewReady() {
        phase = .preview
        state = .ready(makeViewData())
    }

    private func transitionToPreviewMeshing() {
        phase = .preview
        state = .meshing(makeViewData())
    }

    private func transitionToSaving() {
        phase = .saving
        state = .saving(
            makeViewData(
                statusText: L("scan.preview.exporting"),
                spinner: true,
                saveEnabled: false,
                shareEnabled: false,
                verifyEnabled: false
            )
        )
    }

    private func makeViewData(
        statusText: String? = nil,
        spinner: Bool? = nil,
        saveEnabled: Bool? = nil,
        shareEnabled: Bool? = nil,
        verifyEnabled: Bool? = nil
    ) -> PreviewViewData {
        ViewDataFactory.make(
            render: render,
            fit: fit,
            verification: verification,
            settings: settingsStore,
            overrides: .init(
                statusText: statusText,
                spinner: spinner,
                saveEnabled: saveEnabled,
                shareEnabled: shareEnabled,
                verifyEnabled: verifyEnabled
            )
        )
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
