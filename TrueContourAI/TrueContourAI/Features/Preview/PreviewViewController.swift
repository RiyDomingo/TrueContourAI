import UIKit
import SceneKit
import StandardCyborgUI
import StandardCyborgFusion

final class PreviewViewController: UIViewController {
    enum Input {
        case existingScan(ScanItem)
        case postScan(payload: ScanPreviewInput, sessionMetrics: ScanFlowState.ScanSessionMetrics?)
    }

    weak var delegate: PreviewViewControllerDelegate?

    var currentShareSourceView: UIView? {
        previewPresentationController.currentShareSourceView
    }

    private let input: Input
    private let scanReader: PreviewScanReading
    private let settingsStore: SettingsStore
    private let scanFlowState: ScanFlowState
    private let previewSessionController: PreviewSessionController
    private let environment: AppEnvironment
    private let saveExportViewState: SaveExportUIStateAdapting
    private let onToast: ((String) -> Void)?
    private let onExportResult: ((PreviewExportResultEvent) -> Void)?
    private let earServiceFactory: () -> EarLandmarksService?

    private let previewOverlayUI = PreviewOverlayUIController()
    private let alertPresenter = PreviewAlertPresenter()
    private let buttonConfigurator = PreviewButtonConfigurator()
    private let measurementService = LocalMeasurementGenerationService()
    private let previewPresentationController = PreviewPresentationController()
    private let sceneAdapter = PreviewSceneAdapter()
    private let meshingTimeoutSeconds: TimeInterval = 25

    private let previewStore: PreviewStore
    private lazy var exportUseCase = PreviewExportUseCase(
        settingsStore: settingsStore,
        scanExporter: scanExporter
    )
    private lazy var fitUseCase = PreviewFitUseCase(scanReader: scanReader)
    private lazy var earVerificationUseCase = PreviewEarVerificationUseCase()

    private let scanExporter: ScanExporting
    private lazy var earService: EarLandmarksService? = {
        let service = earServiceFactory()
        if service == nil {
            Log.ml.error("EarLandmarksService init failed (non-fatal)")
        }
        return service
    }()

    private lazy var presentationWorkflow = PreviewPresentationWorkflow(
        previewOverlayUI: previewOverlayUI,
        buttonConfigurator: buttonConfigurator,
        saveExportViewState: saveExportViewState
    )

    private lazy var fitWorkflow = PreviewFitWorkflow(
        previewViewModel: previewStore,
        previewOverlayUI: previewOverlayUI,
        alertPresenter: alertPresenter,
        settingsStore: settingsStore,
        scanReader: scanReader,
        useCase: fitUseCase,
        onToast: onToast
    )

    private lazy var overlayWorkflow = PreviewOverlayWorkflow(
        previewOverlayUI: previewOverlayUI,
        fitWorkflow: fitWorkflow
    )

    private lazy var existingScanWorkflow = PreviewExistingScanWorkflow(
        scanReader: scanReader,
        previewViewModel: previewStore,
        scanFlowState: scanFlowState,
        previewSessionController: previewSessionController,
        presentationWorkflow: presentationWorkflow,
        alertPresenter: alertPresenter,
        overlayWorkflow: overlayWorkflow
    )

    private lazy var earVerificationWorkflow = PreviewEarVerificationWorkflow(
        previewViewModel: previewStore,
        previewOverlayUI: previewOverlayUI,
        alertPresenter: alertPresenter,
        sceneAdapter: sceneAdapter,
        useCase: earVerificationUseCase
    )

    private lazy var postScanWorkflow = PreviewPostScanWorkflow(
        settingsStore: settingsStore,
        previewViewModel: previewStore,
        scanFlowState: scanFlowState
    )

    private lazy var meshingWorkflow = PreviewMeshingWorkflow(
        previewViewModel: previewStore,
        saveExportViewState: saveExportViewState,
        previewOverlayUI: previewOverlayUI,
        alertPresenter: alertPresenter,
        meshingTimeoutSeconds: meshingTimeoutSeconds
    )

