import UIKit

final class HomeRecentScansController: NSObject {
    typealias ScanItem = ScanService.ScanItem

    private weak var hostViewController: UIViewController?
    private let homeViewModel: HomeViewModel
    private let homeCoordinator: HomeCoordinator
    private let previewCoordinator: ScanPreviewCoordinator
    private var scans: [ScanItem] = []

    init(
        hostViewController: UIViewController,
        homeViewModel: HomeViewModel,
        homeCoordinator: HomeCoordinator,
        previewCoordinator: ScanPreviewCoordinator
    ) {
        self.hostViewController = hostViewController
        self.homeViewModel = homeViewModel
        self.homeCoordinator = homeCoordinator
        self.previewCoordinator = previewCoordinator
    }

    func attach(to tableView: UITableView) {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ScanCardCell.self, forCellReuseIdentifier: ScanCardCell.reuseID)
    }

    func updateScans(_ scans: [ScanItem]) {
        self.scans = scans
    }
}

extension HomeRecentScansController: UITableViewDataSource, UITableViewDelegate {
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

        cell.onOpenTapped = { [weak self] in
            self?.previewCoordinator.presentExistingScan(item)
        }

        cell.onMoreTapped = { [weak self] sourceView in
            guard let self, let hostViewController else { return }
            self.homeCoordinator.presentScanActions(for: item, sourceView: sourceView ?? cell, from: hostViewController)
        }

        return cell
    }
}
