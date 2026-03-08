import UIKit
import StandardCyborgUI

final class SaveExportViewStateController: SaveExportUIStateAdapting {
    private weak var previewVC: ScenePreviewViewController?
    private weak var savingOverlayView: UIView?
    private weak var meshingStatusContainer: UIView?
    private weak var meshingStatusLabel: UILabel?
    private weak var meshingSpinner: UIActivityIndicatorView?

    func configure(previewVC: ScenePreviewViewController) {
        self.previewVC = previewVC
        ensureMeshingStatusView(in: previewVC)
    }

    func setButtonsEnabled(_ isEnabled: Bool) {
        guard let previewVC else { return }
        previewVC.leftButton.isEnabled = isEnabled
        previewVC.rightButton.isEnabled = isEnabled
        DesignSystem.updateButtonEnabled(previewVC.leftButton, style: .secondary)
        DesignSystem.updateButtonEnabled(previewVC.rightButton, style: .primary)
    }

    func setMeshingStatusText(_ text: String) {
        guard let meshingStatusLabel, let meshingStatusContainer else { return }
        meshingStatusLabel.text = text
        meshingStatusContainer.isHidden = text.isEmpty
    }

    func setMeshingSpinnerActive(_ isActive: Bool) {
        guard let meshingSpinner, let meshingStatusContainer else { return }
        if isActive {
            meshingSpinner.startAnimating()
        } else {
            meshingSpinner.stopAnimating()
        }
        meshingStatusContainer.isHidden = !isActive && (meshingStatusLabel?.text?.isEmpty ?? true)
    }

    func showSavingToast() {
        guard savingOverlayView == nil else { return }
        guard let previewVC else { return }

        let dimView = UIView()
        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        dimView.alpha = 0
        dimView.accessibilityIdentifier = "savingToastLabel"

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = DesignSystem.Colors.overlayCard
        card.layer.cornerRadius = DesignSystem.CornerRadius.large
        card.layer.masksToBounds = true

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = DesignSystem.Colors.textPrimary
        spinner.startAnimating()

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = L("scan.preview.saving")
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.font = DesignSystem.Typography.bodyEmphasis()
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = L("scan.preview.savingDetail")
        subtitleLabel.textColor = DesignSystem.Colors.textSecondary
        subtitleLabel.font = DesignSystem.Typography.caption()
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        card.addSubview(spinner)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        dimView.addSubview(card)
        previewVC.view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: previewVC.view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: previewVC.view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: previewVC.view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: previewVC.view.bottomAnchor),

            card.centerXAnchor.constraint(equalTo: dimView.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: dimView.centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: dimView.leadingAnchor, constant: 28),
            card.trailingAnchor.constraint(lessThanOrEqualTo: dimView.trailingAnchor, constant: -28),

            spinner.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            spinner.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            subtitleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 260)
        ])

        savingOverlayView = dimView
        UIView.animate(withDuration: 0.2) { dimView.alpha = 1 }
    }

    func hideSavingToast() {
        guard let view = savingOverlayView else { return }
        UIView.animate(withDuration: 0.2, animations: {
            view.alpha = 0
        }) { _ in
            view.removeFromSuperview()
        }
        savingOverlayView = nil
    }

    func clear() {
        previewVC = nil
        savingOverlayView?.removeFromSuperview()
        savingOverlayView = nil
        meshingStatusContainer?.removeFromSuperview()
        meshingStatusContainer = nil
        meshingStatusLabel = nil
        meshingSpinner = nil
    }

    private func ensureMeshingStatusView(in previewVC: ScenePreviewViewController) {
        guard meshingStatusContainer == nil else { return }

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = DesignSystem.Colors.overlayCard
        container.layer.cornerRadius = DesignSystem.CornerRadius.medium
        container.layer.masksToBounds = true
        container.isHidden = true

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = DesignSystem.Colors.textPrimary

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignSystem.Typography.caption()
        label.textColor = DesignSystem.Colors.textPrimary
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 2
        label.textAlignment = .left

        container.addSubview(spinner)
        container.addSubview(label)
        previewVC.view.addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: previewVC.view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(lessThanOrEqualTo: previewVC.view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: previewVC.view.safeAreaLayoutGuide.bottomAnchor, constant: -92),

            spinner.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])

        meshingStatusContainer = container
        meshingStatusLabel = label
        meshingSpinner = spinner
    }
}
