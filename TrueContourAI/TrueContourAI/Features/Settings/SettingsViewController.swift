import UIKit

final class SettingsViewController: UITableViewController {
    private let store: SettingsStore
    private let scanService: SettingsScanServicing
    private lazy var storageWorkflow = SettingsStorageWorkflow(scanService: scanService)
    private lazy var feedbackController = SettingsFeedbackController(presenter: self)
    var onScansChanged: (() -> Void)?
    private var sections: [SettingsSection] = []
    private var storageUsageText = L("settings.calculating")

    init(store: SettingsStore, scanService: SettingsScanServicing) {
        self.store = store
        self.scanService = scanService
        super.init(style: .insetGrouped)
        title = L("settings.title")
    }

    @available(*, unavailable, message: "Programmatic-only. Use init(store:scanService:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.background
        tableView.accessibilityIdentifier = "settingsTableView"
        tableView.backgroundColor = .clear
        tableView.separatorColor = DesignSystem.Colors.border
        navigationController?.navigationBar.tintColor = DesignSystem.Colors.textPrimary
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: DesignSystem.Colors.textPrimary,
            .font: DesignSystem.Typography.bodyEmphasis()
        ]
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
        navigationItem.rightBarButtonItem?.accessibilityLabel = L("settings.close")
        buildSections()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.textColor = DesignSystem.Colors.textSecondary
        header.textLabel?.font = DesignSystem.Typography.caption()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        buildSections()
        tableView.reloadData()
        refreshStorageUsage()
    }

    private func buildSections() {
        sections = SettingsSectionBuilder(
            store: store,
            storageUsageText: storageUsageText,
            onDeleteAll: { [weak self] in self?.presentDeleteAllConfirmation() },
            onReset: { [weak self] in self?.presentResetConfirmation() }
        ).build()
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = row.title
        switch row.kind {
        case .option(let options, let selected, _):
            let value = selected()
            config.secondaryText = options.first(where: { $0.value == value })?.title ?? row.subtitle
        default:
            config.secondaryText = row.subtitle
        }
        config.textProperties.color = DesignSystem.Colors.textPrimary
        config.secondaryTextProperties.color = DesignSystem.Colors.textSecondary
        config.textProperties.font = DesignSystem.Typography.bodyEmphasis()
        config.secondaryTextProperties.font = DesignSystem.Typography.caption()
        cell.contentConfiguration = config
        cell.backgroundColor = DesignSystem.Colors.surface
        cell.accessibilityIdentifier = row.identifier
        cell.accessibilityLabel = row.title
        cell.accessibilityHint = row.subtitle

        switch row.kind {
        case .toggle(let isOn, _, let identifier):
            let toggle = UISwitch()
            toggle.isOn = isOn()
            toggle.onTintColor = DesignSystem.Colors.actionPrimary
            toggle.accessibilityLabel = row.title
            toggle.accessibilityIdentifier = identifier
            toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
            toggle.tag = (indexPath.section * 100) + indexPath.row
            cell.accessoryView = toggle
            cell.selectionStyle = .default
            cell.accessibilityTraits = .button
            cell.accessibilityValue = toggle.isOn ? "1" : "0"
        case .option:
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            cell.accessibilityTraits = .button
            if case .option(let options, let selected, _) = row.kind {
                let value = selected()
                cell.accessibilityValue = options.first(where: { $0.value == value })?.title
            }
        case .action:
            cell.accessoryView = nil
            cell.selectionStyle = .default
            cell.accessibilityTraits = .button
        case .info:
            cell.accessoryView = nil
            cell.selectionStyle = .none
            cell.accessibilityTraits = .staticText
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row.kind {
        case .toggle(let isOn, let setOn, let toggleIdentifier):
            let nextValue = !isOn()
            if toggleIdentifier == "settings.exportGLTF",
               nextValue == false {
                feedbackController.showError(
                    title: L("settings.export.minimum.title"),
                    message: L("settings.export.minimum.message")
                )
                return
            }
            setOn(nextValue)
            buildSections()
            tableView.reloadRows(at: [indexPath], with: .none)
        case .action(let handler):
            handler()
        case .option(let options, let selected, let setSelected):
            feedbackController.presentOptionSheet(title: row.title, options: options, selected: selected()) { [weak self] value in
                setSelected(value)
                self?.buildSections()
                self?.tableView.reloadData()
            }
        default:
            break
        }
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        let section = sender.tag / 100
        let row = sender.tag % 100
        guard sections.indices.contains(section), sections[section].rows.indices.contains(row) else { return }
        let item = sections[section].rows[row]
        if case .toggle(_, let setOn, let toggleIdentifier) = item.kind {
            if toggleIdentifier == "settings.exportGLTF",
               sender.isOn == false {
                sender.setOn(true, animated: true)
                feedbackController.showError(
                    title: L("settings.export.minimum.title"),
                    message: L("settings.export.minimum.message")
                )
                return
            }
            setOn(sender.isOn)
        }
    }

    private func refreshStorageUsage() {
        updateStorageUsageRow(with: L("settings.calculating"))
        storageWorkflow.refreshStorageUsage { [weak self] usage in
            guard let self else { return }
            self.updateStorageUsageRow(with: usage)
        }
    }

    private func updateStorageUsageRow(with text: String) {
        storageUsageText = text
        guard let sectionIndex = sections.firstIndex(where: { $0.kind == .storage }) else {
            buildSections()
            tableView.reloadData()
            return
        }

        guard let rowIndex = sections[sectionIndex].rows.firstIndex(where: { $0.identifier == "settings.storageUsageRow" }) else {
            buildSections()
            tableView.reloadData()
            return
        }

        sections[sectionIndex].rows[rowIndex] = SettingsRow(
            title: L("settings.storage.used.title"),
            subtitle: text,
            kind: .info,
            identifier: "settings.storageUsageRow"
        )

        let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
        if tableView.numberOfSections > sectionIndex, tableView.numberOfRows(inSection: sectionIndex) > rowIndex {
            tableView.reloadRows(at: [indexPath], with: .none)
        } else {
            tableView.reloadData()
        }
    }

    private func presentResetConfirmation() {
        feedbackController.confirmReset { [weak self] in
            self?.store.resetToDefaults()
            self?.buildSections()
            self?.tableView.reloadData()
            self?.refreshStorageUsage()
        }
    }

    private func presentDeleteAllConfirmation() {
        feedbackController.confirmDeleteAllScans { [weak self] in
            self?.deleteAllScansConfirmed()
        }
    }

    private func deleteAllScansConfirmed() {
        storageWorkflow.deleteAllScans { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.refreshStorageUsage()
                self.onScansChanged?()
            case .failure(let error):
                self.feedbackController.showError(title: L("settings.delete.failed"), message: error.localizedDescription)
            }
        }
    }

#if DEBUG
    func debug_refreshStorageUsage() {
        refreshStorageUsage()
    }

    func debug_confirmDeleteAllScans() {
        presentDeleteAllConfirmation()
    }

    func debug_deleteAllScansConfirmed() {
        deleteAllScansConfirmed()
    }

    func debug_storageUsageText() -> String {
        storageUsageText
    }
#endif
}