    private lazy var measurementWorkflow = PreviewMeasurementWorkflow(
        measurementService: measurementService,
        previewViewModel: previewStore,
        renderDerivedMeasurements: { [weak self] in
            self?.renderDerivedMeasurementsIfAvailable()
        }
    )

    private lazy var sharingWorkflow = PreviewSharingWorkflow(
        scanReader: scanReader,
        previewSessionController: previewSessionController,
        environment: environment,
        alertPresenter: alertPresenter
    )

    let overlayView = PassthroughView()
    var contentViewController: UIViewController?
    private var isVerifyingEar = false

    init(
        input: Input,
        scanReader: PreviewScanReading,
        settingsStore: SettingsStore,
        scanFlowState: ScanFlowState,
        previewSessionState: PreviewSessionState,
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
        let store = PreviewStore(settingsStore: settingsStore)
        self.input = input
        self.scanReader = scanReader
        self.settingsStore = settingsStore
        self.scanFlowState = scanFlowState
        self.previewSessionController = PreviewSessionController(
            store: store,
            sessionState: previewSessionState
        )
        self.environment = environment
        self.scanExporter = scanExporter
        self.saveExportViewState = saveExportViewState
        self.previewStore = store
        self.earServiceFactory = earServiceFactory
        self.onToast = onToast
        self.onExportResult = onExportResult
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable, message: "Programmatic-only.")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.background
        installOverlay()
        bindStore()
        previewStore.send(.viewDidLoad)
        switch input {
        case .existingScan(let item):
            loadExistingScan(item)
        case .postScan(let payload, let sessionMetrics):
            loadPostScanPreview(payload: payload, sessionMetrics: sessionMetrics)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bringOverlayToFront()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bringOverlayToFront()
    }

