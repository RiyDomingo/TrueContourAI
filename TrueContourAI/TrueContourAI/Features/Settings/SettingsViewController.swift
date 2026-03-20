import UIKit

final class SettingsViewController: UITableViewController {
    private let store: SettingsStore
    private let storageUseCase: SettingsStorageUseCase
    private lazy var feedbackController = SettingsFeedbackController(presenter: self)
    private lazy var interactionController = SettingsInteractionController(
        store: store,
        storageUseCase: storageUseCase,
        feedbackController: feedbackController
    )
    var onScansChanged: (() -> Void)?
    private var sections: [SettingsSection] = []

    init(store: SettingsStore, storageUseCase: SettingsStorageUseCase) {
        self.store = store
        self.storageUseCase = storageUseCase
        super.init(style: .insetGrouped)
        title = L("settings.title")
    }

    @available(*, unavailable, message: "Programmatic-only. Use init(store:storageUseCase:).")
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
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        bindStore()
        apply(state: store.state)
        interactionController.refreshStorageUsage()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        interactionController.refreshStorageUsage()
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.textColor = DesignSystem.Colors.textSecondary
        header.textLabel?.font = DesignSystem.Typography.caption()
    }

    private func bindStore() {
        store.onStateChange = { [weak self] state in
            self?.apply(state: state)
        }
        store.onEffect = { [weak self] effect in
            self?.handle(effect: effect)
        }
    }

    private func apply(state: SettingsState) {
        sections = SettingsSectionBuilder(
            state: state,
            onAction: { [weak self] action in
                self?.store.send(action)
            },
            onDeleteAll: { [weak self] in
                self?.presentDeleteAllConfirmation()
            },
            onReset: { [weak self] in
                self?.presentResetConfirmation()
            }
        ).build()
        if isViewLoaded {
            tableView.reloadData()
        }
    }

    private func handle(effect: SettingsEffect) {
        switch effect {
        case .alert(let title, let message, _):
            feedbackController.showError(title: title, message: message)
        case .scansChanged:
            onScansChanged?()
        }
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
        case .toggle(let isOn, let setOn, _):
            setOn(!isOn())
            tableView.reloadRows(at: [indexPath], with: .none)
        case .action(let handler):
            handler()
        case .option(let options, let selected, let setSelected):
            feedbackController.presentOptionSheet(title: row.title, options: options, selected: selected()) { [weak self] value in
                setSelected(value)
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
        guard case .toggle(_, let setOn, _) = item.kind else { return }
        setOn(sender.isOn)
        sender.setOn(currentToggleValue(for: item), animated: true)
    }

    private func presentResetConfirmation() {
        interactionController.requestReset()
    }

    private func presentDeleteAllConfirmation() {
        interactionController.requestDeleteAllScans()
    }

#if DEBUG
    func debug_refreshStorageUsage() {
        interactionController.refreshStorageUsage()
    }

    func debug_confirmDeleteAllScans() {
        interactionController.requestDeleteAllScans()
    }

    func debug_deleteAllScansConfirmed() {
        interactionController.deleteAllScansConfirmed()
    }

    func debug_storageUsageText() -> String {
        store.state.storageUsageText
    }
#endif

    private func currentToggleValue(for row: SettingsRow) -> Bool {
        guard case .toggle(let isOn, _, _) = row.kind else { return false }
        return isOn()
    }
}
