import UIKit

final class PreviewOverlayUIController {
    private struct OverlayLayoutProfile {
        let bottomControlsInset: CGFloat
        let measurementsBottomInset: CGFloat
        let panelMaxWidth: CGFloat
        let panelMaxHeightMultiplier: CGFloat
    }

    private enum FitPanelVisibilityState {
        case actionsOnly
        case resultsCollapsed
        case resultsWithAdvanced
    }

    private(set) weak var verifyEarButton: UIButton?
    private(set) weak var earOverlayBadge: UIImageView?
    private(set) weak var verifyEarActivityIndicator: UIActivityIndicatorView?
    private(set) weak var verifyEarHintLabel: UILabel?
    private(set) weak var scanQualityLabel: UILabel?
    private(set) weak var scanQualityHintLabel: UILabel?
    private(set) weak var derivedMeasurementsLabel: UILabel?
    private(set) weak var fitCheckButton: UIButton?
    private(set) weak var fitExportButton: UIButton?
    private(set) weak var fitResultsCardLabel: UILabel?
    private(set) weak var fitBrowSlider: UISlider?
    private(set) weak var fitBrowSliderLabel: UILabel?
    private(set) weak var fitBrowAdvancedButton: UIButton?
    private(set) weak var fitPanelToggleButton: UIButton?
    private(set) weak var fitContainerView: UIView?
    private(set) weak var fitPanelScrollView: UIScrollView?
    private(set) weak var hostView: UIView?
    private var fitPanelVisibilityState: FitPanelVisibilityState = .actionsOnly

    private static func layoutProfile(for hostView: UIView) -> OverlayLayoutProfile {
        let compactHeight = hostView.bounds.height > 0 ? hostView.bounds.height < 760 : false
        let compactTraits = hostView.traitCollection.verticalSizeClass == .compact
        if compactHeight || compactTraits {
            return OverlayLayoutProfile(
                bottomControlsInset: 72,
                measurementsBottomInset: 118,
                panelMaxWidth: 264,
                panelMaxHeightMultiplier: 0.30
            )
        }
        return OverlayLayoutProfile(
            bottomControlsInset: 84,
            measurementsBottomInset: 132,
            panelMaxWidth: 300,
            panelMaxHeightMultiplier: 0.35
        )
    }

    func addVerifyEarUI(to hostView: UIView, showHint: Bool) -> UIButton {
        if let existing = verifyEarButton { return existing }
        self.hostView = hostView
        let profile = Self.layoutProfile(for: hostView)

        let button = UIButton(type: .system)
        DesignSystem.applyButton(button, title: L("scan.preview.verify"), style: .secondary, size: .regular)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.accessibilityLabel = L("scan.preview.accessibility.verify.label")
        button.accessibilityHint = L("scan.preview.accessibility.verify.hint")
        button.accessibilityIdentifier = "verifyEarButton"

        let badge = UIImageView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.contentMode = .scaleAspectFill
        badge.clipsToBounds = true
        badge.layer.cornerRadius = DesignSystem.CornerRadius.medium
        badge.layer.borderWidth = 1
        badge.layer.borderColor = DesignSystem.Colors.borderStrong.cgColor
        badge.backgroundColor = DesignSystem.Colors.surfaceSecondary
        badge.isHidden = true
        badge.isAccessibilityElement = true
        badge.accessibilityLabel = L("scan.preview.accessibility.badge")
        badge.accessibilityTraits = .image
        button.layer.zPosition = 999
        badge.layer.zPosition = 999

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = DesignSystem.Colors.textPrimary
        spinner.hidesWhenStopped = true

        hostView.addSubview(button)
        hostView.addSubview(badge)
        hostView.addSubview(spinner)

        let badgeSize: CGFloat
        if hostView.traitCollection.verticalSizeClass == .compact
            || hostView.traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            badgeSize = 84
        } else {
            badgeSize = 112
        }

