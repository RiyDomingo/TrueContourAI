import XCTest
@testable import TrueContourAI

final class ScanQualityValidatorTests: XCTestCase {
    private func makeConfig(
        gateEnabled: Bool = true,
        minValidPoints: Int = 100,
        minValidRatio: Float = 0.6,
        minQualityScore: Float = 0.65,
        minHeadDimensionMeters: Float = 0.10,
        maxHeadDimensionMeters: Float = 0.50
    ) -> ScanQualityValidator.ValidationConfig {
        .init(
            gateEnabled: gateEnabled,
            minValidPoints: minValidPoints,
            minValidRatio: minValidRatio,
            minQualityScore: minQualityScore,
            minHeadDimensionMeters: minHeadDimensionMeters,
            maxHeadDimensionMeters: maxHeadDimensionMeters
        )
    }

    func testNoPointsProducesNoPointsReason() {
        let report = ScanQualityValidator.debug_evaluate(rawCount: 0, validPositions: [], config: makeConfig())
        XCTAssertEqual(report.validPointCount, 0)
        XCTAssertEqual(report.reason, L("scan.quality.reason.noPoints"))
        XCTAssertFalse(report.isExportRecommended)
    }

    func testInvalidPointsProducesInvalidPointsReason() {
        let report = ScanQualityValidator.debug_evaluate(rawCount: 20, validPositions: [], config: makeConfig())
        XCTAssertEqual(report.validPointCount, 0)
        XCTAssertEqual(report.reason, L("scan.quality.reason.invalidPoints"))
        XCTAssertFalse(report.isExportRecommended)
    }

    func testInvalidFormatProducesInvalidFormatReason() {
        let report = ScanQualityValidator.debug_evaluateDataLayout(
            rawCount: 20,
            stride: 0,
            positionOffset: 0,
            componentSize: 4,
            dataSize: 80,
            config: makeConfig()
        )
        XCTAssertEqual(report.reason, L("scan.quality.reason.invalidFormat"))
        XCTAssertFalse(report.isExportRecommended)
    }

    func testIncompleteDataProducesIncompleteDataReason() {
        let report = ScanQualityValidator.debug_evaluateDataLayout(
            rawCount: 20,
            stride: 16,
            positionOffset: 0,
            componentSize: 4,
            dataSize: 40,
            config: makeConfig()
        )
        XCTAssertEqual(report.reason, L("scan.quality.reason.incompleteData"))
        XCTAssertFalse(report.isExportRecommended)
    }

    func testLowCoverageBlocksExport() {
        let points = Array(repeating: SIMD3<Float>(0.2, 0.2, 0.2), count: 50)
        let report = ScanQualityValidator.debug_evaluate(
            rawCount: 200,
            validPositions: points,
            config: makeConfig(minValidPoints: 100, minValidRatio: 0.2)
        )

        XCTAssertEqual(report.reason, L("scan.quality.reason.lowCoverage"))
        XCTAssertEqual(report.advice, .improveLighting)
        XCTAssertFalse(report.isExportRecommended)
    }

    func testNoisyPointsBlocksExportWhenRatioLow() {
        let points = Array(repeating: SIMD3<Float>(0.2, 0.2, 0.2), count: 120)
        let report = ScanQualityValidator.debug_evaluate(
            rawCount: 400,
            validPositions: points,
            config: makeConfig(minValidPoints: 100, minValidRatio: 0.5)
        )

        XCTAssertEqual(report.reason, L("scan.quality.reason.noisyPoints"))
        XCTAssertEqual(report.advice, .reduceMovement)
        XCTAssertFalse(report.isExportRecommended)
    }

    func testBadBoundsBlocksExport() {
        let points = [
            SIMD3<Float>(0.0, 0.0, 0.0),
            SIMD3<Float>(0.02, 0.25, 0.25)
        ] + Array(repeating: SIMD3<Float>(0.01, 0.2, 0.2), count: 148)
        let report = ScanQualityValidator.debug_evaluate(
            rawCount: 150,
            validPositions: points,
            config: makeConfig(minValidPoints: 100, minValidRatio: 0.6)
        )

        XCTAssertEqual(report.reason, L("scan.quality.reason.badBounds"))
        XCTAssertEqual(report.advice, .adjustDistance)
        XCTAssertFalse(report.isExportRecommended)
    }

    func testLowScoreBlocksExport() {
        var points: [SIMD3<Float>] = []
        for i in 0..<100 {
            let x = Float(i % 5) * 0.03 + 0.12
            let y = Float((i / 5) % 5) * 0.03 + 0.12
            let z = Float((i / 20) % 5) * 0.03 + 0.12
            points.append(SIMD3<Float>(x, y, z))
        }
        let report = ScanQualityValidator.debug_evaluate(
            rawCount: 100,
            validPositions: points,
            config: makeConfig(minValidPoints: 100, minValidRatio: 0.6, minQualityScore: 0.99)
        )

        XCTAssertEqual(report.reason, L("scan.quality.reason.lowScore"))
        XCTAssertEqual(report.advice, .rescanSlowly)
        XCTAssertFalse(report.isExportRecommended)
    }

    func testAcceptableScanIsExportable() {
        var points: [SIMD3<Float>] = []
        for i in 0..<200 {
            let x = Float(i % 5) * 0.03 + 0.10
            let y = Float((i / 5) % 5) * 0.03 + 0.10
            let z = Float((i / 25) % 5) * 0.03 + 0.10
            points.append(SIMD3<Float>(x, y, z))
        }
        let report = ScanQualityValidator.debug_evaluate(
            rawCount: 200,
            validPositions: points,
            config: makeConfig(minValidPoints: 100, minValidRatio: 0.6, minQualityScore: 0.1)
        )

        XCTAssertEqual(report.reason, L("scan.quality.reason.acceptable"))
        XCTAssertTrue(report.isExportRecommended)
    }

    func testGateDisabledForcesExportable() {
        let points = Array(repeating: SIMD3<Float>(0.2, 0.2, 0.2), count: 10)
        let report = ScanQualityValidator.debug_evaluate(
            rawCount: 100,
            validPositions: points,
            config: makeConfig(gateEnabled: false, minValidPoints: 90, minValidRatio: 0.9)
        )

        XCTAssertTrue(report.isExportRecommended)
    }
}
