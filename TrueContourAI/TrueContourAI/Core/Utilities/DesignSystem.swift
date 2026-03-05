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
            light: UIColor.black.withAlphaComponent(0.52),
            dark: UIColor.black.withAlphaComponent(0.62)
        )
        static let overlayCard = adaptive(
            light: UIColor.black.withAlphaComponent(0.44),
            dark: UIColor.black.withAlphaComponent(0.56)
        )
        static let elevatedCard = adaptive(
            light: UIColor.white.withAlphaComponent(0.94),
            dark: UIColor(red: 0.10, green: 0.13, blue: 0.20, alpha: 0.94)
        )
        static let floatingCard = adaptive(
            light: UIColor(red: 0.94, green: 0.96, blue: 1.00, alpha: 0.92),
            dark: UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 0.92)
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
        static func title() -> UIFont { font(.title2, 22, .semibold) }
        static func body() -> UIFont { font(.body, 16, .regular) }
        static func bodyEmphasis() -> UIFont { font(.body, 16, .semibold) }
        static func caption() -> UIFont { font(.footnote, 13, .medium) }
        static func button() -> UIFont { font(.headline, 17, .semibold) }
        static func buttonSecondary() -> UIFont { font(.subheadline, 16, .semibold) }

        private static func font(_ style: UIFont.TextStyle, _ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont.systemFont(ofSize: size, weight: weight))
        }
    }

    enum Spacing {
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
    }

    enum CornerRadius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xl: CGFloat = 24
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

    static func applyCardSurface(_ view: UIView, floating: Bool) {
        view.backgroundColor = floating ? Colors.floatingCard : Colors.elevatedCard
        view.layer.cornerRadius = floating ? CornerRadius.large : CornerRadius.medium
        view.layer.borderWidth = 1
        view.layer.borderColor = Colors.border.cgColor
        view.layer.masksToBounds = true
    }

    static func applyStatusChip(_ label: UILabel, style: StatusChipStyle) {
        label.textAlignment = .center
        label.font = Typography.caption()
        label.adjustsFontForContentSizeCategory = true
        label.layer.cornerRadius = CornerRadius.small
        label.layer.masksToBounds = true
        switch style {
        case .good:
            label.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.92)
            label.textColor = .white
        case .caution:
            label.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.92)
            label.textColor = .white
        case .critical:
            label.backgroundColor = UIColor.systemRed.withAlphaComponent(0.92)
            label.textColor = .white
        }
    }

    enum StatusChipStyle {
        case good
        case caution
        case critical
    }

    private static func contentInsets(for size: ButtonSize) -> NSDirectionalEdgeInsets {
        switch size {
        case .large:
            return NSDirectionalEdgeInsets(top: 16, leading: 22, bottom: 16, trailing: 22)
        case .regular:
            return NSDirectionalEdgeInsets(top: 13, leading: 18, bottom: 13, trailing: 18)
        }
    }

    private static func legacyInsets(for size: ButtonSize) -> UIEdgeInsets {
        switch size {
        case .large:
            return UIEdgeInsets(top: 16, left: 22, bottom: 16, right: 22)
        case .regular:
            return UIEdgeInsets(top: 13, left: 18, bottom: 13, right: 18)
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

enum BottomSheetSnapPoint: CaseIterable {
    case collapsed
    case half
    case full
}

protocol BottomSheetControllerDelegate: AnyObject {
    func bottomSheetController(_ controller: BottomSheetController, didSnapTo point: BottomSheetSnapPoint)
}

final class BottomSheetController: NSObject {
    weak var delegate: BottomSheetControllerDelegate?

    let containerView = UIView()
    let handleView = UIView()
    let contentView = UIView()

    private weak var hostView: UIView?
    private var heightConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var snapHeights: [BottomSheetSnapPoint: CGFloat] = [:]
    private(set) var currentSnapPoint: BottomSheetSnapPoint = .collapsed
    private var panStartHeight: CGFloat = 0

    func install(in hostView: UIView, bottomInset: CGFloat = 12) {
        if containerView.superview != nil { return }
        self.hostView = hostView

        containerView.translatesAutoresizingMaskIntoConstraints = false
        DesignSystem.applyCardSurface(containerView, floating: true)
        containerView.accessibilityIdentifier = "bottomSheetContainer"

        handleView.translatesAutoresizingMaskIntoConstraints = false
        handleView.backgroundColor = DesignSystem.Colors.borderStrong
        handleView.layer.cornerRadius = 2
        handleView.accessibilityIdentifier = "bottomSheetHandle"

        contentView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(handleView)
        containerView.addSubview(contentView)
        hostView.addSubview(containerView)

        let heightConstraint = containerView.heightAnchor.constraint(equalToConstant: 180)
        let bottomConstraint = containerView.bottomAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.bottomAnchor, constant: -bottomInset)
        self.heightConstraint = heightConstraint
        self.bottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            containerView.trailingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            bottomConstraint,
            heightConstraint,

            handleView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            handleView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            handleView.widthAnchor.constraint(equalToConstant: 42),
            handleView.heightAnchor.constraint(equalToConstant: 4),

            contentView.topAnchor.constraint(equalTo: handleView.bottomAnchor, constant: 10),
            contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        containerView.addGestureRecognizer(pan)
    }

    func setSnapHeights(collapsed: CGFloat, half: CGFloat, full: CGFloat) {
        snapHeights = [
            .collapsed: max(120, collapsed),
            .half: max(collapsed, half),
            .full: max(half, full)
        ]
        setSnapPoint(currentSnapPoint, animated: false)
    }

    func setSnapPoint(_ snapPoint: BottomSheetSnapPoint, animated: Bool) {
        guard let target = snapHeights[snapPoint], let heightConstraint else { return }
        currentSnapPoint = snapPoint
        let animations = {
            heightConstraint.constant = target
            self.hostView?.layoutIfNeeded()
        }
        if animated {
            UIView.animate(
                withDuration: 0.22,
                delay: 0,
                usingSpringWithDamping: 0.9,
                initialSpringVelocity: 0.18,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: animations
            )
        } else {
            animations()
        }
        delegate?.bottomSheetController(self, didSnapTo: snapPoint)
    }

    private func nearestSnapPoint(for height: CGFloat) -> BottomSheetSnapPoint {
        let points = BottomSheetSnapPoint.allCases
        return points.min {
            let lhs = abs((snapHeights[$0] ?? 0) - height)
            let rhs = abs((snapHeights[$1] ?? 0) - height)
            return lhs < rhs
        } ?? .half
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let hostView, let heightConstraint else { return }
        let translation = gesture.translation(in: hostView)
        switch gesture.state {
        case .began:
            panStartHeight = heightConstraint.constant
        case .changed:
            let full = snapHeights[.full] ?? panStartHeight
            let collapsed = snapHeights[.collapsed] ?? panStartHeight
            let candidate = panStartHeight - translation.y
            heightConstraint.constant = min(full, max(collapsed, candidate))
        case .ended, .cancelled, .failed:
            let velocityY = gesture.velocity(in: hostView).y
            if abs(velocityY) > 300 {
                if velocityY < 0 {
                    if currentSnapPoint == .collapsed {
                        setSnapPoint(.half, animated: true)
                    } else {
                        setSnapPoint(.full, animated: true)
                    }
                } else {
                    if currentSnapPoint == .full {
                        setSnapPoint(.half, animated: true)
                    } else {
                        setSnapPoint(.collapsed, animated: true)
                    }
                }
            } else {
                setSnapPoint(nearestSnapPoint(for: heightConstraint.constant), animated: true)
            }
        default:
            break
        }
    }
}

final class StatusRowView: UIView {
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let titleLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.clear
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = DesignSystem.Colors.textPrimary
        spinner.hidesWhenStopped = true
        spinner.accessibilityIdentifier = "statusRowSpinner"

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.font = DesignSystem.Typography.caption()
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 1
        titleLabel.accessibilityIdentifier = "statusRowTitle"

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.textColor = DesignSystem.Colors.textPrimary
        badgeLabel.font = DesignSystem.Typography.caption()
        badgeLabel.adjustsFontForContentSizeCategory = true
        badgeLabel.backgroundColor = DesignSystem.Colors.surfaceSecondary
        badgeLabel.layer.cornerRadius = DesignSystem.CornerRadius.small
        badgeLabel.layer.masksToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.isHidden = true
        badgeLabel.accessibilityIdentifier = "statusRowBadge"

        addSubview(spinner)
        addSubview(titleLabel)
        addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
            spinner.leadingAnchor.constraint(equalTo: leadingAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
            badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            badgeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 52),
            badgeLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    @available(*, unavailable, message: "Programmatic-only.")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func setStatus(text: String, percent: Int?, spinning: Bool) {
        titleLabel.text = text
        if spinning {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
        if let percent {
            badgeLabel.isHidden = false
            badgeLabel.text = " \(percent)% "
        } else {
            badgeLabel.isHidden = true
        }
        accessibilityLabel = percent.map { "\(text) \($0)%" } ?? text
    }
}
