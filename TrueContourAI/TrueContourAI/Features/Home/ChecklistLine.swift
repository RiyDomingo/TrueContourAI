import UIKit

final class ChecklistLine: UIView {
    private let iconView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = DesignSystem.Colors.surfaceSecondary
        v.layer.cornerRadius = 6
        return v
    }()

    private let label: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = DesignSystem.Colors.textPrimary
        l.font = DesignSystem.Typography.bodyEmphasis()
        l.adjustsFontForContentSizeCategory = true
        l.numberOfLines = 0
        return l
    }()

    init(text: String) {
        super.init(frame: .zero)
        configure(text: text)
    }

    @available(*, unavailable, message: "Programmatic-only. Use init(text:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    private func configure(text: String) {
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        addSubview(label)
        label.text = text
        isAccessibilityElement = true
        accessibilityLabel = text
        accessibilityTraits = .staticText
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 10),
            iconView.heightAnchor.constraint(equalToConstant: 10),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
