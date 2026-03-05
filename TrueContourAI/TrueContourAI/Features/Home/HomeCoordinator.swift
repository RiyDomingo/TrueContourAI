import UIKit

final class HomeCoordinator {
    private let scanService: ScanService
    private let settingsStore: SettingsStore
    private let scanFlowState: ScanFlowState

    var onOpenScan: ((ScanService.ScanItem) -> Void)?
    var onScansChanged: (() -> Void)?

    init(scanService: ScanService, settingsStore: SettingsStore, scanFlowState: ScanFlowState) {
        self.scanService = scanService
        self.settingsStore = settingsStore
        self.scanFlowState = scanFlowState
    }

    func presentPreScanChecklist(from presenter: UIViewController, onStart: @escaping () -> Void) {
        let vc = PreScanChecklistViewController()
        vc.onStateChanged = { [weak self] _, _, _, dontShowAgain in
            self?.settingsStore.showPreScanChecklist = !dontShowAgain
        }
        vc.onStart = { onStart() }
        vc.modalPresentationStyle = .pageSheet
        vc.initialDontShowAgain = !settingsStore.showPreScanChecklist
        presenter.present(vc, animated: true)
    }

    func openLastScan(from presenter: UIViewController) {
        guard let item = scanService.resolveLastScanItem() else {
            presenter.present(alert(title: L("scan.flow.noLast.title"), message: L("scan.flow.noLast.message")), animated: true)
            return
        }
        onOpenScan?(item)
    }

    func presentScansFolderShare(from presenter: UIViewController, sourceView: UIView?) {
        if case .failure = scanService.ensureScansRootFolder() {
            presenter.present(
                alert(
                    title: L("scan.storage.unavailable.title"),
                    message: L("scan.storage.unavailable.message")
                ),
                animated: true
            )
            return
        }
        let av = UIActivityViewController(
            activityItems: scanService.shareItemsForScansRoot(),
            applicationActivities: nil
        )
        if let pop = av.popoverPresentationController {
            let src = sourceView ?? presenter.view
            pop.sourceView = src
            pop.sourceRect = src?.bounds ?? .zero
        }
        presenter.present(av, animated: true)
    }

    func presentSettings(from presenter: UIViewController) {
        let vc = SettingsViewController(store: settingsStore, scanService: scanService)
        vc.onScansChanged = { [weak self] in
            self?.onScansChanged?()
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        presenter.present(nav, animated: true)
    }

    func presentHowToScan(from presenter: UIViewController) {
        let vc = HowToScanViewController()
        vc.modalPresentationStyle = .pageSheet
        presenter.present(vc, animated: true)
    }

    func presentScanActions(for item: ScanService.ScanItem, sourceView: UIView?, from presenter: UIViewController) {
        let alertVC = UIAlertController(title: item.displayName, message: nil, preferredStyle: .actionSheet)
        alertVC.addAction(UIAlertAction(title: L("common.open"), style: .default, handler: { [weak self] _ in
            self?.onOpenScan?(item)
        }))
        alertVC.addAction(UIAlertAction(title: L("common.details"), style: .default, handler: { [weak self, weak presenter] _ in
            guard let self, let presenter else { return }
            self.presentScanDetails(for: item, from: presenter)
        }))
        alertVC.addAction(UIAlertAction(title: L("common.shareScanFolder"), style: .default, handler: { [weak self, weak presenter] _ in
            guard let presenter else { return }
            self?.shareScanFolder(item.folderURL, from: presenter, sourceView: sourceView)
        }))
        alertVC.addAction(UIAlertAction(title: L("common.shareObj"), style: .default, handler: { [weak self, weak presenter] _ in
            guard let self, let presenter else { return }
            self.shareOBJFile(item.folderURL, from: presenter, sourceView: sourceView)
        }))
        alertVC.addAction(UIAlertAction(title: L("common.rename"), style: .default, handler: { [weak self, weak presenter] _ in
            guard let presenter else { return }
            self?.renameScanFolder(item, from: presenter)
        }))
        alertVC.addAction(UIAlertAction(title: L("common.delete"), style: .destructive, handler: { [weak self, weak presenter] _ in
            guard let presenter else { return }
            self?.deleteScanFolder(item, from: presenter)
        }))
        alertVC.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))

