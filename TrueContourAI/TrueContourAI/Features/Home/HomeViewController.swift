//
//  HomeViewController.swift
//  TrueContourAI
//

import UIKit
import StandardCyborgUI
import StandardCyborgFusion

final class HomeViewController: UIViewController {

    // MARK: - State
    private let environment: AppEnvironment
    private let earServiceFactory: () -> EarLandmarksService?

    private let scanFlowState = ScanFlowState()
    private let previewSessionState = PreviewSessionState()

    private let scanListing: any ScanListing
    private let scanLibrary: any HomeScanManaging & SettingsScanServicing
    private let previewScanService: any PreviewScanReading
    private let scanExporter: ScanExporting
    private lazy var homeViewModel = HomeViewModel(scanService: scanListing)

    private let settingsStore: SettingsStore
    private lazy var scanSessionController = HomeScanSessionController(environment: environment)
    private lazy var toastPresenter = HomeToastPresenter(hostView: view, environment: environment)
    private lazy var scanCoordinator = ScanCoordinator(settingsStore: settingsStore, environment: environment)
    private lazy var homeCoordinator = HomeCoordinator(
        scanService: scanLibrary,
        settingsStore: settingsStore,
        previewSessionState: previewSessionState
    )
    private lazy var previewCoordinator = ScanPreviewCoordinator(
        presenter: self,
        scanService: previewScanService,
        settingsStore: settingsStore,
        scanFlowState: scanFlowState,
        previewSessionState: previewSessionState,
        environment: environment,
        scanExporter: scanExporter,
        earServiceFactory: earServiceFactory,
        onToast: { [weak self] message in
            self?.showToast(message)
        }
    )
    private lazy var recentScansController = HomeRecentScansController(
        hostViewController: self,
        homeViewModel: homeViewModel,
        homeCoordinator: homeCoordinator,
        previewCoordinator: previewCoordinator
    )
    private lazy var scanFlowController = HomeScanFlowController(
        settingsStore: settingsStore,
        scanCoordinator: scanCoordinator,
        homeCoordinator: homeCoordinator,
        previewCoordinator: previewCoordinator,
        scanFlowState: scanFlowState,
        scanSessionController: scanSessionController
    )

    init(dependencies: AppDependencies) {
        self.environment = dependencies.environment
        self.earServiceFactory = dependencies.earServiceFactory
        self.scanListing = dependencies.scanRepository
        self.scanLibrary = dependencies.scanRepository
        self.previewScanService = dependencies.scanRepository
        self.scanExporter = dependencies.scanExporter
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

        recentScansController.attach(to: recentScansView.tableView)

        if case .failure = scanLibrary.ensureScansRootFolder() {
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
        scanFlowController.startScan(from: self, delegate: self)
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
        let viewState = homeViewModel.makeViewState()
        recentScansController.updateScans(viewState.scans)
        let trendDisplay = viewState.trend.map(HomeDisplayFormatter.trend)
        headerView.applySubtitle(
            baseText: L("home.subtitle"),
            trendText: trendDisplay?.compactText,
            trendAccessibilityText: trendDisplay?.accessibilityText
        )
        recentScansView.sortControl.selectedSegmentIndex = viewState.sortMode.rawValue
        recentScansView.filterControl.selectedSegmentIndex = viewState.filterMode.rawValue
        recentScansView.emptyLabel.isHidden = !viewState.isEmpty
        if viewState.isFilteredEmpty {
            recentScansView.emptyLabel.text = L("home.empty.filtered.goodplus")
            recentScansView.emptyCTAButton.isHidden = true
            recentScansView.clearFilterButton.isHidden = false
        } else {
            recentScansView.emptyLabel.text = L("home.empty")
            recentScansView.emptyCTAButton.isHidden = !viewState.isEmpty
            recentScansView.clearFilterButton.isHidden = true
        }
        recentScansView.emptyCTAButton.isAccessibilityElement = !recentScansView.emptyCTAButton.isHidden
        recentScansView.clearFilterButton.isAccessibilityElement = !recentScansView.clearFilterButton.isHidden
        recentScansView.tableView.reloadData()
        recentScansView.tableView.alwaysBounceVertical = !viewState.isEmpty
        actionRowView.viewLastScanButton.isEnabled = viewState.canViewLast
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
        guard environment.isDeviceSmokeMode else {
            deviceSmokeDiagnosticsLabel.isHidden = true
            deviceSmokeDiagnosticsLabel.text = nil
            return
        }

        guard let diagnosticsText = scanSessionController.deviceSmokeDiagnosticsText() else {
            deviceSmokeDiagnosticsLabel.isHidden = true
            deviceSmokeDiagnosticsLabel.text = nil
            return
        }

        updateDeviceSmokeDiagnostics(diagnosticsText)
    }

    private func updateDeviceSmokeDiagnostics(_ text: String) {
        guard environment.isDeviceSmokeMode else { return }
        deviceSmokeDiagnosticsLabel.text = text
        deviceSmokeDiagnosticsLabel.accessibilityLabel = text
        deviceSmokeDiagnosticsLabel.isHidden = false
    }
#else
    private func refreshDeviceSmokeDiagnosticsIfNeeded() {}
#endif

}

// MARK: - Scanning delegate

extension HomeViewController: AppScanningViewControllerDelegate {

    func appScanningViewControllerDidCancel(_ controller: AppScanningViewController) {
        scanFlowController.handleScanCanceled(from: self)
    }

    func appScanningViewController(
        _ controller: AppScanningViewController,
        didScan pointCloud: SCPointCloud,
        meshTexturing: SCMeshTexturing
    ) {
        scanFlowController.handleScanCompleted(
            from: controller,
            pointCloud: pointCloud,
            meshTexturing: meshTexturing
        )
    }

}
#if DEBUG
extension HomeViewController {
    func _recordScanStartedForTesting() { scanSessionController.recordScanStarted() }
    func _recordScanCompletedForTesting() { scanSessionController.recordScanCompleted() }
    func _recordScanCanceledForTesting() { scanSessionController.recordScanCanceled() }
    func _scanStartTimeForTesting() -> CFAbsoluteTime? { scanSessionController.scanStartTimeForTesting() }
}
#endif
