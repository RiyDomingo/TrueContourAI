import UIKit
import StandardCyborgUI

final class PreviewSceneAdapter {
    func makeSceneSnapshot(from previewVC: ScenePreviewViewController) -> PreviewSceneSnapshot {
        PreviewSceneSnapshot(
            scene: previewVC.scScene,
            renderedImage: previewVC.renderedSceneImage ?? previewVC.sceneView.snapshot()
        )
    }
}
