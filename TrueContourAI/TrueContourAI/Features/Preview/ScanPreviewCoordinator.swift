import UIKit
import StandardCyborgUI
import StandardCyborgFusion

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
        previewVC: ScenePreviewViewController,
        meshingStatusLabel: UILabel?,
        meshingActivityIndicator: UIActivityIndicatorView?
    )
    func setButtonsEnabled(_ isEnabled: Bool)
    func setMeshingStatusText(_ text: String)
    func setMeshingSpinnerActive(_ isActive: Bool)
    func showSavingToast()
    func hideSavingToast()
    func clear()
}

final class ScanPreviewCoordinator {
    enum ExportResultEvent: Equatable {
        case success(folderName: String, formatSummary: String, earServiceUnavailable: Bool)
        case failure(message: String)
    }

    private enum SavePrecheckResult: Equatable {
        case blockedByQualityGate
        case noExportFormatsEnabled
        case meshNotReady
        case ready
    }

    private weak var presenter: UIViewController?
    private let scanService: ScanService
    private let scanExporter: ScanExporting
    private let settingsStore: SettingsStore
    private let scanFlowState: ScanFlowState
    private var previewViewModel = PreviewViewModel()
    private let onToast: ((String) -> Void)?
    private let onExportResult: ((ExportResultEvent) -> Void)?
    private let earServiceFactory: () -> EarLandmarksService?

    var onScansChanged: (() -> Void)?

    private lazy var earService: EarLandmarksService? = {
        let service = earServiceFactory()
        if service == nil {
            Log.ml.error("EarLandmarksService init failed (non-fatal)")
        }
        return service
    }()

    private weak var scenePreviewVC: ScenePreviewViewController?
    private var previewContainerVC: PreviewContainerViewController?
    private weak var activePreviewVC: UIViewController?

    private weak var meshingStatusLabel: UILabel?
    private weak var meshingActivityIndicator: UIActivityIndicatorView?
    private let saveExportViewState: SaveExportUIStateAdapting
    private let previewOverlayUI = PreviewOverlayUIController()
    private let alertPresenter = PreviewAlertPresenter()
    private let buttonConfigurator = PreviewButtonConfigurator()
    private let measurementService = LocalMeasurementGenerationService()
    private var isVerifyingEar = false
    private let meshingTimeoutController = MeshingTimeoutController()
    private var didShowMeshingTimeoutAlert = false
    private let meshingTimeoutSeconds: TimeInterval = 25
    private var latestSessionMetrics: ScanFlowState.ScanSessionMetrics?
    private var latestQualityReport: ScanQualityReport?
    private var latestMeasurementSummary: LocalMeasurementGenerationService.ResultSummary?

    init(
        presenter: UIViewController,
        scanService: ScanService,
        settingsStore: SettingsStore,
        scanFlowState: ScanFlowState,
        scanExporter: ScanExporting? = nil,
        saveExportViewState: SaveExportUIStateAdapting = SaveExportViewStateController(),
        earServiceFactory: @escaping () -> EarLandmarksService? = {
            do { return try EarLandmarksService() }
            catch { return nil }
        },
        onToast: ((String) -> Void)? = nil,
        onExportResult: ((ExportResultEvent) -> Void)? = nil
    ) {
        self.presenter = presenter
        self.scanService = scanService
        self.scanExporter = scanExporter ?? scanService
        self.settingsStore = settingsStore
        self.scanFlowState = scanFlowState
        self.saveExportViewState = saveExportViewState
        self.earServiceFactory = earServiceFactory
        self.onToast = onToast
        self.onExportResult = onExportResult
    }

