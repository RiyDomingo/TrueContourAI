import UIKit
import StandardCyborgUI
import StandardCyborgFusion
import SceneKit
import simd

enum PreviewQoSQueues {
    static let export = DispatchQueue(
        label: "com.truecontour.preview.export",
        qos: .userInitiated
    )

    static let earVerification = DispatchQueue(
        label: "com.truecontour.preview.earVerification",
        qos: .userInitiated
    )

    static let existingScanLoad = DispatchQueue(
        label: "com.truecontour.preview.existingScanLoad",
        qos: .userInitiated
    )
}

protocol PreviewScanReading: ScanSummaryReading, LastScanReading, ScanFolderSharing {
    var scansRootURL: URL { get }
    func sceneForScan(_ item: ScanItem) -> SCScene?
    func resolveEarVerificationImage(from folder: URL) -> UIImage?
    func resolveLastScanFolderURL() -> URL?
}

extension ScanRepository: PreviewScanReading {}

final class PreviewPostScanWorkflow {
    private let settingsStore: SettingsStore
    private let previewViewModel: PreviewStore
    private let scanFlowState: ScanFlowState

    init(
        settingsStore: SettingsStore,
        previewViewModel: PreviewStore,
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

}

struct PreviewPostScanPresentationContext {
    let previewVC: ScenePreviewViewController
    let container: PreviewViewController
    let buttonActionTarget: PreviewButtonActionTarget
}

final class PreviewButtonActionTarget: NSObject {
    private let onLeftTap: () -> Void
    private let onRightTap: () -> Void

    init(
        onLeftTap: @escaping () -> Void,
        onRightTap: @escaping () -> Void
    ) {
        self.onLeftTap = onLeftTap
        self.onRightTap = onRightTap
    }

    @objc
    func leftTapped() {
        onLeftTap()
    }

    @objc
    func rightTapped() {
        onRightTap()
    }
}

final class PreviewExistingScanWorkflow {
    struct PresentationData {
        let summary: ScanSummary?
        let scene: SCScene?
        let preservedEarVerificationImage: UIImage?
    }

    private let scanReader: PreviewScanReading
    private let previewViewModel: PreviewStore
    private let scanFlowState: ScanFlowState
    private let previewSessionController: PreviewSessionController
    private let presentationWorkflow: PreviewPresentationWorkflow
    private let alertPresenter: PreviewAlertPresenter
    private let overlayWorkflow: PreviewOverlayWorkflow

