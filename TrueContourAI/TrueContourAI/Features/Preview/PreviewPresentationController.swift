import UIKit
import StandardCyborgUI

final class PreviewPresentationController {
    private var scenePreviewVC: ScenePreviewViewController?
    private var previewContainerVC: PreviewContainerViewController?
    private var activePreviewVC: UIViewController?
    private var buttonActionTarget: PreviewButtonActionTarget?

    var currentScenePreviewViewController: ScenePreviewViewController? {
        scenePreviewVC
    }

    var resolvedScenePreviewViewController: ScenePreviewViewController? {
        if let scenePreviewVC {
            return scenePreviewVC
        }
        if let previewVC = previewContainerVC?.contentViewController as? ScenePreviewViewController {
            return previewVC
        }
        return activePreviewVC as? ScenePreviewViewController
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
        resolvedScenePreviewViewController?.rightButton
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
        buttonActionTarget = context.buttonActionTarget
    }

    func bringOverlayToFront() {
        previewContainerVC?.bringOverlayToFront()
    }

    func reset() {
        activePreviewVC = nil
        previewContainerVC = nil
        scenePreviewVC = nil
        buttonActionTarget = nil
    }

    func dismissActivePreview(animated: Bool, completion: (() -> Void)? = nil) {
        guard let activePreviewVC, activePreviewVC.presentingViewController != nil else {
            completion?()
            return
        }

        activePreviewVC.dismiss(animated: animated, completion: completion)
    }
}
