import UIKit
import StandardCyborgUI

final class PreviewPresentationController {
    private var scenePreviewVC: ScenePreviewViewController?
    private var previewContainerVC: PreviewViewController?
    private var postScanButtonActionTarget: PreviewButtonActionTarget?

    var resolvedScenePreviewViewController: ScenePreviewViewController? {
        if let scenePreviewVC {
            return scenePreviewVC
        }
        if let previewVC = previewContainerVC?.contentViewController as? ScenePreviewViewController {
            return previewVC
        }
        return nil
    }

    var currentPreviewViewController: PreviewViewController? {
        previewContainerVC
    }

    var currentShareSourceView: UIView? {
        resolvedScenePreviewViewController?.rightButton
    }

    func setExistingPreview(viewController: UIViewController, scenePreviewViewController: ScenePreviewViewController?) {
        scenePreviewVC = scenePreviewViewController
        postScanButtonActionTarget = nil
        if scenePreviewViewController == nil {
            previewContainerVC = nil
        } else if let container = viewController as? PreviewViewController {
            previewContainerVC = container
        }
    }

    func setPostScanPreview(context: PreviewPostScanPresentationContext) {
        scenePreviewVC = context.previewVC
        previewContainerVC = context.container
        postScanButtonActionTarget = context.buttonActionTarget
    }

    func bringOverlayToFront() {
        previewContainerVC?.bringOverlayToFront()
    }
}
