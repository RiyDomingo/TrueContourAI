import UIKit

final class PreviewOverlayUIController {
    private struct SheetProfile {
        let bottomInset: CGFloat
        let collapsed: CGFloat
        let half: CGFloat
        let full: CGFloat
    }
    private enum FitPanelVisibilityState {
        case actionsOnly
        case resultsCollapsed
        case resultsWithAdvanced
    }

    private enum PreviewSheetSection: Int {
        case summary = 0
        case developer = 1
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

    private let bottomSheet = BottomSheetController()
    private let statusRow = StatusRowView()
    private let summaryStack = UIStackView()
    private let developerStack = UIStackView()
    private let contentStack = UIStackView()
    private let sheetTabControl = UISegmentedControl(items: [L("scan.preview.tab.summary"), L("scan.preview.tab.developer")])
    private let sheetTitleLabel = UILabel()
    private var fitPanelVisibilityState: FitPanelVisibilityState = .actionsOnly
    private var developerMode = false

    private func sheetProfile(for hostView: UIView) -> SheetProfile {
        Self.sheetProfile(forHeight: hostView.bounds.height, isPad: hostView.traitCollection.userInterfaceIdiom == .pad)
    }

    private static func sheetProfile(forHeight h: CGFloat, isPad: Bool) -> SheetProfile {
        if isPad || h >= 900 {
            return SheetProfile(bottomInset: 66, collapsed: 86, half: 132, full: 178)
        }
        if h <= 700 {
            return SheetProfile(bottomInset: 58, collapsed: 80, half: 112, full: 144)
        }
        return SheetProfile(bottomInset: 62, collapsed: 84, half: 120, full: 156)
    }

