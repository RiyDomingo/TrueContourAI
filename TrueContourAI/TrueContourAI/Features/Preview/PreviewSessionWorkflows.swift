import UIKit
import StandardCyborgUI
import StandardCyborgFusion
import SceneKit
import simd

protocol PreviewScanReading: ScanSummaryReading, LastScanReading, ScanFolderSharing {
    var scansRootURL: URL { get }
    func sceneForScan(_ item: ScanItem) -> SCScene?
    func resolveLastScanFolderURL() -> URL?
}

extension ScanRepository: PreviewScanReading {}

final class PreviewPresentationWorkflow {
    private let previewOverlayUI: PreviewOverlayUIController
    private let buttonConfigurator: PreviewButtonConfigurator
    private let saveExportViewState: SaveExportUIStateAdapting

    init(
        previewOverlayUI: PreviewOverlayUIController,
        buttonConfigurator: PreviewButtonConfigurator,
        saveExportViewState: SaveExportUIStateAdapting
    ) {
        self.previewOverlayUI = previewOverlayUI
        self.buttonConfigurator = buttonConfigurator
        self.saveExportViewState = saveExportViewState
    }

    func makeExistingScanPreview(
        scene: SCScene,
        closeTarget: Any,
        shareTarget: Any,
        onClose: Selector,
        onShare: Selector
    ) -> ScenePreviewViewController {
        let vc = ScenePreviewViewController(scScene: scene)
        vc.view.backgroundColor = DesignSystem.Colors.background
        vc.sceneView.backgroundColor = DesignSystem.Colors.background

        buttonConfigurator.configureButtons(for: vc, mode: .existingScan)
        vc.leftButton.addTarget(closeTarget, action: onClose, for: .touchUpInside)
        vc.rightButton.addTarget(shareTarget, action: onShare, for: .touchUpInside)
        return vc
    }

    func makeTestPreview(
        target: Any,
        onClose: Selector,
        onShare: Selector
    ) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = DesignSystem.Colors.background

        let closeButton = UIButton(type: .system)
        let shareButton = UIButton(type: .system)
        DesignSystem.applyButton(closeButton, title: L("common.close"), style: .secondary, size: .regular)
        DesignSystem.applyButton(shareButton, title: L("common.share"), style: .secondary, size: .regular)
        closeButton.accessibilityIdentifier = "previewCloseButton"
        shareButton.accessibilityIdentifier = "previewShareButton"
        closeButton.addTarget(target, action: onClose, for: .touchUpInside)
        shareButton.addTarget(target, action: onShare, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [closeButton, shareButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        vc.view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            stack.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        vc.modalPresentationStyle = .fullScreen
        return vc
    }

    func makePostScanPreview(
        pointCloud: SCPointCloud,
        meshTexturing: SCMeshTexturing,
        target: Any,
        onClose: Selector,
        onSave: Selector
    ) -> ScenePreviewViewController {
        let vc = ScenePreviewViewController(
            pointCloud: pointCloud,
            meshTexturing: meshTexturing,
            landmarks: nil
        )
        vc.view.backgroundColor = DesignSystem.Colors.background
        vc.sceneView.backgroundColor = DesignSystem.Colors.background

        previewOverlayUI.clear()
        buttonConfigurator.configureButtons(for: vc, mode: .newScan)
        vc.leftButton.addTarget(target, action: onClose, for: .touchUpInside)
        vc.rightButton.addTarget(target, action: onSave, for: .touchUpInside)
        vc.leftButton.accessibilityIdentifier = "previewCloseButton"
        vc.rightButton.accessibilityIdentifier = "previewSaveButton"
        vc.rightButton.isEnabled = false
        DesignSystem.updateButtonEnabled(vc.rightButton, style: .primary)
        saveExportViewState.configure(previewVC: vc)
        return vc
    }
}

final class PreviewOverlayWorkflow {
    private let previewOverlayUI: PreviewOverlayUIController
    private let fitWorkflow: PreviewFitWorkflow

    init(
        previewOverlayUI: PreviewOverlayUIController,
        fitWorkflow: PreviewFitWorkflow
    ) {
        self.previewOverlayUI = previewOverlayUI
        self.fitWorkflow = fitWorkflow
    }

    func renderDerivedMeasurements(
        summary: LocalMeasurementGenerationService.ResultSummary,
        hostView: UIView
    ) {
        previewOverlayUI.addOrUpdateDerivedMeasurements(
            to: hostView,
            circumferenceMm: summary.circumferenceMm,
            widthMm: summary.widthMm,
            depthMm: summary.depthMm,
            confidence: summary.confidence
        )
    }

    func addVerifyEarUI(
        hostView: UIView,
        bringOverlayToFront: (() -> Void)?,
        developerModeEnabled: Bool,
        showHint: Bool,
        target: Any,
        action: Selector
    ) {
        bringOverlayToFront?()
        previewOverlayUI.setDeveloperModeEnabled(developerModeEnabled)
        let button = previewOverlayUI.addVerifyEarUI(to: hostView, showHint: showHint)
        button.addTarget(target, action: action, for: .touchUpInside)
    }

    func configureFitModelUI(
        previewVC: ScenePreviewViewController,
        previewContainerVC: PreviewContainerViewController?,
        target: Any,
        fitPanelToggleAction: Selector,
        fitModelCheckAction: Selector,
        exportFitPackAction: Selector,
        fitBrowAdvancedAction: Selector,
        fitBrowSliderChangedAction: Selector
    ) {
        fitWorkflow.configureIfNeeded(previewVC: previewVC, previewContainerVC: previewContainerVC)
        guard let hostView = previewContainerVC?.overlayView ?? previewVC.view else { return }
        let controls = previewOverlayUI.addFitModelUI(to: hostView)
        previewOverlayUI.fitPanelToggleButton?.addTarget(target, action: fitPanelToggleAction, for: .touchUpInside)
        controls.check.addTarget(target, action: fitModelCheckAction, for: .touchUpInside)
        controls.export.addTarget(target, action: exportFitPackAction, for: .touchUpInside)
        previewOverlayUI.fitBrowAdvancedButton?.addTarget(target, action: fitBrowAdvancedAction, for: .touchUpInside)
        controls.browSlider.addTarget(target, action: fitBrowSliderChangedAction, for: .valueChanged)
    }

