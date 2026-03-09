import Foundation

final class PreviewResetController {
    private let previewSessionController: PreviewSessionController
    private let presentationController: PreviewPresentationController
    private let saveExportViewState: SaveExportUIStateAdapting
    private let meshingWorkflow: PreviewMeshingWorkflow
    private let interactionCleanup: () -> Void

    init(
        previewSessionController: PreviewSessionController,
        presentationController: PreviewPresentationController,
        saveExportViewState: SaveExportUIStateAdapting,
        meshingWorkflow: PreviewMeshingWorkflow,
        interactionCleanup: @escaping () -> Void
    ) {
        self.previewSessionController = previewSessionController
        self.presentationController = presentationController
        self.saveExportViewState = saveExportViewState
        self.meshingWorkflow = meshingWorkflow
        self.interactionCleanup = interactionCleanup
    }

    func reset() {
        interactionCleanup()
        previewSessionController.clearPreviewArtifacts()
        saveExportViewState.clear()
        meshingWorkflow.reset()
        previewSessionController.currentPreviewedFolderURL = nil
        presentationController.reset()
    }
}
