import UIKit

enum DesignSystem {
    enum Colors {
        static let background = adaptive(
            light: UIColor(red: 0.95, green: 0.97, blue: 0.99, alpha: 1.0),
            dark: UIColor(red: 0.03, green: 0.05, blue: 0.10, alpha: 1.0)
        )
        static let surface = adaptive(
            light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
            dark: UIColor(red: 0.08, green: 0.11, blue: 0.18, alpha: 1.0)
        )
        static let surfaceSecondary = adaptive(
            light: UIColor(red: 0.91, green: 0.94, blue: 0.98, alpha: 1.0),
            dark: UIColor(red: 0.12, green: 0.16, blue: 0.24, alpha: 1.0)
        )
        static let actionPrimary = adaptive(
            light: UIColor(red: 0.06, green: 0.42, blue: 0.86, alpha: 1.0),
            dark: UIColor(red: 0.14, green: 0.54, blue: 1.0, alpha: 1.0)
        )
        static let actionPrimaryDisabled = adaptive(
            light: UIColor(red: 0.06, green: 0.42, blue: 0.86, alpha: 0.45),
            dark: UIColor(red: 0.14, green: 0.54, blue: 1.0, alpha: 0.55)
        )
        static let actionSecondary = adaptive(
            light: UIColor(red: 0.84, green: 0.89, blue: 0.96, alpha: 1.0),
            dark: UIColor.white.withAlphaComponent(0.12)
        )
        static let actionSecondaryDisabled = adaptive(
            light: UIColor(red: 0.84, green: 0.89, blue: 0.96, alpha: 0.55),
            dark: UIColor.white.withAlphaComponent(0.06)
        )
        static let textPrimary = adaptive(light: .black, dark: .white)
        static let textSecondary = adaptive(
            light: UIColor.black.withAlphaComponent(0.72),
            dark: UIColor.white.withAlphaComponent(0.76)
        )
        static let textTertiary = adaptive(
            light: UIColor.black.withAlphaComponent(0.56),
            dark: UIColor.white.withAlphaComponent(0.60)
        )
        static let border = adaptive(
            light: UIColor.black.withAlphaComponent(0.10),
            dark: UIColor.white.withAlphaComponent(0.12)
        )
        static let borderStrong = adaptive(
            light: UIColor.black.withAlphaComponent(0.18),
            dark: UIColor.white.withAlphaComponent(0.20)
        )
        static let overlay = adaptive(
            light: UIColor.black.withAlphaComponent(0.62),
            dark: UIColor.black.withAlphaComponent(0.72)
        )
        static let qualityGood = UIColor.systemGreen
        static let qualityOk = UIColor.systemOrange
        static let qualityBad = UIColor.systemRed

        private static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
            UIColor { traits in
                switch traits.userInterfaceStyle {
                case .dark:
                    return dark
                default:
                    return light
                }
            }
        }
    }

    enum Typography {
        static func largeTitle() -> UIFont { font(.largeTitle, 32, .bold) }
        static func title() -> UIFont { font(.title2, 20, .bold) }
        static func body() -> UIFont { font(.body, 15, .regular) }
        static func bodyEmphasis() -> UIFont { font(.body, 15, .semibold) }
        static func caption() -> UIFont { font(.footnote, 13, .medium) }
        static func button() -> UIFont { font(.headline, 17, .semibold) }
        static func buttonSecondary() -> UIFont { font(.subheadline, 15, .semibold) }

        private static func font(_ style: UIFont.TextStyle, _ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont.systemFont(ofSize: size, weight: weight))
        }
    }

    enum Spacing {
        static let xs: CGFloat = 6
        static let s: CGFloat = 10
        static let m: CGFloat = 14
        static let l: CGFloat = 18
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum CornerRadius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let large: CGFloat = 18
        static let xl: CGFloat = 22
    }

    enum ButtonStyle {
        case primary
        case secondary
        case destructive
    }

    enum ButtonSize {
        case large
        case regular
    }

    static func applyButton(_ button: UIButton, title: String, style: ButtonStyle, size: ButtonSize = .regular) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.clipsToBounds = true
        ensureMinimumHitTarget(for: button)

        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.cornerStyle = .large
            config.contentInsets = contentInsets(for: size)
            config.attributedTitle = AttributedString(title, attributes: AttributeContainer([
                .font: (size == .large ? Typography.button() : Typography.buttonSecondary())
            ]))

            switch style {
            case .primary:
                config.baseForegroundColor = Colors.textPrimary
                config.baseBackgroundColor = Colors.actionPrimary
            case .secondary:
                config.baseForegroundColor = Colors.textPrimary
                config.baseBackgroundColor = Colors.actionSecondary
            case .destructive:
                config.baseForegroundColor = Colors.textPrimary
                config.baseBackgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
            }

            button.configuration = config
            button.configurationUpdateHandler = { btn in
                guard var cfg = btn.configuration else { return }
                let enabled = btn.isEnabled
                cfg.baseBackgroundColor = backgroundColor(for: style, enabled: enabled)
                cfg.baseForegroundColor = Colors.textPrimary.withAlphaComponent(enabled ? 1.0 : 0.7)
                btn.configuration = cfg
                btn.alpha = enabled ? 1.0 : 0.7
            }
        } else {
            button.setTitle(title, for: .normal)
            button.setTitleColor(Colors.textPrimary, for: .normal)
            button.titleLabel?.font = (size == .large ? Typography.button() : Typography.buttonSecondary())
            button.layer.cornerRadius = (size == .large ? CornerRadius.xl : CornerRadius.large)
            button.contentEdgeInsets = legacyInsets(for: size)
            button.backgroundColor = backgroundColor(for: style, enabled: button.isEnabled)
            button.adjustsImageWhenDisabled = false
        }
    }

    static func updateButtonEnabled(_ button: UIButton, style: ButtonStyle) {
        button.alpha = button.isEnabled ? 1.0 : 0.7
        if #available(iOS 15.0, *) {
            button.configurationUpdateHandler?(button)
        } else {
            button.backgroundColor = backgroundColor(for: style, enabled: button.isEnabled)
        }
    }

    static func hapticPrimary() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    private static func contentInsets(for size: ButtonSize) -> NSDirectionalEdgeInsets {
        switch size {
        case .large:
            return NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        case .regular:
            return NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        }
    }

    private static func legacyInsets(for size: ButtonSize) -> UIEdgeInsets {
        switch size {
        case .large:
            return UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        case .regular:
            return UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        }
    }

    private static func backgroundColor(for style: ButtonStyle, enabled: Bool) -> UIColor {
        switch style {
        case .primary:
            return enabled ? Colors.actionPrimary : Colors.actionPrimaryDisabled
        case .secondary:
            return enabled ? Colors.actionSecondary : Colors.actionSecondaryDisabled
        case .destructive:
            return UIColor.systemRed.withAlphaComponent(enabled ? 0.9 : 0.55)
        }
    }

    private static func ensureMinimumHitTarget(for button: UIButton) {
        if button.constraints.contains(where: { $0.firstAttribute == .height && $0.relation == .greaterThanOrEqual && abs($0.constant - 44) < 0.5 }) {
            return
        }
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }
}
