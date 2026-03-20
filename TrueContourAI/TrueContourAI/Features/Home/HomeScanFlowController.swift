import UIKit
import StandardCyborgFusion

final class HomeScanFlowController {
    private let runtimeSettings: any AppSettingsReading
    private let scanCoordinator: ScanCoordinator
    private let homeCoordinator: HomeCoordinator
    private let previewCoordinator: PreviewCoordinator
    private let scanFlowState: ScanFlowState
    private let scanSessionController: HomeScanSessionController
    private var latestScanMetrics: ScanFlowState.ScanSessionMetrics?

    init(
        runtimeSettings: any AppSettingsReading,
        scanCoordinator: ScanCoordinator,
        homeCoordinator: HomeCoordinator,
        previewCoordinator: PreviewCoordinator,
        scanFlowState: ScanFlowState,
        scanSessionController: HomeScanSessionController
    ) {
        self.runtimeSettings = runtimeSettings
        self.scanCoordinator = scanCoordinator
        self.homeCoordinator = homeCoordinator
        self.previewCoordinator = previewCoordinator
        self.scanFlowState = scanFlowState
        self.scanSessionController = scanSessionController
    }

    func startScan(from presenter: UIViewController, delegate: AppScanningViewControllerDelegate) {
        if runtimeSettings.showPreScanChecklist {
            homeCoordinator.presentPreScanChecklist(from: presenter) { [weak self, weak presenter] in
                guard let self, let presenter else { return }
                self.startScanAfterChecklist(from: presenter, delegate: delegate)
            }
            return
        }

        startScanAfterChecklist(from: presenter, delegate: delegate)
    }

    func handleScanCanceled(from presenter: UIViewController) {
        scanSessionController.recordScanCanceled()
        scanFlowState.failCurrentScan()
        presenter.dismiss(animated: true)
    }

    func handleScanCompleted(
        from controller: UIViewController,
        payload: ScanPreviewInput
    ) {
        scanSessionController.recordScanCompleted()
        latestScanMetrics = scanFlowState.completeScanSession()
        previewCoordinator.presentPreviewAfterScan(
            from: controller,
            payload: payload,
            sessionMetrics: latestScanMetrics
        )
    }

    private func startScanAfterChecklist(from presenter: UIViewController, delegate: AppScanningViewControllerDelegate) {
        latestScanMetrics = nil
        scanCoordinator.startScanFlow(from: presenter, delegate: delegate, scanFlowState: scanFlowState) { [weak self] _ in
            self?.scanSessionController.recordScanStarted()
        }
    }
}
