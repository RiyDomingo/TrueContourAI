//
//  ViewController.swift
//  TrueContourAI
//

import UIKit
import StandardCyborgUI
import StandardCyborgFusion

final class ViewController: UIViewController {

    // MARK: - Data model

    private typealias ScanItem = ScanService.ScanItem

    // MARK: - State

    private var scans: [ScanItem] = []
    private let scanFlowState = ScanFlowState()

    private let scanService = ScanService()
    private lazy var homeViewModel = HomeViewModel(scanService: scanService)

    private let settingsStore = SettingsStore()
    private lazy var scanCoordinator = ScanCoordinator(settingsStore: settingsStore)
    private lazy var homeCoordinator = HomeCoordinator(
        scanService: scanService,
        settingsStore: settingsStore,
        scanFlowState: scanFlowState
    )
    private lazy var previewCoordinator = ScanPreviewCoordinator(
        presenter: self,
        scanService: scanService,
        settingsStore: settingsStore,
        scanFlowState: scanFlowState,
        onToast: { [weak self] message in
            self?.showToast(message)
        }
    )

    // MARK: - UI

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

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = L("home.title")
        l.textColor = .white
        l.font = UIFontMetrics(forTextStyle: .title1)
            .scaledFont(for: .systemFont(ofSize: 32, weight: .bold))
        l.adjustsFontForContentSizeCategory = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var settingsButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        if let img = UIImage(systemName: "gearshape") {
            b.setImage(img, for: .normal)
        } else {
            b.setTitle(L("common.settings"), for: .normal)
        }
        b.tintColor = .white
        b.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        b.accessibilityLabel = L("common.settings")
        b.accessibilityIdentifier = "settingsButton"
        return b
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = L("home.subtitle")
        l.textColor = UIColor.white.withAlphaComponent(0.75)
        l.font = UIFontMetrics(forTextStyle: .subheadline)
            .scaledFont(for: .systemFont(ofSize: 15, weight: .semibold))
        l.adjustsFontForContentSizeCategory = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let startCard: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        v.layer.cornerRadius = 18
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        return v
    }()

    private let startCardTitle: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = L("home.start.title")
        l.textColor = .white
        l.font = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: .systemFont(ofSize: 18, weight: .bold))
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private let startCardSubtitle: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = L("home.start.subtitle")
        l.textColor = UIColor.white.withAlphaComponent(0.75)
        l.font = UIFontMetrics(forTextStyle: .subheadline)
            .scaledFont(for: .systemFont(ofSize: 13, weight: .medium))
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private let checklistStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.spacing = 8
        return s
    }()

    private let checklistLine1 = ChecklistLine(text: L("checklist.lighting"))
    private let checklistLine2 = ChecklistLine(text: L("checklist.hair"))
    private let checklistLine3 = ChecklistLine(text: L("checklist.headstill"))

    private lazy var startScanButton: UIButton = {
        return makePrimaryButton(title: L("home.start.button"))
    }()

    private let startCardFooter: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = UIColor.white.withAlphaComponent(0.65)
        l.font = UIFontMetrics(forTextStyle: .footnote)
            .scaledFont(for: .systemFont(ofSize: 12, weight: .regular))
        l.adjustsFontForContentSizeCategory = true
        l.numberOfLines = 0
        l.text = L("home.tip")
        return l
    }()

    private lazy var howToScanButton: UIButton = {
        let b = makeSecondaryButton(title: L("home.howto"))
        b.accessibilityLabel = L("home.howto.accessibility")
        b.accessibilityHint = L("home.howto.accessibility.hint")
        b.accessibilityIdentifier = "howToScanButton"
        return b
    }()

    private let actionRow: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .horizontal
        s.spacing = 10
        s.distribution = .fillEqually
        return s
    }()

    private lazy var viewLastScanButton: UIButton = {
        return makeSecondaryButton(title: L("home.viewlast"))
    }()

    private lazy var openScansFolderButton: UIButton = {
        return makeSecondaryButton(title: L("home.scansfolder"))
    }()

    private let sectionLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = UIColor.white.withAlphaComponent(0.9)
        l.font = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: .systemFont(ofSize: 16, weight: .bold))
        l.adjustsFontForContentSizeCategory = true
        l.text = L("home.recentscans")
        return l
    }()

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = UIColor.white.withAlphaComponent(0.65)
        l.font = UIFontMetrics(forTextStyle: .body)
            .scaledFont(for: .systemFont(ofSize: 14, weight: .regular))
        l.adjustsFontForContentSizeCategory = true
        l.numberOfLines = 0
        l.textAlignment = .center
        l.text = L("home.empty")
        l.isHidden = true
        return l
    }()

    private lazy var emptyCTAButton: UIButton = {
        let b = makeSecondaryButton(title: L("home.empty.cta"))
        b.isHidden = true
        b.accessibilityIdentifier = "emptyStartScanButton"
        b.accessibilityLabel = L("home.accessibility.start")
        b.accessibilityHint = L("home.accessibility.start.hint")
        return b
    }()

    private let tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .plain)
        t.translatesAutoresizingMaskIntoConstraints = false
        t.backgroundColor = .clear
        t.separatorStyle = .none
        t.showsVerticalScrollIndicator = false
        t.alwaysBounceVertical = false
        return t
    }()

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.03, green: 0.05, blue: 0.10, alpha: 1.0)

        buildUI()
        wireActions()
        view.accessibilityElements = [
            titleLabel,
            subtitleLabel,
            settingsButton,
            startCardTitle,
            startCardSubtitle,
            checklistLine1,
            checklistLine2,
            checklistLine3,
            startScanButton,
            startCardFooter,
            howToScanButton,
            viewLastScanButton,
            openScansFolderButton,
            sectionLabel,
            tableView,
            emptyLabel,
            emptyCTAButton
        ]

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ScanCardCell.self, forCellReuseIdentifier: ScanCardCell.reuseID)

        scanService.ensureScansRootFolder()
        homeViewModel.onChange = { [weak self] in
            self?.applyHomeViewModel()
        }
        homeViewModel.refresh()

        homeCoordinator.onScansChanged = { [weak self] in
            self?.homeViewModel.refresh()
        }
        homeCoordinator.onOpenScan = { [weak self] item in
            self?.previewCoordinator.presentExistingScan(item)
        }
        previewCoordinator.onScansChanged = { [weak self] in
            self?.homeViewModel.refresh()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        homeViewModel.refresh()
    }

    // MARK: - Button builders (fix iOS15+ contentEdgeInsets warnings)

    private func makePrimaryButton(title: String) -> UIButton {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false

        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.baseForegroundColor = .white
            config.baseBackgroundColor = UIColor(red: 0.14, green: 0.54, blue: 1.0, alpha: 0.95)
            config.cornerStyle = .large
            config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
            var attrs = AttributeContainer()
            attrs.font = UIFontMetrics(forTextStyle: .headline)
                .scaledFont(for: .systemFont(ofSize: 18, weight: .semibold))
            config.attributedTitle = AttributedString(title, attributes: attrs)
            b.configuration = config
        } else {
            b.setTitle(title, for: .normal)
            b.setTitleColor(.white, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
            b.backgroundColor = UIColor(red: 0.14, green: 0.54, blue: 1.0, alpha: 0.95)
            b.layer.cornerRadius = 16
            b.contentEdgeInsets = UIEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
        }

        return b
    }

    private func makeSecondaryButton(title: String) -> UIButton {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false

        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.baseForegroundColor = .white
            config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.10)
            config.cornerStyle = .large
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
            var attrs = AttributeContainer()
            attrs.font = UIFontMetrics(forTextStyle: .subheadline)
                .scaledFont(for: .systemFont(ofSize: 15, weight: .semibold))
            config.attributedTitle = AttributedString(title, attributes: attrs)
            b.configuration = config
        } else {
            b.setTitle(title, for: .normal)
            b.setTitleColor(.white, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            b.backgroundColor = UIColor.white.withAlphaComponent(0.10)
            b.layer.cornerRadius = 14
            b.contentEdgeInsets = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        }

        return b
    }

    // MARK: - UI Layout

    private func buildUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        let topStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        topStack.axis = .vertical
        topStack.spacing = 4
        topStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(topStack)
        contentView.addSubview(settingsButton)

        checklistStack.addArrangedSubview(checklistLine1)
        checklistStack.addArrangedSubview(checklistLine2)
        checklistStack.addArrangedSubview(checklistLine3)

        startCard.addSubview(startCardTitle)
        startCard.addSubview(startCardSubtitle)
        startCard.addSubview(checklistStack)
        startCard.addSubview(startScanButton)
        startCard.addSubview(startCardFooter)
        startCard.addSubview(howToScanButton)
        contentView.addSubview(startCard)

        actionRow.addArrangedSubview(viewLastScanButton)
        actionRow.addArrangedSubview(openScansFolderButton)
        contentView.addSubview(actionRow)

        contentView.addSubview(sectionLabel)
        contentView.addSubview(tableView)
        contentView.addSubview(emptyLabel)
        contentView.addSubview(emptyCTAButton)

        NSLayoutConstraint.activate([
            topStack.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 18),
            topStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            topStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            settingsButton.centerYAnchor.constraint(equalTo: topStack.topAnchor),
            settingsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            settingsButton.widthAnchor.constraint(equalToConstant: 32),
            settingsButton.heightAnchor.constraint(equalToConstant: 32),

            startCard.topAnchor.constraint(equalTo: topStack.bottomAnchor, constant: 16),
            startCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            startCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            startCardTitle.topAnchor.constraint(equalTo: startCard.topAnchor, constant: 16),
            startCardTitle.leadingAnchor.constraint(equalTo: startCard.leadingAnchor, constant: 16),
            startCardTitle.trailingAnchor.constraint(equalTo: startCard.trailingAnchor, constant: -16),

            startCardSubtitle.topAnchor.constraint(equalTo: startCardTitle.bottomAnchor, constant: 4),
            startCardSubtitle.leadingAnchor.constraint(equalTo: startCard.leadingAnchor, constant: 16),
            startCardSubtitle.trailingAnchor.constraint(equalTo: startCard.trailingAnchor, constant: -16),

            checklistStack.topAnchor.constraint(equalTo: startCardSubtitle.bottomAnchor, constant: 12),
            checklistStack.leadingAnchor.constraint(equalTo: startCard.leadingAnchor, constant: 16),
            checklistStack.trailingAnchor.constraint(equalTo: startCard.trailingAnchor, constant: -16),

            startScanButton.topAnchor.constraint(equalTo: checklistStack.bottomAnchor, constant: 14),
            startScanButton.leadingAnchor.constraint(equalTo: startCard.leadingAnchor, constant: 16),
            startScanButton.trailingAnchor.constraint(equalTo: startCard.trailingAnchor, constant: -16),

            startCardFooter.topAnchor.constraint(equalTo: startScanButton.bottomAnchor, constant: 10),
            startCardFooter.leadingAnchor.constraint(equalTo: startCard.leadingAnchor, constant: 16),
            startCardFooter.trailingAnchor.constraint(equalTo: startCard.trailingAnchor, constant: -16),

            howToScanButton.topAnchor.constraint(equalTo: startCardFooter.bottomAnchor, constant: 10),
            howToScanButton.leadingAnchor.constraint(equalTo: startCard.leadingAnchor, constant: 16),
            howToScanButton.trailingAnchor.constraint(equalTo: startCard.trailingAnchor, constant: -16),
            howToScanButton.bottomAnchor.constraint(equalTo: startCard.bottomAnchor, constant: -14),

            actionRow.topAnchor.constraint(equalTo: startCard.bottomAnchor, constant: 12),
            actionRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            actionRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            sectionLabel.topAnchor.constraint(equalTo: actionRow.bottomAnchor, constant: 18),
            sectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            sectionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            tableView.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),

            emptyCTAButton.topAnchor.constraint(equalTo: emptyLabel.bottomAnchor, constant: 12),
            emptyCTAButton.centerXAnchor.constraint(equalTo: emptyLabel.centerXAnchor)
        ])
    }

    private func wireActions() {
        startScanButton.addTarget(self, action: #selector(startScanTapped), for: .touchUpInside)
        emptyCTAButton.addTarget(self, action: #selector(startScanTapped), for: .touchUpInside)
        howToScanButton.addTarget(self, action: #selector(howToScanTapped), for: .touchUpInside)
        viewLastScanButton.addTarget(self, action: #selector(viewLastScanTapped), for: .touchUpInside)
        openScansFolderButton.addTarget(self, action: #selector(openScansFolderTapped), for: .touchUpInside)

        startScanButton.accessibilityLabel = L("home.accessibility.start")
        startScanButton.accessibilityHint = L("home.accessibility.start.hint")
        viewLastScanButton.accessibilityLabel = L("home.accessibility.viewlast")
        viewLastScanButton.accessibilityHint = L("home.accessibility.viewlast.hint")
        openScansFolderButton.accessibilityLabel = L("home.accessibility.scansfolder")
        openScansFolderButton.accessibilityHint = L("home.accessibility.scansfolder.hint")

        startScanButton.accessibilityIdentifier = "startScanButton"
        viewLastScanButton.accessibilityIdentifier = "viewLastScanButton"
        openScansFolderButton.accessibilityIdentifier = "openScansFolderButton"
    }

    // MARK: - Actions

    @objc private func startScanTapped() {
        if settingsStore.showPreScanChecklist {
            homeCoordinator.presentPreScanChecklist(from: self) { [weak self] in
                self?.startScanFlow()
            }
        } else {
            startScanFlow()
        }
    }

    private func startScanFlow() {
        scanCoordinator.startScanFlow(from: self, delegate: self, scanFlowState: scanFlowState) { _ in }
    }

    @objc private func viewLastScanTapped() {
        homeCoordinator.openLastScan(from: self)
    }

    @objc private func openScansFolderTapped() {
        homeCoordinator.presentScansFolderShare(from: self, sourceView: openScansFolderButton)
    }

    @objc private func howToScanTapped() {
        homeCoordinator.presentHowToScan(from: self)
    }

    @objc private func settingsTapped() {
        homeCoordinator.presentSettings(from: self)
    }

    // MARK: - Scans folder I/O

    private func applyHomeViewModel() {
        scans = homeViewModel.scans
        emptyLabel.isHidden = !homeViewModel.isEmpty
        emptyCTAButton.isHidden = !homeViewModel.isEmpty
        tableView.reloadData()
        tableView.alwaysBounceVertical = !homeViewModel.isEmpty
        viewLastScanButton.isEnabled = homeViewModel.canViewLast
        viewLastScanButton.alpha = homeViewModel.canViewLast ? 1.0 : 0.5
    }

    // MARK: - Helpers

    private func showToast(_ message: String) {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.alpha = 0

        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18)
        ])

        UIView.animate(withDuration: 0.22) { label.alpha = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            UIView.animate(withDuration: 0.22, animations: { label.alpha = 0 }) { _ in
                label.removeFromSuperview()
            }
        }
    }

}

// MARK: - UITableView

extension ViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        scans.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ScanCardCell.reuseID,
            for: indexPath
        ) as? ScanCardCell else {
            return UITableViewCell()
        }

        let item = scans[indexPath.row]
        cell.configure(title: item.displayName, date: item.date, thumbnailURL: item.thumbnailURL)

        // Open = in-app preview (NO share sheet)
        cell.onOpenTapped = { [weak self] in
            self?.previewCoordinator.presentExistingScan(item)
        }

        // Share = share sheet
        cell.onMoreTapped = { [weak self] sourceView in
            guard let self else { return }
            self.homeCoordinator.presentScanActions(for: item, sourceView: sourceView ?? cell, from: self)
        }

        return cell
    }
}

// MARK: - UITableView actions + share

extension ViewController {
}
// MARK: - Scanning delegate

extension ViewController: ScanningViewControllerDelegate {

    func scanningViewControllerDidCancel(_ controller: ScanningViewController) {
        dismiss(animated: true)
    }

    func scanningViewController(_ controller: ScanningViewController, didScan pointCloud: SCPointCloud) {
        previewCoordinator.presentPreviewAfterScan(
            from: controller,
            pointCloud: pointCloud,
            meshTexturing: controller.meshTexturing
        )
    }

}

// MARK: - UI bits used by the home screen

private final class ChecklistLine: UIView {
    private let iconView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        v.layer.cornerRadius = 5
        return v
    }()
    private let label: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = UIColor.white.withAlphaComponent(0.90)
        l.font = UIFontMetrics(forTextStyle: .body)
            .scaledFont(for: .systemFont(ofSize: 14, weight: .medium))
        l.adjustsFontForContentSizeCategory = true
        l.numberOfLines = 0
        return l
    }()
    init(text: String) {
        super.init(frame: .zero)
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
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