    func addScanQualityLabel(to hostView: UIView, quality: ScanQuality) {
        previewOverlayUI.addScanQualityLabel(
            to: hostView,
            quality: quality,
            anchor: nil
        )
    }
}

final class PreviewPostScanWorkflow {
    private let settingsStore: SettingsStore
    private let previewViewModel: PreviewViewModel
    private let scanFlowState: ScanFlowState

    init(
        settingsStore: SettingsStore,
        previewViewModel: PreviewViewModel,
        scanFlowState: ScanFlowState
    ) {
        self.settingsStore = settingsStore
        self.previewViewModel = previewViewModel
        self.scanFlowState = scanFlowState
    }

    func preparePreviewState(pointCloud: SCPointCloud) {
        let qualityConfig = settingsStore.scanQualityConfig
        let qualityReport = ScanQualityValidator.evaluate(
            pointCloud: pointCloud,
            config: .init(
                gateEnabled: qualityConfig.gateEnabled,
                minValidPoints: qualityConfig.minValidPoints,
                minValidRatio: qualityConfig.minValidRatio,
                minQualityScore: qualityConfig.minQualityScore,
                minHeadDimensionMeters: qualityConfig.minHeadDimensionMeters,
                maxHeadDimensionMeters: qualityConfig.maxHeadDimensionMeters
            )
        )
        previewViewModel.setQualityReport(qualityReport)
        Log.scanning.info(
            """
            Scan quality report: raw=\(qualityReport.pointCount, privacy: .public) \
            valid=\(qualityReport.validPointCount, privacy: .public) \
            bounds=\(qualityReport.widthMeters, privacy: .public)x\(qualityReport.heightMeters, privacy: .public)x\(qualityReport.depthMeters, privacy: .public) \
            score=\(qualityReport.qualityScore, privacy: .public) \
            exportable=\(qualityReport.isExportRecommended, privacy: .public)
            """
        )
        previewViewModel.setMeshingActive(true)
        scanFlowState.setPhase(.preview)
        previewViewModel.setPhase(.preview)
    }

    func presentContainer(
        scanningVC: UIViewController,
        presenter: UIViewController,
        container: PreviewContainerViewController,
        previewSessionID: UUID,
        isCurrentPreviewSession: @escaping (UUID) -> Bool,
        onPresented: @escaping () -> Void
    ) {
        scanningVC.dismiss(animated: false) {
            presenter.present(container, animated: true) {
                guard isCurrentPreviewSession(previewSessionID) else { return }
                onPresented()
            }
        }
    }
}

struct PreviewPostScanPresentationContext {
    let previewVC: ScenePreviewViewController
    let container: PreviewContainerViewController
}

final class PreviewPostScanPresentationWorkflow {
    private let presentationWorkflow: PreviewPresentationWorkflow
    private let postScanWorkflow: PreviewPostScanWorkflow
    private let meshingWorkflow: PreviewMeshingWorkflow
    private let measurementWorkflow: PreviewMeasurementWorkflow
    private let sceneUIController: PreviewSceneUIController

    init(
        presentationWorkflow: PreviewPresentationWorkflow,
        postScanWorkflow: PreviewPostScanWorkflow,
        meshingWorkflow: PreviewMeshingWorkflow,
        measurementWorkflow: PreviewMeasurementWorkflow,
        sceneUIController: PreviewSceneUIController
    ) {
        self.presentationWorkflow = presentationWorkflow
        self.postScanWorkflow = postScanWorkflow
        self.meshingWorkflow = meshingWorkflow
        self.measurementWorkflow = measurementWorkflow
        self.sceneUIController = sceneUIController
    }

    func makePresentationContext(
        scanningVC: UIViewController,
        presenter: UIViewController,
        pointCloud: SCPointCloud,
        meshTexturing: SCMeshTexturing,
        previewSessionID: UUID,
        target: Any,
        onClose: Selector,
        onSave: Selector,
        isCurrentPreviewSession: @escaping (UUID) -> Bool,
        onMeshReady: @escaping (SCMesh) -> Void
    ) -> PreviewPostScanPresentationContext {
        postScanWorkflow.preparePreviewState(pointCloud: pointCloud)

        let previewVC = presentationWorkflow.makePostScanPreview(
            pointCloud: pointCloud,
            meshTexturing: meshTexturing,
            target: target,
            onClose: onClose,
            onSave: onSave
        )
        meshingWorkflow.startTimeout(in: previewVC, sessionID: previewSessionID, isCurrentPreviewSession: isCurrentPreviewSession)
        meshingWorkflow.configureCallbacks(
            for: previewVC,
            previewSessionID: previewSessionID,
            isCurrentPreviewSession: isCurrentPreviewSession,
            onMeshReady: onMeshReady
        )

        measurementWorkflow.generate(
            from: pointCloud,
            previewSessionID: previewSessionID,
            isCurrentPreviewSession: isCurrentPreviewSession
        )

        let container = PreviewContainerViewController(contentViewController: previewVC)
        postScanWorkflow.presentContainer(
            scanningVC: scanningVC,
            presenter: presenter,
            container: container,
            previewSessionID: previewSessionID,
            isCurrentPreviewSession: isCurrentPreviewSession,
            onPresented: { [weak self] in
                guard let self else { return }
                self.sceneUIController.finalizePostScanSceneUI(previewVC: previewVC)
            }
        )

        return PreviewPostScanPresentationContext(
            previewVC: previewVC,
            container: container
        )
    }
}

final class PreviewExistingScanWorkflow {
    private let scanReader: PreviewScanReading
    private let previewViewModel: PreviewViewModel
    private let scanFlowState: ScanFlowState
    private let previewSessionController: PreviewSessionController
    private let presentationWorkflow: PreviewPresentationWorkflow
    private let alertPresenter: PreviewAlertPresenter
    private let overlayWorkflow: PreviewOverlayWorkflow

