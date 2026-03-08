import UIKit
import StandardCyborgUI

final class PreviewPresentationController {
    private weak var scenePreviewVC: ScenePreviewViewController?
    private var previewContainerVC: PreviewContainerViewController?
    private weak var activePreviewVC: UIViewController?

    var currentScenePreviewViewController: ScenePreviewViewController? {
        scenePreviewVC
    }

    var currentPreviewContainerViewController: PreviewContainerViewController? {
        previewContainerVC
    }

    var currentPreviewedViewController: UIViewController? {
        activePreviewVC
    }

    var overlayHostView: UIView? {
        previewContainerVC?.overlayView ?? scenePreviewVC?.view
    }

    var currentShareSourceView: UIView? {
        scenePreviewVC?.rightButton
    }

    func setExistingPreview(viewController: UIViewController, scenePreviewViewController: ScenePreviewViewController?) {
        activePreviewVC = viewController
        scenePreviewVC = scenePreviewViewController
        if scenePreviewViewController == nil {
            previewContainerVC = nil
        }
    }

    func setPostScanPreview(context: PreviewPostScanPresentationContext) {
        scenePreviewVC = context.previewVC
        previewContainerVC = context.container
        activePreviewVC = context.container
    }

    func bringOverlayToFront() {
        previewContainerVC?.bringOverlayToFront()
    }

    func reset() {
        activePreviewVC = nil
        previewContainerVC = nil
        scenePreviewVC = nil
    }

    func dismissActivePreview(animated: Bool, completion: (() -> Void)? = nil) {
        guard let activePreviewVC, activePreviewVC.presentingViewController != nil else {
            completion?()
            return
        }

        activePreviewVC.dismiss(animated: animated, completion: completion)
    }
}
