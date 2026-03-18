import UIKit
import StandardCyborgUI

final class SaveExportViewStateController: SaveExportUIStateAdapting {
    private enum SaveState: String {
        case idle
        case meshing
        case ready
        case invoked
        case saving
        case completed
        case failed
        case blocked
    }

    private weak var surface: (any PreviewSaveExportSurface)?
    private weak var savingOverlayView: UIView?
    private weak var meshingStatusContainer: UIView?
    private weak var meshingStatusLabel: UILabel?
    private weak var meshingSpinner: UIActivityIndicatorView?
    private weak var saveStateAccessibilityView: UIView?

    private var currentSaveState: SaveState = .idle

    func configure(surface: any PreviewSaveExportSurface) {
        self.surface = surface
        ensureMeshingStatusView(in: surface.hostView)
        ensureSaveStateAccessibilityView(in: surface.hostView)
        setSaveButtonEnabled(false)
        updateSaveState(.idle)
    }

    func setButtonsEnabled(_ isEnabled: Bool) {
        guard let surface else { return }
        surface.leftActionButton.isEnabled = isEnabled
        surface.rightActionButton.isEnabled = isEnabled
        DesignSystem.updateButtonEnabled(surface.leftActionButton, style: .secondary)
        DesignSystem.updateButtonEnabled(surface.rightActionButton, style: .primary)
    }

    func markSaveMeshing() {
        setSaveButtonEnabled(false)
        updateSaveState(.meshing)
    }

    func setMeshingStatusText(_ text: String) {
        guard let meshingStatusLabel, let meshingStatusContainer else { return }
        meshingStatusLabel.text = text
        meshingStatusContainer.isHidden = text.isEmpty
        if text == L("scan.preview.readyToSave") {
            markSaveReady()
        } else if text == L("scan.preview.exporting") {
            updateSaveState(.saving)
        } else if !text.isEmpty, meshingSpinner?.isAnimating == true {
            updateSaveState(.meshing)
        }
        updateSaveStateAccessibilityText(text)
    }

    func setMeshingSpinnerActive(_ isActive: Bool) {
        guard let meshingSpinner, let meshingStatusContainer else { return }
        if isActive {
            meshingSpinner.startAnimating()
            if currentSaveState != .saving {
                updateSaveState(.meshing)
            }
        } else {
            meshingSpinner.stopAnimating()
        }
        meshingStatusContainer.isHidden = !isActive && (meshingStatusLabel?.text?.isEmpty ?? true)
        if !isActive, currentSaveState != .saving {
            if meshingStatusLabel?.text == L("scan.preview.readyToSave") {
                updateSaveState(.ready)
            } else if meshingStatusLabel?.text?.isEmpty ?? true {
                updateSaveState(.idle)
            }
        }
    }

    func showSavingToast() {
        guard savingOverlayView == nil else { return }
        guard let surface else { return }

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
        surface.hostView.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: surface.hostView.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: surface.hostView.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: surface.hostView.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: surface.hostView.bottomAnchor),

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
        updateSaveState(.saving)
        UIView.animate(withDuration: 0.2) { dimView.alpha = 1 }
    }

    func markSaveReady() {
        setSaveButtonEnabled(true)
        updateSaveState(.ready)
    }

    func markSaveInvoked() {
        setSaveButtonEnabled(false)
        updateSaveState(.invoked)
    }

    func markSaveBlocked() {
        setSaveButtonEnabled(true)
        updateSaveState(.blocked)
    }

    func markSaveCompleted() {
        updateSaveState(.completed)
    }

    func markSaveFailed() {
        setSaveButtonEnabled(true)
        updateSaveState(.failed)
    }

    func hideSavingToast() {
        guard let view = savingOverlayView else { return }
        UIView.animate(withDuration: 0.2, animations: {
            view.alpha = 0
        }) { _ in
            view.removeFromSuperview()
        }
        savingOverlayView = nil
        if currentSaveState == .completed {
            return
        } else if currentSaveState == .failed || currentSaveState == .blocked {
            updateSaveState(.ready)
        } else if meshingSpinner?.isAnimating == true {
            updateSaveState(.meshing)
        } else if meshingStatusLabel?.text == L("scan.preview.readyToSave") {
            updateSaveState(.ready)
        } else if !(meshingStatusLabel?.text?.isEmpty ?? true) {
            updateSaveState(.ready)
        } else {
            updateSaveState(.idle)
        }
    }

    func clear() {
        surface = nil
        savingOverlayView?.removeFromSuperview()
        savingOverlayView = nil
        meshingStatusContainer?.removeFromSuperview()
        meshingStatusContainer = nil
        meshingStatusLabel = nil
        meshingSpinner = nil
        saveStateAccessibilityView?.removeFromSuperview()
        saveStateAccessibilityView = nil
        currentSaveState = .idle
    }

    private func ensureMeshingStatusView(in hostView: UIView) {
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
        hostView.addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(lessThanOrEqualTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.bottomAnchor, constant: -92),

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

    private func setSaveButtonEnabled(_ isEnabled: Bool) {
        guard let surface else { return }
        surface.rightActionButton.isEnabled = isEnabled
        DesignSystem.updateButtonEnabled(surface.rightActionButton, style: .primary)
    }

    private func ensureSaveStateAccessibilityView(in hostView: UIView) {
        guard saveStateAccessibilityView == nil else { return }

        let stateView = UIView()
        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.isAccessibilityElement = true
        stateView.accessibilityIdentifier = "previewSaveStateView"
        stateView.accessibilityLabel = "Preview save state"
        stateView.accessibilityValue = SaveState.idle.rawValue

        hostView.addSubview(stateView)
        NSLayoutConstraint.activate([
            stateView.topAnchor.constraint(equalTo: hostView.topAnchor),
            stateView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            stateView.widthAnchor.constraint(equalToConstant: 1),
            stateView.heightAnchor.constraint(equalToConstant: 1)
        ])

        saveStateAccessibilityView = stateView
    }

    private func updateSaveState(_ state: SaveState) {
        currentSaveState = state
        saveStateAccessibilityView?.accessibilityValue = state.rawValue
    }

    private func updateSaveStateAccessibilityText(_ text: String) {
        guard let saveStateAccessibilityView else { return }
        saveStateAccessibilityView.accessibilityHint = text
    }
}
