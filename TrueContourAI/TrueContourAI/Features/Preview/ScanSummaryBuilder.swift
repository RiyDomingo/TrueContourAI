import Foundation

enum ScanSummaryBuilder {
    static func build(
        settingsStore: SettingsStore,
        metrics: ScanFlowState.ScanSessionMetrics?,
        qualityReport: ScanQualityReport?,
        measurementSummary: LocalMeasurementGenerationService.ResultSummary?,
        hadEarVerification: Bool
    ) -> ScanService.ScanSummary? {
        guard let metrics else { return nil }

        return ScanService.ScanSummary(
            schemaVersion: settingsStore.scanSummarySchemaVersion,
            startedAt: metrics.startedAt,
            finishedAt: metrics.finishedAt,
            durationSeconds: metrics.durationSeconds,
            overallConfidence: min(metrics.overallConfidence, qualityReport?.qualityScore ?? metrics.overallConfidence),
            completedPoses: 0,
            skippedPoses: 0,
            poseRecords: [],
            pointCountEstimate: qualityReport?.validPointCount ?? 0,
            hadEarVerification: hadEarVerification,
            processingProfile: .init(
                outlierSigma: settingsStore.processingConfig.outlierSigma,
                decimateRatio: settingsStore.processingConfig.decimateRatio,
                cropBelowNeck: settingsStore.processingConfig.cropBelowNeck,
                meshResolution: settingsStore.processingConfig.meshResolution,
                meshSmoothness: settingsStore.processingConfig.meshSmoothness
            ),
            derivedMeasurements: measurementSummary.map {
                ScanService.ScanSummary.DerivedMeasurements(
                    sliceHeightNormalized: $0.sliceHeightNormalized,
                    circumferenceMm: $0.circumferenceMm,
                    widthMm: $0.widthMm,
                    depthMm: $0.depthMm,
                    confidence: $0.confidence,
                    status: $0.status
                )
            }
        )
    }
}
