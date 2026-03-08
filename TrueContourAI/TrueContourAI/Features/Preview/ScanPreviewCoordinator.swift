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
        earArtifacts: ScanService.EarArtifacts?,
        scanSummary: ScanService.ScanSummary?,
        includeGLTF: Bool,
        includeOBJ: Bool
    ) -> ScanService.ExportResult
    func setLastScanFolder(_ folderURL: URL)
}

extension ScanService: ScanExporting {}

protocol SaveExportUIStateAdapting {
    func configure(
        previewVC: ScenePreviewViewController
    )
    func setButtonsEnabled(_ isEnabled: Bool)
    func setMeshingStatusText(_ text: String)
    func setMeshingSpinnerActive(_ isActive: Bool)
    func showSavingToast()
    func hideSavingToast()
    func clear()
}

final class ScanPreviewCoordinator {
    private weak var presenter: UIViewController?
    private let scanReader: PreviewScanReading
    private let scanExporter: ScanExporting
    private let settingsStore: SettingsStore
    private let scanFlowState: ScanFlowState
    private let environment: AppEnvironment
    private let previewSessionController: PreviewSessionController
    private var previewViewModel: PreviewViewModel { previewSessionController.viewModel }
    private let onToast: ((String) -> Void)?
    private let onExportResult: ((PreviewExportResultEvent) -> Void)?
    private let earServiceFactory: () -> EarLandmarksService?

    var onScansChanged: (() -> Void)?

    private lazy var earService: EarLandmarksService? = {
        let service = earServiceFactory()
        if service == nil {
            Log.ml.error("EarLandmarksService init failed (non-fatal)")
        }
        return service
    }()

