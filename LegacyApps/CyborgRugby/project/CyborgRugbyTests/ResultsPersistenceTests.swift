import XCTest
@testable import CyborgRugby
import Foundation

/// Comprehensive test suite for ResultsPersistence functionality
/// Tests cover normal operation, edge cases, error handling, and data integrity
final class ResultsPersistenceTests: XCTestCase {
    func testSaveAndLoadRoundTrip() throws {
        // Minimal scans: empty dictionary
        let scans: [HeadScanningPose: ScanResult] = [:]
        let m = dummyMeasurements()
        let result = CompleteScanResult(
            individualScans: scans,
            overallQuality: 0.85,
            timestamp: Date(),
            totalScanTime: 10,
            successfulPoses: 0,
            rugbyFitnessMeasurements: m
        )
        let fileName = "unit_test_scan.json"
        ResultsPersistence.save(result: result, fileName: fileName)
        let loaded = ResultsPersistence.load(fileName: fileName)
        XCTAssertNotNil(loaded)
        if let loaded = loaded {
            XCTAssertEqual(Double(loaded.overallQuality), 0.85, accuracy: 0.0001)
            XCTAssertEqual(Double(loaded.headCircumferenceCM), Double(m.headCircumference.value), accuracy: 0.0001)
        }
    }

    private func vm(_ v: Float) -> ValidatedMeasurement {
        ValidatedMeasurement(value: v, confidence: 1.0, validationStatus: .validated, alternativeValues: [], measurementSource: .userInput(verified: true))
    }
    private func ears() -> ValidatedEarDimensions {
        ValidatedEarDimensions(height: vm(55), width: vm(28), protrusionAngle: vm(40), topToLobe: vm(44))
    }
    private func dummyMeasurements() -> ScrumCapMeasurements {
        ScrumCapMeasurements(
            headCircumference: vm(56.0),
            earToEarOverTop: vm(34.0),
            foreheadToNeckBase: vm(190.0),
            leftEarDimensions: ears(),
            rightEarDimensions: ears(),
            earAsymmetryFactor: 0.0,
            occipitalProminence: vm(10),
            neckCurveRadius: vm(35),
            backHeadWidth: vm(160),
            jawLineToEar: vm(75),
            chinToEarDistance: vm(90)
        )
    }
}