    func presentExistingScan(_ item: ScanService.ScanItem) {
        guard let presenter else { return }
        let skipGLTF = ProcessInfo.processInfo.arguments.contains("ui-test-skip-gltf")
        let existingSummary = scanService.resolveScanSummary(from: item.folderURL)
        if skipGLTF {
            Log.ui.info("Presenting test preview for scan: \(item.displayName, privacy: .public)")
            presentTestPreview(for: item, presenter: presenter)
            return
        }

        guard let scene = scanService.sceneForScan(item) else {
            Log.ui.error("Missing scene.gltf for scan: \(item.displayName, privacy: .public)")
            alertPresenter.presentAlert(
                on: presenter,
                title: L("scan.preview.missingScene.title"),
                message: L("scan.preview.missingScene.message"),
                identifier: "missingSceneAlert"
            )
            return
        }

        scanFlowState.setPhase(.preview)
        previewViewModel.setPhase(.preview)

        let vc = ScenePreviewViewController(scScene: scene)
        vc.view.backgroundColor = DesignSystem.Colors.background
        vc.sceneView.backgroundColor = DesignSystem.Colors.background

        buttonConfigurator.configureButtons(for: vc, mode: .existingScan)
        vc.leftButton.addTarget(self, action: #selector(dismissPreviewTapped), for: .touchUpInside)
        vc.rightButton.addTarget(self, action: #selector(shareOpenedScanTapped), for: .touchUpInside)

        scanFlowState.currentlyPreviewedFolderURL = item.folderURL

        vc.modalPresentationStyle = .fullScreen
        scenePreviewVC = vc
        activePreviewVC = vc
        presenter.present(vc, animated: true) { [weak self, weak vc] in
            guard let self, let vc else { return }
            if let derived = existingSummary?.derivedMeasurements {
                self.previewOverlayUI.addOrUpdateDerivedMeasurements(
                    to: vc.view,
                    circumferenceMm: derived.circumferenceMm,
                    widthMm: derived.widthMm,
                    depthMm: derived.depthMm,
                    confidence: derived.confidence
                )
            }
        }
        Log.ui.info("Presented existing scan preview: \(item.displayName, privacy: .public)")
    }

    private func presentTestPreview(for item: ScanService.ScanItem, presenter: UIViewController) {
        scanFlowState.setPhase(.preview)
        previewViewModel.setPhase(.preview)
        scanFlowState.currentlyPreviewedFolderURL = item.folderURL

        let vc = UIViewController()
        vc.view.backgroundColor = DesignSystem.Colors.background

        let closeButton = UIButton(type: .system)
        let shareButton = UIButton(type: .system)
        DesignSystem.applyButton(closeButton, title: L("common.close"), style: .secondary, size: .regular)
        DesignSystem.applyButton(shareButton, title: L("common.share"), style: .secondary, size: .regular)
        closeButton.accessibilityIdentifier = "previewCloseButton"
        shareButton.accessibilityIdentifier = "previewShareButton"
        closeButton.addTarget(self, action: #selector(dismissPreviewTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareOpenedScanTapped), for: .touchUpInside)

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
        scenePreviewVC = nil
        previewContainerVC = nil
        activePreviewVC = vc
        presenter.present(vc, animated: true)
    }

    func presentPreviewAfterScan(
        from scanningVC: UIViewController,
        pointCloud: SCPointCloud,
        meshTexturing: SCMeshTexturing,
        sessionMetrics: ScanFlowState.ScanSessionMetrics?
    ) {
        guard let presenter else { return }

        Log.scan.info("Presenting preview after scan")
        latestSessionMetrics = sessionMetrics
        latestMeasurementSummary = nil
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
        latestQualityReport = qualityReport
        Log.scanning.info(
            """
            Scan quality report: raw=\(qualityReport.pointCount, privacy: .public) \
            valid=\(qualityReport.validPointCount, privacy: .public) \
            bounds=\(qualityReport.widthMeters, privacy: .public)x\(qualityReport.heightMeters, privacy: .public)x\(qualityReport.depthMeters, privacy: .public) \
            score=\(qualityReport.qualityScore, privacy: .public) \
            exportable=\(qualityReport.isExportRecommended, privacy: .public)
            """
        )
        let quality = previewViewModel.evaluateScanQuality(pointCount: qualityReport.validPointCount)
        previewViewModel.setScanQuality(quality)
        scanFlowState.setPhase(.preview)
        previewViewModel.setPhase(.preview)

        let vc = ScenePreviewViewController(
            pointCloud: pointCloud,
            meshTexturing: meshTexturing,
            landmarks: nil
        )
        vc.view.backgroundColor = DesignSystem.Colors.background
        vc.sceneView.backgroundColor = DesignSystem.Colors.background

        previewViewModel.clearVerification()
        previewOverlayUI.clear()

        buttonConfigurator.configureButtons(for: vc, mode: .newScan)

        vc.leftButton.addTarget(self, action: #selector(dismissPreviewTapped), for: .touchUpInside)
        vc.rightButton.addTarget(self, action: #selector(saveFromPreviewTapped), for: .touchUpInside)
        vc.leftButton.accessibilityIdentifier = "previewCloseButton"
        vc.rightButton.accessibilityIdentifier = "previewSaveButton"

        previewViewModel.setMeshForExport(nil)
        vc.rightButton.isEnabled = false
        DesignSystem.updateButtonEnabled(vc.rightButton, style: .primary)
        addMeshingStatusLabel(to: vc)
        startMeshingTimeout(in: vc)
        saveExportViewState.configure(
            previewVC: vc,
            meshingStatusLabel: meshingStatusLabel,
            meshingActivityIndicator: meshingActivityIndicator
        )

        vc.onTexturedMeshGenerated = { [weak self, weak vc] mesh in
            DispatchQueue.main.async {
                self?.previewViewModel.setMeshForExport(mesh)
                vc?.rightButton.isEnabled = true
                vc?.rightButton.alpha = 1.0
                self?.saveExportViewState.setMeshingStatusText(L("scan.preview.readyToSave"))
                self?.saveExportViewState.setMeshingSpinnerActive(false)
                self?.cancelMeshingTimeout()
                Log.scan.info("Mesh ready for export")
            }
        }

        measurementService.generate(
            from: pointCloud,
            progress: { progress in
                Log.scan.debug("Measurement generation progress: \(progress, privacy: .public)")
            },
            completion: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let summary):
                    self.latestMeasurementSummary = summary
                    Log.scan.info("Derived measurements ready. Circumference: \(summary.circumferenceMm, privacy: .public) mm")
                    self.renderDerivedMeasurementsIfAvailable()
                case .failure(let error):
                    self.latestMeasurementSummary = nil
                    Log.scan.error("Measurement generation failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        )

        let container = PreviewContainerViewController(contentViewController: vc)
        scenePreviewVC = vc
        previewContainerVC = container
        activePreviewVC = container
        scanningVC.dismiss(animated: false) { [weak self] in
            presenter.present(container, animated: true) { [weak self] in
                guard let self else { return }
                self.addVerifyEarUI(to: vc)
                if let quality = self.previewViewModel.scanQuality {
                    self.addScanQualityLabel(to: vc, quality: quality)
                }
                self.renderDerivedMeasurementsIfAvailable()
            }
        }
    }

    // MARK: - Actions

    @objc private func dismissPreviewTapped() {
        Log.ui.info("Dismissed preview")
        removeVerifyEarUI()
        cancelMeshingTimeout()
        scanFlowState.setPhase(.idle)
        previewViewModel.setPhase(.idle)
        scanFlowState.currentlyPreviewedFolderURL = nil
        activePreviewVC = nil
        previewContainerVC = nil
        scenePreviewVC = nil
        dismissActivePreview(animated: true)
    }

    @objc private func shareOpenedScanTapped() {
        guard let presenter else { return }
        let presentingVC = activePreviewVC ?? presenter
        let forceMissing = ProcessInfo.processInfo.arguments.contains("ui-test-force-missing-folder")
        guard let folder = forceMissing ? nil : (scanFlowState.currentlyPreviewedFolderURL ?? scanService.resolveLastScanFolderURL()) else {
            alertPresenter.presentAlert(
                on: presentingVC,
                title: L("scan.preview.missingFolder.title"),
                message: L("scan.preview.missingFolder.message"),
                identifier: "missingFolderAlert"
            )
            return
        }
        let source: UIView? = scenePreviewVC?.rightButton
        let av = UIActivityViewController(activityItems: scanService.shareItems(for: folder), applicationActivities: nil)
        if let pop = av.popoverPresentationController {
            let src = source ?? presenter.view
            pop.sourceView = src
            pop.sourceRect = src?.bounds ?? .zero
        }
        presentingVC.present(av, animated: true)
    }

    @objc private func verifyEarTapped() {
        guard let previewVC = scenePreviewVC else { return }
        guard !isVerifyingEar else { return }
        guard let svc = earService else {
            previewVC.present(
                alertPresenter.makeAlert(
                    title: L("scan.preview.earUnavailable.title"),
                    message: L("scan.preview.earUnavailable.message"),
                    identifier: "earUnavailableAlert"
                ),
                animated: true
            )
            return
        }

        Log.ml.info("User requested ear verification")
        DesignSystem.hapticPrimary()
        let snapshot = previewVC.renderedSceneImage ?? previewVC.sceneView.snapshot()

        let mlStart = CFAbsoluteTimeGetCurrent()
        isVerifyingEar = true
        previewOverlayUI.verifyEarButton?.isEnabled = false
        if let button = previewOverlayUI.verifyEarButton {
            DesignSystem.updateButtonEnabled(button, style: .secondary)
        }
        previewOverlayUI.setVerifyButtonTitle(L("scan.preview.verifying"))
        previewOverlayUI.verifyEarActivityIndicator?.startAnimating()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                guard let result = try svc.detect(in: snapshot) else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.finishVerifyEarUI(title: L("scan.preview.verify"))
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

                let overlay = svc.renderOverlay(
                    on: snapshot,
                    result: result,
                    drawBoundingBox: true,
                    flipY: true,
                    flipX: false
                )

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.previewViewModel.setVerifiedEar(
                        image: snapshot,
                        result: result,
                        overlay: overlay
                    )

                    let mlElapsed = CFAbsoluteTimeGetCurrent() - mlStart
                    Log.ml.info("Ear verification completed in \(mlElapsed, privacy: .public)s")
                    self.previewOverlayUI.showBadge(image: overlay)

                    self.finishVerifyEarUI(title: L("scan.preview.verified"))
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
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let mlElapsed = CFAbsoluteTimeGetCurrent() - mlStart
                    Log.ml.info("Ear verification failed in \(mlElapsed, privacy: .public)s")
                    self.finishVerifyEarUI(title: L("scan.preview.verify"))
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

    @objc private func saveFromPreviewTapped() {
        guard let previewVC = scenePreviewVC else { return }
        DesignSystem.hapticPrimary()

        let precheck = savePrecheck(qualityReport: latestQualityReport, meshAvailable: previewViewModel.meshForExport != nil)
        if precheck == .blockedByQualityGate, let qualityReport = latestQualityReport {
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
            saveExportViewState.setMeshingStatusText(L("scan.preview.qualityNeedsAttention"))
            Log.export.error("Export blocked by quality gate: \(qualityReport.reason, privacy: .public)")
            return
        }
        if precheck == .noExportFormatsEnabled {
            previewVC.present(
                alertPresenter.makeAlert(
                    title: L("settings.export.minimum.title"),
                    message: L("settings.export.minimum.message"),
                    identifier: "exportFormatsDisabledAlert"
                ),
                animated: true
            )
            Log.export.error("Export blocked: no export formats enabled")
            return
        }

        scanFlowState.setPhase(.saving)
        previewViewModel.setPhase(.saving)
        saveExportViewState.setButtonsEnabled(false)
        saveExportViewState.setMeshingStatusText(L("scan.preview.exporting"))
        saveExportViewState.setMeshingSpinnerActive(true)
        saveExportViewState.showSavingToast()
        Log.export.info("User requested export")
        guard precheck != .meshNotReady, let mesh = previewViewModel.meshForExport else {
            previewVC.present(
                alertPresenter.makeAlert(
                    title: L("scan.preview.meshNotReady.title"),
                    message: L("scan.preview.meshNotReady.message"),
                    identifier: "meshNotReadyAlert"
                ),
                animated: true
            )
            scanFlowState.setPhase(.preview)
            previewViewModel.setPhase(.preview)
            saveExportViewState.setButtonsEnabled(true)
            saveExportViewState.setMeshingStatusText(L("scan.preview.readyToSave"))
            saveExportViewState.setMeshingSpinnerActive(false)
            saveExportViewState.hideSavingToast()
            Log.export.error("Export blocked: mesh not ready")
            return
        }

        let artifacts: ScanService.EarArtifacts?
        if let earImage = previewViewModel.verifiedEarImage,
           let earResult = previewViewModel.verifiedEarResult,
           let earOverlay = previewViewModel.verifiedEarOverlay {
            artifacts = .init(earImage: earImage, earResult: earResult, earOverlay: earOverlay)
        } else {
            artifacts = nil
        }

        let isEarServiceUnavailable = (earService == nil && artifacts == nil)
        let scene = previewVC.scScene
        let thumbnail = previewVC.renderedSceneImage
        let includeGLTF = settingsStore.exportGLTF
        let includeOBJ = settingsStore.exportOBJ
        let scanSummary = ScanSummaryBuilder.build(
            settingsStore: settingsStore,
            metrics: latestSessionMetrics,
            qualityReport: latestQualityReport,
            measurementSummary: latestMeasurementSummary,
            hadEarVerification: artifacts != nil
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let exportStart = CFAbsoluteTimeGetCurrent()
            let exportResult = self.scanExporter.exportScanFolder(
            mesh: mesh,
            scene: scene,
            thumbnail: thumbnail,
            earArtifacts: artifacts,
            scanSummary: scanSummary,
            includeGLTF: includeGLTF,
            includeOBJ: includeOBJ
        )

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let exportElapsed = CFAbsoluteTimeGetCurrent() - exportStart
                Log.export.info("Export completed in \(exportElapsed, privacy: .public)s")
                switch exportResult {
                case .failure(let msg):
                    previewVC.present(
                        alertPresenter.makeAlert(
                            title: L("scan.preview.exportFailed.title"),
                            message: String(format: L("scan.preview.exportFailed.message"), msg),
                            identifier: "exportFailedAlert"
                        ),
                        animated: true
                    )
                    self.scanFlowState.setPhase(.preview)
                    self.previewViewModel.setPhase(.preview)
                    self.saveExportViewState.setButtonsEnabled(true)
                    self.saveExportViewState.setMeshingStatusText(L("scan.preview.readyToSave"))
                    self.saveExportViewState.setMeshingSpinnerActive(false)
                    self.saveExportViewState.hideSavingToast()
                    self.onExportResult?(.failure(message: msg))
                    Log.export.error("Export failed: \(msg, privacy: .public)")

                case .success(let folderURL):
                    let formatSummary = self.exportFormatSummary(includeGLTF: includeGLTF, includeOBJ: includeOBJ)
                    self.scanExporter.setLastScanFolder(folderURL)
                    self.onScansChanged?()
#if DEBUG
                    ScanDiagnostics.recordExportArtifacts(folderURL: folderURL)
#endif

                    self.dismissActivePreview(animated: true) { [weak self] in
                        guard let self else { return }
                        self.saveExportViewState.hideSavingToast()
                        self.removeVerifyEarUI()
                        self.scanFlowState.currentlyPreviewedFolderURL = nil
                        self.activePreviewVC = nil
                        self.previewContainerVC = nil
                        self.scenePreviewVC = nil
                        let feedback = UINotificationFeedbackGenerator()
                        feedback.notificationOccurred(.success)
                        self.onToast?(String(format: L("scan.preview.toast.savedWithFormats"), folderURL.lastPathComponent, formatSummary))
                        if isEarServiceUnavailable {
                            self.onToast?(L("scan.preview.toast.earUnavailable"))
                        }
#if DEBUG
                        if ProcessInfo.processInfo.arguments.contains("ui-test-device-smoke") {
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
                                earServiceUnavailable: isEarServiceUnavailable
                            )
                        )
                        self.scanFlowState.setPhase(.idle)
                        self.previewViewModel.setPhase(.idle)
                        Log.export.info("Export succeeded: \(folderURL.lastPathComponent, privacy: .public)")
                    }
                }
            }
        }
    }

    private func savePrecheck(qualityReport: ScanQualityReport?, meshAvailable: Bool) -> SavePrecheckResult {
        if let qualityReport, !qualityReport.isExportRecommended {
            return .blockedByQualityGate
        }
        if !settingsStore.hasAnyExportFormatEnabled {
            return .noExportFormatsEnabled
        }
        if !meshAvailable {
            return .meshNotReady
        }
        return .ready
    }

    private func renderDerivedMeasurementsIfAvailable() {
        guard let summary = latestMeasurementSummary else { return }
        guard let hostView = previewContainerVC?.overlayView ?? scenePreviewVC?.view else { return }
        previewOverlayUI.addOrUpdateDerivedMeasurements(
            to: hostView,
            circumferenceMm: summary.circumferenceMm,
            widthMm: summary.widthMm,
            depthMm: summary.depthMm,
            confidence: summary.confidence
        )
    }

    private func exportFormatSummary(includeGLTF: Bool, includeOBJ: Bool) -> String {
        var formats: [String] = []
        if includeGLTF { formats.append(L("scan.preview.exportFormat.gltf")) }
        if includeOBJ { formats.append(L("scan.preview.exportFormat.obj")) }
        if formats.isEmpty { return L("scan.preview.exportFormat.none") }
        return formats.joined(separator: ", ")
    }

    // MARK: - Preview UI

    private func addVerifyEarUI(to previewVC: ScenePreviewViewController) {
        guard let hostView = previewContainerVC?.overlayView ?? previewVC.view else { return }
        previewContainerVC?.bringOverlayToFront()
        let button = previewOverlayUI.addVerifyEarUI(to: hostView, showHint: settingsStore.showVerifyEarHint)
        button.addTarget(self, action: #selector(verifyEarTapped), for: .touchUpInside)
    }

    private func addMeshingStatusLabel(to previewVC: ScenePreviewViewController) {
        if meshingStatusLabel != nil { return }
        guard let hostView = previewVC.view else { return }

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = DesignSystem.Colors.textSecondary
        label.font = DesignSystem.Typography.caption()
        label.adjustsFontForContentSizeCategory = true
        label.text = L("scan.preview.meshing")
        label.accessibilityLabel = L("scan.preview.meshing.accessibility")
        label.accessibilityIdentifier = "meshingStatusLabel"

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = DesignSystem.Colors.textPrimary
        spinner.hidesWhenStopped = true

        hostView.addSubview(label)
        hostView.addSubview(spinner)
        NSLayoutConstraint.activate([
            label.bottomAnchor.constraint(equalTo: previewVC.rightButton.topAnchor, constant: -8),
            label.trailingAnchor.constraint(equalTo: previewVC.rightButton.trailingAnchor),

            spinner.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            spinner.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 6)
        ])

        meshingStatusLabel = label
        meshingActivityIndicator = spinner
        saveExportViewState.setMeshingSpinnerActive(true)
        saveExportViewState.configure(
            previewVC: previewVC,
            meshingStatusLabel: label,
            meshingActivityIndicator: spinner
        )
    }

    private func startMeshingTimeout(in previewVC: ScenePreviewViewController) {
        cancelMeshingTimeout()
        didShowMeshingTimeoutAlert = false
        meshingTimeoutController.start(after: meshingTimeoutSeconds) { [weak self, weak previewVC] in
            guard let self, let previewVC else { return }
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

    private func cancelMeshingTimeout() {
        meshingTimeoutController.cancel()
    }

    private func addScanQualityLabel(to previewVC: ScenePreviewViewController, quality: ScanQuality) {
        guard let hostView = previewContainerVC?.overlayView ?? previewVC.view else { return }
        previewOverlayUI.addScanQualityLabel(
            to: hostView,
            quality: quality,
            anchor: previewOverlayUI.verifyEarButton
        )
    }

    private func removeVerifyEarUI() {
        previewOverlayUI.clear()
        isVerifyingEar = false
        previewViewModel.clearVerification()
        meshingStatusLabel?.removeFromSuperview()
        meshingStatusLabel = nil
        meshingActivityIndicator?.removeFromSuperview()
        meshingActivityIndicator = nil
        saveExportViewState.clear()
        cancelMeshingTimeout()
        didShowMeshingTimeoutAlert = false
    }

    private func dismissActivePreview(animated: Bool, completion: (() -> Void)? = nil) {
        if let activePreviewVC, activePreviewVC.presentingViewController != nil {
            activePreviewVC.dismiss(animated: animated, completion: completion)
            return
        }

        if let presenter, presenter.presentedViewController != nil {
            presenter.dismiss(animated: animated, completion: completion)
            return
        }

        completion?()
    }

    private func finishVerifyEarUI(title: String) {
        isVerifyingEar = false
        previewOverlayUI.verifyEarActivityIndicator?.stopAnimating()
        previewOverlayUI.verifyEarButton?.isEnabled = true
        if let button = previewOverlayUI.verifyEarButton {
            DesignSystem.updateButtonEnabled(button, style: .secondary)
        }
        previewOverlayUI.setVerifyButtonTitle(title)
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
        switch result {
        case .failure(let message):
            onExportResult?(.failure(message: message))
            scanFlowState.setPhase(.preview)
        case .success(let folderURL):
            scanExporter.setLastScanFolder(folderURL)
            onScansChanged?()
            let formatSummary = exportFormatSummary(includeGLTF: settingsStore.exportGLTF, includeOBJ: settingsStore.exportOBJ)
            onToast?(String(format: L("scan.preview.toast.savedWithFormats"), folderURL.lastPathComponent, formatSummary))
            if isEarServiceUnavailable {
                onToast?(L("scan.preview.toast.earUnavailable"))
            }
            onExportResult?(
                .success(
                    folderName: folderURL.lastPathComponent,
                    formatSummary: formatSummary,
                    earServiceUnavailable: isEarServiceUnavailable
                )
            )
            scanFlowState.setPhase(.idle)
        }
    }

    func debug_savePrecheck(qualityReport: ScanQualityReport?, hasMesh: Bool) -> String {
        switch savePrecheck(qualityReport: qualityReport, meshAvailable: hasMesh) {
        case .blockedByQualityGate:
            return "blockedByQualityGate"
        case .noExportFormatsEnabled:
            return "noExportFormatsEnabled"
        case .meshNotReady:
            return "meshNotReady"
        case .ready:
            return "ready"
        }
    }
    #endif
}