    private let saveExportViewState: SaveExportUIStateAdapting
    private let previewOverlayUI = PreviewOverlayUIController()
    private let alertPresenter = PreviewAlertPresenter()
    private let buttonConfigurator = PreviewButtonConfigurator()
    private let measurementService = LocalMeasurementGenerationService()
    private let presentationController = PreviewPresentationController()
    private lazy var earVerificationWorkflow = PreviewEarVerificationWorkflow(
        previewViewModel: previewViewModel,
        previewOverlayUI: previewOverlayUI,
        alertPresenter: alertPresenter
    )
    private let meshingTimeoutSeconds: TimeInterval = 25
    private lazy var presentationWorkflow = PreviewPresentationWorkflow(
        previewOverlayUI: previewOverlayUI,
        buttonConfigurator: buttonConfigurator,
        saveExportViewState: saveExportViewState
    )
    private lazy var fitWorkflow = PreviewFitWorkflow(
        previewViewModel: previewViewModel,
        previewOverlayUI: previewOverlayUI,
        alertPresenter: alertPresenter,
        settingsStore: settingsStore,
        scanReader: scanReader,
        onToast: onToast
    )
    private lazy var overlayWorkflow = PreviewOverlayWorkflow(
        previewOverlayUI: previewOverlayUI,
        fitWorkflow: fitWorkflow
    )
    private lazy var existingScanWorkflow = PreviewExistingScanWorkflow(
        scanReader: scanReader,
        previewViewModel: previewViewModel,
        scanFlowState: scanFlowState,
        previewSessionController: previewSessionController,
        presentationWorkflow: presentationWorkflow,
        alertPresenter: alertPresenter,
        overlayWorkflow: overlayWorkflow
    )
    private lazy var measurementWorkflow = PreviewMeasurementWorkflow(
        measurementService: measurementService,
        previewViewModel: previewViewModel,
        renderDerivedMeasurements: { [weak self] in
            self?.renderDerivedMeasurementsIfAvailable()
        }
    )
    private lazy var postScanWorkflow = PreviewPostScanWorkflow(
        settingsStore: settingsStore,
        previewViewModel: previewViewModel,
        scanFlowState: scanFlowState
    )
    private lazy var postScanPresentationWorkflow = PreviewPostScanPresentationWorkflow(
        presentationWorkflow: presentationWorkflow,
        postScanWorkflow: postScanWorkflow,
        meshingWorkflow: meshingWorkflow,
        measurementWorkflow: measurementWorkflow,
        previewViewModel: previewViewModel,
        previewOverlayUI: previewOverlayUI,
        addVerifyEarUI: { [weak self] previewVC in
            self?.addVerifyEarUI(to: previewVC)
        },
        configureFitModelUIIfNeeded: { [weak self] previewVC in
            self?.configureFitModelUIIfNeeded(previewVC: previewVC)
        },
        addScanQualityLabel: { [weak self] previewVC, quality in
            self?.addScanQualityLabel(to: previewVC, quality: quality)
        },
        renderDerivedMeasurementsIfAvailable: { [weak self] in
            self?.renderDerivedMeasurementsIfAvailable()
        }
    )
    private lazy var meshingWorkflow = PreviewMeshingWorkflow(
        previewViewModel: previewViewModel,
        saveExportViewState: saveExportViewState,
        previewOverlayUI: previewOverlayUI,
        alertPresenter: alertPresenter,
        meshingTimeoutSeconds: meshingTimeoutSeconds
    )
    private lazy var exportController = PreviewExportController(
        previewViewModel: previewViewModel,
        settingsStore: settingsStore,
        scanFlowState: scanFlowState,
        saveExportViewState: saveExportViewState,
        alertPresenter: alertPresenter,
        scanExporter: scanExporter,
        environment: environment,
        onToast: onToast,
        onExportResult: onExportResult,
        onScansChanged: onScansChanged,
        dismissActivePreview: { [weak self] animated, completion in
            self?.presentationController.dismissActivePreview(animated: animated, completion: completion)
        },
        resetPreviewState: { [weak self] in
            self?.resetPreviewState()
        },
        invalidatePreviewSession: { [weak self] in
            self?.invalidatePreviewSession()
        },
        isCurrentPreviewSession: { [weak self] sessionID in
            guard let self else { return false }
            return self.isCurrentPreviewSession(sessionID)
        }
    )
    private lazy var lifecycleWorkflow = PreviewLifecycleWorkflow(
        scanFlowState: scanFlowState,
        previewViewModel: previewViewModel,
        resetPreviewState: { [weak self] in
            self?.resetPreviewState()
        },
        invalidatePreviewSession: { [weak self] in
            self?.invalidatePreviewSession()
        },
        dismissActivePreview: { [weak self] animated, completion in
            self?.presentationController.dismissActivePreview(animated: animated, completion: completion)
        }
    )
    private lazy var sharingWorkflow = PreviewSharingWorkflow(
        scanReader: scanReader,
        previewSessionController: previewSessionController,
        environment: environment,
        alertPresenter: alertPresenter
    )
    private lazy var interactionController = PreviewInteractionController(
        presenter: presenter ?? UIViewController(),
        previewViewModel: previewViewModel,
        previewSessionController: previewSessionController,
        presentationController: presentationController,
        sharingWorkflow: sharingWorkflow,
        earVerificationWorkflow: earVerificationWorkflow,
        fitWorkflow: fitWorkflow,
        overlayWorkflow: overlayWorkflow,
        previewOverlayUI: previewOverlayUI,
        settingsStore: settingsStore,
        earServiceProvider: { [weak self] in
            self?.earService
        },
        isCurrentPreviewSession: { [weak self] sessionID in
            guard let self else { return false }
            return self.isCurrentPreviewSession(sessionID)
        }
    )
    private lazy var routingController = PreviewRoutingController(
        presenter: presenter ?? UIViewController(),
        environment: environment,
        previewViewModel: previewViewModel,
        existingScanWorkflow: existingScanWorkflow,
        postScanPresentationWorkflow: postScanPresentationWorkflow,
        presentationController: presentationController,
        startPreviewSession: { [weak self] sessionMetrics in
            guard let self else { return UUID() }
            return self.startPreviewSession(sessionMetrics: sessionMetrics)
        },
        isCurrentPreviewSession: { [weak self] sessionID in
            guard let self else { return false }
            return self.isCurrentPreviewSession(sessionID)
        }
    )

    private var exportWorkflow: PreviewExportWorkflow {
        PreviewExportWorkflow(settingsStore: settingsStore)
    }

    init(
        presenter: UIViewController,
        scanService: any PreviewScanReading,
        settingsStore: SettingsStore,
        scanFlowState: ScanFlowState,
        previewSessionState: PreviewSessionState = PreviewSessionState(),
        environment: AppEnvironment = .current,
        scanExporter: ScanExporting? = nil,
        saveExportViewState: SaveExportUIStateAdapting = SaveExportViewStateController(),
        earServiceFactory: @escaping () -> EarLandmarksService? = {
            do { return try EarLandmarksService() }
            catch { return nil }
        },
        onToast: ((String) -> Void)? = nil,
        onExportResult: ((PreviewExportResultEvent) -> Void)? = nil
    ) {
        let resolvedScanExporter = scanExporter ?? (scanService as? ScanExporting)
        precondition(resolvedScanExporter != nil, "ScanPreviewCoordinator requires a ScanExporting dependency")
        self.presenter = presenter
        self.scanReader = scanService
        self.scanExporter = resolvedScanExporter!
        self.settingsStore = settingsStore
        self.scanFlowState = scanFlowState
        self.previewSessionController = PreviewSessionController(
            viewModel: PreviewViewModel(),
            sessionState: previewSessionState
        )
        self.environment = environment
        self.saveExportViewState = saveExportViewState
        self.earServiceFactory = earServiceFactory
        self.onToast = onToast
        self.onExportResult = onExportResult
    }

