import StandardCyborgUI

final class PreviewSceneUIController {
    private let previewViewModel: PreviewViewModel
    private let previewOverlayUI: PreviewOverlayUIController
    private let interactionController: PreviewInteractionController

    init(
        previewViewModel: PreviewViewModel,
        previewOverlayUI: PreviewOverlayUIController,
        interactionController: PreviewInteractionController
    ) {
        self.previewViewModel = previewViewModel
        self.previewOverlayUI = previewOverlayUI
        self.interactionController = interactionController
    }

    func configureFitModelUIIfNeeded(previewVC: ScenePreviewViewController) {
        interactionController.configureFitModelUIIfNeeded(previewVC: previewVC)
    }

    func finalizePostScanSceneUI(previewVC: ScenePreviewViewController) {
        interactionController.addVerifyEarUI(to: previewVC)
        previewOverlayUI.setMeshingStatus(L("scan.preview.meshing"), percent: nil, spinning: true)
        interactionController.configureFitModelUIIfNeeded(previewVC: previewVC)
        if let quality = previewViewModel.scanQuality {
            interactionController.addScanQualityLabel(to: previewVC, quality: quality)
        }
        interactionController.renderDerivedMeasurementsIfAvailable()
    }
}