    init(
        scanReader: PreviewScanReading,
        previewViewModel: PreviewViewModel,
        scanFlowState: ScanFlowState,
        previewSessionController: PreviewSessionController,
        presentationWorkflow: PreviewPresentationWorkflow,
        alertPresenter: PreviewAlertPresenter,
        overlayWorkflow: PreviewOverlayWorkflow
    ) {
        self.scanReader = scanReader
        self.previewViewModel = previewViewModel
        self.scanFlowState = scanFlowState
        self.previewSessionController = previewSessionController
        self.presentationWorkflow = presentationWorkflow
        self.alertPresenter = alertPresenter
        self.overlayWorkflow = overlayWorkflow
    }

    func makePresentation(
        item: ScanItem,
        presenter: UIViewController,
        skipGLTF: Bool,
        closeTarget: AnyObject,
        shareTarget: AnyObject,
        onClose: Selector,
        onShare: Selector
    ) -> (UIViewController, ScenePreviewViewController?, ScanSummary?)? {
        let existingSummary = scanReader.resolveScanSummary(from: item.folderURL)
        if skipGLTF {
            Log.ui.info("Presenting test preview for scan: \(item.displayName, privacy: .public)")
            scanFlowState.setPhase(.preview)
            previewViewModel.setPhase(.preview)
            previewSessionController.currentPreviewedFolderURL = item.folderURL
            let vc = presentationWorkflow.makeTestPreview(
                target: closeTarget,
                onClose: onClose,
                onShare: onShare
            )
            if closeTarget !== shareTarget {
                let stacks = vc.view.subviews.compactMap { $0 as? UIStackView }
                let arrangedSubviews = stacks.flatMap(\.arrangedSubviews)
                let buttons = arrangedSubviews.compactMap { $0 as? UIButton }
                let shareButton = buttons.first {
                    $0.accessibilityIdentifier == "previewShareButton"
                }
                shareButton?.addTarget(shareTarget, action: onShare, for: .touchUpInside)
            }
            return (vc, nil, existingSummary)
        }

        guard let scene = scanReader.sceneForScan(item) else {
            Log.ui.error("Missing scene.gltf for scan: \(item.displayName, privacy: .public)")
            alertPresenter.presentAlert(
                on: presenter,
                title: L("scan.preview.missingScene.title"),
                message: L("scan.preview.missingScene.message"),
                identifier: "missingSceneAlert"
            )
            return nil
        }

        scanFlowState.setPhase(.preview)
        previewViewModel.setPhase(.preview)
        previewSessionController.currentPreviewedFolderURL = item.folderURL

        let vc = presentationWorkflow.makeExistingScanPreview(
            scene: scene,
            closeTarget: closeTarget,
            shareTarget: shareTarget,
            onClose: onClose,
            onShare: onShare
        )
        return (vc, vc, existingSummary)
    }

    func finalizePresentation(
        summary: ScanSummary?,
        previewVC: ScenePreviewViewController,
        configureFitModelUI: (ScenePreviewViewController) -> Void
    ) {
        if let derived = summary?.derivedMeasurements {
            overlayWorkflow.renderDerivedMeasurements(
                summary: .init(
                    sliceHeightNormalized: derived.sliceHeightNormalized,
                    circumferenceMm: derived.circumferenceMm,
                    widthMm: derived.widthMm,
                    depthMm: derived.depthMm,
                    confidence: derived.confidence,
                    status: derived.status
                ),
                hostView: previewVC.view
            )
        }
        configureFitModelUI(previewVC)
    }
}

final class PreviewLifecycleWorkflow {
    private let scanFlowState: ScanFlowState
    private let previewViewModel: PreviewViewModel
    private let previewSessionController: PreviewSessionController
    private let presentationController: PreviewPresentationController
    private let resetController: PreviewResetController

    init(
        scanFlowState: ScanFlowState,
        previewViewModel: PreviewViewModel,
        previewSessionController: PreviewSessionController,
        presentationController: PreviewPresentationController,
        resetController: PreviewResetController
    ) {
        self.scanFlowState = scanFlowState
        self.previewViewModel = previewViewModel
        self.previewSessionController = previewSessionController
        self.presentationController = presentationController
        self.resetController = resetController
    }

    func dismissPreview() {
        Log.ui.info("Dismissed preview")
        previewSessionController.invalidateSession()
        presentationController.dismissActivePreview(animated: true) { [weak self] in
            guard let self else { return }
            self.resetController.reset()
            self.scanFlowState.setPhase(.idle)
            self.previewViewModel.setPhase(.idle)
        }
    }
}

final class PreviewSharingWorkflow {
    private let scanReader: PreviewScanReading
    private let previewSessionController: PreviewSessionController
    private let environment: AppEnvironment
    private let alertPresenter: PreviewAlertPresenter

    init(
        scanReader: PreviewScanReading,
        previewSessionController: PreviewSessionController,
        environment: AppEnvironment,
        alertPresenter: PreviewAlertPresenter
    ) {
        self.scanReader = scanReader
        self.previewSessionController = previewSessionController
        self.environment = environment
        self.alertPresenter = alertPresenter
    }

    func presentShareSheet(
        from presentingVC: UIViewController,
        sourceView: UIView?
    ) {
        let forceMissing = environment.forcesMissingFolder
        guard let folder = forceMissing ? nil : (previewSessionController.currentPreviewedFolderURL ?? scanReader.resolveLastScanFolderURL()) else {
            alertPresenter.presentAlert(
                on: presentingVC,
                title: L("scan.preview.missingFolder.title"),
                message: L("scan.preview.missingFolder.message"),
                identifier: "missingFolderAlert"
            )
            return
        }

        let activityVC = UIActivityViewController(
            activityItems: scanReader.shareItems(for: folder),
            applicationActivities: nil
        )
        if let popover = activityVC.popoverPresentationController {
            let anchorView = sourceView ?? presentingVC.view
            popover.sourceView = anchorView
            popover.sourceRect = anchorView?.bounds ?? .zero
        }
        presentingVC.present(activityVC, animated: true)
    }
}

enum PreviewSavePrecheckResult: Equatable {
    case gltfExportRequired
    case meshNotReady
    case qualityGateBlocked(ScanQualityReport)
    case ready
}

struct PreviewExportContext {
    let mesh: SCMesh
    let scene: SCScene
    let thumbnail: UIImage?
    let earArtifacts: ScanEarArtifacts?
    let scanSummary: ScanSummary?
    let includeGLTF: Bool
    let includeOBJ: Bool
    let isEarServiceUnavailable: Bool
}

struct PreviewExportWorkflow {
    let settingsStore: SettingsStore

