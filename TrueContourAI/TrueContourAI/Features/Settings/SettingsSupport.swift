import UIKit

protocol SettingsScanServicing {
    var scansRootURL: URL { get }
    func ensureScansRootFolder() -> Result<Void, Error>
    func deleteAllScans() -> Result<Void, Error>
}

extension ScanService: SettingsScanServicing {}

final class SettingsStorageWorkflow {
    private let scanService: SettingsScanServicing

    init(scanService: SettingsScanServicing) {
        self.scanService = scanService
    }

    func refreshStorageUsage(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .utility).async { [scanService] in
            let usage = Self.formatStorageUsage(scanService: scanService)
            DispatchQueue.main.async {
                completion(usage)
            }
        }
    }

    func deleteAllScans(completion: @escaping (Result<Void, Error>) -> Void) {
        completion(scanService.deleteAllScans())
    }

    private static func formatStorageUsage(scanService: SettingsScanServicing) -> String {
        if case .failure = scanService.ensureScansRootFolder() {
            return L("settings.storage.unavailable")
        }
        let bytes = directorySize(at: scanService.scansRootURL)
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
}

enum SettingsSectionKind {
    case general
    case export
    case advanced
    case storage
}

enum SettingsRowKind {
    case toggle(isOn: () -> Bool, setOn: (Bool) -> Void, identifier: String)
    case option(options: [SettingsOption], selected: () -> Int, setSelected: (Int) -> Void)
    case action(handler: () -> Void)
    case info
}

struct SettingsOption {
    let title: String
    let value: Int
}

struct SettingsRow {
    let title: String
    let subtitle: String?
    let kind: SettingsRowKind
    let identifier: String?
}

struct SettingsSection {
    let kind: SettingsSectionKind
    let title: String
    var rows: [SettingsRow]
}

struct SettingsSectionBuilder {
    let store: SettingsStore
    let storageUsageText: String
    let onDeleteAll: () -> Void
    let onReset: () -> Void

    func build() -> [SettingsSection] {
        [
            generalSection(),
            exportSection(),
            advancedSection(),
            storageSection()
        ]
    }

    private func generalSection() -> SettingsSection {
        SettingsSection(
            kind: .general,
            title: L("settings.section.general"),
            rows: [
                SettingsRow(
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
                    ),
                    identifier: nil
                ),
                SettingsRow(
                    title: L("settings.showChecklist.title"),
                    subtitle: L("settings.showChecklist.subtitle"),
                    kind: .toggle(
                        isOn: { [store] in store.showPreScanChecklist },
                        setOn: { [store] value in store.showPreScanChecklist = value },
                        identifier: "settings.showPreScanChecklist"
                    ),
                    identifier: nil
                ),
                SettingsRow(
                    title: L("settings.ear.hint.title"),
                    subtitle: L("settings.ear.hint.subtitle"),
                    kind: .toggle(
                        isOn: { [store] in store.showVerifyEarHint },
                        setOn: { [store] value in store.showVerifyEarHint = value },
                        identifier: "settings.showVerifyEarHint"
                    ),
                    identifier: nil
                )
            ]
        )
    }

    private func exportSection() -> SettingsSection {
        SettingsSection(
            kind: .export,
            title: L("settings.section.export"),
            rows: [
                SettingsRow(
                    title: L("settings.export.gltf.title"),
                    subtitle: L("settings.export.gltf.subtitle"),
                    kind: .toggle(
                        isOn: { [store] in store.exportGLTF },
                        setOn: { [store] value in store.exportGLTF = value },
                        identifier: "settings.exportGLTF"
                    ),
                    identifier: nil
                ),
                SettingsRow(
                    title: L("settings.export.obj.title"),
                    subtitle: L("settings.export.obj.subtitle"),
                    kind: .toggle(
                        isOn: { [store] in store.exportOBJ },
                        setOn: { [store] value in store.exportOBJ = value },
                        identifier: "settings.exportOBJ"
                    ),
                    identifier: nil
                )
            ]
        )
    }

    private func advancedSection() -> SettingsSection {
        SettingsSection(
            kind: .advanced,
            title: L("settings.section.advanced"),
            rows: [
                SettingsRow(
                    title: L("settings.advanced.warning.title"),
                    subtitle: L("settings.advanced.warning.subtitle"),
                    kind: .info,
                    identifier: nil
                ),
                SettingsRow(
                    title: L("settings.developerMode.title"),
                    subtitle: L("settings.developerMode.subtitle"),
                    kind: .toggle(
                        isOn: { [store] in store.developerModeEnabled },
                        setOn: { [store] value in store.developerModeEnabled = value },
                        identifier: "settings.developerModeEnabled"
                    ),
                    identifier: nil
                ),
                SettingsRow(
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
                    ),
                    identifier: nil
                ),
                SettingsRow(
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
                    ),
                    identifier: nil
                ),
                SettingsRow(
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
                    ),
                    identifier: nil
                ),
                SettingsRow(
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
                    ),
                    identifier: nil
                )
            ]
        )
    }

    private func storageSection() -> SettingsSection {
        SettingsSection(
            kind: .storage,
            title: L("settings.section.storage"),
            rows: [
                SettingsRow(
                    title: L("settings.storage.used.title"),
                    subtitle: storageUsageText,
                    kind: .info,
                    identifier: "settings.storageUsageRow"
                ),
                SettingsRow(
                    title: L("settings.filesharing.title"),
                    subtitle: L("settings.filesharing.subtitle"),
                    kind: .info,
                    identifier: "settings.filesharingRow"
                ),
                SettingsRow(
                    title: L("settings.deleteAll.title"),
                    subtitle: L("settings.deleteAll.subtitle"),
                    kind: .action(handler: onDeleteAll),
                    identifier: "settings.deleteAllRow"
                ),
                SettingsRow(
                    title: L("settings.reset.title"),
                    subtitle: L("settings.reset.subtitle"),
                    kind: .action(handler: onReset),
                    identifier: "settings.resetRow"
                )
            ]
        )
    }
}
