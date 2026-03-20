import UIKit
import StandardCyborgUI

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
        previewContainerVC: PreviewViewController?,
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
        previewOverlayUI.fitPanelToggleButton?.addTarget(target, action: fitPanelToggleAction, for: UIControl.Event.touchUpInside)
        controls.check.addTarget(target, action: fitModelCheckAction, for: UIControl.Event.touchUpInside)
        controls.export.addTarget(target, action: exportFitPackAction, for: UIControl.Event.touchUpInside)
        previewOverlayUI.fitBrowAdvancedButton?.addTarget(target, action: fitBrowAdvancedAction, for: UIControl.Event.touchUpInside)
        controls.browSlider.addTarget(target, action: fitBrowSliderChangedAction, for: UIControl.Event.valueChanged)
    }

    func addScanQualityLabel(to hostView: UIView, quality: ScanQuality) {
        previewOverlayUI.addScanQualityLabel(
            to: hostView,
            quality: quality,
            anchor: nil
        )
    }
}
