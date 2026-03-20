import UIKit

final class HomeRecentScansController: NSObject {
    private let onOpenScan: (URL) -> Void
    private let onPresentActions: (URL, UIView?) -> Void
    private var rows: [HomeScanRowViewData] = []

    init(
        onOpenScan: @escaping (URL) -> Void,
        onPresentActions: @escaping (URL, UIView?) -> Void
    ) {
        self.onOpenScan = onOpenScan
        self.onPresentActions = onPresentActions
    }

    func attach(to tableView: UITableView) {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ScanCardCell.self, forCellReuseIdentifier: ScanCardCell.reuseID)
    }

    func updateRows(_ rows: [HomeScanRowViewData]) {
        self.rows = rows
    }
}

extension HomeRecentScansController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ScanCardCell.reuseID,
            for: indexPath
        ) as? ScanCardCell else {
            return UITableViewCell()
        }

        let row = rows[indexPath.row]
        let badgeDisplay = row.qualityTier.map {
            HomeDisplayFormatter.ScanQualityBadgeDisplay(
                tier: mapTier($0),
                text: qualityText($0),
                accessibilityText: String(format: L("home.scan.badge.accessibility"), qualityText($0))
            )
        }
        cell.configure(
            title: row.title,
            date: nil,
            thumbnailURL: row.thumbnailURL,
            detailText: row.subtitle,
            accessibilityDetail: row.subtitle,
            qualityBadge: badgeDisplay,
            isOpenEnabled: row.isOpenEnabled
        )

        cell.onOpenTapped = { [weak self] in
            self?.onOpenScan(row.folderURL)
        }

        cell.onMoreTapped = { [weak self] sourceView in
            guard let self else { return }
            self.onPresentActions(row.folderURL, sourceView ?? cell)
        }

        return cell
    }

    private func mapTier(_ tier: ScanQualityTier) -> HomeViewModel.ScanQualityBadge.Tier {
        switch tier {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    private func qualityText(_ tier: ScanQualityTier) -> String {
        switch tier {
        case .high: return L("home.scan.quality.high")
        case .medium: return L("home.scan.quality.medium")
        case .low: return L("home.scan.quality.low")
        }
    }
}
