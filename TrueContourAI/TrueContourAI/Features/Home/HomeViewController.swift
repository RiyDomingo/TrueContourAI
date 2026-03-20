import UIKit
import StandardCyborgUI
import StandardCyborgFusion

final class HomeViewController: UIViewController {
    private let homeViewModel: HomeViewModel
    private let feedbackController: HomeFeedbackController
    private let homeCoordinator: HomeCoordinator
    private let recentScansController: HomeRecentScansController

    var previewCoordinator: PreviewCoordinator?
    var scanFlowController: HomeScanFlowController?
    var scanSessionController: HomeScanSessionController?

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
    private let startScanCardView = StartScanCardView()
    private let actionRowView = HomeActionRowView()
    private let recentScansView = RecentScansView()

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    init(
        homeViewModel: HomeViewModel,
        feedbackController: HomeFeedbackController,
        homeCoordinator: HomeCoordinator,
        recentScansController: HomeRecentScansController
    ) {
        self.homeViewModel = homeViewModel
        self.feedbackController = feedbackController
        self.homeCoordinator = homeCoordinator
        self.recentScansController = recentScansController
        super.init(nibName: nil, bundle: nil)
        feedbackController.attach(hostViewController: self)
    }

    @available(*, unavailable, message: "Programmatic-only. Use HomeAssembler.")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.background

        buildUI()
        wireActions()
        recentScansController.attach(to: recentScansView.tableView)

        homeCoordinator.presentStorageUnavailableIfNeeded(from: self)

        homeViewModel.onStateChange = { [weak self] in
            self?.apply(state: $0)
        }
        homeViewModel.onEffect = { [weak self] effect in
            switch effect {
            case .refreshDiagnostics:
                self?.feedbackController.refreshDiagnosticsIfNeeded()
            }
        }

        homeCoordinator.onScansChanged = { [weak self] in
            self?.homeViewModel.send(.scansChangedExternally)
        }
        previewCoordinator?.onScansChanged = { [weak self] in
            self?.homeViewModel.send(.scansChangedExternally)
        }

        homeViewModel.send(.viewDidLoad)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        homeViewModel.send(.viewWillAppear)
    }

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
        contentView.addSubview(feedbackController.diagnosticsLabel)
        contentView.addSubview(startScanCardView)
        contentView.addSubview(actionRowView)
        contentView.addSubview(recentScansView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 18),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            feedbackController.diagnosticsLabel.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            feedbackController.diagnosticsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            feedbackController.diagnosticsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            startScanCardView.topAnchor.constraint(equalTo: feedbackController.diagnosticsLabel.bottomAnchor, constant: 16),
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

    @objc private func startScanTapped() {
        DesignSystem.hapticPrimary()
        scanFlowController?.startScan(from: self, delegate: self)
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
        let mode = HomeViewModel.ScanSortMode(rawValue: recentScansView.sortControl.selectedSegmentIndex) ?? .dateNewest
        homeViewModel.send(.sortChanged(mode))
    }

    @objc private func filterModeChanged() {
        let mode = HomeViewModel.ScanFilterMode(rawValue: recentScansView.filterControl.selectedSegmentIndex) ?? .all
        homeViewModel.send(.filterChanged(mode))
    }

    @objc private func clearFilterTapped() {
        homeViewModel.send(.clearFilter)
    }

    private func apply(state: HomeState) {
        let viewData = state.viewData
        recentScansController.updateRows(viewData.scanRows)
        headerView.applySubtitle(
            baseText: viewData.subtitleText,
            trendText: viewData.trendText,
            trendAccessibilityText: viewData.trendAccessibilityText
        )
        recentScansView.sortControl.selectedSegmentIndex = viewData.selectedSortMode.rawValue
        recentScansView.filterControl.selectedSegmentIndex = viewData.selectedFilterMode.rawValue
        recentScansView.emptyLabel.isHidden = !viewData.isEmpty
        if viewData.isFilteredEmpty {
            recentScansView.emptyLabel.text = L("home.empty.filtered.goodplus")
            recentScansView.emptyCTAButton.isHidden = true
            recentScansView.clearFilterButton.isHidden = false
        } else {
            recentScansView.emptyLabel.text = L("home.empty")
            recentScansView.emptyCTAButton.isHidden = !viewData.isEmpty
            recentScansView.clearFilterButton.isHidden = true
        }
        recentScansView.emptyCTAButton.isAccessibilityElement = !recentScansView.emptyCTAButton.isHidden
        recentScansView.clearFilterButton.isAccessibilityElement = !recentScansView.clearFilterButton.isHidden
        recentScansView.tableView.reloadData()
        recentScansView.tableView.alwaysBounceVertical = !viewData.isEmpty
        actionRowView.viewLastScanButton.isEnabled = viewData.canViewLast
        DesignSystem.updateButtonEnabled(actionRowView.viewLastScanButton, style: .secondary)
    }
}

extension HomeViewController: AppScanningViewControllerDelegate {
    func appScanningViewControllerDidCancel(_ controller: AppScanningViewController) {
        scanFlowController?.handleScanCanceled(from: self)
    }

    func appScanningViewController(_ controller: AppScanningViewController, didCompleteScan payload: ScanPreviewInput) {
        scanFlowController?.handleScanCompleted(from: controller, payload: payload)
    }

    func appScanningViewController(_ controller: AppScanningViewController, didScan pointCloud: SCPointCloud, meshTexturing: SCMeshTexturing) {}
}

#if DEBUG
extension HomeViewController {
    func _recordScanStartedForTesting() { scanSessionController?.recordScanStarted() }
    func _recordScanCompletedForTesting() { scanSessionController?.recordScanCompleted() }
    func _recordScanCanceledForTesting() { scanSessionController?.recordScanCanceled() }
    func _scanStartTimeForTesting() -> CFAbsoluteTime? { scanSessionController?.scanStartTimeForTesting() }
    func debug_triggerScansChanged() { homeCoordinator.onScansChanged?() }
    func debug_homeViewModel() -> HomeViewModel { homeViewModel }
}
#endif
