import UIKit
import StandardCyborgUI

final class PreviewInteractionController: NSObject {
    private weak var presenter: UIViewController?
    private let previewViewModel: PreviewViewModel
    private let previewSessionController: PreviewSessionController
    private let presentationController: PreviewPresentationController
    private let sharingWorkflow: PreviewSharingWorkflow
    private let earVerificationWorkflow: PreviewEarVerificationWorkflow
    private let fitWorkflow: PreviewFitWorkflow
    private let overlayWorkflow: PreviewOverlayWorkflow
    private let previewOverlayUI: PreviewOverlayUIController
    private let settingsStore: SettingsStore
    private let earServiceProvider: () -> EarLandmarksService?
    private let isCurrentPreviewSession: (UUID) -> Bool
    private var isVerifyingEar = false

    init(
        presenter: UIViewController,
        previewViewModel: PreviewViewModel,
        previewSessionController: PreviewSessionController,
        presentationController: PreviewPresentationController,
        sharingWorkflow: PreviewSharingWorkflow,
        earVerificationWorkflow: PreviewEarVerificationWorkflow,
        fitWorkflow: PreviewFitWorkflow,
        overlayWorkflow: PreviewOverlayWorkflow,
        previewOverlayUI: PreviewOverlayUIController,
        settingsStore: SettingsStore,
        earServiceProvider: @escaping () -> EarLandmarksService?,
        isCurrentPreviewSession: @escaping (UUID) -> Bool
    ) {
        self.presenter = presenter
        self.previewViewModel = previewViewModel
        self.previewSessionController = previewSessionController
        self.presentationController = presentationController
        self.sharingWorkflow = sharingWorkflow
        self.earVerificationWorkflow = earVerificationWorkflow
        self.fitWorkflow = fitWorkflow
        self.overlayWorkflow = overlayWorkflow
        self.previewOverlayUI = previewOverlayUI
        self.settingsStore = settingsStore
        self.earServiceProvider = earServiceProvider
        self.isCurrentPreviewSession = isCurrentPreviewSession
    }

    @objc func shareOpenedScanTapped() {
        guard let presentingVC = presentationController.currentPreviewedViewController ?? presenter else { return }
        sharingWorkflow.presentShareSheet(
            from: presentingVC,
            sourceView: presentationController.currentShareSourceView
        )
    }

    @objc func verifyEarTapped() {
        guard let previewVC = presentationController.resolvedScenePreviewViewController else { return }
        guard !isVerifyingEar else { return }
        let previewSessionID = previewSessionController.sessionID
        guard let svc = earServiceProvider() else {
            earVerificationWorkflow.presentEarUnavailable(on: previewVC)
            return
        }

        Log.ml.info("User requested ear verification")
        DesignSystem.hapticPrimary()
        isVerifyingEar = true
        earVerificationWorkflow.performVerification(
            using: svc,
            previewVC: previewVC,
            isCurrentSession: { [weak self] in
                guard let self else { return false }
                return self.isCurrentPreviewSession(previewSessionID)
            },
            onComplete: { [weak self] in
                self?.isVerifyingEar = false
            }
        )
    }

    @objc func fitModelCheckTapped() {
        fitWorkflow.runFitModelCheck(
            scenePreviewVC: presentationController.resolvedScenePreviewViewController,
            currentPreviewedFolderURL: previewSessionController.currentPreviewedFolderURL,
            showHaptic: true,
            allowEarPickPrompt: true,
            fitEarPickTarget: self,
            fitEarPickAction: #selector(handleFitEarPickTap(_:))
        )
    }

    @objc func exportFitPackTapped() {
        fitWorkflow.exportFitPack(
            scenePreviewVC: presentationController.resolvedScenePreviewViewController,
            currentPreviewedFolderURL: previewSessionController.currentPreviewedFolderURL
        )
    }

    @objc func fitPanelToggleTapped() {
        fitWorkflow.toggleFitPanelExpanded()
    }

    @objc func fitBrowAdvancedTapped() {
        fitWorkflow.toggleAdvancedBrowControlsVisible()
    }

    @objc func fitBrowSliderChanged(_ slider: UISlider) {
        fitWorkflow.updateBrowPlaneDropFromTopFraction(slider.value)
        if previewViewModel.latestFitMeshData != nil {
            fitWorkflow.runFitModelCheck(
                scenePreviewVC: presentationController.resolvedScenePreviewViewController,
                currentPreviewedFolderURL: previewSessionController.currentPreviewedFolderURL,
                showHaptic: false,
                allowEarPickPrompt: false,
                fitEarPickTarget: self,
                fitEarPickAction: #selector(handleFitEarPickTap(_:))
            )
        }
    }

    @objc func handleFitEarPickTap(_ gesture: UITapGestureRecognizer) {
        fitWorkflow.handleFitEarPickTap(
            gesture,
            scenePreviewVC: presentationController.resolvedScenePreviewViewController,
            currentPreviewedFolderURL: previewSessionController.currentPreviewedFolderURL
        )
    }

    func renderDerivedMeasurementsIfAvailable() {
        guard let summary = previewViewModel.measurementSummary else { return }
        guard let hostView = presentationController.overlayHostView else { return }
        overlayWorkflow.renderDerivedMeasurements(summary: summary, hostView: hostView)
    }

    func addVerifyEarUI(to previewVC: ScenePreviewViewController) {
        guard let hostView = presentationController.overlayHostView ?? previewVC.view else { return }
        overlayWorkflow.addVerifyEarUI(
            hostView: hostView,
            bringOverlayToFront: { [weak self] in
                self?.presentationController.bringOverlayToFront()
            },
            developerModeEnabled: settingsStore.developerModeEnabled,
            showHint: settingsStore.showVerifyEarHint,
            target: self,
            action: #selector(verifyEarTapped)
        )
    }

    func configureFitModelUIIfNeeded(previewVC: ScenePreviewViewController) {
        overlayWorkflow.configureFitModelUI(
            previewVC: previewVC,
            previewContainerVC: presentationController.currentPreviewContainerViewController,
            target: self,
            fitPanelToggleAction: #selector(fitPanelToggleTapped),
            fitModelCheckAction: #selector(fitModelCheckTapped),
            exportFitPackAction: #selector(exportFitPackTapped),
            fitBrowAdvancedAction: #selector(fitBrowAdvancedTapped),
            fitBrowSliderChangedAction: #selector(fitBrowSliderChanged(_:))
        )
    }

    func addScanQualityLabel(to previewVC: ScenePreviewViewController, quality: ScanQuality) {
        guard let hostView = presentationController.overlayHostView ?? previewVC.view else { return }
        overlayWorkflow.addScanQualityLabel(to: hostView, quality: quality)
    }

    func cleanup() {
        isVerifyingEar = false
        fitWorkflow.cleanup(scenePreviewVC: presentationController.resolvedScenePreviewViewController)
        previewOverlayUI.clear()
    }
}