    func savePrecheck(qualityReport: ScanQualityReport?, meshAvailable: Bool) -> PreviewSavePrecheckResult {
        if !settingsStore.hasRequiredExportFormatsEnabled {
            return .gltfExportRequired
        }
        if !meshAvailable {
            return .meshNotReady
        }
        let qualityConfig = settingsStore.scanQualityConfig
        if qualityConfig.gateEnabled,
           let qualityReport,
           !qualityReport.isExportRecommended {
            return .qualityGateBlocked(qualityReport)
        }
        return .ready
    }

    func makeExportContext(
        previewVC: ScenePreviewViewController,
        previewViewModel: PreviewViewModel,
        earServiceUnavailable: Bool
    ) -> PreviewExportContext? {
        guard let mesh = previewViewModel.meshForExport else { return nil }

        let earArtifacts: ScanEarArtifacts?
        if let earImage = previewViewModel.verifiedEarImage,
           let earResult = previewViewModel.verifiedEarResult,
           let earOverlay = previewViewModel.verifiedEarOverlay {
            earArtifacts = .init(earImage: earImage, earResult: earResult, earOverlay: earOverlay)
        } else {
            earArtifacts = nil
        }

        return PreviewExportContext(
            mesh: mesh,
            scene: previewVC.scScene,
            thumbnail: previewVC.renderedSceneImage,
            earArtifacts: earArtifacts,
            scanSummary: ScanSummaryBuilder.build(
                settingsStore: settingsStore,
                metrics: previewViewModel.sessionMetrics,
                qualityReport: previewViewModel.qualityReport,
                measurementSummary: previewViewModel.measurementSummary,
                hadEarVerification: earArtifacts != nil
            ),
            includeGLTF: settingsStore.exportGLTF,
            includeOBJ: settingsStore.exportOBJ,
            isEarServiceUnavailable: earServiceUnavailable && earArtifacts == nil
        )
    }

    func exportFormatSummary() -> String {
        var formats: [String] = []
        if settingsStore.exportGLTF { formats.append(L("scan.preview.exportFormat.gltf")) }
        if settingsStore.exportOBJ { formats.append(L("scan.preview.exportFormat.obj")) }
        if formats.isEmpty { return L("scan.preview.exportFormat.none") }
        return formats.joined(separator: ", ")
    }
}

final class PreviewSaveWorkflow {
    private let previewViewModel: PreviewViewModel
    private let scanFlowState: ScanFlowState
    private let saveExportViewState: SaveExportUIStateAdapting
    private let alertPresenter: PreviewAlertPresenter
    private let scanExporter: ScanExporting

    init(
        previewViewModel: PreviewViewModel,
        scanFlowState: ScanFlowState,
        saveExportViewState: SaveExportUIStateAdapting,
        alertPresenter: PreviewAlertPresenter,
        scanExporter: ScanExporting
    ) {
        self.previewViewModel = previewViewModel
        self.scanFlowState = scanFlowState
        self.saveExportViewState = saveExportViewState
        self.alertPresenter = alertPresenter
        self.scanExporter = scanExporter
    }

    func performSave(
        previewVC: ScenePreviewViewController,
        previewSessionID: UUID,
        exportWorkflow: PreviewExportWorkflow,
        earServiceUnavailable: Bool,
        isCurrentPreviewSession: @escaping (UUID) -> Bool,
        onFailure: @escaping (String) -> Void,
        onSuccess: @escaping (URL, PreviewExportContext) -> Void
    ) {
        let precheck = exportWorkflow.savePrecheck(
            qualityReport: previewViewModel.qualityReport,
            meshAvailable: previewViewModel.meshForExport != nil
        )
        if precheck == .gltfExportRequired {
            previewVC.present(
                alertPresenter.makeAlert(
                    title: L("settings.export.minimum.title"),
                    message: L("settings.export.minimum.message"),
                    identifier: "exportFormatsDisabledAlert"
                ),
                animated: true
            )
            Log.export.error("Export blocked: GLTF export disabled")
            return
        }

        if case .qualityGateBlocked(let qualityReport) = precheck {
            previewVC.present(
                alertPresenter.makeAlert(
                    title: L("scan.quality.gate.title"),
                    message: String(
                        format: L("scan.quality.gate.message"),
                        qualityReport.reason,
                        qualityReport.advice.message
                    ),
                    identifier: "qualityGateAlert"
                ),
                animated: true
            )
            Log.export.error("Export blocked: quality gate")
            return
        }

        scanFlowState.setPhase(.saving)
        previewViewModel.setPhase(.saving)
        saveExportViewState.setButtonsEnabled(false)
        saveExportViewState.setMeshingStatusText(L("scan.preview.exporting"))
        saveExportViewState.setMeshingSpinnerActive(true)
        saveExportViewState.showSavingToast()
        Log.export.info("User requested export")

        guard precheck != .meshNotReady else {
            previewVC.present(
                alertPresenter.makeAlert(
                    title: L("scan.preview.meshNotReady.title"),
                    message: L("scan.preview.meshNotReady.message"),
                    identifier: "meshNotReadyAlert"
                ),
                animated: true
            )
            resetToPreviewReadyState()
            Log.export.error("Export blocked: mesh not ready")
            return
        }

        guard let exportContext = exportWorkflow.makeExportContext(
            previewVC: previewVC,
            previewViewModel: previewViewModel,
            earServiceUnavailable: earServiceUnavailable
        ) else {
            resetToPreviewReadyState()
            Log.export.error("Export blocked: export context unavailable")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let exportStart = CFAbsoluteTimeGetCurrent()
            let exportResult = self.scanExporter.exportScanFolder(
                mesh: exportContext.mesh,
                scene: exportContext.scene,
                thumbnail: exportContext.thumbnail,
                earArtifacts: exportContext.earArtifacts,
                scanSummary: exportContext.scanSummary,
                includeGLTF: exportContext.includeGLTF,
                includeOBJ: exportContext.includeOBJ
            )

            DispatchQueue.main.async {
                guard isCurrentPreviewSession(previewSessionID) else { return }
                let exportElapsed = CFAbsoluteTimeGetCurrent() - exportStart
                Log.export.info("Export completed in \(exportElapsed, privacy: .public)s")
                switch exportResult {
                case .failure(let message):
                    onFailure(message)
                case .success(let folderURL):
                    onSuccess(folderURL, exportContext)
                }
            }
        }
    }