    private func installOverlay() {
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.backgroundColor = .clear
        overlayView.isUserInteractionEnabled = true
        view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bindStore() {
        previewStore.onStateChange = { [weak self] state in
            self?.apply(state: state)
        }
        previewStore.onEffect = { [weak self] effect in
            self?.handle(effect: effect)
        }
    }

    private func loadExistingScan(_ item: ScanItem) {
        PreviewQoSQueues.existingScanLoad.async { [weak self] in
            guard let self else { return }
            let presentationData = self.existingScanWorkflow.loadPresentationData(
                item: item,
                skipGLTF: self.environment.skipsGLTFPreview
            )
            let selectionMetadata = presentationData.preservedEarVerificationImage.map { _ in
                EarVerificationSelectionMetadata(
                    source: .latestCaptureFallback,
                    frameIndex: nil,
                    totalScore: nil,
                    profileScore: nil,
                    trackingScore: nil,
                    guidanceScore: nil,
                    timingScore: nil
                )
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let sessionID = self.previewSessionController.beginExistingScanSession(
                    preservedEarVerificationImage: presentationData.preservedEarVerificationImage,
                    preservedEarVerificationSelectionMetadata: selectionMetadata
                )
                guard self.previewSessionController.isCurrentSession(sessionID) else { return }
                self.previewSessionController.currentPreviewedFolderURL = item.folderURL

                if self.environment.skipsGLTFPreview {
                    let testVC = self.presentationWorkflow.makeTestPreview(
                        target: self,
                        onClose: #selector(self.closeTapped),
                        onShare: #selector(self.shareTapped)
                    )
                    self.previewPresentationController.setExistingPreview(viewController: testVC, scenePreviewViewController: nil)
                    self.embedContent(testVC)
                    self.scanFlowState.setPhase(.preview)
                    self.previewStore.send(.existingScanLoaded(
                        .init(
                            scene: nil,
                            scanSummary: presentationData.summary,
                            earVerificationImage: presentationData.preservedEarVerificationImage,
                            folderURL: item.folderURL
                        )
                    ))
                    return
                }

                guard let scene = presentationData.scene else {
                    self.presentMissingSceneAlertAndDismiss()
                    return
                }

                let previewVC = self.presentationWorkflow.makeExistingScanPreview(
                    scene: scene,
                    closeTarget: self,
                    shareTarget: self,
                    onClose: #selector(self.closeTapped),
                    onShare: #selector(self.shareTapped)
                )
                self.previewPresentationController.setExistingPreview(viewController: previewVC, scenePreviewViewController: previewVC)
                self.embedContent(previewVC)
                self.scanFlowState.setPhase(.preview)
                self.previewStore.send(.existingScanLoaded(
                    .init(
                        scene: scene,
                        scanSummary: presentationData.summary,
                        earVerificationImage: presentationData.preservedEarVerificationImage,
                        folderURL: item.folderURL
                    )
                ))
                self.existingScanWorkflow.finalizePresentation(
                    summary: presentationData.summary,
                    previewVC: previewVC,
                    configureSceneUI: { [weak self] scenePreviewVC in
                        self?.configureExistingSceneUI(previewVC: scenePreviewVC)
                    }
                )
            }
        }
    }

    private func loadPostScanPreview(
        payload: ScanPreviewInput,
        sessionMetrics: ScanFlowState.ScanSessionMetrics?
    ) {
        let previewSessionID = previewSessionController.beginPreviewSession(
            sessionMetrics: sessionMetrics,
            preservedEarVerificationImage: payload.earVerificationImage,
            preservedEarVerificationSelectionMetadata: payload.earVerificationSelectionMetadata
        )
        postScanWorkflow.preparePreviewState(pointCloud: payload.pointCloud)

        let actionTarget = PreviewButtonActionTarget(
            onLeftTap: { [weak self] in self?.closeTapped() },
            onRightTap: { [weak self] in self?.saveTapped() }
        )
        let previewVC = presentationWorkflow.makePostScanPreview(
            pointCloud: payload.pointCloud,
            meshTexturing: payload.meshTexturing,
            actionTarget: actionTarget
        )
        previewPresentationController.setPostScanPreview(
            context: .init(
                previewVC: previewVC,
                container: self,
                buttonActionTarget: actionTarget
            )
        )
        embedContent(previewVC)
        meshingWorkflow.beginMeshing(in: previewVC)
        meshingWorkflow.startTimeout(
            in: previewVC,
            sessionID: previewSessionID,
            isCurrentPreviewSession: { [weak self] sessionID in
                self?.previewSessionController.isCurrentSession(sessionID) ?? false
            }
        )
        meshingWorkflow.configureCallbacks(
            for: previewVC,
            previewSessionID: previewSessionID,
            isCurrentPreviewSession: { [weak self] sessionID in
                self?.previewSessionController.isCurrentSession(sessionID) ?? false
            },
            onMeshReady: { [weak self] mesh in
                self?.previewStore.setMeshForExport(mesh)
            }
        )
        measurementWorkflow.generate(
            from: payload.pointCloud,
            previewSessionID: previewSessionID,
            isCurrentPreviewSession: { [weak self] sessionID in
                self?.previewSessionController.isCurrentSession(sessionID) ?? false
            }
        )
        configurePostScanSceneUI(previewVC: previewVC)
        previewStore.send(.postScanLoaded(payload))
    }

    private func embedContent(_ childViewController: UIViewController) {
        if let current = contentViewController {
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }
        contentViewController = childViewController
        addChild(childViewController)
        view.insertSubview(childViewController.view, belowSubview: overlayView)
        childViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            childViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            childViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            childViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        childViewController.didMove(toParent: self)
        bringOverlayToFront()
    }

    func bringOverlayToFront() {
        view.bringSubviewToFront(overlayView)
    }

    @objc
    private func closeTapped() {
        previewStore.send(.closeTapped)
    }

    @objc
    private func saveTapped() {
        guard let previewVC = previewPresentationController.resolvedScenePreviewViewController else {
            handleExportInvocationFailure(reason: L("scan.preview.exportUnavailable.message"))
            return
        }

        let eligibility = exportUseCase.makeEligibilityInput(
            meshAvailable: previewStore.meshForExport != nil,
            qualityReport: previewStore.qualityReport
        )
        if let blocked = exportUseCase.precheck(eligibility) {
            presentBlockedSave(blocked, on: previewVC)
            return
        }

        guard let exportSnapshot = exportUseCase.makeExportSnapshot(
            store: previewStore,
            sceneSnapshot: sceneAdapter.makeSceneSnapshot(from: previewVC)
        ) else {
            presentBlockedSave(.exportUnavailable, on: previewVC)
            return
        }

        scanFlowState.setPhase(.saving)
        previewStore.send(.saveTapped)
        saveExportViewState.markSaveInvoked()
        saveExportViewState.setButtonsEnabled(false)
        saveExportViewState.setMeshingStatusText(L("scan.preview.exporting"))
        saveExportViewState.setMeshingSpinnerActive(true)
        saveExportViewState.showSavingToast()

        exportUseCase.export(
            snapshot: exportSnapshot,
            earServiceUnavailable: earService == nil
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let saved):
                self.previewStore.send(.exportCompleted(.success(saved)))
            case .failure(let failure):
                self.scanFlowState.setPhase(.preview)
                self.previewStore.send(.exportCompleted(.failure(failure)))
                self.saveExportViewState.markSaveFailed()
                self.saveExportViewState.setButtonsEnabled(true)
                self.saveExportViewState.setMeshingStatusText(L("scan.preview.readyToSave"))
                self.saveExportViewState.setMeshingSpinnerActive(false)
                self.saveExportViewState.hideSavingToast()
                if case .exportFailed(let message) = failure {
                    self.onExportResult?(.failure(message: message))
                }
            }
        }
    }

    @objc
    private func shareTapped() {
        previewStore.send(.shareTapped)
        guard let folder = previewSessionController.currentPreviewedFolderURL ?? scanReader.resolveLastScanFolderURL() else {
            alertPresenter.presentAlert(
                on: self,
                title: L("scan.preview.missingFolder.title"),
                message: L("scan.preview.missingFolder.message"),
                identifier: "missingFolderAlert"
            )
            return
        }
        previewStore.presentShare(
            items: scanReader.shareItems(for: folder),
            sourceRect: currentShareSourceView?.bounds
        )
    }

    @objc
    private func verifyEarTapped() {
        previewStore.send(.verifyEarTapped)
        guard let previewVC = previewPresentationController.resolvedScenePreviewViewController else { return }
        guard !isVerifyingEar else { return }
        guard let service = earService else {
            earVerificationWorkflow.presentEarUnavailable(on: previewVC)
            return
        }

        let previewSessionID = previewSessionController.sessionID
        isVerifyingEar = true
        earVerificationWorkflow.performVerification(
            using: service,
            previewVC: previewVC,
            isCurrentSession: { [weak self] in
                guard let self else { return false }
                return self.previewSessionController.isCurrentSession(previewSessionID)
            },
            onComplete: { [weak self] in
                self?.isVerifyingEar = false
            }
        )
    }

    @objc
    private func fitModelCheckTapped() {
        previewStore.send(.fitTapped)
        fitWorkflow.runFitModelCheck(
            scenePreviewVC: previewPresentationController.resolvedScenePreviewViewController,
            currentPreviewedFolderURL: previewSessionController.currentPreviewedFolderURL,
            showHaptic: false,
            allowEarPickPrompt: true,
            fitEarPickTarget: self,
            fitEarPickAction: #selector(handleFitEarPickTap(_:))
        )
    }

    @objc
    private func exportFitPackTapped() {
        fitWorkflow.exportFitPack(
            scenePreviewVC: previewPresentationController.resolvedScenePreviewViewController,
            currentPreviewedFolderURL: previewSessionController.currentPreviewedFolderURL
        )
    }

    @objc
    private func fitPanelToggleTapped() {
        fitWorkflow.toggleFitPanelExpanded()
        apply(state: previewStore.state)
    }

    @objc
    private func fitBrowAdvancedTapped() {
        fitWorkflow.toggleAdvancedBrowControlsVisible()
    }

    @objc
    private func fitBrowSliderChanged(_ slider: UISlider) {
        fitWorkflow.updateBrowPlaneDropFromTopFraction(slider.value)
        if previewStore.latestFitMeshData != nil {
            fitWorkflow.runFitModelCheck(
                scenePreviewVC: previewPresentationController.resolvedScenePreviewViewController,
                currentPreviewedFolderURL: previewSessionController.currentPreviewedFolderURL,
                showHaptic: false,
                allowEarPickPrompt: false,
                fitEarPickTarget: self,
                fitEarPickAction: #selector(handleFitEarPickTap(_:))
            )
        }
    }

    @objc
    private func handleFitEarPickTap(_ gesture: UITapGestureRecognizer) {
        fitWorkflow.handleFitEarPickTap(
            gesture,
            scenePreviewVC: previewPresentationController.resolvedScenePreviewViewController,
            currentPreviewedFolderURL: previewSessionController.currentPreviewedFolderURL
        )
    }

    private func configureExistingSceneUI(previewVC: ScenePreviewViewController) {
        addVerifyEarUI(to: previewVC)
        configureFitModelUIIfNeeded(previewVC: previewVC)
    }

    private func configurePostScanSceneUI(previewVC: ScenePreviewViewController) {
        addVerifyEarUI(to: previewVC)
        previewOverlayUI.setMeshingStatus(L("scan.preview.meshing"), percent: nil, spinning: true)
        configureFitModelUIIfNeeded(previewVC: previewVC)
        if let quality = previewStore.scanQuality {
            previewOverlayUI.addScanQualityLabel(to: overlayView, quality: quality, anchor: nil)
        }
        renderDerivedMeasurementsIfAvailable()
    }

    private func addVerifyEarUI(to previewVC: ScenePreviewViewController) {
        let hostView = overlayView
        _ = previewOverlayUI.addVerifyEarUI(to: hostView, showHint: settingsStore.showVerifyEarHint)
        previewOverlayUI.setDeveloperModeEnabled(settingsStore.developerModeEnabled)
        previewOverlayUI.verifyEarButton?.addTarget(self, action: #selector(verifyEarTapped), for: .touchUpInside)
        bringOverlayToFront()
        _ = previewVC
    }

    private func configureFitModelUIIfNeeded(previewVC: ScenePreviewViewController) {
        guard settingsStore.developerModeEnabled else { return }
        overlayWorkflow.configureFitModelUI(
            previewVC: previewVC,
            previewContainerVC: self,
            target: self,
            fitPanelToggleAction: #selector(fitPanelToggleTapped),
            fitModelCheckAction: #selector(fitModelCheckTapped),
            exportFitPackAction: #selector(exportFitPackTapped),
            fitBrowAdvancedAction: #selector(fitBrowAdvancedTapped),
            fitBrowSliderChangedAction: #selector(fitBrowSliderChanged(_:))
        )
    }

    private func renderDerivedMeasurementsIfAvailable() {
        guard let summary = previewStore.measurementSummary else { return }
        overlayWorkflow.renderDerivedMeasurements(summary: summary, hostView: overlayView)
    }

    private func handle(effect: PreviewEffect) {
        switch effect {
        case .alert(let title, let message, let identifier):
            present(
                alertPresenter.makeAlert(title: title, message: message, identifier: identifier),
                animated: true
            )
        case .toast(let message):
            onToast?(message)
        case .route(let route):
            if case .returnHomeAfterSave = route {
                saveExportViewState.markSaveCompleted()
                saveExportViewState.hideSavingToast()
            }
            delegate?.previewViewController(self, handle: route)
        case .hapticPrimary:
            DesignSystem.hapticPrimary()
        }
    }

    private func apply(state: PreviewState) {
        let viewData: PreviewViewData?
        switch state {
        case .loading:
            viewData = nil
        case .ready(let data), .meshing(let data), .saving(let data), .blocked(_, let data), .failed(_, let data):
            viewData = data
        case .saved:
            viewData = nil
        }

        guard let viewData else { return }
        if let previewVC = previewPresentationController.resolvedScenePreviewViewController {
            if previewVC.rightButton.accessibilityIdentifier == "previewSaveButton" {
                previewVC.rightButton.isEnabled = viewData.saveButtonEnabled
                DesignSystem.updateButtonEnabled(previewVC.rightButton, style: .primary)
            } else if previewVC.rightButton.accessibilityIdentifier == "previewShareButton" {
                previewVC.rightButton.isEnabled = viewData.shareButtonEnabled
                DesignSystem.updateButtonEnabled(previewVC.rightButton, style: .secondary)
            }
        }

        saveExportViewState.setMeshingStatusText(viewData.meshingStatusText)
        saveExportViewState.setMeshingSpinnerActive(viewData.meshingSpinnerVisible)
        previewOverlayUI.setFitPanelExpanded(viewData.fitPanelExpanded)
        previewOverlayUI.setFitToolsAvailable(!previewStore.isMeshingActive)

        if let button = previewOverlayUI.verifyEarButton {
            button.isEnabled = viewData.verifyEarButtonEnabled
            DesignSystem.updateButtonEnabled(button, style: .secondary)
        }
        if viewData.earVerified {
            earVerificationWorkflow.finishVerificationUI(title: L("scan.preview.verified"))
            previewOverlayUI.removeVerifyHint()
        }
    }

    private func presentBlockedSave(_ blocked: PreviewBlockReason, on previewVC: UIViewController) {
        previewStore.blockSave(reason: blocked)
        scanFlowState.setPhase(.preview)
        saveExportViewState.markSaveBlocked()

        let alert: UIAlertController
        switch blocked {
        case .gltfRequired:
            alert = alertPresenter.makeAlert(
                title: L("settings.export.minimum.title"),
                message: L("settings.export.minimum.message"),
                identifier: "exportFormatsDisabledAlert"
            )
        case .meshNotReady:
            alert = alertPresenter.makeAlert(
                title: L("scan.preview.meshNotReady.title"),
                message: L("scan.preview.meshNotReady.message"),
                identifier: "meshNotReadyAlert"
            )
        case .qualityGateBlocked(let reason, let advice):
            alert = alertPresenter.makeAlert(
                title: L("scan.quality.gate.title"),
                message: String(format: L("scan.quality.gate.message"), reason, advice),
                identifier: "qualityGateAlert"
            )
        case .exportUnavailable:
            alert = alertPresenter.makeAlert(
                title: L("scan.preview.exportFailed.title"),
                message: String(format: L("scan.preview.exportFailed.message"), L("scan.preview.exportUnavailable.message")),
                identifier: "exportUnavailableAlert"
            )
        }
        previewVC.present(alert, animated: true)
        restoreReadyState()
    }

    private func handleExportInvocationFailure(reason: String) {
        saveExportViewState.markSaveFailed()
        present(
            alertPresenter.makeAlert(
                title: L("scan.preview.exportFailed.title"),
                message: String(format: L("scan.preview.exportFailed.message"), reason),
                identifier: "exportInvocationAlert"
            ),
            animated: true
        )
        scanFlowState.setPhase(.preview)
        restoreReadyState()
        onExportResult?(.failure(message: reason))
        Log.export.error("Save invocation failed: \(reason, privacy: .public)")
    }

    private func restoreReadyState() {
        previewStore.restoreReadyState()
        saveExportViewState.setButtonsEnabled(true)
        saveExportViewState.setMeshingStatusText(L("scan.preview.readyToSave"))
        saveExportViewState.setMeshingSpinnerActive(false)
        saveExportViewState.hideSavingToast()
    }

    private func presentMissingSceneAlertAndDismiss() {
        let alert = UIAlertController(
            title: L("scan.preview.missingScene.title"),
            message: L("scan.preview.missingScene.message"),
            preferredStyle: .alert
        )
        alert.view.accessibilityIdentifier = "missingSceneAlert"
        alert.addAction(UIAlertAction(title: L("common.ok"), style: .default) { [weak self] _ in
            guard let self else { return }
            self.delegate?.previewViewController(self, handle: .dismiss)
        })
        present(alert, animated: true)
    }

    #if DEBUG
    @discardableResult
    static func debug_addFitControlsIfDeveloperMode(hostView: UIView, settingsStore: SettingsStore) -> Bool {
        guard settingsStore.developerModeEnabled else { return false }
        let overlay = PreviewOverlayUIController()
        _ = overlay.addFitModelUI(to: hostView)
        return overlay.fitBrowSlider != nil
    }
    #endif
}

final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}
