import UIKit

final class PreviewOverlayUIController {
    private(set) weak var verifyEarButton: UIButton?
    private(set) weak var earOverlayBadge: UIImageView?
    private(set) weak var verifyEarActivityIndicator: UIActivityIndicatorView?
    private(set) weak var verifyEarHintLabel: UILabel?
    private(set) weak var scanQualityLabel: UILabel?
    private(set) weak var scanQualityHintLabel: UILabel?
    private(set) weak var derivedMeasurementsLabel: UILabel?
    private(set) weak var hostView: UIView?

    func addVerifyEarUI(to hostView: UIView, showHint: Bool) -> UIButton {
        if let existing = verifyEarButton { return existing }
        self.hostView = hostView

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
            button.topAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.topAnchor, constant: 12),

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
    }

    func addOrUpdateDerivedMeasurements(
        to hostView: UIView,
        circumferenceMm: Float,
        widthMm: Float,
        depthMm: Float,
        confidence: Float
    ) {
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
        label.backgroundColor = DesignSystem.Colors.overlay.withAlphaComponent(0.82)
        label.layer.cornerRadius = DesignSystem.CornerRadius.medium
        label.layer.masksToBounds = true
        label.accessibilityLabel = text
        label.accessibilityIdentifier = "derivedMeasurementsLabel"

        hostView.addSubview(label)
        let anchor = scanQualityHintLabel ?? scanQualityLabel ?? verifyEarButton
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: (anchor?.bottomAnchor ?? hostView.safeAreaLayoutGuide.topAnchor), constant: 8),
            label.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
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
            hint.topAnchor.constraint(equalTo: anchor.bottomAnchor, constant: 6),
            hint.trailingAnchor.constraint(lessThanOrEqualTo: hostView.trailingAnchor, constant: -12)
        ])

        verifyEarHintLabel = hint

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.removeVerifyHint()
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
