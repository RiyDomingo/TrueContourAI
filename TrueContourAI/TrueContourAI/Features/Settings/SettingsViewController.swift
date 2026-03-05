import UIKit

protocol SettingsScanServicing {
    var scansRootURL: URL { get }
    func ensureScansRootFolder() -> Result<Void, Error>
    func deleteAllScans() -> Result<Void, Error>
}

extension ScanService: SettingsScanServicing {}

final class SettingsViewController: UITableViewController {
    private enum SectionKind {
        case general
        case export
        case advanced
        case storage
    }

    private enum RowKind {
        case toggle(isOn: () -> Bool, setOn: (Bool) -> Void, identifier: String)
        case option(options: [Option], selected: () -> Int, setSelected: (Int) -> Void)
        case action(handler: () -> Void)
        case info
    }

    private struct Option {
        let title: String
        let value: Int
    }

    private struct Row {
        let title: String
        let subtitle: String?
        let kind: RowKind
        let identifier: String?

        init(title: String, subtitle: String?, kind: RowKind, identifier: String? = nil) {
            self.title = title
            self.subtitle = subtitle
            self.kind = kind
            self.identifier = identifier
        }
    }

    private let store: SettingsStore
    private let scanService: SettingsScanServicing
    var onScansChanged: (() -> Void)?
    private var sections: [(kind: SectionKind, title: String, rows: [Row])] = []
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
        sections = [
            (.general, L("settings.section.general"), [
                Row(
                    title: L("settings.scanDuration.title"),
                    subtitle: L("settings.scanDuration.subtitle"),
                    kind: .option(
                        options: [
                            .init(title: L("settings.scanDuration.manual"), value: 0),
                            .init(title: L("settings.scanDuration.10s"), value: 10),
                            .init(title: L("settings.scanDuration.20s"), value: 20)
                        ],
                        selected: { [store] in store.scanDurationSeconds },
                        setSelected: { [store] value in store.scanDurationSeconds = value }
                    )
                ),
                Row(
                    title: L("settings.showChecklist.title"),
                    subtitle: L("settings.showChecklist.subtitle"),
                    kind: .toggle(
                        isOn: { [store] in store.showPreScanChecklist },
                        setOn: { [store] value in store.showPreScanChecklist = value },
                        identifier: "settings.showPreScanChecklist"
                    )
                ),
                Row(
                    title: L("settings.developerMode.title"),
                    subtitle: L("settings.developerMode.subtitle"),
                    kind: .toggle(
                        isOn: { [store] in store.developerModeEnabled },
                        setOn: { [store] value in store.developerModeEnabled = value },
                        identifier: "settings.developerModeEnabled"
                    )
                ),
                Row(
                    title: L("settings.ear.hint.title"),
                    subtitle: L("settings.ear.hint.subtitle"),
                    kind: .toggle(
                        isOn: { [store] in store.showVerifyEarHint },
                        setOn: { [store] value in store.showVerifyEarHint = value },
                        identifier: "settings.showVerifyEarHint"
                    )
                )
            ]),
            (.export, L("settings.section.export"), [
                Row(
                    title: L("settings.export.gltf.title"),
                    subtitle: L("settings.export.gltf.subtitle"),
                    kind: .toggle(
                        isOn: { [store] in store.exportGLTF },
                        setOn: { [store] value in store.exportGLTF = value },
                        identifier: "settings.exportGLTF"
                    )
                ),
                Row(
                    title: L("settings.export.obj.title"),
                    subtitle: L("settings.export.obj.subtitle"),
                    kind: .toggle(
                        isOn: { [store] in store.exportOBJ },
                        setOn: { [store] value in store.exportOBJ = value },
                        identifier: "settings.exportOBJ"
                    )
                )
            ]),
            (.advanced, L("settings.section.advanced"), [
                Row(
                    title: L("settings.advanced.warning.title"),
                    subtitle: L("settings.advanced.warning.subtitle"),
                    kind: .info
                ),
                Row(
                    title: L("settings.advanced.qualityGate.title"),
                    subtitle: L("settings.advanced.qualityGate.subtitle"),
                    kind: .toggle(
                        isOn: { [store] in store.scanQualityConfig.gateEnabled },
                        setOn: { [store] value in
                            var cfg = store.scanQualityConfig
                            cfg.gateEnabled = value
                            store.scanQualityConfig = cfg
                        },
                        identifier: "settings.qualityGateEnabled"
                    )
                ),
                Row(
                    title: L("settings.advanced.minQualityScore.title"),
                    subtitle: L("settings.advanced.minQualityScore.subtitle"),
                    kind: .option(
                        options: [
                            .init(title: L("settings.advanced.minQualityScore.lenient"), value: 55),
                            .init(title: L("settings.advanced.minQualityScore.balanced"), value: 65),
                            .init(title: L("settings.advanced.minQualityScore.strict"), value: 75)
                        ],
                        selected: { [store] in Int(round(store.scanQualityConfig.minQualityScore * 100)) },
                        setSelected: { [store] value in
                            var cfg = store.scanQualityConfig
                            cfg.minQualityScore = Float(value) / 100.0
                            store.scanQualityConfig = cfg
                        }
                    )
                ),
                Row(
                    title: L("settings.advanced.minValidPoints.title"),
                    subtitle: L("settings.advanced.minValidPoints.subtitle"),
                    kind: .option(
                        options: [
                            .init(title: L("settings.advanced.minValidPoints.low"), value: 70_000),
                            .init(title: L("settings.advanced.minValidPoints.recommended"), value: 90_000),
                            .init(title: L("settings.advanced.minValidPoints.high"), value: 120_000)
                        ],
                        selected: { [store] in store.scanQualityConfig.minValidPoints },
                        setSelected: { [store] value in
                            var cfg = store.scanQualityConfig
                            cfg.minValidPoints = value
                            store.scanQualityConfig = cfg
                        }
                    )
                ),
                Row(
                    title: L("settings.advanced.minValidRatio.title"),
                    subtitle: L("settings.advanced.minValidRatio.subtitle"),
                    kind: .option(
                        options: [
                            .init(title: L("settings.advanced.minValidRatio.low"), value: 50),
                            .init(title: L("settings.advanced.minValidRatio.recommended"), value: 60),
                            .init(title: L("settings.advanced.minValidRatio.high"), value: 70)
                        ],
                        selected: { [store] in Int(round(store.scanQualityConfig.minValidRatio * 100)) },
                        setSelected: { [store] value in
                            var cfg = store.scanQualityConfig
                            cfg.minValidRatio = Float(value) / 100.0
                            store.scanQualityConfig = cfg
                        }
                    )
                )
            ]),
            (.storage, L("settings.section.storage"), [
                Row(
                    title: L("settings.storage.used.title"),
                    subtitle: storageUsageText,
                    kind: .info,
                    identifier: "settings.storageUsageRow"
                ),
                Row(
                    title: L("settings.filesharing.title"),
                    subtitle: L("settings.filesharing.subtitle"),
                    kind: .info,
                    identifier: "settings.filesharingRow"
                ),
                Row(
                    title: L("settings.deleteAll.title"),
                    subtitle: L("settings.deleteAll.subtitle"),
                    kind: .action(handler: { [weak self] in
                        self?.confirmDeleteAllScans()
                    }),
                    identifier: "settings.deleteAllRow"
                ),
                Row(
                    title: L("settings.reset.title"),
                    subtitle: L("settings.reset.subtitle"),
                    kind: .action(handler: { [weak self] in
                        self?.confirmReset()
                    }),
                    identifier: "settings.resetRow"
                )
            ])
        ]
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
            cell.selectionStyle = .none
            cell.accessibilityTraits = .none
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
        case .action(let handler):
            handler()
        case .option(let options, let selected, let setSelected):
            presentOptionSheet(title: row.title, options: options, selected: selected(), setSelected: setSelected)
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
                showError(
                    title: L("settings.export.minimum.title"),
                    message: L("settings.export.minimum.message")
                )
                return
            }
            setOn(sender.isOn)
        }
    }

    private func presentOptionSheet(title: String, options: [Option], selected: Int, setSelected: @escaping (Int) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for option in options {
            let optionTitle = option.value == selected
                ? option.title + L("settings.option.currentSuffix")
                : option.title
            alert.addAction(UIAlertAction(title: optionTitle, style: .default, handler: { [weak self] _ in
                setSelected(option.value)
                self?.buildSections()
                self?.tableView.reloadData()
            }))
        }
        alert.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(alert, animated: true)
    }

    private func refreshStorageUsage() {
        updateStorageUsageRow(with: L("settings.calculating"))

        let scanService = self.scanService
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let usage = Self.formatStorageUsage(scanService: scanService)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.updateStorageUsageRow(with: usage)
            }
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

        sections[sectionIndex].rows[rowIndex] = Row(
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

    private static func formatStorageUsage(scanService: SettingsScanServicing) -> String {
        if case .failure = scanService.ensureScansRootFolder() {
            return L("settings.storage.unavailable")
        }
        let url = scanService.scansRootURL
        let bytes = directorySize(at: url)
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private static func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        return total
    }

    private func confirmReset() {
        let alert = UIAlertController(
            title: L("settings.reset.confirm.title"),
            message: L("settings.reset.confirm.message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("settings.reset.action"), style: .destructive, handler: { [weak self] _ in
            self?.store.resetToDefaults()
            self?.buildSections()
            self?.tableView.reloadData()
            self?.refreshStorageUsage()
        }))
        present(alert, animated: true)
    }

    private func confirmDeleteAllScans() {
        let alert = UIAlertController(
            title: L("settings.deleteAll.confirm.title"),
            message: L("settings.deleteAll.confirm.message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("common.delete"), style: .destructive, handler: { [weak self] _ in
            self?.deleteAllScansConfirmed()
        }))
        present(alert, animated: true)
    }

    private func deleteAllScansConfirmed() {
        switch scanService.deleteAllScans() {
        case .success:
            refreshStorageUsage()
            onScansChanged?()
        case .failure(let error):
            showError(title: L("settings.delete.failed"), message: error.localizedDescription)
        }
    }

    private func showError(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("common.ok"), style: .default))
        present(alert, animated: true)
    }

#if DEBUG
    func debug_refreshStorageUsage() {
        refreshStorageUsage()
    }

    func debug_confirmDeleteAllScans() {
        confirmDeleteAllScans()
    }

    func debug_deleteAllScansConfirmed() {
        deleteAllScansConfirmed()
    }

    func debug_storageUsageText() -> String {
        storageUsageText
    }
#endif
}
