import Foundation

struct SettingsState: Equatable {
    let showPreScanChecklist: Bool
    let developerModeEnabled: Bool
    let exportGLTF: Bool
    let exportOBJ: Bool
    let showVerifyEarHint: Bool
    let scanDurationSeconds: Int
    let scanQualityConfig: SettingsStore.ScanQualityConfig
    let processingConfig: SettingsStore.ProcessingConfig
    let storageUsageText: String
}

enum SettingsAction {
    case setShowPreScanChecklist(Bool)
    case setDeveloperModeEnabled(Bool)
    case setExportGLTF(Bool)
    case setExportOBJ(Bool)
    case setShowVerifyEarHint(Bool)
    case setScanDurationSeconds(Int)
    case setQualityGateEnabled(Bool)
    case setMinQualityScorePercent(Int)
    case setMinValidPoints(Int)
    case setMinValidRatioPercent(Int)
    case refreshStorageRequested
    case storageUsageUpdated(String)
    case deleteAllCompleted(Result<Void, Error>)
    case resetDefaults
}

enum SettingsEffect: Equatable {
    case alert(title: String, message: String, identifier: String)
    case scansChanged
}

final class SettingsStore {
    struct ScanQualityConfig: Equatable {
        var gateEnabled: Bool
        var minValidPoints: Int
        var minValidRatio: Float
        var minQualityScore: Float
        var minHeadDimensionMeters: Float
        var maxHeadDimensionMeters: Float

        static let `default` = ScanQualityConfig(
            gateEnabled: true,
            minValidPoints: 90_000,
            minValidRatio: 0.60,
            minQualityScore: 0.65,
            minHeadDimensionMeters: 0.10,
            maxHeadDimensionMeters: 0.50
        )
    }

    struct ProcessingConfig: Equatable {
        var outlierSigma: Float
        var decimateRatio: Float
        var cropBelowNeck: Bool
        var meshResolution: Int
        var meshSmoothness: Int

        static let `default` = ProcessingConfig(
            outlierSigma: 3.0,
            decimateRatio: 1.0,
            cropBelowNeck: true,
            meshResolution: 6,
            meshSmoothness: 3
        )
    }

