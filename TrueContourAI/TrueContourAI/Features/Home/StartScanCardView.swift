import UIKit

final class StartScanCardView: UIView {
    let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = L("home.start.title")
        l.textColor = DesignSystem.Colors.textPrimary
        l.font = DesignSystem.Typography.title()
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    let subtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = L("home.start.subtitle")
        l.textColor = DesignSystem.Colors.textSecondary
        l.font = DesignSystem.Typography.caption()
        l.numberOfLines = 0
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    let prepSummaryLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = L("home.start.prepSummary")
        l.textColor = DesignSystem.Colors.textTertiary
        l.font = DesignSystem.Typography.caption()
        l.numberOfLines = 0
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    let startScanButton: UIButton = {
        let b = UIButton(type: .system)
        DesignSystem.applyButton(b, title: L("home.start.button"), style: .primary, size: .large)
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        b.accessibilityIdentifier = "startScanButton"
        return b
    }()

    let howToScanButton: UIButton = {
        let b = UIButton(type: .system)
        DesignSystem.applyButton(b, title: L("home.howto"), style: .secondary, size: .regular)
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        b.accessibilityLabel = L("home.howto.accessibility")
        b.accessibilityHint = L("home.howto.accessibility.hint")
        b.accessibilityIdentifier = "howToScanButton"
        return b
    }()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        configure()
    }

    @available(*, unavailable, message: "Programmatic-only. Use init().")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    private func configure() {
        backgroundColor = DesignSystem.Colors.surface
        layer.cornerRadius = DesignSystem.CornerRadius.large
        layer.borderWidth = 1
        layer.borderColor = DesignSystem.Colors.border.cgColor

        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(prepSummaryLabel)
        addSubview(startScanButton)
        addSubview(howToScanButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            prepSummaryLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 10),
            prepSummaryLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            prepSummaryLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            startScanButton.topAnchor.constraint(equalTo: prepSummaryLabel.bottomAnchor, constant: 14),
            startScanButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            startScanButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            howToScanButton.topAnchor.constraint(equalTo: startScanButton.bottomAnchor, constant: 10),
            howToScanButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            howToScanButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            howToScanButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }
}
