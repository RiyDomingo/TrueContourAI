import UIKit

class ResultsDetailViewController: UITableViewController {
    private let saved: ResultsPersistence.SavedScanResult

    init(saved: ResultsPersistence.SavedScanResult) {
        self.saved = saved
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Results Details"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Summary" : "Measurements"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 4 : 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "Cell")
        cell.selectionStyle = .none
        switch (indexPath.section, indexPath.row) {
        case (0,0):
            cell.imageView?.image = UIImage(systemName: "calendar")
            cell.textLabel?.text = "Date"
            cell.detailTextLabel?.text = DateFormatter.localizedString(from: saved.timestamp, dateStyle: .medium, timeStyle: .short)
        case (0,1):
            cell.imageView?.image = UIImage(systemName: "gauge")
            cell.textLabel?.text = "Overall Quality"
            cell.detailTextLabel?.text = String(format: "%.0f%%", saved.overallQuality * 100)
        case (0,2):
            cell.imageView?.image = UIImage(systemName: "checkmark.seal")
            cell.textLabel?.text = "Successful Poses"
            cell.detailTextLabel?.text = "\(saved.successfulPoses) / \(saved.poses.count)"
        case (0,3):
            cell.imageView?.image = UIImage(systemName: "timer")
            cell.textLabel?.text = "Total Scan Time"
            cell.detailTextLabel?.text = String(format: "%.0f s", saved.totalScanTime)
        case (1,0):
            cell.imageView?.image = UIImage(systemName: "ruler")
            cell.textLabel?.text = "Head Circumference"
            cell.detailTextLabel?.text = String(format: "%.1f cm", saved.headCircumferenceCM)
        case (1,1):
            cell.imageView?.image = UIImage(systemName: "arrow.left.and.right")
            cell.textLabel?.text = "Back Head Width"
            cell.detailTextLabel?.text = String(format: "%.0f mm", saved.backHeadWidthMM)
        case (1,2):
            cell.imageView?.image = UIImage(systemName: "arrow.up.and.down")
            cell.textLabel?.text = "Occipital Prominence"
            cell.detailTextLabel?.text = String(format: "%.0f mm", saved.occipitalProminenceMM)
        default: break
        }
        return cell
    }
}
