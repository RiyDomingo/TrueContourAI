//
//  HomeViewController.swift
//  TrueContourAI
//

import UIKit
import StandardCyborgUI
import StandardCyborgFusion

final class HomeViewController: UIViewController {

    // MARK: - Data model

    private typealias ScanItem = ScanService.ScanItem

    // MARK: - State
    private let dependencies: AppDependencies

    private var scans: [ScanItem] = []
    private let scanFlowState = ScanFlowState()

    private let scanService: ScanService
    private lazy var homeViewModel = HomeViewModel(scanService: scanService)

    private let settingsStore: SettingsStore
    private var scanStartTime: CFAbsoluteTime?
    private var latestScanMetrics: ScanFlowState.ScanSessionMetrics?
    private lazy var toastPresenter = HomeToastPresenter(hostView: view)
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
        earServiceFactory: dependencies.earServiceFactory,
        onToast: { [weak self] message in
            self?.showToast(message)
        }
    )

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.scanService = dependencies.scanService
        self.settingsStore = dependencies.settingsStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable, message: "Programmatic-only. Use init(dependencies:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

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

    private let headerView = HomeHeaderView()
    private let deviceSmokeDiagnosticsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = DesignSystem.Colors.textSecondary
        label.font = DesignSystem.Typography.caption()
        label.numberOfLines = 0
        label.accessibilityIdentifier = "deviceSmokeDiagnosticsLabel"
        label.isHidden = true
        return label
    }()
    private let startScanCardView = StartScanCardView()
    private let actionRowView = HomeActionRowView()
    private let recentScansView = RecentScansView()

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.background

        buildUI()
        wireActions()

        recentScansView.tableView.dataSource = self
        recentScansView.tableView.delegate = self
        recentScansView.tableView.register(ScanCardCell.self, forCellReuseIdentifier: ScanCardCell.reuseID)

        if case .failure = scanService.ensureScansRootFolder() {
            presentStorageUnavailableAlert()
        }
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
        refreshDeviceSmokeDiagnosticsIfNeeded()
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

        contentView.addSubview(headerView)
        contentView.addSubview(deviceSmokeDiagnosticsLabel)
        contentView.addSubview(startScanCardView)
        contentView.addSubview(actionRowView)
        contentView.addSubview(recentScansView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 18),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            deviceSmokeDiagnosticsLabel.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            deviceSmokeDiagnosticsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            deviceSmokeDiagnosticsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            startScanCardView.topAnchor.constraint(equalTo: deviceSmokeDiagnosticsLabel.bottomAnchor, constant: 16),
            startScanCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            startScanCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            actionRowView.topAnchor.constraint(equalTo: startScanCardView.bottomAnchor, constant: 12),
            actionRowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            actionRowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            recentScansView.topAnchor.constraint(equalTo: actionRowView.bottomAnchor, constant: 18),
            recentScansView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            recentScansView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            recentScansView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func wireActions() {
        startScanCardView.startScanButton.addTarget(self, action: #selector(startScanTapped), for: .touchUpInside)
        recentScansView.emptyCTAButton.addTarget(self, action: #selector(startScanTapped), for: .touchUpInside)
        recentScansView.clearFilterButton.addTarget(self, action: #selector(clearFilterTapped), for: .touchUpInside)
        startScanCardView.howToScanButton.addTarget(self, action: #selector(howToScanTapped), for: .touchUpInside)
        actionRowView.viewLastScanButton.addTarget(self, action: #selector(viewLastScanTapped), for: .touchUpInside)
        actionRowView.openScansFolderButton.addTarget(self, action: #selector(openScansFolderTapped), for: .touchUpInside)
        headerView.settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        recentScansView.sortControl.addTarget(self, action: #selector(sortModeChanged), for: .valueChanged)
        recentScansView.filterControl.addTarget(self, action: #selector(filterModeChanged), for: .valueChanged)

        startScanCardView.startScanButton.accessibilityLabel = L("home.accessibility.start")
        startScanCardView.startScanButton.accessibilityHint = L("home.accessibility.start.hint")
        startScanCardView.startScanButton.accessibilityIdentifier = "startScanButton"
    }

    // MARK: - Actions

    @objc private func startScanTapped() {
        DesignSystem.hapticPrimary()
        if settingsStore.showPreScanChecklist {
            homeCoordinator.presentPreScanChecklist(from: self) { [weak self] in
                self?.startScanFlow()
            }
        } else {
            startScanFlow()
        }
    }

    private func startScanFlow() {
        latestScanMetrics = nil
        scanCoordinator.startScanFlow(from: self, delegate: self, scanFlowState: scanFlowState) { [weak self] _ in
            self?.recordScanStarted()
        }
    }

    @objc private func viewLastScanTapped() {
        homeCoordinator.openLastScan(from: self)
    }

    @objc private func openScansFolderTapped() {
        homeCoordinator.presentScansFolderShare(from: self, sourceView: actionRowView.openScansFolderButton)
    }

    @objc private func howToScanTapped() {
        homeCoordinator.presentHowToScan(from: self)
    }

    @objc private func settingsTapped() {
        homeCoordinator.presentSettings(from: self)
    }

    @objc private func sortModeChanged() {
        let selectedIndex = recentScansView.sortControl.selectedSegmentIndex
        let mode = HomeViewModel.ScanSortMode(rawValue: selectedIndex) ?? .dateNewest
        homeViewModel.updateSortMode(mode)
    }

    @objc private func filterModeChanged() {
        let selectedIndex = recentScansView.filterControl.selectedSegmentIndex
        let mode = HomeViewModel.ScanFilterMode(rawValue: selectedIndex) ?? .all
        homeViewModel.updateFilterMode(mode)
    }

    @objc private func clearFilterTapped() {
        homeViewModel.updateFilterMode(.all)
    }

    // MARK: - Scans folder I/O

    private func applyHomeViewModel() {
        scans = homeViewModel.scans
        let trendDisplay = homeViewModel.trend.map(HomeDisplayFormatter.trend)
        headerView.applySubtitle(
            baseText: L("home.subtitle"),
            trendText: trendDisplay?.compactText,
            trendAccessibilityText: trendDisplay?.accessibilityText
        )
        recentScansView.sortControl.selectedSegmentIndex = homeViewModel.sortMode.rawValue
        recentScansView.filterControl.selectedSegmentIndex = homeViewModel.filterMode.rawValue
        let noScansAtAll = homeViewModel.totalScanCount == 0
        let filteredOut = homeViewModel.isEmpty && !noScansAtAll && homeViewModel.filterMode == .goodPlus
        recentScansView.emptyLabel.isHidden = !homeViewModel.isEmpty
        if filteredOut {
            recentScansView.emptyLabel.text = L("home.empty.filtered.goodplus")
            recentScansView.emptyCTAButton.isHidden = true
            recentScansView.clearFilterButton.isHidden = false
        } else {
            recentScansView.emptyLabel.text = L("home.empty")
            recentScansView.emptyCTAButton.isHidden = !homeViewModel.isEmpty
            recentScansView.clearFilterButton.isHidden = true
        }
        recentScansView.emptyCTAButton.isAccessibilityElement = !recentScansView.emptyCTAButton.isHidden
        recentScansView.clearFilterButton.isAccessibilityElement = !recentScansView.clearFilterButton.isHidden
        recentScansView.tableView.reloadData()
        recentScansView.tableView.alwaysBounceVertical = !homeViewModel.isEmpty
        actionRowView.viewLastScanButton.isEnabled = homeViewModel.canViewLast
        DesignSystem.updateButtonEnabled(actionRowView.viewLastScanButton, style: .secondary)
    }

    // MARK: - Helpers

    private func showToast(_ message: String) {
#if DEBUG
        if message.hasPrefix("diag:") {
            updateDeviceSmokeDiagnostics(message.replacingOccurrences(of: "diag:", with: ""))
            return
        }
#endif
        toastPresenter.show(message: message)
    }

    private func presentStorageUnavailableAlert() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.presentedViewController == nil else { return }
            let alert = UIAlertController(
                title: L("scan.storage.unavailable.title"),
                message: L("scan.storage.unavailable.message"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L("common.ok"), style: .default))
            self.present(alert, animated: true)
        }
    }

#if DEBUG
    private func refreshDeviceSmokeDiagnosticsIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("ui-test-device-smoke") else {
            deviceSmokeDiagnosticsLabel.isHidden = true
            deviceSmokeDiagnosticsLabel.text = nil
            return
        }

        let snapshot = ScanDiagnostics.snapshot()
        guard snapshot.lastExportFolderName != nil || snapshot.scanStartTimestamp != nil || snapshot.finalizeCompletionTimestamp != nil else {
            deviceSmokeDiagnosticsLabel.isHidden = true
            deviceSmokeDiagnosticsLabel.text = nil
            return
        }

        updateDeviceSmokeDiagnostics(
            "gltf=\(snapshot.hasSceneGLTF ? 1 : 0),obj=\(snapshot.hasHeadMeshOBJ ? 1 : 0),folder=\(snapshot.lastExportFolderName ?? "none")"
        )
    }

    private func updateDeviceSmokeDiagnostics(_ text: String) {
        guard ProcessInfo.processInfo.arguments.contains("ui-test-device-smoke") else { return }
        deviceSmokeDiagnosticsLabel.text = text
        deviceSmokeDiagnosticsLabel.accessibilityLabel = text
        deviceSmokeDiagnosticsLabel.isHidden = false
    }
#else
    private func refreshDeviceSmokeDiagnosticsIfNeeded() {}
#endif

}

// MARK: - UITableView

extension HomeViewController: UITableViewDataSource, UITableViewDelegate {

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
        let insightDisplay = homeViewModel.insight(for: item).map(HomeDisplayFormatter.insight)
        let badgeDisplay = homeViewModel.qualityBadge(for: item).map(HomeDisplayFormatter.qualityBadge)
        cell.configure(
            title: item.displayName,
            date: item.date,
            thumbnailURL: item.thumbnailURL,
            detailText: insightDisplay?.compactText,
            accessibilityDetail: insightDisplay?.accessibilityText,
            qualityBadge: badgeDisplay
        )

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

extension HomeViewController {
}
// MARK: - Scanning delegate

extension HomeViewController: AppScanningViewControllerDelegate {

    func appScanningViewControllerDidCancel(_ controller: AppScanningViewController) {
        recordScanCanceled()
        scanFlowState.failCurrentScan()
        dismiss(animated: true)
    }

    func appScanningViewController(
        _ controller: AppScanningViewController,
        didScan pointCloud: SCPointCloud,
        meshTexturing: SCMeshTexturing
    ) {
        recordScanCompleted()
        latestScanMetrics = scanFlowState.completeScanSession(estimatedConfidence: 0)
        previewCoordinator.presentPreviewAfterScan(
            from: controller,
            pointCloud: pointCloud,
            meshTexturing: meshTexturing,
            sessionMetrics: latestScanMetrics
        )
    }

}

// MARK: - Scan timing

private extension HomeViewController {
    func recordScanStarted() {
        scanStartTime = CFAbsoluteTimeGetCurrent()
        Log.scan.info("Scan started")
#if DEBUG
        ScanDiagnostics.recordScanStart()
#endif
    }

    func recordScanCompleted() {
        if let start = scanStartTime {
            let duration = CFAbsoluteTimeGetCurrent() - start
            Log.scan.info("Scan completed in \(duration, privacy: .public)s")
        } else {
            Log.scan.info("Scan completed (duration unavailable)")
        }
        scanStartTime = nil
#if DEBUG
        ScanDiagnostics.recordFinalizeCompletion()
#endif
    }

    func recordScanCanceled() {
        if let start = scanStartTime {
            let duration = CFAbsoluteTimeGetCurrent() - start
            Log.scan.info("Scan canceled after \(duration, privacy: .public)s")
        } else {
            Log.scan.info("Scan canceled (duration unavailable)")
        }
        scanStartTime = nil
    }
}

#if DEBUG
extension HomeViewController {
    func _recordScanStartedForTesting() { recordScanStarted() }
    func _recordScanCompletedForTesting() { recordScanCompleted() }
    func _recordScanCanceledForTesting() { recordScanCanceled() }
    func _scanStartTimeForTesting() -> CFAbsoluteTime? { scanStartTime }
}
#endif
