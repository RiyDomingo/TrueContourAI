import UIKit
import StandardCyborgUI

final class PreviewCoordinatorComponents {
    private weak var presenter: UIViewController?
    private let scanReader: PreviewScanReading
    private let scanExporter: ScanExporting
    private let settingsStore: SettingsStore
    private let scanFlowState: ScanFlowState
    private let environment: AppEnvironment
    private let saveExportViewState: SaveExportUIStateAdapting
    private let earServiceFactory: () -> EarLandmarksService?
    private let onToast: ((String) -> Void)?
    private let onExportResult: ((PreviewExportResultEvent) -> Void)?

    var onScansChanged: (() -> Void)?

    let previewSessionController: PreviewSessionController
    let previewOverlayUI = PreviewOverlayUIController()
    let alertPresenter = PreviewAlertPresenter()
    let buttonConfigurator = PreviewButtonConfigurator()
    let measurementService = LocalMeasurementGenerationService()
    let presentationController = PreviewPresentationController()
    let meshingTimeoutSeconds: TimeInterval = 25

    var previewViewModel: PreviewViewModel { previewSessionController.viewModel }

    private lazy var earService: EarLandmarksService? = {
        let service = earServiceFactory()
        if service == nil {
            Log.ml.error("EarLandmarksService init failed (non-fatal)")
        }
        return service
    }()

    private lazy var earVerificationWorkflow = PreviewEarVerificationWorkflow(
        previewViewModel: previewViewModel,
        previewOverlayUI: previewOverlayUI,
        alertPresenter: alertPresenter
    )

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

    lazy var interactionController = PreviewInteractionController(
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
            self?.previewSessionController.isCurrentSession(sessionID) ?? false
        }
    )

    private lazy var sceneUIController = PreviewSceneUIController(
        previewViewModel: previewViewModel,
        previewOverlayUI: previewOverlayUI,
        interactionController: interactionController
    )

    private lazy var measurementWorkflow = PreviewMeasurementWorkflow(
        measurementService: measurementService,
        previewViewModel: previewViewModel,
        renderDerivedMeasurements: { [weak self] in
            self?.interactionController.renderDerivedMeasurementsIfAvailable()
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
        sceneUIController: sceneUIController
    )

    private lazy var meshingWorkflow = PreviewMeshingWorkflow(
        previewViewModel: previewViewModel,
        saveExportViewState: saveExportViewState,
        previewOverlayUI: previewOverlayUI,
        alertPresenter: alertPresenter,
        meshingTimeoutSeconds: meshingTimeoutSeconds
    )

    lazy var resetController = PreviewResetController(
        previewSessionController: previewSessionController,
        presentationController: presentationController,
        saveExportViewState: saveExportViewState,
        meshingWorkflow: meshingWorkflow,
        interactionCleanup: { [weak self] in
            self?.interactionController.cleanup()
        }
    )

    lazy var exportController = PreviewExportController(
        previewViewModel: previewViewModel,
        settingsStore: settingsStore,
        scanFlowState: scanFlowState,
        saveExportViewState: saveExportViewState,
        alertPresenter: alertPresenter,
        scanExporter: scanExporter,
        environment: environment,
        onToast: onToast,
        onExportResult: onExportResult,
        onScansChanged: { [weak self] in
            self?.onScansChanged?()
        },
        previewSessionController: previewSessionController,
        presentationController: presentationController,
        resetController: resetController
    )

    private lazy var lifecycleWorkflow = PreviewLifecycleWorkflow(
        scanFlowState: scanFlowState,
        previewViewModel: previewViewModel,
        previewSessionController: previewSessionController,
        presentationController: presentationController,
        resetController: resetController
    )

    private lazy var sharingWorkflow = PreviewSharingWorkflow(
        scanReader: scanReader,
        previewSessionController: previewSessionController,
        environment: environment,
        alertPresenter: alertPresenter
    )

    lazy var actionController = PreviewActionController(
        lifecycleWorkflow: lifecycleWorkflow,
        exportController: exportController,
        presentationController: presentationController,
        previewSessionController: previewSessionController,
        earServiceAvailable: { [weak self] in
            self?.earService != nil
        }
    )

    lazy var routingController = PreviewRoutingController(
        presenter: presenter ?? UIViewController(),
        environment: environment,
        previewViewModel: previewViewModel,
        previewSessionController: previewSessionController,
        existingScanWorkflow: existingScanWorkflow,
        postScanPresentationWorkflow: postScanPresentationWorkflow,
        presentationController: presentationController
    )

    init(
        presenter: UIViewController,
        scanReader: PreviewScanReading,
        scanExporter: ScanExporting,
        settingsStore: SettingsStore,
        scanFlowState: ScanFlowState,
        previewSessionState: PreviewSessionState,
        environment: AppEnvironment,
        saveExportViewState: SaveExportUIStateAdapting,
        earServiceFactory: @escaping () -> EarLandmarksService?,
        onToast: ((String) -> Void)?,
        onExportResult: ((PreviewExportResultEvent) -> Void)?
    ) {
        self.presenter = presenter
        self.scanReader = scanReader
        self.scanExporter = scanExporter
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

    func configureExistingScanFitUI(previewVC: ScenePreviewViewController) {
        sceneUIController.configureFitModelUIIfNeeded(previewVC: previewVC)
    }
}
