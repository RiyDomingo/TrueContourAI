import UIKit

final class HomeHeaderView: UIView {
    let titleLabel: UILabel = {
        let l = UILabel()
        l.text = L("home.title")
        l.textColor = DesignSystem.Colors.textPrimary
        l.font = DesignSystem.Typography.largeTitle()
        l.adjustsFontForContentSizeCategory = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = L("home.subtitle")
        l.textColor = DesignSystem.Colors.textSecondary
        l.font = DesignSystem.Typography.bodyEmphasis()
        l.adjustsFontForContentSizeCategory = true
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    let settingsButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        if let img = UIImage(systemName: "gearshape") {
            b.setImage(img, for: .normal)
        } else {
            b.setTitle(L("common.settings"), for: .normal)
        }
        b.backgroundColor = DesignSystem.Colors.surfaceSecondary
        b.layer.cornerRadius = DesignSystem.CornerRadius.medium
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            b.configuration = config
        } else {
            b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        }
        b.tintColor = DesignSystem.Colors.textPrimary
        b.accessibilityLabel = L("common.settings")
        b.accessibilityIdentifier = "settingsButton"
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
        let topStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        topStack.axis = .vertical
        topStack.spacing = 4
        topStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(topStack)
        addSubview(settingsButton)

        NSLayoutConstraint.activate([
            topStack.topAnchor.constraint(equalTo: topAnchor),
            topStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            topStack.trailingAnchor.constraint(lessThanOrEqualTo: settingsButton.leadingAnchor, constant: -12),

            settingsButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            settingsButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44),

            topStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomAnchor.constraint(greaterThanOrEqualTo: settingsButton.bottomAnchor)
        ])
    }

    func applySubtitle(baseText: String, trendText: String?, trendAccessibilityText: String?) {
        if let trendText, !trendText.isEmpty {
            subtitleLabel.text = "\(baseText)\n\(trendText)"
        } else {
            subtitleLabel.text = baseText
        }
        if let trendAccessibilityText, !trendAccessibilityText.isEmpty {
            subtitleLabel.accessibilityLabel = "\(baseText). \(trendAccessibilityText)"
        } else {
            subtitleLabel.accessibilityLabel = baseText
        }
    }
}
