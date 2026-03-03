import UIKit

final class RecentScansView: UIView {
    let sectionLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = DesignSystem.Colors.textPrimary
        l.font = DesignSystem.Typography.bodyEmphasis()
        l.adjustsFontForContentSizeCategory = true
        l.text = L("home.recentscans")
        return l
    }()

    let sortControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [
            L("home.recentscans.sort.date"),
            L("home.recentscans.sort.quality")
        ])
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0
        control.backgroundColor = DesignSystem.Colors.surface
        control.selectedSegmentTintColor = DesignSystem.Colors.surfaceSecondary
        control.accessibilityIdentifier = "recentScansSortControl"
        control.accessibilityLabel = L("home.recentscans.sort.accessibility")
        control.accessibilityHint = L("home.recentscans.sort.hint")
        return control
    }()

    let filterControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [
            L("home.recentscans.filter.all"),
            L("home.recentscans.filter.goodplus")
        ])
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0
        control.backgroundColor = DesignSystem.Colors.surface
        control.selectedSegmentTintColor = DesignSystem.Colors.surfaceSecondary
        control.accessibilityIdentifier = "recentScansFilterControl"
        control.accessibilityLabel = L("home.recentscans.filter.accessibility")
        control.accessibilityHint = L("home.recentscans.filter.hint")
        return control
    }()

    let tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .plain)
        t.translatesAutoresizingMaskIntoConstraints = false
        t.backgroundColor = .clear
        t.separatorStyle = .none
        t.showsVerticalScrollIndicator = false
        t.alwaysBounceVertical = false
        return t
    }()

    let emptyLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = DesignSystem.Colors.textTertiary
        l.font = DesignSystem.Typography.body()
        l.adjustsFontForContentSizeCategory = true
        l.numberOfLines = 0
        l.textAlignment = .center
        l.text = L("home.empty")
        l.isHidden = true
        return l
    }()

    let emptyCTAButton: UIButton = {
        let b = UIButton(type: .system)
        DesignSystem.applyButton(b, title: L("home.empty.cta"), style: .secondary, size: .regular)
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        b.isHidden = true
        b.accessibilityIdentifier = "emptyStartScanButton"
        b.accessibilityLabel = L("home.accessibility.start")
        b.accessibilityHint = L("home.accessibility.start.hint")
        return b
    }()

    let clearFilterButton: UIButton = {
        let b = UIButton(type: .system)
        DesignSystem.applyButton(b, title: L("home.empty.filtered.clear"), style: .secondary, size: .regular)
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        b.isHidden = true
        b.accessibilityIdentifier = "emptyClearFilterButton"
        b.accessibilityLabel = L("home.empty.filtered.clear")
        b.accessibilityHint = L("home.empty.filtered.clear.hint")
        return b
    }()

    private let controlsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
        return stack
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
        sortControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        filterControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        controlsStack.addArrangedSubview(sortControl)
        controlsStack.addArrangedSubview(filterControl)

        addSubview(sectionLabel)
        addSubview(controlsStack)
        addSubview(tableView)
        addSubview(emptyLabel)
        addSubview(emptyCTAButton)
        addSubview(clearFilterButton)

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: topAnchor),
            sectionLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            sectionLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            controlsStack.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 10),
            controlsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            controlsStack.trailingAnchor.constraint(equalTo: trailingAnchor),

            tableView.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),

            emptyCTAButton.topAnchor.constraint(equalTo: emptyLabel.bottomAnchor, constant: 12),
            emptyCTAButton.centerXAnchor.constraint(equalTo: emptyLabel.centerXAnchor),

            clearFilterButton.topAnchor.constraint(equalTo: emptyLabel.bottomAnchor, constant: 12),
            clearFilterButton.centerXAnchor.constraint(equalTo: emptyLabel.centerXAnchor)
        ])
    }
}
