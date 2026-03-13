import UIKit

final class HowToScanViewController: UIViewController {

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = L("howto.title")
        l.textColor = DesignSystem.Colors.textPrimary
        l.font = DesignSystem.Typography.title()
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = L("howto.subtitle")
        l.textColor = DesignSystem.Colors.textSecondary
        l.font = DesignSystem.Typography.caption()
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.alwaysBounceVertical = true
        s.showsVerticalScrollIndicator = true
        return s
    }()

    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let stack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.spacing = 12
        return s
    }()

    private let faqTitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = L("howto.faq.title")
        l.textColor = DesignSystem.Colors.textPrimary
        l.font = DesignSystem.Typography.bodyEmphasis()
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private let faqStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.spacing = 10
        return s
    }()

    private lazy var closeButton: UIButton = {
        let b = UIButton(type: .system)
        DesignSystem.applyButton(b, title: L("howto.close"), style: .secondary, size: .regular)
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        b.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        b.accessibilityLabel = L("howto.close")
        b.accessibilityIdentifier = "howToCloseButton"
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.background

        view.addSubview(closeButton)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(stack)
        contentView.addSubview(faqTitleLabel)
        contentView.addSubview(faqStack)

        stack.addArrangedSubview(HowToRow(title: L("howto.step1.title"), body: L("howto.step1.body"), iconName: "lightbulb"))
        stack.addArrangedSubview(HowToRow(title: L("howto.step2.title"), body: L("howto.step2.body"), iconName: "person.crop.circle"))
        stack.addArrangedSubview(HowToRow(title: L("howto.step3.title"), body: L("howto.step3.body"), iconName: "arrow.triangle.2.circlepath"))
        stack.addArrangedSubview(HowToRow(title: L("howto.step4.title"), body: L("howto.step4.body"), iconName: "checkmark.circle"))

        faqStack.addArrangedSubview(HowToRow(title: L("howto.faq.q1"), body: L("howto.faq.a1"), iconName: "waveform.path.ecg"))
        faqStack.addArrangedSubview(HowToRow(title: L("howto.faq.q2"), body: L("howto.faq.a2"), iconName: "ear"))
        faqStack.addArrangedSubview(HowToRow(title: L("howto.faq.q3"), body: L("howto.faq.a3"), iconName: "hourglass"))

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            stack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            faqTitleLabel.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 18),
            faqTitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            faqTitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            faqStack.topAnchor.constraint(equalTo: faqTitleLabel.bottomAnchor, constant: 10),
            faqStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            faqStack.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            faqStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])
    }

    @objc private func closeTapped() { dismiss(animated: true) }
}

private final class HowToRow: UIView {
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let iconView = UIImageView()

    init(title: String, body: String, iconName: String? = nil) {
        super.init(frame: .zero)
        configure(title: title, body: body, iconName: iconName)
    }

    @available(*, unavailable, message: "Programmatic-only. Use init(title:body:iconName:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    private func configure(title: String, body: String, iconName: String?) {
        translatesAutoresizingMaskIntoConstraints = false
        DesignSystem.applyCardSurface(self, floating: false)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let iconName, let image = UIImage(systemName: iconName) {
            iconView.image = image
        }
        iconView.tintColor = DesignSystem.Colors.textSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.font = DesignSystem.Typography.bodyEmphasis()
        titleLabel.adjustsFontForContentSizeCategory = true

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.text = body
        bodyLabel.textColor = DesignSystem.Colors.textSecondary
        bodyLabel.font = DesignSystem.Typography.body()
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.numberOfLines = 0

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            bodyLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
}