        if let pop = alertVC.popoverPresentationController {
            let src = sourceView ?? presenter.view
            pop.sourceView = src
            pop.sourceRect = src?.bounds ?? .zero
        }
        presenter.present(alertVC, animated: true)
    }

    func shareScanFolder(_ folderURL: URL, from presenter: UIViewController, sourceView: UIView?) {
        let av = UIActivityViewController(activityItems: scanService.shareItems(for: folderURL), applicationActivities: nil)
        if let pop = av.popoverPresentationController {
            let src = sourceView ?? presenter.view
            pop.sourceView = src
            pop.sourceRect = src?.bounds ?? .zero
        }
        presenter.present(av, animated: true)
    }

    private func shareOBJFile(_ folderURL: URL, from presenter: UIViewController, sourceView: UIView?) {
        guard let objURL = scanService.resolveOBJFromFolder(folderURL) else {
            presenter.present(
                alert(
                    title: L("scan.preview.missingOBJ.title"),
                    message: L("scan.preview.missingOBJ.message")
                ),
                animated: true
            )
            return
        }
        let av = UIActivityViewController(activityItems: [objURL], applicationActivities: nil)
        if let pop = av.popoverPresentationController {
            let src = sourceView ?? presenter.view
            pop.sourceView = src
            pop.sourceRect = src?.bounds ?? .zero
        }
        presenter.present(av, animated: true)
    }

    // MARK: - Private

    private func presentScanDetails(for item: ScanService.ScanItem, from presenter: UIViewController) {
        let loadingVC = ScanDetailsLoadingViewController()
        let nav = UINavigationController(rootViewController: loadingVC)
        nav.modalPresentationStyle = .pageSheet
        presenter.present(nav, animated: true)

        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak nav] in
            guard let self else { return }
            let summary = self.scanService.resolveScanSummary(from: item.folderURL)
            let previousSummary = self.resolvePreviousSummary(for: item)
            DispatchQueue.main.async {
                guard let nav, nav.presentingViewController != nil else { return }
                let detailsVC = ScanDetailsViewController(item: item, summary: summary, previousSummary: previousSummary)
                nav.setViewControllers([detailsVC], animated: false)
            }
        }
    }

    private func resolvePreviousSummary(for item: ScanService.ScanItem) -> ScanService.ScanSummary? {
        let scans = scanService.listScans()
        guard let currentIndex = scans.firstIndex(where: { $0.folderURL == item.folderURL }) else { return nil }
        let previousIndex = currentIndex + 1
        guard scans.indices.contains(previousIndex) else { return nil }
        return scanService.resolveScanSummary(from: scans[previousIndex].folderURL)
    }

    private func renameScanFolder(_ item: ScanService.ScanItem, from presenter: UIViewController) {
        let alertVC = UIAlertController(
            title: L("scan.flow.rename.title"),
            message: L("scan.flow.rename.message"),
            preferredStyle: .alert
        )
        alertVC.addTextField { tf in
            tf.placeholder = L("scan.flow.rename.placeholder")
            tf.text = item.displayName
            tf.autocapitalizationType = .words
        }
        alertVC.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))
        alertVC.addAction(UIAlertAction(title: L("common.rename"), style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let newNameRaw = alertVC.textFields?.first?.text ?? ""
            switch self.scanService.renameScanFolder(item, to: newNameRaw) {
            case .success(let newURL):
                if self.scanFlowState.currentlyPreviewedFolderURL == item.folderURL {
                    self.scanFlowState.currentlyPreviewedFolderURL = newURL
                }
                self.onScansChanged?()
            case .nameExists:
                presenter.present(self.alert(title: L("scan.flow.rename.nameExists.title"),
                                             message: L("scan.flow.rename.nameExists.message")),
                                  animated: true)
            case .invalidName:
                presenter.present(self.alert(title: L("scan.flow.rename.invalid.title"),
                                             message: L("scan.flow.rename.invalid.message")),
                                  animated: true)
            case .failure(let error):
                presenter.present(self.alert(title: L("scan.flow.rename.failed.title"),
                                             message: error.localizedDescription),
                                  animated: true)
            }
        }))
        presenter.present(alertVC, animated: true)
    }

    private func deleteScanFolder(_ item: ScanService.ScanItem, from presenter: UIViewController) {
        let alertVC = UIAlertController(
            title: L("scan.flow.delete.title"),
            message: L("scan.flow.delete.message"),
            preferredStyle: .alert
        )
        alertVC.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))
        alertVC.addAction(UIAlertAction(title: L("common.delete"), style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            switch self.scanService.deleteScanFolder(item) {
            case .success:
                if self.scanFlowState.currentlyPreviewedFolderURL == item.folderURL {
                    self.scanFlowState.currentlyPreviewedFolderURL = nil
                }
                self.onScansChanged?()
            case .failure(let error):
                presenter.present(self.alert(title: L("scan.flow.delete.failed.title"), message: error.localizedDescription), animated: true)
            }
        }))
        presenter.present(alertVC, animated: true)
    }

    private func alert(title: String, message: String) -> UIAlertController {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: L("common.ok"), style: .default))
        return a
    }
}
