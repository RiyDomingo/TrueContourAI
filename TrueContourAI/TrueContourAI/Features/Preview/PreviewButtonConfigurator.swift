import UIKit
import StandardCyborgUI

final class PreviewButtonConfigurator {
    enum Mode {
        case existingScan
        case newScan
    }

    func configureButtons(for previewVC: ScenePreviewViewController, mode: Mode) {
        switch mode {
        case .existingScan:
            previewVC.leftButton.setTitle(L("common.close"), for: .normal)
            previewVC.rightButton.setTitle(L("common.share"), for: .normal)
            DesignSystem.applyButton(previewVC.leftButton, title: L("common.close"), style: .secondary, size: .regular)
            DesignSystem.applyButton(previewVC.rightButton, title: L("common.share"), style: .secondary, size: .regular)
            previewVC.leftButton.accessibilityIdentifier = "previewCloseButton"
            previewVC.rightButton.accessibilityIdentifier = "previewShareButton"
        case .newScan:
            previewVC.leftButton.setTitle(L("common.rescan"), for: .normal)
            previewVC.rightButton.setTitle(L("common.save"), for: .normal)
            DesignSystem.applyButton(previewVC.leftButton, title: L("common.rescan"), style: .secondary, size: .regular)
            DesignSystem.applyButton(previewVC.rightButton, title: L("common.save"), style: .primary, size: .regular)
            previewVC.leftButton.accessibilityIdentifier = "previewRescanButton"
            previewVC.rightButton.accessibilityIdentifier = "previewSaveButton"
        }
    }
}
