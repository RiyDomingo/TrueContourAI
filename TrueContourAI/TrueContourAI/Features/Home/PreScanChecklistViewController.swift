import UIKit

final class PreScanChecklistViewController: UIViewController {

    var onStateChanged: ((Bool, Bool, Bool, Bool) -> Void)?
    var onStart: (() -> Void)?
    var initialDontShowAgain = false

    private var goodLighting = false
    private var hairClear = false
    private var headStill = false
    private var dontShowAgain = false

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = L("precheck.title")
        l.textColor = DesignSystem.Colors.textPrimary
        l.font = DesignSystem.Typography.title()
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = L("precheck.subtitle")
        l.textColor = DesignSystem.Colors.textSecondary
        l.font = DesignSystem.Typography.caption()
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private let stack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.spacing = 10
        return s
    }()

    private let startButton: UIButton = {
        let b = UIButton(type: .system)
        DesignSystem.applyButton(b, title: L("precheck.start"), style: .primary, size: .large)
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        b.isEnabled = false
        DesignSystem.updateButtonEnabled(b, style: .primary)
        return b
    }()

    private let dontShowSwitch = UISwitch()
    private let dontShowLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = L("precheck.dontshow")
        l.textColor = DesignSystem.Colors.textSecondary
        l.font = DesignSystem.Typography.caption()
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private lazy var rowLighting = ChecklistToggleRow(text: L("checklist.lighting")) { [weak self] on in
        self?.goodLighting = on
        self?.syncState()
    }
    private lazy var rowHair = ChecklistToggleRow(text: L("checklist.hair")) { [weak self] on in
        self?.hairClear = on
        self?.syncState()
    }
    private lazy var rowHeadStill = ChecklistToggleRow(text: L("checklist.headstill")) { [weak self] on in
        self?.headStill = on
        self?.syncState()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.background

        let close = UIButton(type: .system)
        DesignSystem.applyButton(close, title: L("precheck.close"), style: .secondary, size: .regular)
        close.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        close.accessibilityLabel = L("precheck.close.label")
        close.accessibilityIdentifier = "preScanChecklistCloseButton"

        view.addSubview(close)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(stack)
        contentView.addSubview(startButton)

        stack.addArrangedSubview(rowLighting)
        stack.addArrangedSubview(rowHair)
        stack.addArrangedSubview(rowHeadStill)

        let dontShowRow = UIView()
        dontShowRow.translatesAutoresizingMaskIntoConstraints = false
        dontShowSwitch.translatesAutoresizingMaskIntoConstraints = false
        dontShowSwitch.onTintColor = DesignSystem.Colors.actionPrimary
        dontShowSwitch.addTarget(self, action: #selector(dontShowToggled), for: .valueChanged)
        dontShowSwitch.accessibilityLabel = L("precheck.dontshow.label")
        dontShowSwitch.isOn = initialDontShowAgain
        dontShowAgain = initialDontShowAgain
        dontShowRow.addSubview(dontShowLabel)
        dontShowRow.addSubview(dontShowSwitch)

        NSLayoutConstraint.activate([
            dontShowLabel.leadingAnchor.constraint(equalTo: dontShowRow.leadingAnchor),
            dontShowLabel.centerYAnchor.constraint(equalTo: dontShowRow.centerYAnchor),
            dontShowSwitch.trailingAnchor.constraint(equalTo: dontShowRow.trailingAnchor),
            dontShowSwitch.centerYAnchor.constraint(equalTo: dontShowRow.centerYAnchor),
            dontShowRow.heightAnchor.constraint(equalToConstant: 44)
        ])

        stack.addArrangedSubview(dontShowRow)

        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        startButton.accessibilityLabel = L("precheck.start.label")
        startButton.accessibilityHint = L("precheck.start.hint")
        startButton.accessibilityIdentifier = "preScanChecklistStartButton"
        syncState()

        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            close.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: close.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -18),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            stack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -18),

            startButton.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 16),
            startButton.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            startButton.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            startButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])
    }

    @objc private func dontShowToggled() {
        dontShowAgain = dontShowSwitch.isOn
        syncState()
    }

    private func syncState() {
        let ready = goodLighting && hairClear && headStill
        startButton.isEnabled = ready
        DesignSystem.updateButtonEnabled(startButton, style: .primary)
        onStateChanged?(goodLighting, hairClear, headStill, dontShowAgain)
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    @objc private func startTapped() {
        DesignSystem.hapticPrimary()
        dismiss(animated: true) { [weak self] in self?.onStart?() }
    }
}

private final class ChecklistToggleRow: UIView {

    private let label = UILabel()
    private let toggle = UISwitch()
    private let onChanged: (Bool) -> Void

    init(text: String, onChanged: @escaping (Bool) -> Void) {
        self.onChanged = onChanged
        super.init(frame: .zero)
        configure(text: text)
    }

    @objc private func toggled() { onChanged(toggle.isOn) }

    @available(*, unavailable, message: "Programmatic-only. Use init(text:onChanged:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    private func configure(text: String) {
        translatesAutoresizingMaskIntoConstraints = false
        DesignSystem.applyCardSurface(self, floating: false)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = DesignSystem.Colors.textPrimary
        label.font = DesignSystem.Typography.bodyEmphasis()
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0

        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.addTarget(self, action: #selector(toggled), for: .valueChanged)
        toggle.accessibilityLabel = text

        addSubview(label)
        addSubview(toggle)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 54),

            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            label.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -12),

            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
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