    private func resetToPreviewReadyState() {
        scanFlowState.setPhase(.preview)
        previewViewModel.setPhase(.preview)
        saveExportViewState.setButtonsEnabled(true)
        saveExportViewState.setMeshingStatusText(L("scan.preview.readyToSave"))
        saveExportViewState.setMeshingSpinnerActive(false)
        saveExportViewState.hideSavingToast()
    }
}

final class PreviewFitWorkflow {
    private let previewViewModel: PreviewViewModel
    private let previewOverlayUI: PreviewOverlayUIController
    private let alertPresenter: PreviewAlertPresenter
    private let settingsStore: SettingsStore
    private let scanReader: PreviewScanReading
    private let fitModelPackService = FitModelPackService()
    private let onToast: ((String) -> Void)?

    private var fitEarPickTapGesture: UITapGestureRecognizer?

    init(
        previewViewModel: PreviewViewModel,
        previewOverlayUI: PreviewOverlayUIController,
        alertPresenter: PreviewAlertPresenter,
        settingsStore: SettingsStore,
        scanReader: PreviewScanReading,
        onToast: ((String) -> Void)?
    ) {
        self.previewViewModel = previewViewModel
        self.previewOverlayUI = previewOverlayUI
        self.alertPresenter = alertPresenter
        self.settingsStore = settingsStore
        self.scanReader = scanReader
        self.onToast = onToast
    }

    func configureIfNeeded(
        previewVC: ScenePreviewViewController,
        previewContainerVC: PreviewContainerViewController?
    ) {
        guard settingsStore.developerModeEnabled else { return }
        guard let hostView = previewContainerVC?.overlayView ?? previewVC.view else { return }
        let controls = previewOverlayUI.addFitModelUI(to: hostView)
        controls.check.removeTarget(nil, action: nil, for: .allEvents)
        controls.export.removeTarget(nil, action: nil, for: .allEvents)
        controls.browSlider.removeTarget(nil, action: nil, for: .allEvents)
        previewOverlayUI.fitBrowAdvancedButton?.removeTarget(nil, action: nil, for: .allEvents)
        previewOverlayUI.fitPanelToggleButton?.removeTarget(nil, action: nil, for: .allEvents)
        if previewViewModel.latestFitCheckResult == nil {
            previewOverlayUI.resetFitPanelToActionsOnly()
        }
        previewOverlayUI.setFitToolsAvailable(!previewViewModel.isMeshingActive)
        previewOverlayUI.setFitPanelExpanded(previewViewModel.showsFitPanel)
        controls.browSlider.value = previewViewModel.browPlaneDropFromTopFraction
        previewOverlayUI.updateBrowSliderLabel(percentage: Int((previewViewModel.browPlaneDropFromTopFraction * 100).rounded()))
        previewOverlayUI.setBrowControlsVisible(previewViewModel.showsAdvancedBrowControls)
    }

    func toggleFitPanelExpanded() {
        previewViewModel.toggleFitPanelExpanded()
        previewOverlayUI.setFitPanelExpanded(previewViewModel.showsFitPanel)
    }

    func toggleAdvancedBrowControlsVisible() {
        previewViewModel.toggleAdvancedBrowControlsVisible()
        previewOverlayUI.setBrowControlsVisible(previewViewModel.showsAdvancedBrowControls)
    }

    func updateBrowPlaneDropFromTopFraction(_ value: Float) {
        previewViewModel.setBrowPlaneDropFromTopFraction(value)
        previewOverlayUI.updateBrowSliderLabel(percentage: Int((previewViewModel.browPlaneDropFromTopFraction * 100).rounded()))
    }

    func exportFitPack(scenePreviewVC: ScenePreviewViewController?, currentPreviewedFolderURL: URL?) {
        guard let previewVC = scenePreviewVC else { return }
        guard let fitResult = previewViewModel.latestFitCheckResult,
              let meshData = previewViewModel.latestFitMeshData else {
            runFitModelCheck(
                scenePreviewVC: scenePreviewVC,
                currentPreviewedFolderURL: currentPreviewedFolderURL,
                showHaptic: true,
                allowEarPickPrompt: true,
                fitEarPickTarget: nil,
                fitEarPickAction: nil
            )
            return
        }

        let parentFolderURL: URL
        if let scanFolder = currentPreviewedFolderURL {
            parentFolderURL = scanFolder
        } else {
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            parentFolderURL = scanReader.scansRootURL.appendingPathComponent("FitModelPack-\(stamp)", isDirectory: true)
            try? FileManager.default.createDirectory(at: parentFolderURL, withIntermediateDirectories: true)
        }

        do {
            let packURL = try fitModelPackService.exportPack(
                meshData: meshData,
                fitCheckResult: fitResult,
                parentFolderURL: parentFolderURL
            )
            onToast?(String(format: L("scan.preview.fit.export.success"), packURL.lastPathComponent))
        } catch {
            previewVC.present(
                alertPresenter.makeAlert(
                    title: L("scan.preview.fit.export.failed.title"),
                    message: String(format: L("scan.preview.fit.export.failed.message"), error.localizedDescription),
                    identifier: "fitExportFailedAlert"
                ),
                animated: true
            )
        }
    }

