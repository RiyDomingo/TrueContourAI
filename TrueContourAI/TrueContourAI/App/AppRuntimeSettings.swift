import Foundation

protocol AppSettingsReading {
    var showPreScanChecklist: Bool { get }
    var developerModeEnabled: Bool { get }
    var exportGLTF: Bool { get }
    var exportOBJ: Bool { get }
    var showVerifyEarHint: Bool { get }
    var scanDurationSeconds: Int { get }
    var scanQualityConfig: SettingsStore.ScanQualityConfig { get }
    var processingConfig: SettingsStore.ProcessingConfig { get }
    var scanSummarySchemaVersion: Int { get }
}

extension SettingsStore: AppSettingsReading {}

struct AppRuntimeOverrides {
    let showPreScanChecklist: Bool?
    let minimumScanDurationSeconds: Int?
    let forceExportGLTF: Bool
    let exportOBJ: Bool?
    let qualityGateEnabled: Bool?
    let minimumValidPoints: Int?

    static let none = AppRuntimeOverrides(
        showPreScanChecklist: nil,
        minimumScanDurationSeconds: nil,
        forceExportGLTF: false,
        exportOBJ: nil,
        qualityGateEnabled: nil,
        minimumValidPoints: nil
    )

    static func make(for environment: AppEnvironment) -> AppRuntimeOverrides {
        var overrides = AppRuntimeOverrides.none

        if environment.isDeviceSmokeMode {
            overrides = AppRuntimeOverrides(
                showPreScanChecklist: false,
                minimumScanDurationSeconds: 30,
                forceExportGLTF: true,
                exportOBJ: !environment.disablesOBJExport,
                qualityGateEnabled: nil,
                minimumValidPoints: nil
            )
        }

        if environment.requestsDisabledGLTFExport {
            overrides = AppRuntimeOverrides(
                showPreScanChecklist: overrides.showPreScanChecklist,
                minimumScanDurationSeconds: overrides.minimumScanDurationSeconds,
                forceExportGLTF: true,
                exportOBJ: overrides.exportOBJ,
                qualityGateEnabled: overrides.qualityGateEnabled,
                minimumValidPoints: overrides.minimumValidPoints
            )
        }

        if environment.disablesOBJExport {
            overrides = AppRuntimeOverrides(
                showPreScanChecklist: overrides.showPreScanChecklist,
                minimumScanDurationSeconds: overrides.minimumScanDurationSeconds,
                forceExportGLTF: overrides.forceExportGLTF,
                exportOBJ: false,
                qualityGateEnabled: overrides.qualityGateEnabled,
                minimumValidPoints: overrides.minimumValidPoints
            )
        }

        if environment.disablesQualityGate {
            overrides = AppRuntimeOverrides(
                showPreScanChecklist: overrides.showPreScanChecklist,
                minimumScanDurationSeconds: overrides.minimumScanDurationSeconds,
                forceExportGLTF: overrides.forceExportGLTF,
                exportOBJ: overrides.exportOBJ,
                qualityGateEnabled: false,
                minimumValidPoints: overrides.minimumValidPoints
            )
        }

        if environment.forcesQualityGateBlock {
            overrides = AppRuntimeOverrides(
                showPreScanChecklist: overrides.showPreScanChecklist,
                minimumScanDurationSeconds: overrides.minimumScanDurationSeconds,
                forceExportGLTF: overrides.forceExportGLTF,
                exportOBJ: overrides.exportOBJ,
                qualityGateEnabled: true,
                minimumValidPoints: 9_999_999
            )
        }

        return overrides
    }
}

final class AppRuntimeSettings: AppSettingsReading {
    private let settingsStore: SettingsStore
    private let overrides: AppRuntimeOverrides

    init(settingsStore: SettingsStore, environment: AppEnvironment) {
        self.settingsStore = settingsStore
        self.overrides = AppRuntimeOverrides.make(for: environment)
    }

    var showPreScanChecklist: Bool {
        overrides.showPreScanChecklist ?? settingsStore.showPreScanChecklist
    }

    var developerModeEnabled: Bool {
        settingsStore.developerModeEnabled
    }

    var exportGLTF: Bool {
        overrides.forceExportGLTF ? true : settingsStore.exportGLTF
    }

    var exportOBJ: Bool {
        overrides.exportOBJ ?? settingsStore.exportOBJ
    }

    var showVerifyEarHint: Bool {
        settingsStore.showVerifyEarHint
    }

    var scanDurationSeconds: Int {
        if let minimum = overrides.minimumScanDurationSeconds {
            return max(settingsStore.scanDurationSeconds, minimum)
        }
        return settingsStore.scanDurationSeconds
    }

    var scanQualityConfig: SettingsStore.ScanQualityConfig {
        var config = settingsStore.scanQualityConfig
        if let qualityGateEnabled = overrides.qualityGateEnabled {
            config.gateEnabled = qualityGateEnabled
        }
        if let minimumValidPoints = overrides.minimumValidPoints {
            config.minValidPoints = max(config.minValidPoints, minimumValidPoints)
        }
        return config
    }

    var processingConfig: SettingsStore.ProcessingConfig {
        settingsStore.processingConfig
    }

    var scanSummarySchemaVersion: Int {
        settingsStore.scanSummarySchemaVersion
    }
}