        let badgeTopOffset: CGFloat = 12

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            button.bottomAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.bottomAnchor, constant: -profile.bottomControlsInset),

            badge.trailingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            badge.topAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.topAnchor, constant: badgeTopOffset),
            badge.widthAnchor.constraint(equalToConstant: badgeSize),
            badge.heightAnchor.constraint(equalToConstant: badgeSize),

            spinner.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            spinner.leadingAnchor.constraint(equalTo: button.trailingAnchor, constant: 8)
        ])

        verifyEarButton = button
        earOverlayBadge = badge
        verifyEarActivityIndicator = spinner

        if showHint {
            addVerifyEarHint(to: hostView, near: button)
        }

        DispatchQueue.main.async { [weak hostView] in
            guard let view = hostView else { return }
            view.bringSubviewToFront(button)
            view.bringSubviewToFront(badge)
        }

        return button
    }

    func setVerifyButtonTitle(_ title: String) {
        if #available(iOS 15.0, *) {
            var cfg = verifyEarButton?.configuration
            cfg?.title = title
            verifyEarButton?.configuration = cfg
        } else {
            verifyEarButton?.setTitle(title, for: .normal)
        }
    }

    func showBadge(image: UIImage) {
        earOverlayBadge?.isHidden = false
        earOverlayBadge?.image = image
    }

    func removeVerifyHint() {
        verifyEarHintLabel?.removeFromSuperview()
        verifyEarHintLabel = nil
    }

    func addScanQualityLabel(to hostView: UIView, quality: ScanQuality, anchor: UIView?) {
        if scanQualityLabel != nil { return }

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = DesignSystem.Colors.textPrimary
        label.font = DesignSystem.Typography.caption()
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.text = quality.title
        label.backgroundColor = quality.color.withAlphaComponent(0.9)
        label.layer.cornerRadius = DesignSystem.CornerRadius.medium
        label.layer.masksToBounds = true
        label.accessibilityLabel = String(format: L("scan.preview.accessibility.quality"), quality.title)
        label.accessibilityIdentifier = "scanQualityLabel"

        hostView.addSubview(label)
        let topAnchor = anchor?.bottomAnchor ?? hostView.safeAreaLayoutGuide.topAnchor
        let topConstant: CGFloat = (anchor == nil) ? 12 : 8
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: topConstant),
            label.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 28)
        ])

        scanQualityLabel = label
        addScanQualityHint(to: hostView, quality: quality, anchor: label)
    }

    func clear() {
        verifyEarButton?.removeFromSuperview()
        earOverlayBadge?.removeFromSuperview()
        verifyEarActivityIndicator?.removeFromSuperview()
        fitCheckButton?.removeFromSuperview()
        fitExportButton?.removeFromSuperview()
        fitResultsCardLabel?.removeFromSuperview()
        fitBrowSlider?.removeFromSuperview()
        fitBrowSliderLabel?.removeFromSuperview()
        fitBrowAdvancedButton?.removeFromSuperview()
        fitPanelToggleButton?.removeFromSuperview()
        fitContainerView?.removeFromSuperview()
        fitPanelScrollView?.removeFromSuperview()
        removeVerifyHint()
        scanQualityLabel?.removeFromSuperview()
        scanQualityLabel = nil
        scanQualityHintLabel?.removeFromSuperview()
        scanQualityHintLabel = nil
        derivedMeasurementsLabel?.removeFromSuperview()
        derivedMeasurementsLabel = nil
        hostView = nil
        verifyEarButton = nil
        earOverlayBadge = nil
        verifyEarActivityIndicator = nil
        fitCheckButton = nil
        fitExportButton = nil
        fitResultsCardLabel = nil
        fitBrowSlider = nil
        fitBrowSliderLabel = nil
        fitBrowAdvancedButton = nil
        fitPanelToggleButton = nil
        fitContainerView = nil
        fitPanelScrollView = nil
        fitPanelVisibilityState = .actionsOnly
    }

    func addFitModelUI(to hostView: UIView) -> (check: UIButton, export: UIButton, resultsCard: UILabel, browSlider: UISlider) {
        if let check = fitCheckButton, let export = fitExportButton, let card = fitResultsCardLabel, let slider = fitBrowSlider {
            return (check, export, card, slider)
        }
        self.hostView = hostView
        let profile = Self.layoutProfile(for: hostView)

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = DesignSystem.Colors.overlayCard
        container.layer.cornerRadius = DesignSystem.CornerRadius.medium
        container.layer.masksToBounds = true
        container.accessibilityIdentifier = "fitModelControlsContainer"
        container.isHidden = true

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "fitModelPanelScrollView"

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let panelToggleButton: UIButton
        if let existing = fitPanelToggleButton {
            panelToggleButton = existing
        } else {
            let button = UIButton(type: .system)
            DesignSystem.applyButton(button, title: L("scan.preview.fit.tools"), style: .secondary, size: .regular)
            button.accessibilityIdentifier = "fitModelPanelToggleButton"
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            hostView.addSubview(button)
            NSLayoutConstraint.activate([
                button.trailingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
                button.bottomAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.bottomAnchor, constant: -profile.bottomControlsInset)
            ])
            fitPanelToggleButton = button
            panelToggleButton = button
        }

        let checkButton = UIButton(type: .system)
        DesignSystem.applyButton(checkButton, title: L("scan.preview.fit.check"), style: .secondary, size: .regular)
        checkButton.accessibilityIdentifier = "fitModelCheckButton"
        checkButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        let exportButton = UIButton(type: .system)
        DesignSystem.applyButton(exportButton, title: L("scan.preview.fit.export"), style: .secondary, size: .regular)
        exportButton.accessibilityIdentifier = "fitModelExportButton"
        exportButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        let card = UILabel()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.numberOfLines = 0
        card.textAlignment = .left
        card.font = DesignSystem.Typography.caption()
        card.textColor = DesignSystem.Colors.textPrimary
        card.backgroundColor = UIColor.clear
        card.text = "\(L("scan.preview.fit.results.title"))\n\(L("scan.preview.fit.results.pending"))"
        card.accessibilityIdentifier = "fitModelResultsCard"
        card.isHidden = true

        let advancedButton = UIButton(type: .system)
        advancedButton.translatesAutoresizingMaskIntoConstraints = false
        advancedButton.setTitle(L("scan.preview.fit.brow.advanced"), for: .normal)
        advancedButton.titleLabel?.font = DesignSystem.Typography.caption()
        advancedButton.contentHorizontalAlignment = .left
        advancedButton.setTitleColor(DesignSystem.Colors.textSecondary, for: .normal)
        advancedButton.accessibilityIdentifier = "fitModelBrowAdvancedButton"
        advancedButton.isHidden = true

        let browLabel = UILabel()
        browLabel.translatesAutoresizingMaskIntoConstraints = false
        browLabel.numberOfLines = 2
        browLabel.textAlignment = .left
        browLabel.font = DesignSystem.Typography.caption()
        browLabel.textColor = DesignSystem.Colors.textSecondary
        browLabel.text = String(format: L("scan.preview.fit.brow.slider"), 25)
        browLabel.accessibilityIdentifier = "fitModelBrowSliderLabel"
        browLabel.isHidden = true

        let browSlider = UISlider()
        browSlider.translatesAutoresizingMaskIntoConstraints = false
        browSlider.minimumValue = 0.20
        browSlider.maximumValue = 0.30
        browSlider.value = 0.25
        browSlider.accessibilityIdentifier = "fitModelBrowSlider"
        browSlider.isHidden = true

        let actionsRow = UIStackView(arrangedSubviews: [checkButton, exportButton])
        actionsRow.translatesAutoresizingMaskIntoConstraints = false
        actionsRow.axis = .vertical
        actionsRow.spacing = 8
        actionsRow.distribution = .fill

        hostView.addSubview(container)
        container.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(actionsRow)
        contentView.addSubview(card)
        contentView.addSubview(advancedButton)
        contentView.addSubview(browLabel)
        contentView.addSubview(browSlider)
        NSLayoutConstraint.activate([
            // Keep the center viewport clear: diagnostics stay in the right-bottom quadrant.
            container.leadingAnchor.constraint(greaterThanOrEqualTo: hostView.centerXAnchor, constant: 8),
            container.trailingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            container.bottomAnchor.constraint(equalTo: panelToggleButton.topAnchor, constant: -8),
            container.widthAnchor.constraint(lessThanOrEqualToConstant: profile.panelMaxWidth),
            container.heightAnchor.constraint(lessThanOrEqualTo: hostView.heightAnchor, multiplier: profile.panelMaxHeightMultiplier),
            container.topAnchor.constraint(greaterThanOrEqualTo: hostView.safeAreaLayoutGuide.topAnchor, constant: 12),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            actionsRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            actionsRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            actionsRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            card.leadingAnchor.constraint(equalTo: actionsRow.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: actionsRow.trailingAnchor),
            card.topAnchor.constraint(equalTo: actionsRow.bottomAnchor, constant: 8),

            advancedButton.leadingAnchor.constraint(equalTo: actionsRow.leadingAnchor),
            advancedButton.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 8),
            advancedButton.trailingAnchor.constraint(equalTo: actionsRow.trailingAnchor),

            browLabel.leadingAnchor.constraint(equalTo: actionsRow.leadingAnchor),
            browLabel.topAnchor.constraint(equalTo: advancedButton.bottomAnchor, constant: 8),
            browLabel.trailingAnchor.constraint(equalTo: actionsRow.trailingAnchor),

            browSlider.leadingAnchor.constraint(equalTo: actionsRow.leadingAnchor),
            browSlider.topAnchor.constraint(equalTo: browLabel.bottomAnchor, constant: 4),
            browSlider.trailingAnchor.constraint(equalTo: actionsRow.trailingAnchor),
            browSlider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])

        fitCheckButton = checkButton
        fitExportButton = exportButton
        fitResultsCardLabel = card
        fitBrowSlider = browSlider
        fitBrowSliderLabel = browLabel
        fitBrowAdvancedButton = advancedButton
        fitContainerView = container
        fitPanelScrollView = scrollView
        applyFitPanelVisibility(.actionsOnly)
        return (checkButton, exportButton, card, browSlider)
    }

    func updateFitResultsCard(_ text: String) {
        fitResultsCardLabel?.text = text
        fitResultsCardLabel?.accessibilityLabel = text
        if fitPanelVisibilityState == .resultsWithAdvanced {
            applyFitPanelVisibility(.resultsWithAdvanced)
        } else {
            applyFitPanelVisibility(.resultsCollapsed)
        }
    }

    func updateBrowSliderLabel(percentage: Int) {
        let text = String(format: L("scan.preview.fit.brow.slider"), percentage)
        fitBrowSliderLabel?.text = text
        fitBrowSliderLabel?.accessibilityLabel = text
    }

    func setBrowControlsVisible(_ visible: Bool) {
        guard fitPanelVisibilityState != .actionsOnly else { return }
        if visible {
            applyFitPanelVisibility(.resultsWithAdvanced)
        } else {
            applyFitPanelVisibility(.resultsCollapsed)
        }
    }

    func resetFitPanelToActionsOnly() {
        applyFitPanelVisibility(.actionsOnly)
    }

    func setFitPanelExpanded(_ expanded: Bool) {
        fitContainerView?.isHidden = !expanded
        let title = expanded ? L("scan.preview.fit.tools.hide") : L("scan.preview.fit.tools")
        if #available(iOS 15.0, *) {
            var cfg = fitPanelToggleButton?.configuration
            cfg?.title = title
            fitPanelToggleButton?.configuration = cfg
        } else {
            fitPanelToggleButton?.setTitle(title, for: .normal)
        }
    }

    func setFitToolsAvailable(_ available: Bool) {
        if !available {
            setFitPanelExpanded(false)
        }
        fitPanelToggleButton?.isHidden = !available
    }

    func addOrUpdateDerivedMeasurements(
        to hostView: UIView,
        circumferenceMm: Float,
        widthMm: Float,
        depthMm: Float,
        confidence: Float
    ) {
        let profile = Self.layoutProfile(for: hostView)
        let text = String(
            format: L("scan.preview.measurements.format"),
            Int(round(circumferenceMm)),
            Int(round(widthMm)),
            Int(round(depthMm)),
            Int(round(confidence * 100))
        )

        if let label = derivedMeasurementsLabel {
            label.text = text
            label.accessibilityLabel = text
            return
        }

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = DesignSystem.Colors.textPrimary
        label.font = DesignSystem.Typography.caption()
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.numberOfLines = 2
        label.text = text
        label.backgroundColor = DesignSystem.Colors.overlayCard
        label.layer.cornerRadius = DesignSystem.CornerRadius.medium
        label.layer.masksToBounds = true
        label.accessibilityLabel = text
        label.accessibilityIdentifier = "derivedMeasurementsLabel"

        hostView.addSubview(label)
        NSLayoutConstraint.activate([
            label.bottomAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.bottomAnchor, constant: -profile.measurementsBottomInset),
            label.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
            label.topAnchor.constraint(greaterThanOrEqualTo: hostView.safeAreaLayoutGuide.topAnchor, constant: 12),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: hostView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: hostView.trailingAnchor, constant: -20)
        ])

        derivedMeasurementsLabel = label
    }

    // MARK: - Private

    private func addVerifyEarHint(to hostView: UIView, near anchor: UIView) {
        if verifyEarHintLabel != nil { return }

        let hint = UILabel()
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.textColor = DesignSystem.Colors.textSecondary
        hint.font = DesignSystem.Typography.caption()
        hint.adjustsFontForContentSizeCategory = true
        hint.numberOfLines = 2
        hint.text = L("scan.preview.hint.verify")
        hint.accessibilityLabel = L("scan.preview.hint.verify")

        hostView.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.leadingAnchor.constraint(equalTo: anchor.leadingAnchor),
            hint.bottomAnchor.constraint(equalTo: anchor.topAnchor, constant: -6),
            hint.trailingAnchor.constraint(lessThanOrEqualTo: hostView.trailingAnchor, constant: -12)
        ])

        verifyEarHintLabel = hint

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.removeVerifyHint()
        }
    }

    private func applyFitPanelVisibility(_ state: FitPanelVisibilityState) {
        // Visibility matrix (single source of truth):
        // actionsOnly         => show check/export only
        // resultsCollapsed    => show results + advanced toggle
        // resultsWithAdvanced => show results + advanced toggle + brow controls
        fitPanelVisibilityState = state
        switch state {
        case .actionsOnly:
            fitResultsCardLabel?.isHidden = true
            fitBrowAdvancedButton?.isHidden = true
            fitBrowSliderLabel?.isHidden = true
            fitBrowSlider?.isHidden = true
        case .resultsCollapsed:
            fitResultsCardLabel?.isHidden = false
            fitBrowAdvancedButton?.isHidden = false
            fitBrowSliderLabel?.isHidden = true
            fitBrowSlider?.isHidden = true
        case .resultsWithAdvanced:
            fitResultsCardLabel?.isHidden = false
            fitBrowAdvancedButton?.isHidden = false
            fitBrowSliderLabel?.isHidden = false
            fitBrowSlider?.isHidden = false
        }
    }

    private func addScanQualityHint(to hostView: UIView, quality: ScanQuality, anchor: UIView) {
        if scanQualityHintLabel != nil { return }

        let hint = UILabel()
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.textColor = DesignSystem.Colors.textSecondary
        hint.font = DesignSystem.Typography.caption()
        hint.adjustsFontForContentSizeCategory = true
        hint.numberOfLines = 2
        hint.textAlignment = .center
        hint.text = quality.tip
        hint.accessibilityLabel = String(format: L("scan.preview.accessibility.qualityTip"), quality.tip)

        hostView.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: anchor.bottomAnchor, constant: 6),
            hint.centerXAnchor.constraint(equalTo: anchor.centerXAnchor),
            hint.leadingAnchor.constraint(greaterThanOrEqualTo: hostView.leadingAnchor, constant: 24),
            hint.trailingAnchor.constraint(lessThanOrEqualTo: hostView.trailingAnchor, constant: -24)
        ])

        scanQualityHintLabel = hint
    }
}