    func addVerifyEarUI(to hostView: UIView, showHint: Bool) -> UIButton {
        ensureSheet(on: hostView)
        if let existing = verifyEarButton { return existing }

        let button = UIButton(type: .system)
        DesignSystem.applyButton(button, title: L("scan.preview.verify"), style: .secondary, size: .regular)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.accessibilityLabel = L("scan.preview.accessibility.verify.label")
        button.accessibilityHint = L("scan.preview.accessibility.verify.hint")
        button.accessibilityIdentifier = "verifyEarButton"

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = DesignSystem.Colors.textPrimary
        spinner.hidesWhenStopped = true

        let buttonWrap = UIView()
        buttonWrap.translatesAutoresizingMaskIntoConstraints = false
        buttonWrap.addSubview(button)
        buttonWrap.addSubview(spinner)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: buttonWrap.topAnchor),
            button.leadingAnchor.constraint(equalTo: buttonWrap.leadingAnchor),
            button.bottomAnchor.constraint(equalTo: buttonWrap.bottomAnchor),
            spinner.leadingAnchor.constraint(equalTo: button.trailingAnchor, constant: 8),
            spinner.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            spinner.trailingAnchor.constraint(lessThanOrEqualTo: buttonWrap.trailingAnchor)
        ])

        developerStack.insertArrangedSubview(buttonWrap, at: 0)
        verifyEarButton = button
        verifyEarActivityIndicator = spinner

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
        hostView.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.trailingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            badge.topAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.topAnchor, constant: 12),
            badge.widthAnchor.constraint(equalToConstant: 92),
            badge.heightAnchor.constraint(equalToConstant: 92)
        ])
        earOverlayBadge = badge

        if showHint {
            addVerifyEarHint(to: hostView, near: bottomSheet.containerView)
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

    func addScanQualityLabel(to hostView: UIView, quality: ScanQuality, anchor _: UIView?) {
        ensureSheet(on: hostView)
        scanQualityLabel?.removeFromSuperview()
        scanQualityHintLabel?.removeFromSuperview()

        let qualityChip = UILabel()
        qualityChip.translatesAutoresizingMaskIntoConstraints = false
        qualityChip.text = "  \(quality.title)  "
        qualityChip.accessibilityIdentifier = "scanQualityLabel"
        qualityChip.accessibilityLabel = String(format: L("scan.preview.accessibility.quality"), quality.title)
        qualityChip.textAlignment = .center
        qualityChip.font = DesignSystem.Typography.caption()
        qualityChip.adjustsFontForContentSizeCategory = true
        qualityChip.layer.cornerRadius = DesignSystem.CornerRadius.small
        qualityChip.layer.masksToBounds = true
        qualityChip.backgroundColor = quality.color.withAlphaComponent(0.9)
        qualityChip.textColor = .white

        let qualityHint = UILabel()
        qualityHint.translatesAutoresizingMaskIntoConstraints = false
        qualityHint.numberOfLines = 2
        qualityHint.textColor = DesignSystem.Colors.textSecondary
        qualityHint.font = DesignSystem.Typography.caption()
        qualityHint.adjustsFontForContentSizeCategory = true
        qualityHint.text = quality.tip
        qualityHint.accessibilityLabel = String(format: L("scan.preview.accessibility.qualityTip"), quality.tip)

        summaryStack.insertArrangedSubview(qualityChip, at: 0)
        summaryStack.insertArrangedSubview(qualityHint, at: 1)
        scanQualityLabel = qualityChip
        scanQualityHintLabel = qualityHint
    }

    func clear() {
        verifyEarHintLabel?.removeFromSuperview()
        verifyEarButton = nil
        earOverlayBadge?.removeFromSuperview()
        earOverlayBadge = nil
        verifyEarActivityIndicator = nil
        scanQualityLabel = nil
        scanQualityHintLabel = nil
        derivedMeasurementsLabel = nil
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

        statusRow.removeFromSuperview()
        summaryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        developerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        sheetTabControl.removeFromSuperview()
        sheetTitleLabel.removeFromSuperview()
        contentStack.removeFromSuperview()
        bottomSheet.containerView.removeFromSuperview()
        hostView = nil
    }

    func addFitModelUI(to hostView: UIView) -> (check: UIButton, export: UIButton, resultsCard: UILabel, browSlider: UISlider) {
        ensureSheet(on: hostView)

        if let check = fitCheckButton,
           let export = fitExportButton,
           let card = fitResultsCardLabel,
           let slider = fitBrowSlider {
            return (check, export, card, slider)
        }

        let panelToggle = UIButton(type: .system)
        DesignSystem.applyButton(panelToggle, title: L("scan.preview.fit.tools"), style: .secondary, size: .regular)
        panelToggle.accessibilityIdentifier = "fitModelPanelToggleButton"

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        DesignSystem.applyCardSurface(container, floating: false)
        container.isHidden = true

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let checkButton = UIButton(type: .system)
        DesignSystem.applyButton(checkButton, title: L("scan.preview.fit.check"), style: .secondary, size: .regular)
        checkButton.accessibilityIdentifier = "fitModelCheckButton"

        let exportButton = UIButton(type: .system)
        DesignSystem.applyButton(exportButton, title: L("scan.preview.fit.export"), style: .secondary, size: .regular)
        exportButton.accessibilityIdentifier = "fitModelExportButton"

        let card = UILabel()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.numberOfLines = 6
        card.textAlignment = .left
        card.font = DesignSystem.Typography.caption()
        card.textColor = DesignSystem.Colors.textPrimary
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
        browLabel.numberOfLines = 1
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

        let actions = UIStackView(arrangedSubviews: [checkButton, exportButton])
        actions.translatesAutoresizingMaskIntoConstraints = false
        actions.axis = .vertical
        actions.spacing = DesignSystem.Spacing.xs

        developerStack.addArrangedSubview(panelToggle)
        developerStack.addArrangedSubview(container)
        container.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(actions)
        contentView.addSubview(card)
        contentView.addSubview(advancedButton)
        contentView.addSubview(browLabel)
        contentView.addSubview(browSlider)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(lessThanOrEqualToConstant: 280),

            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            actions.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            actions.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            actions.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),

            card.topAnchor.constraint(equalTo: actions.bottomAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: actions.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: actions.trailingAnchor),

            advancedButton.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 8),
            advancedButton.leadingAnchor.constraint(equalTo: actions.leadingAnchor),
            advancedButton.trailingAnchor.constraint(equalTo: actions.trailingAnchor),

            browLabel.topAnchor.constraint(equalTo: advancedButton.bottomAnchor, constant: 8),
            browLabel.leadingAnchor.constraint(equalTo: actions.leadingAnchor),
            browLabel.trailingAnchor.constraint(equalTo: actions.trailingAnchor),

            browSlider.topAnchor.constraint(equalTo: browLabel.bottomAnchor, constant: 4),
            browSlider.leadingAnchor.constraint(equalTo: actions.leadingAnchor),
            browSlider.trailingAnchor.constraint(equalTo: actions.trailingAnchor),
            browSlider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])

        fitCheckButton = checkButton
        fitExportButton = exportButton
        fitResultsCardLabel = card
        fitBrowSlider = browSlider
        fitBrowSliderLabel = browLabel
        fitBrowAdvancedButton = advancedButton
        fitPanelToggleButton = panelToggle
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
        applyFitPanelVisibility(visible ? .resultsWithAdvanced : .resultsCollapsed)
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

    func setMeshingStatus(_ text: String, percent: Int?, spinning: Bool) {
        if statusRow.superview == nil {
            summaryStack.insertArrangedSubview(statusRow, at: 0)
        }
        statusRow.setStatus(text: text, percent: percent, spinning: spinning)
    }

    func addOrUpdateDerivedMeasurements(
        to hostView: UIView,
        circumferenceMm: Float,
        widthMm: Float,
        depthMm: Float,
        confidence: Float
    ) {
        ensureSheet(on: hostView)
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
        label.textAlignment = .left
        label.numberOfLines = 2
        label.text = text
        label.accessibilityLabel = text
        label.accessibilityIdentifier = "derivedMeasurementsLabel"
        summaryStack.addArrangedSubview(label)
        derivedMeasurementsLabel = label
    }

    private func ensureSheet(on hostView: UIView) {
        if self.hostView === hostView { return }
        self.hostView = hostView

        let profile = sheetProfile(for: hostView)
        bottomSheet.install(in: hostView, bottomInset: profile.bottomInset)
        bottomSheet.setSnapHeights(collapsed: profile.collapsed, half: profile.half, full: profile.full)
        bottomSheet.setSnapPoint(.collapsed, animated: false)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = DesignSystem.Spacing.xs

        sheetTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        sheetTitleLabel.text = L("scan.preview.sheet.title")
        sheetTitleLabel.textColor = DesignSystem.Colors.textPrimary
        sheetTitleLabel.font = DesignSystem.Typography.bodyEmphasis()
        sheetTitleLabel.adjustsFontForContentSizeCategory = true

        sheetTabControl.translatesAutoresizingMaskIntoConstraints = false
        sheetTabControl.selectedSegmentIndex = 0
        sheetTabControl.accessibilityIdentifier = "previewSheetTabControl"
        sheetTabControl.addTarget(self, action: #selector(sheetTabChanged(_:)), for: .valueChanged)

        summaryStack.translatesAutoresizingMaskIntoConstraints = false
        summaryStack.axis = .vertical
        summaryStack.spacing = 6

        developerStack.translatesAutoresizingMaskIntoConstraints = false
        developerStack.axis = .vertical
        developerStack.spacing = 6
        developerStack.isHidden = true

        bottomSheet.contentView.addSubview(contentStack)
        contentStack.addArrangedSubview(sheetTabControl)
        contentStack.addArrangedSubview(summaryStack)
        contentStack.addArrangedSubview(developerStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: bottomSheet.contentView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: bottomSheet.contentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: bottomSheet.contentView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomSheet.contentView.bottomAnchor)
        ])

        setDeveloperModeEnabled(developerMode)
    }

    @objc private func sheetTabChanged(_ control: UISegmentedControl) {
        guard let section = PreviewSheetSection(rawValue: control.selectedSegmentIndex) else { return }
        summaryStack.isHidden = (section != .summary)
        developerStack.isHidden = (section != .developer)
    }

    func setDeveloperModeEnabled(_ enabled: Bool) {
        developerMode = enabled
        sheetTabControl.isHidden = !enabled
        if let hostView {
            let profile = sheetProfile(for: hostView)
            bottomSheet.setSnapHeights(collapsed: profile.collapsed, half: profile.half, full: profile.full)
        }
        if !enabled {
            sheetTabControl.selectedSegmentIndex = PreviewSheetSection.summary.rawValue
            summaryStack.isHidden = false
            developerStack.isHidden = true
        }
        bottomSheet.setSnapPoint(.collapsed, animated: false)
    }

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

#if DEBUG
    static func debug_sheetProfile(height: CGFloat, isPad: Bool) -> (bottomInset: CGFloat, collapsed: CGFloat, half: CGFloat, full: CGFloat) {
        let p = sheetProfile(forHeight: height, isPad: isPad)
        return (p.bottomInset, p.collapsed, p.half, p.full)
    }

    func debug_installSheet(on hostView: UIView) {
        ensureSheet(on: hostView)
    }

    func debug_currentSnapPoint() -> BottomSheetSnapPoint {
        bottomSheet.currentSnapPoint
    }

    func debug_sheetFrame(on hostView: UIView, developerModeEnabled: Bool) -> CGRect {
        ensureSheet(on: hostView)
        setDeveloperModeEnabled(developerModeEnabled)
        hostView.layoutIfNeeded()
        return bottomSheet.containerView.frame
    }
#endif
}
