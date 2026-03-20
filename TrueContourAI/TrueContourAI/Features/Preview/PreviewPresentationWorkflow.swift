import UIKit
import StandardCyborgUI
import StandardCyborgFusion
import SceneKit

final class PreviewPresentationWorkflow {
    private let previewOverlayUI: PreviewOverlayUIController
    private let buttonConfigurator: PreviewButtonConfigurator
    private let saveExportViewState: SaveExportUIStateAdapting

    init(
        previewOverlayUI: PreviewOverlayUIController,
        buttonConfigurator: PreviewButtonConfigurator,
        saveExportViewState: SaveExportUIStateAdapting
    ) {
        self.previewOverlayUI = previewOverlayUI
        self.buttonConfigurator = buttonConfigurator
        self.saveExportViewState = saveExportViewState
    }

    func makeExistingScanPreview(
        scene: SCScene,
        closeTarget: Any,
        shareTarget: Any,
        onClose: Selector,
        onShare: Selector
    ) -> ScenePreviewViewController {
        let vc = ScenePreviewViewController(scScene: scene)
        vc.view.backgroundColor = DesignSystem.Colors.background
        vc.sceneView.backgroundColor = DesignSystem.Colors.background

        buttonConfigurator.configureButtons(for: vc, mode: .existingScan)
        bind(button: vc.leftButton, to: closeTarget, action: onClose)
        bind(button: vc.rightButton, to: shareTarget, action: onShare)
        return vc
    }

    func makeTestPreview(
        target: Any,
        onClose: Selector,
        onShare: Selector
    ) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = DesignSystem.Colors.background

        let closeButton = UIButton(type: .system)
        let shareButton = UIButton(type: .system)
        DesignSystem.applyButton(closeButton, title: L("common.close"), style: .secondary, size: .regular)
        DesignSystem.applyButton(shareButton, title: L("common.share"), style: .secondary, size: .regular)
        closeButton.accessibilityIdentifier = "previewCloseButton"
        shareButton.accessibilityIdentifier = "previewShareButton"
        bind(button: closeButton, to: target, action: onClose)
        bind(button: shareButton, to: target, action: onShare)

        let stack = UIStackView(arrangedSubviews: [closeButton, shareButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        vc.view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            stack.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        vc.modalPresentationStyle = .fullScreen
        return vc
    }

    func makePostScanPreview(
        pointCloud: SCPointCloud,
        meshTexturing: SCMeshTexturing,
        actionTarget: PreviewButtonActionTarget
    ) -> ScenePreviewViewController {
        let vc = ScenePreviewViewController(
            pointCloud: pointCloud,
            meshTexturing: meshTexturing,
            landmarks: nil
        )
        vc.view.backgroundColor = DesignSystem.Colors.background
        vc.sceneView.backgroundColor = DesignSystem.Colors.background

        previewOverlayUI.clear()
        buttonConfigurator.configureButtons(for: vc, mode: .newScan)
        bind(button: vc.leftButton, to: actionTarget, action: #selector(PreviewButtonActionTarget.leftTapped))
        bind(button: vc.rightButton, to: actionTarget, action: #selector(PreviewButtonActionTarget.rightTapped))
        vc.leftButton.accessibilityIdentifier = "previewCloseButton"
        vc.rightButton.accessibilityIdentifier = "previewSaveButton"
        vc.rightButton.isEnabled = false
        DesignSystem.updateButtonEnabled(vc.rightButton, style: .primary)
        saveExportViewState.configure(surface: vc)
        return vc
    }

    private func bind(button: UIButton, to target: Any, action: Selector) {
        button.addTarget(target, action: action, for: .touchUpInside)
    }
}
