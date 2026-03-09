import Foundation

enum ScanSummaryBuilder {
    static func build(
        settingsStore: SettingsStore,
        metrics: ScanFlowState.ScanSessionMetrics?,
        qualityReport: ScanQualityReport?,
        measurementSummary: LocalMeasurementGenerationService.ResultSummary?,
        hadEarVerification: Bool
    ) -> ScanSummary? {
        guard let metrics else { return nil }

        return ScanSummary(
            schemaVersion: settingsStore.scanSummarySchemaVersion,
            startedAt: metrics.startedAt,
            finishedAt: metrics.finishedAt,
            durationSeconds: metrics.durationSeconds,
            overallConfidence: qualityReport?.qualityScore ?? measurementSummary?.confidence ?? 0,
            pointCountEstimate: qualityReport?.validPointCount ?? 0,
            hadEarVerification: hadEarVerification,
            processingProfile: nil,
            derivedMeasurements: measurementSummary.map {
                ScanSummary.DerivedMeasurements(
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
