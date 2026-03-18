import UIKit
import StandardCyborgUI
import StandardCyborgFusion

final class PreviewRoutingController {
    private weak var presenter: UIViewController?
    private let environment: AppEnvironment
    private let previewViewModel: PreviewViewModel
    private let previewSessionController: PreviewSessionController
    private let existingScanWorkflow: PreviewExistingScanWorkflow
    private let postScanPresentationWorkflow: PreviewPostScanPresentationWorkflow
    private let presentationController: PreviewPresentationController

    init(
        presenter: UIViewController,
        environment: AppEnvironment,
        previewViewModel: PreviewViewModel,
        previewSessionController: PreviewSessionController,
        existingScanWorkflow: PreviewExistingScanWorkflow,
        postScanPresentationWorkflow: PreviewPostScanPresentationWorkflow,
        presentationController: PreviewPresentationController
    ) {
        self.presenter = presenter
        self.environment = environment
        self.previewViewModel = previewViewModel
        self.previewSessionController = previewSessionController
        self.existingScanWorkflow = existingScanWorkflow
        self.postScanPresentationWorkflow = postScanPresentationWorkflow
        self.presentationController = presentationController
    }

    func presentExistingScan(
        _ item: ScanItem,
        closeTarget: AnyObject,
        shareTarget: AnyObject,
        closeAction: Selector,
        shareAction: Selector,
        configureSceneUI: @escaping (ScenePreviewViewController) -> Void
    ) {
        guard let presenter else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak presenter] in
            guard let self, let presenter else { return }
            let presentationData = self.existingScanWorkflow.loadPresentationData(
                item: item,
                skipGLTF: self.environment.skipsGLTFPreview
            )
            let selectionMetadata = presentationData.preservedEarVerificationImage.map { _ in
                EarVerificationSelectionMetadata(
                    source: .latestCaptureFallback,
                    frameIndex: nil,
                    totalScore: nil,
                    profileScore: nil,
                    trackingScore: nil,
                    guidanceScore: nil,
                    timingScore: nil
                )
            }

            DispatchQueue.main.async { [weak self, weak presenter] in
                guard let self, let presenter else { return }
                let sessionID = self.previewSessionController.beginExistingScanSession(
                    preservedEarVerificationImage: presentationData.preservedEarVerificationImage,
                    preservedEarVerificationSelectionMetadata: selectionMetadata
                )
                guard let presentation = self.existingScanWorkflow.makePresentation(
                    item: item,
                    presenter: presenter,
                    skipGLTF: self.environment.skipsGLTFPreview,
                    presentationData: presentationData,
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

                self.presentationController.setExistingPreview(viewController: vc, scenePreviewViewController: sceneVC)

                if sceneVC == nil {
                    presenter.present(vc, animated: true)
                    return
                }

                presenter.present(vc, animated: true) { [weak self, weak sceneVC] in
                    guard let self, let sceneVC, self.previewSessionController.isCurrentSession(sessionID) else { return }
                    self.existingScanWorkflow.finalizePresentation(
                        summary: existingSummary,
                        previewVC: sceneVC,
                        configureSceneUI: configureSceneUI
                    )
                }
                Log.ui.info("Presented existing scan preview: \(item.displayName, privacy: .public)")
            }
        }
    }

    func presentPreviewAfterScan(
        from scanningVC: UIViewController,
        payload: ScanPreviewInput,
        sessionMetrics: ScanFlowState.ScanSessionMetrics?,
        onClose: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        guard let presenter else { return }
        let previewSessionID = previewSessionController.beginPreviewSession(
            sessionMetrics: sessionMetrics,
            preservedEarVerificationImage: payload.earVerificationImage,
            preservedEarVerificationSelectionMetadata: payload.earVerificationSelectionMetadata
        )

        Log.scan.info("Presenting preview after scan")
        let context = postScanPresentationWorkflow.makePresentationContext(
            scanningVC: scanningVC,
            presenter: presenter,
            pointCloud: payload.pointCloud,
            meshTexturing: payload.meshTexturing,
            previewSessionID: previewSessionID,
            onCloseHandler: onClose,
            onSaveHandler: onSave,
            isCurrentPreviewSession: { [weak self] sessionID in
                guard let self else { return false }
                return self.previewSessionController.isCurrentSession(sessionID)
            },
            onMeshReady: { [weak self] mesh in
                self?.previewViewModel.setMeshForExport(mesh)
            }
        )
        presentationController.setPostScanPreview(context: context)
    }
}
