import UIKit
import StandardCyborgUI
import StandardCyborgFusion

final class PreviewRoutingController {
    private weak var presenter: UIViewController?
    private let environment: AppEnvironment
    private let previewViewModel: PreviewViewModel
    private let existingScanWorkflow: PreviewExistingScanWorkflow
    private let postScanPresentationWorkflow: PreviewPostScanPresentationWorkflow
    private let presentationController: PreviewPresentationController
    private let startPreviewSession: (ScanFlowState.ScanSessionMetrics?) -> UUID
    private let isCurrentPreviewSession: (UUID) -> Bool

    init(
        presenter: UIViewController,
        environment: AppEnvironment,
        previewViewModel: PreviewViewModel,
        existingScanWorkflow: PreviewExistingScanWorkflow,
        postScanPresentationWorkflow: PreviewPostScanPresentationWorkflow,
        presentationController: PreviewPresentationController,
        startPreviewSession: @escaping (ScanFlowState.ScanSessionMetrics?) -> UUID,
        isCurrentPreviewSession: @escaping (UUID) -> Bool
    ) {
        self.presenter = presenter
        self.environment = environment
        self.previewViewModel = previewViewModel
        self.existingScanWorkflow = existingScanWorkflow
        self.postScanPresentationWorkflow = postScanPresentationWorkflow
        self.presentationController = presentationController
        self.startPreviewSession = startPreviewSession
        self.isCurrentPreviewSession = isCurrentPreviewSession
    }

    func presentExistingScan(
        _ item: ScanService.ScanItem,
        closeTarget: AnyObject,
        shareTarget: AnyObject,
        closeAction: Selector,
        shareAction: Selector,
        configureFitModelUI: @escaping (ScenePreviewViewController) -> Void
    ) {
        guard let presenter else { return }
        let sessionID = startPreviewSession(nil)
        guard let presentation = existingScanWorkflow.makePresentation(
            item: item,
            presenter: presenter,
            skipGLTF: environment.skipsGLTFPreview,
            closeTarget: closeTarget,
            shareTarget: shareTarget,
            onClose: closeAction,
            onShare: shareAction
        ) else {
            return
        }

        let vc = presentation.0
        let sceneVC = presentation.1
        let existingSummary = presentation.2

        presentationController.setExistingPreview(viewController: vc, scenePreviewViewController: sceneVC)

        if sceneVC == nil {
            presenter.present(vc, animated: true)
            return
        }

        presenter.present(vc, animated: true) { [weak self, weak sceneVC] in
            guard let self, let sceneVC, self.isCurrentPreviewSession(sessionID) else { return }
            self.existingScanWorkflow.finalizePresentation(
                summary: existingSummary,
                previewVC: sceneVC,
                configureFitModelUI: {
                    configureFitModelUI(sceneVC)
                }
            )
        }
        Log.ui.info("Presented existing scan preview: \(item.displayName, privacy: .public)")
    }

    func presentPreviewAfterScan(
        from scanningVC: UIViewController,
        pointCloud: SCPointCloud,
        meshTexturing: SCMeshTexturing,
        sessionMetrics: ScanFlowState.ScanSessionMetrics?,
        closeTarget: AnyObject,
        closeAction: Selector,
        saveTarget: AnyObject,
        saveAction: Selector
    ) {
        guard let presenter else { return }
        let previewSessionID = startPreviewSession(sessionMetrics)

        Log.scan.info("Presenting preview after scan")
        let context = postScanPresentationWorkflow.makePresentationContext(
            scanningVC: scanningVC,
            presenter: presenter,
            pointCloud: pointCloud,
            meshTexturing: meshTexturing,
            previewSessionID: previewSessionID,
            target: closeTarget,
            onClose: closeAction,
            onSave: saveAction,
            isCurrentPreviewSession: { [weak self] sessionID in
                guard let self else { return false }
                return self.isCurrentPreviewSession(sessionID)
            },
            onMeshReady: { [weak self] mesh in
                self?.previewViewModel.setMeshForExport(mesh)
            }
        )
        // Save target is currently the same target object as close target in the coordinator path.
        _ = saveTarget
        presentationController.setPostScanPreview(context: context)
    }
}
