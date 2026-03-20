import UIKit

struct HomeAssembler {
    private let dependencies: AppDependencies
    private let makeSettingsViewController: (@escaping () -> Void) -> SettingsViewController
    private let makeScanCoordinator: () -> ScanCoordinator
    private let makePreviewCoordinator: (
        _ presenter: UIViewController,
        _ scanFlowState: ScanFlowState,
        _ previewSessionState: PreviewSessionState,
        _ onToast: ((String) -> Void)?
    ) -> PreviewCoordinator

    init(
        dependencies: AppDependencies,
        makeSettingsViewController: @escaping (@escaping () -> Void) -> SettingsViewController,
        makeScanCoordinator: @escaping () -> ScanCoordinator,
        makePreviewCoordinator: @escaping (
            _ presenter: UIViewController,
            _ scanFlowState: ScanFlowState,
            _ previewSessionState: PreviewSessionState,
            _ onToast: ((String) -> Void)?
        ) -> PreviewCoordinator
    ) {
        self.dependencies = dependencies
        self.makeSettingsViewController = makeSettingsViewController
        self.makeScanCoordinator = makeScanCoordinator
        self.makePreviewCoordinator = makePreviewCoordinator
    }

    func makeHomeViewController() -> HomeViewController {
        let scanFlowState = ScanFlowState()
        let previewSessionState = PreviewSessionState()
        let homeViewModel = HomeViewModel(scanService: dependencies.scanRepository)
        let scanSessionController = HomeScanSessionController(environment: dependencies.environment)
        let feedbackController = HomeFeedbackController(
            environment: dependencies.environment,
            diagnosticsTextProvider: {
                scanSessionController.deviceSmokeDiagnosticsText()
            }
        )
        let scanCoordinator = makeScanCoordinator()
        let homeCoordinator = HomeCoordinator(
            scanService: dependencies.scanRepository,
            settingsStore: dependencies.settingsStore,
            previewSessionState: previewSessionState,
            makeSettingsViewController: makeSettingsViewController
        )
        let recentScansController = HomeRecentScansController(
            onOpenScan: { [weak homeViewModel, weak homeCoordinator] folderURL in
                guard let item = homeViewModel?.scanItem(for: folderURL) else { return }
                homeCoordinator?.onOpenScan?(item)
            },
            onPresentActions: { [weak homeViewModel, weak homeCoordinator] folderURL, sourceView in
                guard let controller = homeCoordinator?.hostViewController,
                      let homeCoordinator,
                      let item = homeViewModel?.scanItem(for: folderURL) else { return }
                homeCoordinator.presentScanActions(for: item, sourceView: sourceView, from: controller)
            }
        )
        let controller = HomeViewController(
            homeViewModel: homeViewModel,
            feedbackController: feedbackController,
            homeCoordinator: homeCoordinator,
            recentScansController: recentScansController
        )
        homeCoordinator.hostViewController = controller
        let previewCoordinator = makePreviewCoordinator(
            controller,
            scanFlowState,
            previewSessionState,
            { [weak feedbackController] message in
                feedbackController?.handleToast(message)
            }
        )
        homeCoordinator.onOpenScan = { [weak previewCoordinator] item in
            previewCoordinator?.presentExistingScan(item)
        }
        let scanFlowController = HomeScanFlowController(
            settingsStore: dependencies.settingsStore,
            scanCoordinator: scanCoordinator,
            homeCoordinator: homeCoordinator,
            previewCoordinator: previewCoordinator,
            scanFlowState: scanFlowState,
            scanSessionController: scanSessionController
        )
        controller.scanFlowController = scanFlowController
        controller.scanSessionController = scanSessionController
        controller.previewCoordinator = previewCoordinator
        return controller
    }
}
