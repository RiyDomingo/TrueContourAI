import XCTest
@testable import TrueContourAI

final class ScanSummaryBuilderTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var settingsStore: SettingsStore!

    override func setUp() {
        super.setUp()
        suiteName = "ScanSummaryBuilderTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        settingsStore = SettingsStore(defaults: defaults)
    }

    override func tearDown() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        settingsStore = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testBuildReturnsNilWhenMetricsMissing() {
        let summary = ScanSummaryBuilder.build(
            settingsStore: settingsStore,
            metrics: nil,
            qualityReport: nil,
            measurementSummary: nil,
            hadEarVerification: false
        )

        XCTAssertNil(summary)
    }

    func testBuildCapsOverallConfidenceByQualityScore() {
        let metrics = ScanFlowState.ScanSessionMetrics(
            startedAt: Date(timeIntervalSince1970: 100),
            finishedAt: Date(timeIntervalSince1970: 110),
            durationSeconds: 10,
            overallConfidence: 0.92
        )
        let report = ScanQualityReport(
            pointCount: 100_000,
            validPointCount: 88_000,
            widthMeters: 0.18,
            heightMeters: 0.22,
            depthMeters: 0.19,
            qualityScore: 0.74,
            isExportRecommended: true,
            advice: .rescanSlowly,
            reason: "ok"
        )

        let summary = ScanSummaryBuilder.build(
            settingsStore: settingsStore,
            metrics: metrics,
            qualityReport: report,
            measurementSummary: nil,
            hadEarVerification: false
        )

        XCTAssertNotNil(summary)
        guard let overallConfidence = summary?.overallConfidence else {
            return XCTFail("Expected overallConfidence")
        }
        XCTAssertEqual(overallConfidence, Float(0.74), accuracy: Float(0.0001))
        XCTAssertEqual(summary?.pointCountEstimate, 88_000)
        XCTAssertEqual(summary?.schemaVersion, settingsStore.scanSummarySchemaVersion)
    }

    func testBuildMapsDerivedMeasurementsAndProcessingProfile() {
        var processing = settingsStore.processingConfig
        processing.outlierSigma = 4.0
        processing.decimateRatio = 1.25
        processing.cropBelowNeck = false
        processing.meshResolution = 7
        processing.meshSmoothness = 5
        settingsStore.processingConfig = processing

        let metrics = ScanFlowState.ScanSessionMetrics(
            startedAt: Date(timeIntervalSince1970: 200),
            finishedAt: Date(timeIntervalSince1970: 230),
            durationSeconds: 30,
            overallConfidence: 0.81
        )
        let measurement = LocalMeasurementGenerationService.ResultSummary(
            sliceHeightNormalized: 0.5,
            circumferenceMm: 560,
            widthMm: 170,
            depthMm: 210,
            confidence: 0.88,
            status: "validated"
        )

        let summary = ScanSummaryBuilder.build(
            settingsStore: settingsStore,
            metrics: metrics,
            qualityReport: nil,
            measurementSummary: measurement,
            hadEarVerification: true
        )

        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.hadEarVerification, true)
        XCTAssertEqual(summary?.pointCountEstimate, 0)
        guard let outlierSigma = summary?.processingProfile?.outlierSigma else {
            return XCTFail("Expected outlierSigma")
        }
        guard let decimateRatio = summary?.processingProfile?.decimateRatio else {
            return XCTFail("Expected decimateRatio")
        }
        XCTAssertEqual(outlierSigma, Float(4.0), accuracy: Float(0.0001))
        XCTAssertEqual(decimateRatio, Float(1.25), accuracy: Float(0.0001))
        XCTAssertEqual(summary?.processingProfile?.cropBelowNeck, false)
        XCTAssertEqual(summary?.processingProfile?.meshResolution, 7)
        XCTAssertEqual(summary?.processingProfile?.meshSmoothness, 5)
        guard let circumferenceMm = summary?.derivedMeasurements?.circumferenceMm else {
            return XCTFail("Expected circumferenceMm")
        }
        XCTAssertEqual(circumferenceMm, Float(560), accuracy: Float(0.0001))
        XCTAssertEqual(summary?.derivedMeasurements?.status, "validated")
    }
}
