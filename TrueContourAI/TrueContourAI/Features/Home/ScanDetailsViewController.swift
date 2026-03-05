import UIKit

final class ScanDetailsViewController: UIViewController {
    private let item: ScanService.ScanItem
    private let summary: ScanService.ScanSummary?
    private let previousSummary: ScanService.ScanSummary?

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = DesignSystem.Spacing.s
        return stack
    }()

    init(item: ScanService.ScanItem, summary: ScanService.ScanSummary?, previousSummary: ScanService.ScanSummary?) {
        self.item = item
        self.summary = summary
        self.previousSummary = previousSummary
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable, message: "Programmatic-only. Use init(item:summary:previousSummary:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("scan.details.title")
        view.backgroundColor = DesignSystem.Colors.background
        configureNavigation()
        buildUI()
        populateRows()
    }

    private func configureNavigation() {
        let closeStyle: UIBarButtonItem.Style
        if #available(iOS 26.0, *) {
            closeStyle = .prominent
        } else {
            closeStyle = .done
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L("common.close"),
            style: closeStyle,
            target: self,
            action: #selector(closeTapped)
        )
    }

    private func buildUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func populateRows() {
        addHeader(title: item.displayName, subtitle: Self.dateFormatter.string(from: item.date))

        guard let summary else {
            addBody(L("scan.details.missing"))
            return
        }

        addSection(title: L("scan.details.section.quality"))
        let qualityText = String(format: L("scan.details.quality.value"), Int((max(0, min(1, summary.overallConfidence)) * 100).rounded()))
        addMetric(label: L("scan.details.quality"), value: qualityText)
        addMetric(label: L("scan.details.points"), value: Self.countFormatter.string(from: NSNumber(value: summary.pointCountEstimate)) ?? "\(summary.pointCountEstimate)")
        addMetric(label: L("scan.details.duration"), value: String(format: L("scan.details.duration.value"), Int(summary.durationSeconds.rounded())))

        addSection(title: L("scan.details.section.measurements"))
        if let measured = summary.derivedMeasurements {
            addMetric(label: L("scan.details.circumference"), value: String(format: L("scan.details.mm.value"), Int(measured.circumferenceMm.rounded())))
            addMetric(label: L("scan.details.width"), value: String(format: L("scan.details.mm.value"), Int(measured.widthMm.rounded())))
            addMetric(label: L("scan.details.depth"), value: String(format: L("scan.details.mm.value"), Int(measured.depthMm.rounded())))
        } else {
            addBody(L("scan.details.measurements.unavailable"))
        }

        addSection(title: L("scan.details.section.trend"))
        if let previousSummary {
            let trend = ScanInsightFormatter.makeTrend(current: summary, previous: previousSummary)
            addBody(HomeDisplayFormatter.trend(trend).compactText)
        } else {
            addBody(L("scan.details.trend.unavailable"))
        }
    }

    private func addHeader(title: String, subtitle: String) {
        let titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.font = DesignSystem.Typography.title()
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.text = title

        let subtitleLabel = UILabel()
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textColor = DesignSystem.Colors.textTertiary
        subtitleLabel.font = DesignSystem.Typography.caption()
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.text = subtitle

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
    }

    private func addSection(title: String) {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        DesignSystem.applyCardSurface(card, floating: false)
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textColor = DesignSystem.Colors.textSecondary
        label.font = DesignSystem.Typography.bodyEmphasis()
        label.adjustsFontForContentSizeCategory = true
        label.text = title
        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: DesignSystem.Spacing.s),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DesignSystem.Spacing.m),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DesignSystem.Spacing.m),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DesignSystem.Spacing.s)
        ])
        stackView.addArrangedSubview(card)
    }

    private func addMetric(label: String, value: String) {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        DesignSystem.applyCardSurface(card, floating: false)
        let metricLabel = UILabel()
        metricLabel.translatesAutoresizingMaskIntoConstraints = false
        metricLabel.numberOfLines = 0
        metricLabel.textColor = DesignSystem.Colors.textPrimary
        metricLabel.font = DesignSystem.Typography.body()
        metricLabel.adjustsFontForContentSizeCategory = true
        metricLabel.text = "\(label): \(value)"
        card.addSubview(metricLabel)
        NSLayoutConstraint.activate([
            metricLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: DesignSystem.Spacing.s),
            metricLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DesignSystem.Spacing.m),
            metricLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DesignSystem.Spacing.m),
            metricLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DesignSystem.Spacing.s)
        ])
        stackView.addArrangedSubview(card)
    }

    private func addBody(_ text: String) {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        DesignSystem.applyCardSurface(card, floating: false)
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textColor = DesignSystem.Colors.textPrimary
        label.font = DesignSystem.Typography.body()
        label.adjustsFontForContentSizeCategory = true
        label.text = text
        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: DesignSystem.Spacing.s),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DesignSystem.Spacing.m),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DesignSystem.Spacing.m),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DesignSystem.Spacing.s)
        ])
        stackView.addArrangedSubview(card)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let countFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}
