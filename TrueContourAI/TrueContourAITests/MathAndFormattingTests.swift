import XCTest
import simd
@testable import TrueContourAI

final class MathAndFormattingTests: XCTestCase {

    private func assertVectorClose(_ v: SIMD3<Float>, _ target: SIMD3<Float>, tol: Float = 1e-4) {
        XCTAssertLessThan(simd_length(v - target), tol)
    }

    func testRotationHandlesOppositeVectors() {
        let a = SIMD3<Float>(0, 1, 0)
        let b = SIMD3<Float>(0, -1, 0)
        let r = HeadMeasurementService._rotationForTest(from: a, to: b)
        let rotated = r * a
        assertVectorClose(rotated, b)
    }

    func testOBJFormattingUsesDotDecimal() {
        let s = ScanExporterService._formatOBJVectorForTest(prefix: "v", x: 1.25, y: 2.5, z: 3.75)
        XCTAssertTrue(s.hasPrefix("v "))
        XCTAssertTrue(s.contains("1.250000"))
        XCTAssertFalse(s.contains(","))
    }

    func testScanInsightFormatterPrefersDerivedCircumference() {
        let summary = makeSummary(
            overallConfidence: 0.91,
            pointCountEstimate: 80_000,
            derivedMeasurements: .init(
                sliceHeightNormalized: 0.5,
                circumferenceMm: 560,
                widthMm: 170,
                depthMm: 220,
                confidence: 0.9,
                status: "ok"
            )
        )

        let insight = ScanInsightFormatter.makeInsight(from: summary)

        XCTAssertNotNil(insight)
        if case .circumferenceMm(let value)? = insight?.detail {
            XCTAssertEqual(value, 560)
        } else {
            XCTFail("Expected circumference detail")
        }
    }

    func testScanInsightFormatterUsesPointCountWhenNoDerivedMeasurements() {
        let summary = makeSummary(
            overallConfidence: 0.78,
            pointCountEstimate: 12_500,
            derivedMeasurements: nil
        )

        let insight = ScanInsightFormatter.makeInsight(from: summary)

        XCTAssertNotNil(insight)
        if case .pointCount(let count)? = insight?.detail {
            XCTAssertEqual(count, 12_500)
        } else {
            XCTFail("Expected point count detail")
        }
    }

    func testScanInsightFormatterReturnsNilWhenNoDerivedAndNoPoints() {
        let summary = makeSummary(
            overallConfidence: 0.42,
            pointCountEstimate: 0,
            derivedMeasurements: nil
        )

        XCTAssertNil(ScanInsightFormatter.makeInsight(from: summary))
    }

    func testTrendPrefersCircumferenceChangeWhenAvailable() {
        let previous = makeSummary(
            overallConfidence: 0.72,
            pointCountEstimate: 40_000,
            derivedMeasurements: .init(
                sliceHeightNormalized: 0.5,
                circumferenceMm: 550,
                widthMm: 165,
                depthMm: 215,
                confidence: 0.8,
                status: "ok"
            )
        )
        let current = makeSummary(
            overallConfidence: 0.95,
            pointCountEstimate: 42_000,
            derivedMeasurements: .init(
                sliceHeightNormalized: 0.5,
                circumferenceMm: 558,
                widthMm: 168,
                depthMm: 218,
                confidence: 0.88,
                status: "ok"
            )
        )

        let trend = ScanInsightFormatter.makeTrend(current: current, previous: previous)
        if case .circumferenceIncrease(let value) = trend.kind {
            XCTAssertEqual(value, 8)
        } else {
            XCTFail("Expected circumference increase trend")
        }
    }

    func testTrendFallsBackToConfidenceChange() {
        let previous = makeSummary(overallConfidence: 0.62, pointCountEstimate: 40_000, derivedMeasurements: nil)
        let current = makeSummary(overallConfidence: 0.71, pointCountEstimate: 42_000, derivedMeasurements: nil)

        let trend = ScanInsightFormatter.makeTrend(current: current, previous: previous)
        if case .confidenceImproved(let value) = trend.kind {
            XCTAssertEqual(value, 9)
        } else {
            XCTFail("Expected confidence improved trend")
        }
    }

    func testTrendStableWhenDeltasSmall() {
        let previous = makeSummary(overallConfidence: 0.70, pointCountEstimate: 40_000, derivedMeasurements: nil)
        let current = makeSummary(overallConfidence: 0.71, pointCountEstimate: 42_000, derivedMeasurements: nil)

        let trend = ScanInsightFormatter.makeTrend(current: current, previous: previous)
        if case .stable = trend.kind {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected stable trend")
        }
    }

    func testQualityBadgeTierThresholds() {
        let high = ScanInsightFormatter.makeQualityBadge(from: makeSummary(overallConfidence: 0.81, pointCountEstimate: 10_000, derivedMeasurements: nil))
        let medium = ScanInsightFormatter.makeQualityBadge(from: makeSummary(overallConfidence: 0.65, pointCountEstimate: 10_000, derivedMeasurements: nil))
        let low = ScanInsightFormatter.makeQualityBadge(from: makeSummary(overallConfidence: 0.45, pointCountEstimate: 10_000, derivedMeasurements: nil))

        XCTAssertEqual(high.tier, .high)
        XCTAssertEqual(medium.tier, .medium)
        XCTAssertEqual(low.tier, .low)
    }

    private func makeSummary(
        overallConfidence: Float,
        pointCountEstimate: Int,
        derivedMeasurements: ScanSummary.DerivedMeasurements?
    ) -> ScanSummary {
        ScanSummary(
            schemaVersion: 2,
            startedAt: Date(timeIntervalSince1970: 0),
            finishedAt: Date(timeIntervalSince1970: 5),
            durationSeconds: 5.0,
            overallConfidence: overallConfidence,
            completedPoses: 0,
            skippedPoses: 0,
            poseRecords: [],
            pointCountEstimate: pointCountEstimate,
            hadEarVerification: false,
            processingProfile: nil,
            derivedMeasurements: derivedMeasurements
        )
    }
}
