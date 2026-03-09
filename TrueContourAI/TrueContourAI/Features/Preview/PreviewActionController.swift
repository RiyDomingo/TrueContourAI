import UIKit

final class PreviewActionController: NSObject {
    private let lifecycleWorkflow: PreviewLifecycleWorkflow
    private let exportController: PreviewExportController
    private let presentationController: PreviewPresentationController
    private let previewSessionController: PreviewSessionController
    private let earServiceAvailable: () -> Bool

    init(
        lifecycleWorkflow: PreviewLifecycleWorkflow,
        exportController: PreviewExportController,
        presentationController: PreviewPresentationController,
        previewSessionController: PreviewSessionController,
        earServiceAvailable: @escaping () -> Bool
    ) {
        self.lifecycleWorkflow = lifecycleWorkflow
        self.exportController = exportController
        self.presentationController = presentationController
        self.previewSessionController = previewSessionController
        self.earServiceAvailable = earServiceAvailable
    }

    @objc
    func dismissPreviewTapped() {
        lifecycleWorkflow.dismissPreview()
    }

    @objc
    func saveFromPreviewTapped() {
        guard let previewVC = presentationController.currentScenePreviewViewController else { return }
        let previewSessionID = previewSessionController.sessionID
        DesignSystem.hapticPrimary()
        exportController.performSave(
            previewVC: previewVC,
            previewSessionID: previewSessionID,
            earServiceUnavailable: !earServiceAvailable()
        )
    }
}