    func runFitModelCheck(
        scenePreviewVC: ScenePreviewViewController?,
        currentPreviewedFolderURL: URL?,
        showHaptic: Bool,
        allowEarPickPrompt: Bool,
        fitEarPickTarget: AnyObject?,
        fitEarPickAction: Selector?
    ) {
        guard let previewVC = scenePreviewVC else { return }
        if showHaptic {
            DesignSystem.hapticPrimary()
        }

        let appVersion = Self.appVersionString()
        let deviceModel = UIDevice.current.model

        let meshData: FitModelPackService.MeshData?
        if let mesh = previewViewModel.meshForExport {
            meshData = FitModelPackService.extractMeshData(from: mesh)
        } else if let folder = currentPreviewedFolderURL,
                  let objURL = scanReader.resolveOBJFromFolder(folder) {
            meshData = FitModelPackService.readOBJMeshData(from: objURL)
        } else {
            meshData = nil
        }

        guard let meshData else {
            previewVC.present(
                alertPresenter.makeAlert(
                    title: L("scan.preview.fit.unavailable.title"),
                    message: L("scan.preview.fit.unavailable.message"),
                    identifier: "fitUnavailableAlert"
                ),
                animated: true
            )
            return
        }

        previewViewModel.setFitMeshData(meshData)
        let result = fitModelPackService.checkFromOBJMeshData(
            meshData: meshData,
            manualEarLeftMeters: previewViewModel.manualEarLeftMeters,
            manualEarRightMeters: previewViewModel.manualEarRightMeters,
            browPlaneDropFromTopFraction: previewViewModel.browPlaneDropFromTopFraction,
            appVersion: appVersion,
            deviceModel: deviceModel
        )

        guard let result else {
            previewVC.present(
                alertPresenter.makeAlert(
                    title: L("scan.preview.fit.unavailable.title"),
                    message: L("scan.preview.fit.unavailable.message"),
                    identifier: "fitUnavailableAlert"
                ),
                animated: true
            )
            return
        }

        previewViewModel.setFitCheckResult(result)
        updateFitResultsCard(with: result)
        if allowEarPickPrompt,
           result.fitData.ear_left_xyz_mm == nil || result.fitData.ear_right_xyz_mm == nil {
            beginFitEarPicking(in: previewVC, target: fitEarPickTarget, action: fitEarPickAction)
        }
    }

    func handleFitEarPickTap(_ gesture: UITapGestureRecognizer, scenePreviewVC: ScenePreviewViewController?, currentPreviewedFolderURL: URL?) {
        guard let previewVC = scenePreviewVC else { return }
        guard previewViewModel.fitEarPickState != .none else { return }
        let location = gesture.location(in: previewVC.sceneView)
        let hits = previewVC.sceneView.hitTest(location, options: [
            SCNHitTestOption.firstFoundOnly: true
        ])
        guard let hit = hits.first else {
            onToast?(L("scan.preview.fit.pick.failed"))
            return
        }
        let w = hit.worldCoordinates
        let point = SIMD3<Float>(w.x, w.y, w.z)

        switch previewViewModel.fitEarPickState {
        case .pickLeft:
            previewViewModel.setManualLeftEar(point)
            previewViewModel.setNextFitEarPickState(.pickRight)
            onToast?(L("scan.preview.fit.pick.right"))
        case .pickRight:
            previewViewModel.setManualRightEar(point)
            previewViewModel.setNextFitEarPickState(.none)
            if let tap = fitEarPickTapGesture {
                previewVC.sceneView.removeGestureRecognizer(tap)
                fitEarPickTapGesture = nil
            }
            runFitModelCheck(
                scenePreviewVC: scenePreviewVC,
                currentPreviewedFolderURL: currentPreviewedFolderURL,
                showHaptic: true,
                allowEarPickPrompt: true,
                fitEarPickTarget: nil,
                fitEarPickAction: nil
            )
        case .none:
            break
        }
    }

    func cleanup(scenePreviewVC: ScenePreviewViewController?) {
        if let tap = fitEarPickTapGesture, let sceneView = scenePreviewVC?.sceneView {
            sceneView.removeGestureRecognizer(tap)
        }
        fitEarPickTapGesture = nil
    }

    private func updateFitResultsCard(with result: FitModelCheckResult) {
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
        previewOverlayUI.updateFitResultsCard("\(L("scan.preview.fit.results.title"))\n\(text)")
    }