    init(
        scanReader: PreviewScanReading,
        previewViewModel: PreviewStore,
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

    func loadPresentationData(
        item: ScanItem,
        skipGLTF: Bool
    ) -> PresentationData {
        let loadStart = CFAbsoluteTimeGetCurrent()

        let summaryLoadStart = CFAbsoluteTimeGetCurrent()
        let summary = scanReader.resolveScanSummary(from: item.folderURL)
        let summaryLoadMs = Int((CFAbsoluteTimeGetCurrent() - summaryLoadStart) * 1000)

        var scene: SCScene?
        var sceneLoadMs: Int?
        if !skipGLTF {
            let sceneLoadStart = CFAbsoluteTimeGetCurrent()
            scene = scanReader.sceneForScan(item)
            sceneLoadMs = Int((CFAbsoluteTimeGetCurrent() - sceneLoadStart) * 1000)
        }

        let earImageLoadStart = CFAbsoluteTimeGetCurrent()
        let preservedEarVerificationImage = scanReader.resolveEarVerificationImage(from: item.folderURL)
        let earImageLoadMs = Int((CFAbsoluteTimeGetCurrent() - earImageLoadStart) * 1000)

#if DEBUG
        ScanDiagnostics.recordExistingPreviewLoadTimings(
            .init(
                totalMs: Int((CFAbsoluteTimeGetCurrent() - loadStart) * 1000),
                summaryLoadMs: summaryLoadMs,
                sceneLoadMs: sceneLoadMs,
                earImageLoadMs: earImageLoadMs,
                skipsGLTF: skipGLTF
            )
        )
#endif

        return PresentationData(
            summary: summary,
            scene: scene,
            preservedEarVerificationImage: preservedEarVerificationImage
        )
    }

    func makePresentation(
        item: ScanItem,
        presenter: UIViewController,
        skipGLTF: Bool,
        presentationData: PresentationData,
        closeTarget: AnyObject,
        shareTarget: AnyObject,
        onClose: Selector,
        onShare: Selector
    ) -> (UIViewController, ScenePreviewViewController?, ScanSummary?)? {
        let existingSummary = presentationData.summary
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

        guard let scene = presentationData.scene else {
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
        configureSceneUI: (ScenePreviewViewController) -> Void
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
        configureSceneUI(previewVC)
    }

    func resolveEarVerificationImage(for item: ScanItem) -> UIImage? {
        scanReader.resolveEarVerificationImage(from: item.folderURL)
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

final class PreviewFitWorkflow {
    private let previewViewModel: PreviewStore
    private let previewOverlayUI: PreviewOverlayUIController
    private let alertPresenter: PreviewAlertPresenter
    private let settingsStore: SettingsStore
    private let scanReader: PreviewScanReading
    private let fitModelPackService = FitModelPackService()
    private let useCase: PreviewFitUseCase
    private let onToast: ((String) -> Void)?

    private var fitEarPickTapGesture: UITapGestureRecognizer?

    init(
        previewViewModel: PreviewStore,
        previewOverlayUI: PreviewOverlayUIController,
        alertPresenter: PreviewAlertPresenter,
        settingsStore: SettingsStore,
        scanReader: PreviewScanReading,
        useCase: PreviewFitUseCase,
        onToast: ((String) -> Void)?
    ) {
        self.previewViewModel = previewViewModel
        self.previewOverlayUI = previewOverlayUI
        self.alertPresenter = alertPresenter
        self.settingsStore = settingsStore
        self.scanReader = scanReader
        self.useCase = useCase
        self.onToast = onToast
    }

    func configureIfNeeded(
        previewVC: ScenePreviewViewController,
        previewContainerVC: PreviewViewController?
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

        switch useCase.runFit(
            mesh: previewViewModel.meshForExport,
            folderURL: currentPreviewedFolderURL,
            manualEarLeftMeters: previewViewModel.manualEarLeftMeters,
            manualEarRightMeters: previewViewModel.manualEarRightMeters,
            browPlaneDropFromTopFraction: previewViewModel.browPlaneDropFromTopFraction
        ) {
        case .success(let output):
            previewViewModel.setFitMeshData(output.1)
            previewViewModel.send(.fitCompleted(.success(output.0)))
            if let fitCheckResult = output.0.fitCheckResult {
                updateFitResultsCard(summaryText: output.0.summaryText, result: fitCheckResult)
            }
            guard let result = output.0.fitCheckResult else { return }
            if allowEarPickPrompt,
               result.fitData.ear_left_xyz_mm == nil || result.fitData.ear_right_xyz_mm == nil {
                beginFitEarPicking(in: previewVC, target: fitEarPickTarget, action: fitEarPickAction)
            }
        case .failure(let failure):
            previewViewModel.send(.fitCompleted(.failure(failure)))
            previewVC.present(
                alertPresenter.makeAlert(
                    title: L("scan.preview.fit.unavailable.title"),
                    message: failureMessage(from: failure),
                    identifier: "fitUnavailableAlert"
                ),
                animated: true
            )
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
            previewViewModel.send(.fitEarPointSelected(point))
            onToast?(L("scan.preview.fit.pick.right"))
        case .pickRight:
            previewViewModel.send(.fitEarPointSelected(point))
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

    private func updateFitResultsCard(summaryText: String, result _: FitModelCheckResult) {
        previewOverlayUI.updateFitResultsCard("\(L("scan.preview.fit.results.title"))\n\(summaryText)")
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

    private func failureMessage(from failure: PreviewFailure) -> String {
        switch failure {
        case .fitFailed(let message):
            return message
        case .exportFailed(let message), .loadFailed(let message), .verificationFailed(let message):
            return message
        }
    }
}

final class PreviewEarVerificationWorkflow {
    private let previewViewModel: PreviewStore
    private let previewOverlayUI: PreviewOverlayUIController
    private let alertPresenter: PreviewAlertPresenter
    private let sceneAdapter: PreviewSceneAdapter
    private let useCase: PreviewEarVerificationUseCase

    init(
        previewViewModel: PreviewStore,
        previewOverlayUI: PreviewOverlayUIController,
        alertPresenter: PreviewAlertPresenter,
        sceneAdapter: PreviewSceneAdapter,
        useCase: PreviewEarVerificationUseCase
    ) {
        self.previewViewModel = previewViewModel
        self.previewOverlayUI = previewOverlayUI
        self.alertPresenter = alertPresenter
        self.sceneAdapter = sceneAdapter
        self.useCase = useCase
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
        let previewSnapshot = sceneAdapter.makeSceneSnapshot(from: previewVC).renderedImage ?? UIImage()
        let verificationImage = previewViewModel.preservedEarVerificationImage ?? previewSnapshot
        let verificationSource: PreviewStore.EarVerificationImageSource =
            previewViewModel.preservedEarVerificationSelectionMetadata.map {
                switch $0.source {
                case .bestCaptureFrame:
                    return .bestCaptureFrame
                case .latestCaptureFallback:
                    return .latestCaptureFallback
                }
            } ?? (previewViewModel.preservedEarVerificationImage != nil ? .latestCaptureFallback : .previewSnapshotFallback)
        let mlStart = CFAbsoluteTimeGetCurrent()
        beginVerificationUI()

        useCase.verify(
            service: service,
            verificationImage: verificationImage,
            source: verificationSource,
            selectionMetadata: previewViewModel.preservedEarVerificationSelectionMetadata
        ) { [weak self] result in
            guard let self else { return }
            defer { onComplete() }
            guard isCurrentSession() else { return }

            switch result {
            case .success(let verification):
                self.previewViewModel.setEarVerificationImageSource(verificationSource)
                self.previewViewModel.send(.earVerificationCompleted(.success(verification)))

                let mlElapsed = CFAbsoluteTimeGetCurrent() - mlStart
                Log.ml.info("Ear verification completed in \(mlElapsed, privacy: .public)")
                self.previewOverlayUI.showBadge(image: verification.earOverlay)
                self.finishVerificationUI(title: L("scan.preview.verified"))
                self.previewOverlayUI.removeVerifyHint()
                Log.ml.info("Ear verification succeeded, landmarks: \(verification.earResult.landmarks.count, privacy: .public)")
            case .failure(let failure):
                let mlElapsed = CFAbsoluteTimeGetCurrent() - mlStart
                Log.ml.info("Ear verification failed in \(mlElapsed, privacy: .public)")
                self.finishVerificationUI(title: L("scan.preview.verify"))
                if case .verificationFailed(let message) = failure,
                   message == L("scan.preview.noEar.message") {
                    previewVC.present(
                        self.alertPresenter.makeAlert(
                            title: L("scan.preview.noEar.title"),
                            message: L("scan.preview.noEar.message"),
                            identifier: "noEarAlert"
                        ),
                        animated: true
                    )
                } else {
                    self.previewViewModel.send(.earVerificationCompleted(.failure(failure)))
                    Log.ml.error("Ear verification failed: \(String(describing: failure), privacy: .public)")
                }
            }
        }
    }
}

final class PreviewMeshingWorkflow {
    private let previewViewModel: PreviewStore
    private let saveExportViewState: SaveExportUIStateAdapting
    private let previewOverlayUI: PreviewOverlayUIController
    private let alertPresenter: PreviewAlertPresenter
    private let meshingTimeoutController = MeshingTimeoutController()
    private let meshingTimeoutSeconds: TimeInterval
    private var didShowMeshingTimeoutAlert = false

    init(
        previewViewModel: PreviewStore,
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

    func beginMeshing(in previewVC: ScenePreviewViewController) {
        previewViewModel.setMeshingActive(true)
        saveExportViewState.markSaveMeshing()
        saveExportViewState.setMeshingStatusText(L("scan.preview.meshing"))
        saveExportViewState.setMeshingSpinnerActive(true)
        previewOverlayUI.setMeshingStatus(L("scan.preview.meshing"), percent: nil, spinning: true)
        previewVC.rightButton.isEnabled = false
        previewVC.rightButton.alpha = 0.6
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
                onMeshReady(mesh)
                let canExportNow = previewVC?.scScene != nil && self.previewViewModel.meshForExport != nil
                previewVC?.rightButton.isEnabled = canExportNow
                previewVC?.rightButton.alpha = canExportNow ? 1.0 : 0.6
                if canExportNow {
                    self.saveExportViewState.markSaveReady()
                    self.saveExportViewState.setMeshingStatusText(L("scan.preview.readyToSave"))
                    self.previewOverlayUI.setMeshingStatus(L("scan.preview.readyToSave"), percent: nil, spinning: false)
                } else {
                    self.saveExportViewState.markSaveFailed()
                    self.saveExportViewState.setMeshingStatusText(L("scan.preview.exportUnavailable.inline"))
                    self.previewOverlayUI.setMeshingStatus(L("scan.preview.exportUnavailable.inline"), percent: nil, spinning: false)
                }
                self.saveExportViewState.setMeshingSpinnerActive(false)
                self.previewOverlayUI.setFitToolsAvailable(true)
                self.cancelTimeout()
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
    private let previewViewModel: PreviewStore
    private let renderDerivedMeasurements: () -> Void

    init(
        measurementService: LocalMeasurementGenerationService,
        previewViewModel: PreviewStore,
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