    private func startPreviewSession(sessionMetrics: ScanFlowState.ScanSessionMetrics? = nil) -> UUID {
        if let sessionMetrics {
            return previewSessionController.beginPreviewSession(sessionMetrics: sessionMetrics)
        }
        return previewSessionController.beginExistingScanSession()
    }

    private func invalidatePreviewSession() {
        previewSessionController.invalidateSession()
    }

    private func isCurrentPreviewSession(_ sessionID: UUID) -> Bool {
        previewSessionController.isCurrentSession(sessionID)
    }

    func presentExistingScan(_ item: ScanService.ScanItem) {
        routingController.presentExistingScan(
            item,
            closeTarget: self,
            shareTarget: interactionController,
            closeAction: #selector(dismissPreviewTapped),
            shareAction: #selector(PreviewInteractionController.shareOpenedScanTapped),
            configureFitModelUI: { [weak self] previewVC in
                self?.configureFitModelUIIfNeeded(previewVC: previewVC)
            }
        )
    }

    func presentPreviewAfterScan(
        from scanningVC: UIViewController,
        pointCloud: SCPointCloud,
        meshTexturing: SCMeshTexturing,
        sessionMetrics: ScanFlowState.ScanSessionMetrics?
    ) {
        routingController.presentPreviewAfterScan(
            from: scanningVC,
            pointCloud: pointCloud,
            meshTexturing: meshTexturing,
            sessionMetrics: sessionMetrics,
            closeTarget: self,
            closeAction: #selector(dismissPreviewTapped),
            saveTarget: self,
            saveAction: #selector(saveFromPreviewTapped)
        )
    }

    // MARK: - Actions

    @objc private func dismissPreviewTapped() {
        lifecycleWorkflow.dismissPreview()
    }

    @objc private func saveFromPreviewTapped() {
        guard let previewVC = presentationController.currentScenePreviewViewController else { return }
        let previewSessionID = previewSessionController.sessionID
        DesignSystem.hapticPrimary()
        exportController.performSave(
            previewVC: previewVC,
            previewSessionID: previewSessionID,
            earServiceUnavailable: earService == nil
        )
    }

    private func renderDerivedMeasurementsIfAvailable() {
        interactionController.renderDerivedMeasurementsIfAvailable()
    }

    // MARK: - Preview UI

    private func addVerifyEarUI(to previewVC: ScenePreviewViewController) {
        interactionController.addVerifyEarUI(to: previewVC)
    }

    private func configureFitModelUIIfNeeded(previewVC: ScenePreviewViewController) {
        interactionController.configureFitModelUIIfNeeded(previewVC: previewVC)
    }

    private func addScanQualityLabel(to previewVC: ScenePreviewViewController, quality: ScanQuality) {
        interactionController.addScanQualityLabel(to: previewVC, quality: quality)
    }

    private func resetPreviewState() {
        interactionController.cleanup()
        previewSessionController.clearPreviewArtifacts()
        saveExportViewState.clear()
        meshingWorkflow.reset()
        previewSessionController.currentPreviewedFolderURL = nil
        presentationController.reset()
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

    func debug_handleExportResult(_ result: ScanService.ExportResult, isEarServiceUnavailable: Bool) {
        exportController.debugHandleExportResult(result, isEarServiceUnavailable: isEarServiceUnavailable)
    }

    func debug_savePrecheck(qualityReport: ScanQualityReport?, hasMesh: Bool) -> String {
        exportController.debugSavePrecheck(qualityReport: qualityReport, hasMesh: hasMesh)
    }

    @discardableResult
    func debug_addFitControlsIfDeveloperMode(hostView: UIView) -> Bool {
        guard settingsStore.developerModeEnabled else { return false }
        _ = previewOverlayUI.addFitModelUI(to: hostView)
        return previewOverlayUI.fitBrowSlider != nil
    }

    func debug_hasFitBrowSlider() -> Bool {
        previewOverlayUI.fitBrowSlider != nil
    }
    #endif
}
