import Foundation

final class SettingsStore {
    struct ScanQualityConfig {
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

    struct ProcessingConfig {
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
}
