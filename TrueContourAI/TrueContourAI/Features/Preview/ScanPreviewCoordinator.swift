import UIKit
import StandardCyborgUI
import StandardCyborgFusion
import SceneKit
import simd

protocol ScanExporting {
    func exportScanFolder(
        mesh: SCMesh,
        scene: SCScene,
        thumbnail: UIImage?,
        earArtifacts: ScanEarArtifacts?,
        scanSummary: ScanSummary?,
        includeGLTF: Bool,
        includeOBJ: Bool
    ) -> ScanExportResult
    func setLastScanFolder(_ folderURL: URL)
}

protocol SaveExportUIStateAdapting {
    func configure(
        previewVC: ScenePreviewViewController
    )
    func setButtonsEnabled(_ isEnabled: Bool)
    func markSaveReady()
    func markSaveInvoked()
    func markSaveBlocked()
    func setMeshingStatusText(_ text: String)
    func setMeshingSpinnerActive(_ isActive: Bool)
    func showSavingToast()
    func hideSavingToast()
    func markSaveCompleted()
    func markSaveFailed()
    func clear()
}

final class ScanPreviewCoordinator {
    private let settingsStore: SettingsStore
    private let components: PreviewCoordinatorComponents

    var onScansChanged: (() -> Void)? {
        didSet {
            components.onScansChanged = onScansChanged
        }
    }

    init(
        presenter: UIViewController,
        scanService: any PreviewScanReading,
        settingsStore: SettingsStore,
        scanFlowState: ScanFlowState,
        previewSessionState: PreviewSessionState = PreviewSessionState(),
        environment: AppEnvironment = .current,
        scanExporter: ScanExporting,
        saveExportViewState: SaveExportUIStateAdapting = SaveExportViewStateController(),
        earServiceFactory: @escaping () -> EarLandmarksService? = {
            do { return try EarLandmarksService() }
            catch { return nil }
        },
        onToast: ((String) -> Void)? = nil,
        onExportResult: ((PreviewExportResultEvent) -> Void)? = nil
    ) {
        self.settingsStore = settingsStore
        self.components = PreviewCoordinatorComponents(
            presenter: presenter,
            scanReader: scanService,
            scanExporter: scanExporter,
            settingsStore: settingsStore,
            scanFlowState: scanFlowState,
            previewSessionState: previewSessionState,
            environment: environment,
            saveExportViewState: saveExportViewState,
            earServiceFactory: earServiceFactory,
            onToast: onToast,
            onExportResult: onExportResult
        )
        self.components.onScansChanged = onScansChanged
    }

    func presentExistingScan(_ item: ScanItem) {
        components.routingController.presentExistingScan(
            item,
            closeTarget: components.actionController,
            shareTarget: components.interactionController,
            closeAction: #selector(PreviewActionController.dismissPreviewTapped),
            shareAction: #selector(PreviewInteractionController.shareOpenedScanTapped),
            configureFitModelUI: { [weak self] previewVC in
                self?.components.configureExistingScanFitUI(previewVC: previewVC)
            }
        )
    }

    func presentPreviewAfterScan(
        from scanningVC: UIViewController,
        payload: ScanPreviewInput,
        sessionMetrics: ScanFlowState.ScanSessionMetrics?
    ) {
        components.routingController.presentPreviewAfterScan(
            from: scanningVC,
            payload: payload,
            sessionMetrics: sessionMetrics,
            onClose: { [weak actionController = components.actionController] in
                actionController?.dismissPreviewTapped()
            },
            onSave: { [weak actionController = components.actionController] in
                actionController?.saveFromPreviewTapped()
            }
        )
    }

    #if DEBUG
    func debug_makeVerifyEarButton() -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(L("scan.preview.verify"), for: .normal)
        b.accessibilityLabel = L("scan.preview.accessibility.verify.label")
        b.accessibilityHint = L("scan.preview.accessibility.verify.hint")
        b.accessibilityIdentifier = "verifyEarButton"
        return b
    }

    func debug_handleExportResult(_ result: ScanExportResult, isEarServiceUnavailable: Bool) {
        components.exportController.debugHandleExportResult(result, isEarServiceUnavailable: isEarServiceUnavailable)
    }

    func debug_savePrecheck(qualityReport: ScanQualityReport?, hasMesh: Bool) -> String {
        components.exportController.debugSavePrecheck(qualityReport: qualityReport, hasMesh: hasMesh)
    }

    @discardableResult
    func debug_addFitControlsIfDeveloperMode(hostView: UIView) -> Bool {
        guard settingsStore.developerModeEnabled else { return false }
        _ = components.previewOverlayUI.addFitModelUI(to: hostView)
        return components.previewOverlayUI.fitBrowSlider != nil
    }

    func debug_hasFitBrowSlider() -> Bool {
        components.previewOverlayUI.fitBrowSlider != nil
    }
    #endif
}