    private func beginFitEarPicking(in previewVC: ScenePreviewViewController, target: AnyObject?, action: Selector?) {
        previewViewModel.beginFitEarPicking()
        onToast?(L("scan.preview.fit.pick.left"))

        if fitEarPickTapGesture == nil {
            let tap = UITapGestureRecognizer(target: target, action: action)
            tap.cancelsTouchesInView = false
            previewVC.sceneView.addGestureRecognizer(tap)
            fitEarPickTapGesture = tap
        }
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

final class PreviewEarVerificationWorkflow {
    private let previewViewModel: PreviewViewModel
    private let previewOverlayUI: PreviewOverlayUIController
    private let alertPresenter: PreviewAlertPresenter

    init(
        previewViewModel: PreviewViewModel,
        previewOverlayUI: PreviewOverlayUIController,
        alertPresenter: PreviewAlertPresenter
    ) {
        self.previewViewModel = previewViewModel
        self.previewOverlayUI = previewOverlayUI
        self.alertPresenter = alertPresenter
    }

    func beginVerificationUI() {
        previewOverlayUI.verifyEarButton?.isEnabled = false
        if let button = previewOverlayUI.verifyEarButton {
            DesignSystem.updateButtonEnabled(button, style: .secondary)
        }
        previewOverlayUI.setVerifyButtonTitle(L("scan.preview.verifying"))
        previewOverlayUI.verifyEarActivityIndicator?.startAnimating()
    }

    func finishVerificationUI(title: String) {
        previewOverlayUI.verifyEarActivityIndicator?.stopAnimating()
        previewOverlayUI.verifyEarButton?.isEnabled = true
        if let button = previewOverlayUI.verifyEarButton {
            DesignSystem.updateButtonEnabled(button, style: .secondary)
        }
        previewOverlayUI.setVerifyButtonTitle(title)
    }

    func presentEarUnavailable(on previewVC: UIViewController) {
        previewVC.present(
            alertPresenter.makeAlert(
                title: L("scan.preview.earUnavailable.title"),
                message: L("scan.preview.earUnavailable.message"),
                identifier: "earUnavailableAlert"
            ),
            animated: true
        )
    }

    func performVerification(
        using service: EarLandmarksService,
        previewVC: ScenePreviewViewController,
        isCurrentSession: @escaping () -> Bool,
        onComplete: @escaping () -> Void
    ) {
        let snapshot = previewVC.renderedSceneImage ?? previewVC.sceneView.snapshot()
        let mlStart = CFAbsoluteTimeGetCurrent()
        beginVerificationUI()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            defer {
                DispatchQueue.main.async {
                    onComplete()
                }
            }

            do {
                guard let result = try service.detect(in: snapshot) else {
                    DispatchQueue.main.async {
                        guard isCurrentSession() else { return }
                        self.finishVerificationUI(title: L("scan.preview.verify"))
                        previewVC.present(
                            self.alertPresenter.makeAlert(
                                title: L("scan.preview.noEar.title"),
                                message: L("scan.preview.noEar.message"),
                                identifier: "noEarAlert"
                            ),
                            animated: true
                        )
                    }
                    return
                }

                let overlay = service.renderOverlay(
                    on: snapshot,
                    result: result,
                    drawBoundingBox: true,
                    flipY: true,
                    flipX: false
                )

                DispatchQueue.main.async {
                    guard isCurrentSession() else { return }
                    self.previewViewModel.setVerifiedEar(
                        image: snapshot,
                        result: result,
                        overlay: overlay
                    )

                    let mlElapsed = CFAbsoluteTimeGetCurrent() - mlStart
                    Log.ml.info("Ear verification completed in \(mlElapsed, privacy: .public)")
                    self.previewOverlayUI.showBadge(image: overlay)
                    self.finishVerificationUI(title: L("scan.preview.verified"))
                    self.previewOverlayUI.removeVerifyHint()

                    previewVC.present(
                        self.alertPresenter.makeAlert(
                            title: L("scan.preview.verified.alert.title"),
                            message: L("scan.preview.verified.alert.message"),
                            identifier: "earVerifiedAlert"
                        ),
                        animated: true
                    )
                    Log.ml.info("Ear verification succeeded, landmarks: \(result.landmarks.count, privacy: .public)")
                }
            } catch {
                DispatchQueue.main.async {
                    guard isCurrentSession() else { return }
                    let mlElapsed = CFAbsoluteTimeGetCurrent() - mlStart
                    Log.ml.info("Ear verification failed in \(mlElapsed, privacy: .public)")
                    self.finishVerificationUI(title: L("scan.preview.verify"))
                    previewVC.present(
                        self.alertPresenter.makeAlert(
                            title: L("scan.preview.verifyFailed.title"),
                            message: error.localizedDescription,
                            identifier: "earVerifyFailedAlert"
                        ),
                        animated: true
                    )
                    Log.ml.error("Ear verification failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
}

final class PreviewExportResultWorkflow {
    private let previewViewModel: PreviewViewModel
    private let saveExportViewState: SaveExportUIStateAdapting
    private let alertPresenter: PreviewAlertPresenter
    private let scanFlowState: ScanFlowState
    private let scanExporter: ScanExporting
    private let environment: AppEnvironment
    private let onToast: ((String) -> Void)?
    private let onExportResult: ((PreviewExportResultEvent) -> Void)?
    private let onScansChanged: (() -> Void)?
    private let previewSessionController: PreviewSessionController
    private let presentationController: PreviewPresentationController
    private let resetController: PreviewResetController
    private let exportFormatSummary: () -> String

    init(
        previewViewModel: PreviewViewModel,
        saveExportViewState: SaveExportUIStateAdapting,
        alertPresenter: PreviewAlertPresenter,
        scanFlowState: ScanFlowState,
        scanExporter: ScanExporting,
        environment: AppEnvironment,
        onToast: ((String) -> Void)?,
        onExportResult: ((PreviewExportResultEvent) -> Void)?,
        onScansChanged: (() -> Void)?,
        previewSessionController: PreviewSessionController,
        presentationController: PreviewPresentationController,
        resetController: PreviewResetController,
        exportFormatSummary: @escaping () -> String
    ) {
        self.previewViewModel = previewViewModel
        self.saveExportViewState = saveExportViewState
        self.alertPresenter = alertPresenter
        self.scanFlowState = scanFlowState
        self.scanExporter = scanExporter
        self.environment = environment
        self.onToast = onToast
        self.onExportResult = onExportResult
        self.onScansChanged = onScansChanged
        self.previewSessionController = previewSessionController
        self.presentationController = presentationController
        self.resetController = resetController
        self.exportFormatSummary = exportFormatSummary
    }

    func handleFailure(message: String, previewVC: ScenePreviewViewController) {
        previewVC.present(
            alertPresenter.makeAlert(
                title: L("scan.preview.exportFailed.title"),
                message: String(format: L("scan.preview.exportFailed.message"), message),
                identifier: "exportFailedAlert"
            ),
            animated: true
        )
        scanFlowState.setPhase(.preview)
        previewViewModel.setPhase(.preview)
        saveExportViewState.setButtonsEnabled(true)
        saveExportViewState.setMeshingStatusText(L("scan.preview.readyToSave"))
        saveExportViewState.setMeshingSpinnerActive(false)
        saveExportViewState.hideSavingToast()
        onExportResult?(.failure(message: message))
        Log.export.error("Export failed: \(message, privacy: .public)")
    }

    func handleSuccess(
        folderURL: URL,
        previewSessionID: UUID,
        exportContext: PreviewExportContext
    ) {
        let formatSummary = exportFormatSummary()
        scanExporter.setLastScanFolder(folderURL)
        onScansChanged?()
#if DEBUG
        ScanDiagnostics.recordExportArtifacts(folderURL: folderURL)
#endif

        presentationController.dismissActivePreview(animated: true) { [weak self] in
            guard let self, self.previewSessionController.isCurrentSession(previewSessionID) else { return }
            self.previewSessionController.invalidateSession()
            self.saveExportViewState.hideSavingToast()
            self.resetController.reset()
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
            self.onToast?(String(format: L("scan.preview.toast.savedWithFormats"), folderURL.lastPathComponent, formatSummary))
            if exportContext.isEarServiceUnavailable {
                self.onToast?(L("scan.preview.toast.earUnavailable"))
            }
#if DEBUG
            if self.environment.isDeviceSmokeMode {
                let diag = ScanDiagnostics.snapshot()
                self.onToast?(
                    "diag:gltf=\(diag.hasSceneGLTF ? 1 : 0),obj=\(diag.hasHeadMeshOBJ ? 1 : 0),folder=\(diag.lastExportFolderName ?? "none")"
                )
            }
#endif
            self.onExportResult?(
                .success(
                    folderName: folderURL.lastPathComponent,
                    formatSummary: formatSummary,
                    earServiceUnavailable: exportContext.isEarServiceUnavailable
                )
            )
            self.scanFlowState.setPhase(.idle)
            self.previewViewModel.setPhase(.idle)
            Log.export.info("Export succeeded: \(folderURL.lastPathComponent, privacy: .public)")
        }
    }
}

final class PreviewMeshingWorkflow {
    private let previewViewModel: PreviewViewModel
    private let saveExportViewState: SaveExportUIStateAdapting
    private let previewOverlayUI: PreviewOverlayUIController
    private let alertPresenter: PreviewAlertPresenter
    private let meshingTimeoutController = MeshingTimeoutController()
    private let meshingTimeoutSeconds: TimeInterval
    private var didShowMeshingTimeoutAlert = false

    init(
        previewViewModel: PreviewViewModel,
        saveExportViewState: SaveExportUIStateAdapting,
        previewOverlayUI: PreviewOverlayUIController,
        alertPresenter: PreviewAlertPresenter,
        meshingTimeoutSeconds: TimeInterval
    ) {
        self.previewViewModel = previewViewModel
        self.saveExportViewState = saveExportViewState
        self.previewOverlayUI = previewOverlayUI
        self.alertPresenter = alertPresenter
        self.meshingTimeoutSeconds = meshingTimeoutSeconds
    }

    func configureCallbacks(
        for previewVC: ScenePreviewViewController,
        previewSessionID: UUID,
        isCurrentPreviewSession: @escaping (UUID) -> Bool,
        onMeshReady: @escaping (SCMesh) -> Void
    ) {
        previewVC.onMeshingProgressUpdated = { [weak self] progress in
            DispatchQueue.main.async {
                guard let self, isCurrentPreviewSession(previewSessionID) else { return }
                let clamped = max(0, min(1, progress))
                let percent = Int((clamped * 100).rounded())
                let statusText = String(format: L("scan.preview.meshing.progressFormat"), clamped * 100)
                self.saveExportViewState.setMeshingStatusText(statusText)
                self.previewOverlayUI.setMeshingStatus(statusText, percent: percent, spinning: true)
            }
        }

        previewVC.onTexturedMeshGenerated = { [weak self, weak previewVC] mesh in
            DispatchQueue.main.async {
                guard let self, isCurrentPreviewSession(previewSessionID) else { return }
                self.previewViewModel.setMeshingActive(false)
                previewVC?.rightButton.isEnabled = true
                previewVC?.rightButton.alpha = 1.0
                self.saveExportViewState.setMeshingStatusText(L("scan.preview.readyToSave"))
                self.saveExportViewState.setMeshingSpinnerActive(false)
                self.previewOverlayUI.setMeshingStatus(L("scan.preview.readyToSave"), percent: nil, spinning: false)
                self.previewOverlayUI.setFitToolsAvailable(true)
                self.cancelTimeout()
                onMeshReady(mesh)
                Log.scan.info("Mesh ready for export")
            }
        }
    }

    func startTimeout(
        in previewVC: ScenePreviewViewController,
        sessionID: UUID,
        isCurrentPreviewSession: @escaping (UUID) -> Bool
    ) {
        cancelTimeout()
        didShowMeshingTimeoutAlert = false
        meshingTimeoutController.start(after: meshingTimeoutSeconds) { [weak self, weak previewVC] in
            guard let self, let previewVC else { return }
            guard isCurrentPreviewSession(sessionID) else { return }
            guard self.previewViewModel.phase == .preview else { return }
            guard self.previewViewModel.meshForExport == nil else { return }
            guard !self.didShowMeshingTimeoutAlert else { return }
            self.didShowMeshingTimeoutAlert = true
            previewVC.present(
                self.alertPresenter.makeAlert(
                    title: L("scan.preview.meshNotReady.title"),
                    message: L("scan.preview.meshNotReady.message"),
                    identifier: "meshTimeoutAlert"
                ),
                animated: true
            )
        }
    }

    func cancelTimeout() {
        meshingTimeoutController.cancel()
    }

    func reset() {
        cancelTimeout()
        didShowMeshingTimeoutAlert = false
    }
}

final class PreviewMeasurementWorkflow {
    private let measurementService: LocalMeasurementGenerationService
    private let previewViewModel: PreviewViewModel
    private let renderDerivedMeasurements: () -> Void

    init(
        measurementService: LocalMeasurementGenerationService,
        previewViewModel: PreviewViewModel,
        renderDerivedMeasurements: @escaping () -> Void
    ) {
        self.measurementService = measurementService
        self.previewViewModel = previewViewModel
        self.renderDerivedMeasurements = renderDerivedMeasurements
    }

    func generate(
        from pointCloud: SCPointCloud,
        previewSessionID: UUID,
        isCurrentPreviewSession: @escaping (UUID) -> Bool
    ) {
        measurementService.generate(
            from: pointCloud,
            progress: { progress in
                Log.scan.debug("Measurement generation progress: \(progress, privacy: .public)")
            },
            completion: { [weak self] result in
                guard let self, isCurrentPreviewSession(previewSessionID) else { return }
                switch result {
                case .success(let summary):
                    self.previewViewModel.setMeasurementSummary(summary)
                    Log.scan.info("Derived measurements ready. Circumference: \(summary.circumferenceMm, privacy: .public) mm")
                    self.renderDerivedMeasurements()
                case .failure(let error):
                    self.previewViewModel.setMeasurementSummary(nil)
                    Log.scan.error("Measurement generation failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        )
    }
}
