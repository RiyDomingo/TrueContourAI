import UIKit

class ResultsListViewController: UITableViewController {
    private var saved: ResultsPersistence.SavedScanResult?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Previous Results"
        // Use subtitle style for richer rows
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        loadSaved()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Details", style: .plain, target: self, action: #selector(showDetails))
        updateEmptyState()
    }

    private func loadSaved() {
        saved = ResultsPersistence.load()
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        if saved == nil {
            let label = UILabel()
            label.text = "No previous results yet\nStart a scan to see them here"
            label.textAlignment = .center
            label.numberOfLines = 0
            label.textColor = .secondaryLabel
            label.font = UIFont.preferredFont(forTextStyle: .body)
            label.adjustsFontForContentSizeCategory = true
            tableView.backgroundView = label
        } else {
            tableView.backgroundView = nil
        }
    }

    @objc private func showDetails() {
        guard let saved = saved else { return }
        let vc = ResultsDetailViewController(saved: saved)
        navigationController?.pushViewController(vc, animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        guard let s = saved else { return 0 }
        var sections = 1 // Summary
        if s.fusedPointCloudPLY != nil || s.fusedMeshPLY != nil { sections += 1 }
        sections += 1 // Per-pose
        return sections
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let s = saved else { return nil }
        let hasFused = (s.fusedPointCloudPLY != nil || s.fusedMeshPLY != nil || s.fusedMeshOBJZip != nil || s.fusedMeshGLB != nil)
        switch section {
        case 0: return "Summary"
        case 1: return hasFused ? "Fused Files" : "Per‑Pose Files"
        case 2: return "Per‑Pose Files"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let s = saved else { return 0 }
        let hasFused = (s.fusedPointCloudPLY != nil || s.fusedMeshPLY != nil)
        if section == 0 { return 4 }
        if section == 1 && hasFused {
            return (s.fusedPointCloudPLY != nil ? 1 : 0) + (s.fusedMeshPLY != nil ? 1 : 0) + (s.fusedMeshOBJZip != nil ? 1 : 0) + (s.fusedMeshGLB != nil ? 1 : 0)
        }
        return s.poses.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        guard let s = saved else { return cell }

        let hasFused = (s.fusedPointCloudPLY != nil || s.fusedMeshPLY != nil)
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                cell.imageView?.image = UIImage(systemName: "calendar")
                cell.textLabel?.text = "Date"
                cell.detailTextLabel?.text = DateFormatter.localizedString(from: s.timestamp, dateStyle: .medium, timeStyle: .short)
            case 1:
                cell.imageView?.image = UIImage(systemName: "gauge")
                cell.textLabel?.text = "Overall Quality"
                cell.detailTextLabel?.text = String(format: "%.0f%%", s.overallQuality * 100)
            case 2:
                cell.imageView?.image = UIImage(systemName: "ruler")
                cell.textLabel?.text = "Head Circumference"
                cell.detailTextLabel?.text = String(format: "%.1f cm", s.headCircumferenceCM)
            case 3:
                cell.imageView?.image = UIImage(systemName: "head.profile")
                cell.textLabel?.text = "Back Width / Occipital"
                cell.detailTextLabel?.text = String(format: "%.0f mm / %.0f mm", s.backHeadWidthMM, s.occipitalProminenceMM)
            default: break
            }
            cell.accessoryType = .none
        } else if indexPath.section == 1 && hasFused {
            var idx = indexPath.row
            if let name = s.fusedPointCloudPLY {
                if idx == 0 {
                    cell.imageView?.image = UIImage(systemName: "square.stack.3d.up")
                    cell.textLabel?.text = "Fused Point Cloud (PLY)"
                    cell.detailTextLabel?.text = name
                    cell.accessoryType = .disclosureIndicator
                    return cell
                } else { idx -= 1 }
            }
            if let name = s.fusedMeshPLY {
                if idx == 0 {
                    cell.imageView?.image = UIImage(systemName: "cube.transparent")
                    cell.textLabel?.text = "Fused Mesh (PLY)"
                    cell.detailTextLabel?.text = name
                    cell.accessoryType = .disclosureIndicator
                    return cell
                } else { idx -= 1 }
            }
            if let name = s.fusedMeshOBJZip {
                if idx == 0 {
                    cell.imageView?.image = UIImage(systemName: "shippingbox.and.arrow.backward")
                    cell.textLabel?.text = "Fused Mesh (OBJ.zip)"
                    cell.detailTextLabel?.text = name
                    cell.accessoryType = .disclosureIndicator
                    return cell
                } else { idx -= 1 }
            }
            if let name = s.fusedMeshGLB {
                cell.imageView?.image = UIImage(systemName: "shippingbox")
                cell.textLabel?.text = "Fused Mesh (GLB)"
                cell.detailTextLabel?.text = name
                cell.accessoryType = .disclosureIndicator
            }
        } else {
            let p = s.poses[indexPath.row]
            cell.imageView?.image = UIImage(systemName: "doc.richtext")
            cell.textLabel?.text = p.pose
            cell.detailTextLabel?.text = p.plyPath ?? "(no file)"
            cell.accessoryType = p.plyPath == nil ? .none : .disclosureIndicator
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let s = saved else { return }
        let hasFused = (s.fusedPointCloudPLY != nil || s.fusedMeshPLY != nil || s.fusedMeshOBJZip != nil || s.fusedMeshGLB != nil)
        var url: URL?
        if indexPath.section == 1 && hasFused {
            var idx = indexPath.row
            if let name = s.fusedPointCloudPLY {
                if idx == 0 { url = ResultsPersistence.appSupportURL().appendingPathComponent(name) } else { idx -= 1 }
            }
            if url == nil, let name = s.fusedMeshPLY {
                if idx == 0 { url = ResultsPersistence.appSupportURL().appendingPathComponent(name) } else { idx -= 1 }
            }
            if url == nil, let name = s.fusedMeshOBJZip {
                if idx == 0 { url = ResultsPersistence.appSupportURL().appendingPathComponent(name) } else { idx -= 1 }
            }
            if url == nil, let name = s.fusedMeshGLB {
                url = ResultsPersistence.appSupportURL().appendingPathComponent(name)
            }
        } else if indexPath.section == (hasFused ? 2 : 1) {
            let p = s.poses[indexPath.row]
            if let name = p.plyPath { url = ResultsPersistence.appSupportURL().appendingPathComponent(name) }
        }
        if let url = url {
            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            present(av, animated: true)
        }
    }
}