    private let defaults: UserDefaults
    private var storageUsageText = L("settings.calculating")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = SettingsState(
            showPreScanChecklist: true,
            developerModeEnabled: false,
            exportGLTF: true,
            exportOBJ: true,
            showVerifyEarHint: true,
            scanDurationSeconds: 0,
            scanQualityConfig: .default,
            processingConfig: .default,
            storageUsageText: L("settings.calculating")
        )
        syncState()
    }

    private enum Keys {
        static let showPreScanChecklist = "settings_show_pre_scan_checklist"
        static let developerModeEnabled = "settings_developer_mode_enabled"
        static let exportGLTF = "settings_export_gltf"
        static let exportOBJ = "settings_export_obj"
        static let showVerifyEarHint = "settings_show_verify_ear_hint"
        static let scanDurationSeconds = "settings_scan_duration_seconds"
        static let qualityGateEnabled = "settings_quality_gate_enabled"
        static let qualityMinValidPoints = "settings_quality_min_valid_points"
        static let qualityMinValidRatio = "settings_quality_min_valid_ratio"
        static let qualityMinScore = "settings_quality_min_score"
        static let qualityMinHeadDim = "settings_quality_min_head_dimension"
        static let qualityMaxHeadDim = "settings_quality_max_head_dimension"
        static let processingOutlierSigma = "settings_processing_outlier_sigma"
        static let processingDecimateRatio = "settings_processing_decimate_ratio"
        static let processingCropBelowNeck = "settings_processing_crop_below_neck"
        static let processingMeshResolution = "settings_processing_mesh_resolution"
        static let processingMeshSmoothness = "settings_processing_mesh_smoothness"
    }

    private(set) var state: SettingsState {
        didSet {
            guard oldValue != state else { return }
            emitStateChange()
        }
    }

    var onStateChange: ((SettingsState) -> Void)?
    var onEffect: ((SettingsEffect) -> Void)?

    var showPreScanChecklist: Bool {
        get { bool(forKey: Keys.showPreScanChecklist, default: true) }
        set { defaults.set(newValue, forKey: Keys.showPreScanChecklist) }
    }

    var developerModeEnabled: Bool {
        get { bool(forKey: Keys.developerModeEnabled, default: false) }
        set { defaults.set(newValue, forKey: Keys.developerModeEnabled) }
    }

    var exportGLTF: Bool {
        get { bool(forKey: Keys.exportGLTF, default: true) }
        set { defaults.set(newValue, forKey: Keys.exportGLTF) }
    }

    var exportOBJ: Bool {
        get { bool(forKey: Keys.exportOBJ, default: true) }
        set { defaults.set(newValue, forKey: Keys.exportOBJ) }
    }

    var showVerifyEarHint: Bool {
        get { bool(forKey: Keys.showVerifyEarHint, default: true) }
        set { defaults.set(newValue, forKey: Keys.showVerifyEarHint) }
    }

    var scanDurationSeconds: Int {
        get {
            let value = defaults.integer(forKey: Keys.scanDurationSeconds)
            return value
        }
        set { defaults.set(newValue, forKey: Keys.scanDurationSeconds) }
    }

    var scanQualityConfig: ScanQualityConfig {
        get {
            ScanQualityConfig(
                gateEnabled: bool(forKey: Keys.qualityGateEnabled, default: ScanQualityConfig.default.gateEnabled),
                minValidPoints: int(forKey: Keys.qualityMinValidPoints, default: ScanQualityConfig.default.minValidPoints),
                minValidRatio: float(forKey: Keys.qualityMinValidRatio, default: ScanQualityConfig.default.minValidRatio),
                minQualityScore: float(forKey: Keys.qualityMinScore, default: ScanQualityConfig.default.minQualityScore),
                minHeadDimensionMeters: float(forKey: Keys.qualityMinHeadDim, default: ScanQualityConfig.default.minHeadDimensionMeters),
                maxHeadDimensionMeters: float(forKey: Keys.qualityMaxHeadDim, default: ScanQualityConfig.default.maxHeadDimensionMeters)
            )
        }
        set {
            defaults.set(newValue.gateEnabled, forKey: Keys.qualityGateEnabled)
            defaults.set(newValue.minValidPoints, forKey: Keys.qualityMinValidPoints)
            defaults.set(newValue.minValidRatio, forKey: Keys.qualityMinValidRatio)
            defaults.set(newValue.minQualityScore, forKey: Keys.qualityMinScore)
            defaults.set(newValue.minHeadDimensionMeters, forKey: Keys.qualityMinHeadDim)
            defaults.set(newValue.maxHeadDimensionMeters, forKey: Keys.qualityMaxHeadDim)
        }
    }

    var processingConfig: ProcessingConfig {
        get {
            ProcessingConfig(
                outlierSigma: float(forKey: Keys.processingOutlierSigma, default: ProcessingConfig.default.outlierSigma),
                decimateRatio: float(forKey: Keys.processingDecimateRatio, default: ProcessingConfig.default.decimateRatio),
                cropBelowNeck: bool(forKey: Keys.processingCropBelowNeck, default: ProcessingConfig.default.cropBelowNeck),
                meshResolution: int(forKey: Keys.processingMeshResolution, default: ProcessingConfig.default.meshResolution),
                meshSmoothness: int(forKey: Keys.processingMeshSmoothness, default: ProcessingConfig.default.meshSmoothness)
            )
        }
        set {
            defaults.set(newValue.outlierSigma, forKey: Keys.processingOutlierSigma)
            defaults.set(newValue.decimateRatio, forKey: Keys.processingDecimateRatio)
            defaults.set(newValue.cropBelowNeck, forKey: Keys.processingCropBelowNeck)
            defaults.set(newValue.meshResolution, forKey: Keys.processingMeshResolution)
            defaults.set(newValue.meshSmoothness, forKey: Keys.processingMeshSmoothness)
        }
    }

    var scanSummarySchemaVersion: Int { 3 }

    var hasRequiredExportFormatsEnabled: Bool {
        exportGLTF
    }

    func send(_ action: SettingsAction) {
        switch action {
        case .setShowPreScanChecklist(let value):
            showPreScanChecklist = value
            syncState()
        case .setDeveloperModeEnabled(let value):
            developerModeEnabled = value
            syncState()
        case .setExportGLTF(let value):
            guard value || exportOBJ else {
                emitEffect(.alert(
                    title: L("settings.export.minimum.title"),
                    message: L("settings.export.minimum.message"),
                    identifier: "settings.export.minimum"
                ))
                syncState()
                return
            }
            exportGLTF = value
            syncState()
        case .setExportOBJ(let value):
            exportOBJ = value
            syncState()
        case .setShowVerifyEarHint(let value):
            showVerifyEarHint = value
            syncState()
        case .setScanDurationSeconds(let value):
            scanDurationSeconds = value
            syncState()
        case .setQualityGateEnabled(let value):
            var config = scanQualityConfig
            config.gateEnabled = value
            scanQualityConfig = config
            syncState()
        case .setMinQualityScorePercent(let value):
            var config = scanQualityConfig
            config.minQualityScore = Float(value) / 100.0
            scanQualityConfig = config
            syncState()
        case .setMinValidPoints(let value):
            var config = scanQualityConfig
            config.minValidPoints = value
            scanQualityConfig = config
            syncState()
        case .setMinValidRatioPercent(let value):
            var config = scanQualityConfig
            config.minValidRatio = Float(value) / 100.0
            scanQualityConfig = config
            syncState()
        case .refreshStorageRequested:
            storageUsageText = L("settings.calculating")
            syncState()
        case .storageUsageUpdated(let text):
            storageUsageText = text
            syncState()
        case .deleteAllCompleted(let result):
            switch result {
            case .success:
                emitEffect(.scansChanged)
            case .failure(let error):
                emitEffect(.alert(
                    title: L("settings.delete.failed"),
                    message: error.localizedDescription,
                    identifier: "settings.delete.failed"
                ))
            }
        case .resetDefaults:
            resetToDefaults()
            syncState()
        }
    }

    func resetToDefaults() {
        defaults.removeObject(forKey: Keys.showPreScanChecklist)
        defaults.removeObject(forKey: Keys.developerModeEnabled)
        defaults.removeObject(forKey: Keys.exportGLTF)
        defaults.removeObject(forKey: Keys.exportOBJ)
        defaults.removeObject(forKey: Keys.showVerifyEarHint)
        defaults.removeObject(forKey: Keys.scanDurationSeconds)
        defaults.removeObject(forKey: Keys.qualityGateEnabled)
        defaults.removeObject(forKey: Keys.qualityMinValidPoints)
        defaults.removeObject(forKey: Keys.qualityMinValidRatio)
        defaults.removeObject(forKey: Keys.qualityMinScore)
        defaults.removeObject(forKey: Keys.qualityMinHeadDim)
        defaults.removeObject(forKey: Keys.qualityMaxHeadDim)
        defaults.removeObject(forKey: Keys.processingOutlierSigma)
        defaults.removeObject(forKey: Keys.processingDecimateRatio)
        defaults.removeObject(forKey: Keys.processingCropBelowNeck)
        defaults.removeObject(forKey: Keys.processingMeshResolution)
        defaults.removeObject(forKey: Keys.processingMeshSmoothness)
    }

    private func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if defaults.object(forKey: key) == nil { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private func int(forKey key: String, default defaultValue: Int) -> Int {
        if defaults.object(forKey: key) == nil { return defaultValue }
        return defaults.integer(forKey: key)
    }

    private func float(forKey key: String, default defaultValue: Float) -> Float {
        if defaults.object(forKey: key) == nil { return defaultValue }
        return defaults.float(forKey: key)
    }

    private func syncState() {
        state = SettingsState(
            showPreScanChecklist: showPreScanChecklist,
            developerModeEnabled: developerModeEnabled,
            exportGLTF: exportGLTF,
            exportOBJ: exportOBJ,
            showVerifyEarHint: showVerifyEarHint,
            scanDurationSeconds: scanDurationSeconds,
            scanQualityConfig: scanQualityConfig,
            processingConfig: processingConfig,
            storageUsageText: storageUsageText
        )
    }

    private func emitStateChange() {
        if Thread.isMainThread {
            onStateChange?(state)
        } else {
            DispatchQueue.main.async { [weak self, state] in
                self?.onStateChange?(state)
            }
        }
    }

    private func emitEffect(_ effect: SettingsEffect) {
        if Thread.isMainThread {
            onEffect?(effect)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onEffect?(effect)
            }
        }
    }
}
