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

    init(scanReader: PreviewScanReading) {
        self.scanReader = scanReader
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

}

final class PreviewFitWorkflow {
    private let previewViewModel: PreviewStore
    private let previewOverlayUI: PreviewOverlayUIController
    private let settingsStore: SettingsStore
    private let scanReader: PreviewScanReading
    private let fitModelPackService = FitModelPackService()
    private let useCase: PreviewFitUseCase
    private let onToast: ((String) -> Void)?

    private var fitEarPickTapGesture: UITapGestureRecognizer?

    init(
        previewViewModel: PreviewStore,
        previewOverlayUI: PreviewOverlayUIController,
        settingsStore: SettingsStore,
        scanReader: PreviewScanReading,
        useCase: PreviewFitUseCase,
        onToast: ((String) -> Void)?
    ) {
        self.previewViewModel = previewViewModel
        self.previewOverlayUI = previewOverlayUI
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
        guard scenePreviewVC != nil else { return }
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
            previewViewModel.presentFitExportFailure(message: error.localizedDescription)
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
            if allowEarPickPrompt,
               useCase.shouldPromptForManualEarPicking(output.0) {
                beginFitEarPicking(in: previewVC, target: fitEarPickTarget, action: fitEarPickAction)
            }
        case .failure(let failure):
            previewViewModel.send(.fitCompleted(.failure(failure)))
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
}

final class PreviewEarVerificationWorkflow {
    private let previewViewModel: PreviewStore
    private let previewOverlayUI: PreviewOverlayUIController
    private let sceneAdapter: PreviewSceneAdapter
    private let useCase: PreviewEarVerificationUseCase

    init(
        previewViewModel: PreviewStore,
        previewOverlayUI: PreviewOverlayUIController,
        sceneAdapter: PreviewSceneAdapter,
        useCase: PreviewEarVerificationUseCase
    ) {
        self.previewViewModel = previewViewModel
        self.previewOverlayUI = previewOverlayUI
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
        _ = previewVC
        previewViewModel.presentEarServiceUnavailable()
    }

    func performVerification(
        using service: EarLandmarksService,
        previewVC: ScenePreviewViewController,
        isCurrentSession: @escaping () -> Bool,
        onComplete: @escaping () -> Void
    ) {
        let previewSnapshot = sceneAdapter.makeSceneSnapshot(from: previewVC).renderedImage ?? UIImage()
        let request = previewViewModel.makeEarVerificationRequest(previewSnapshot: previewSnapshot)
        let mlStart = CFAbsoluteTimeGetCurrent()
        beginVerificationUI()

        useCase.verify(
            service: service,
            request: request
        ) { [weak self] result in
            guard let self else { return }
            defer { onComplete() }
            guard isCurrentSession() else { return }

            switch result {
            case .success(let verification):
                self.previewViewModel.setEarVerificationImageSource(request.source)
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
                self.previewViewModel.send(.earVerificationCompleted(.failure(failure)))
                Log.ml.error("Ear verification failed: \(String(describing: failure), privacy: .public)")
            }
        }
    }
}

final class PreviewMeshingWorkflow {
    private let previewViewModel: PreviewStore
    private let meshingTimeoutController = MeshingTimeoutController()
    private let meshingTimeoutSeconds: TimeInterval
    private var didShowMeshingTimeoutAlert = false

    init(
        previewViewModel: PreviewStore,
        meshingTimeoutSeconds: TimeInterval
    ) {
        self.previewViewModel = previewViewModel
        self.meshingTimeoutSeconds = meshingTimeoutSeconds
    }

    func beginMeshing(in previewVC: ScenePreviewViewController) {
        previewViewModel.setMeshingActive(true)
        _ = previewVC
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
                self.previewViewModel.send(.meshingProgressUpdated(clamped))
            }
        }

        previewVC.onTexturedMeshGenerated = { [weak self] mesh in
            DispatchQueue.main.async {
                guard let self, isCurrentPreviewSession(previewSessionID) else { return }
                self.previewViewModel.setMeshingActive(false)
                onMeshReady(mesh)
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
            _ = previewVC
            self.previewViewModel.send(.meshingTimedOut)
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
