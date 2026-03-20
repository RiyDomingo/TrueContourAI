import UIKit
import StandardCyborgUI
import StandardCyborgFusion
import SceneKit

protocol ScanExporting {
    func exportScanFolder(
        mesh: SCMesh,
        scene: SCScene,
        thumbnail: UIImage?,
        earArtifacts: ScanEarArtifacts?,
        scanSummary: ScanSummary?,
        includeGLTF: Bool,
        includeOBJ: Bool
    ) -> ScanExportResult
    func setLastScanFolder(_ folderURL: URL)
}

protocol PreviewSaveExportSurface: AnyObject {
    var hostView: UIView { get }
    var leftActionButton: UIButton { get }
    var rightActionButton: UIButton { get }
}

protocol SaveExportUIStateAdapting {
    func configure(surface: any PreviewSaveExportSurface)
    func setButtonsEnabled(_ isEnabled: Bool)
    func markSaveMeshing()
    func markSaveReady()
    func markSaveInvoked()
    func markSaveBlocked()
    func setMeshingStatusText(_ text: String)
    func setMeshingSpinnerActive(_ isActive: Bool)
    func showSavingToast()
    func hideSavingToast()
    func markSaveCompleted()
    func markSaveFailed()
    func clear()
}

extension ScenePreviewViewController: PreviewSaveExportSurface {
    var hostView: UIView { view }
    var leftActionButton: UIButton { leftButton }
    var rightActionButton: UIButton { rightButton }
}

protocol PreviewViewControllerDelegate: AnyObject {
    func previewViewController(_ controller: PreviewViewController, handle route: PreviewRoute)
}

final class PreviewCoordinator: PreviewViewControllerDelegate {
    typealias PreviewViewControllerFactory = (PreviewViewController.Input) -> PreviewViewController

    private weak var presenter: UIViewController?
    private let scanFlowState: ScanFlowState
    private let onToast: ((String) -> Void)?
    private let onExportResult: ((PreviewExportResultEvent) -> Void)?
    private let previewViewControllerFactory: PreviewViewControllerFactory

    var onScansChanged: (() -> Void)?

    init(
        presenter: UIViewController,
        scanFlowState: ScanFlowState,
        onToast: ((String) -> Void)? = nil,
        onExportResult: ((PreviewExportResultEvent) -> Void)? = nil,
        previewViewControllerFactory: @escaping PreviewViewControllerFactory
    ) {
        self.presenter = presenter
        self.scanFlowState = scanFlowState
        self.onToast = onToast
        self.onExportResult = onExportResult
        self.previewViewControllerFactory = previewViewControllerFactory
    }

    func presentExistingScan(_ item: ScanItem) {
        guard let presenter else { return }
        let previewVC = previewViewControllerFactory(.existingScan(item))
        previewVC.delegate = self
        presenter.present(previewVC, animated: true)
    }

    func presentPreviewAfterScan(
        from scanningVC: UIViewController,
        payload: ScanPreviewInput,
        sessionMetrics: ScanFlowState.ScanSessionMetrics?
    ) {
        guard let presenter else { return }
        let previewVC = previewViewControllerFactory(.postScan(payload: payload, sessionMetrics: sessionMetrics))
        previewVC.delegate = self
        scanningVC.dismiss(animated: false) {
            presenter.present(previewVC, animated: true)
        }
    }

    func previewViewController(_ controller: PreviewViewController, handle route: PreviewRoute) {
        switch route {
        case .dismiss:
            controller.dismiss(animated: true) { [weak self] in
                self?.scanFlowState.setPhase(.idle)
            }
        case .returnHomeAfterSave(let result):
            controller.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
                self.onScansChanged?()
                self.onToast?(String(format: L("scan.preview.toast.savedWithFormats"), result.folderName, result.formatSummary))
                if result.earServiceUnavailable {
                    self.onToast?(L("scan.preview.toast.earUnavailable"))
                }
                self.onExportResult?(.success(
                    folderName: result.folderName,
                    formatSummary: result.formatSummary,
                    earServiceUnavailable: result.earServiceUnavailable
                ))
                self.scanFlowState.setPhase(.idle)
            }
        case .presentShare(let items, let sourceRect):
            let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                let anchorView = controller.currentShareSourceView ?? controller.view
                popover.sourceView = anchorView
                popover.sourceRect = sourceRect ?? anchorView?.bounds ?? .zero
            }
            controller.present(activityVC, animated: true)
        }
    }
}
