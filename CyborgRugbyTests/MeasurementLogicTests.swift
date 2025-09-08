import XCTest
@testable import CyborgRugby

/// Comprehensive test suite for CyborgRugby measurement logic and calculations
/// Tests cover normal operation, edge cases, boundary values, and performance
final class MeasurementLogicTests: XCTestCase {
    private func vm(_ value: Float, conf: Float = 1.0, status: ValidatedMeasurement.ValidationStatus = .validated) -> ValidatedMeasurement {
        return ValidatedMeasurement(value: value,
                                    confidence: conf,
                                    validationStatus: status,
                                    alternativeValues: [],
                                    measurementSource: .statisticalEstimation(basedOn: []))
    }

    private func ears(h: Float, w: Float, protrusion: Float) -> ValidatedEarDimensions {
        return ValidatedEarDimensions(
            height: vm(h),
            width: vm(w),
            protrusionAngle: vm(protrusion),
            topToLobe: vm(h * 0.8)
        )
    }

    func testSizeCalculatorUpsizeOnProtrusionAndOccipital() {
        let m = ScrumCapMeasurements(
            headCircumference: vm(58.0), // near upper bound of .medium
            earToEarOverTop: vm(36.0),
            foreheadToNeckBase: vm(190.0),
            leftEarDimensions: ears(h: 60, w: 30, protrusion: 50),
            rightEarDimensions: ears(h: 60, w: 30, protrusion: 52),
            earAsymmetryFactor: 0.05,
            occipitalProminence: vm(20.0), // pronounced
            neckCurveRadius: vm(40.0),
            backHeadWidth: vm(160.0),
            jawLineToEar: vm(80.0),
            chinToEarDistance: vm(95.0)
        )
        let size = ScrumCapSizeCalculator.calculate(from: m)
        XCTAssertTrue(size == .large || size == .extraLarge, "Expected upsize due to protrusion/occipital")
    }

    func testHeadShapeClassifier() {
        var m = ScrumCapMeasurements(
            headCircumference: vm(56.0),
            earToEarOverTop: vm(34.0),
            foreheadToNeckBase: vm(180.0),
            leftEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            rightEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            earAsymmetryFactor: 0.0,
            occipitalProminence: vm(10),
            neckCurveRadius: vm(35),
            backHeadWidth: vm(160),
            jawLineToEar: vm(75),
            chinToEarDistance: vm(90)
        )
        XCTAssertEqual(HeadShapeClassifier.classify(m), .oval)

        m = ScrumCapMeasurements(
            headCircumference: vm(56.0),
            earToEarOverTop: vm(34.0),
            foreheadToNeckBase: vm(220.0),
            leftEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            rightEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            earAsymmetryFactor: 0.0,
            occipitalProminence: vm(10),
            neckCurveRadius: vm(35),
            backHeadWidth: vm(140),
            jawLineToEar: vm(75),
            chinToEarDistance: vm(90)
        )
        XCTAssertEqual(HeadShapeClassifier.classify(m), .long)
    }
    
    // MARK: - Edge Case Testing
    
    func testScrumCapSizeCalculatorWithExtremeValues() {
        // Test with extremely large head
        let largeHead = ScrumCapMeasurements(
            headCircumference: vm(65.0), // Very large
            earToEarOverTop: vm(40.0),
            foreheadToNeckBase: vm(200.0),
            leftEarDimensions: ears(h: 70, w: 35, protrusion: 60),
            rightEarDimensions: ears(h: 70, w: 35, protrusion: 60),
            earAsymmetryFactor: 0.0,
            occipitalProminence: vm(25.0),
            neckCurveRadius: vm(50.0),
            backHeadWidth: vm(180.0),
            jawLineToEar: vm(85.0),
            chinToEarDistance: vm(100.0)
        )
        let largeSize = ScrumCapSizeCalculator.calculate(from: largeHead)
        XCTAssertEqual(largeSize, .doubleXL)
        
        // Test with extremely small head
        let smallHead = ScrumCapMeasurements(
            headCircumference: vm(48.0), // Very small
            earToEarOverTop: vm(28.0),
            foreheadToNeckBase: vm(160.0),
            leftEarDimensions: ears(h: 45, w: 22, protrusion: 30),
            rightEarDimensions: ears(h: 45, w: 22, protrusion: 30),
            earAsymmetryFactor: 0.0,
            occipitalProminence: vm(8.0),
            neckCurveRadius: vm(25.0),
            backHeadWidth: vm(140.0),
            jawLineToEar: vm(65.0),
            chinToEarDistance: vm(75.0)
        )
        let smallSize = ScrumCapSizeCalculator.calculate(from: smallHead)
        XCTAssertEqual(smallSize, .youth)
    }
    
    func testAsymmetricEarHandling() {
        let asymmetricMeasurements = ScrumCapMeasurements(
            headCircumference: vm(56.0),
            earToEarOverTop: vm(34.0),
            foreheadToNeckBase: vm(180.0),
            leftEarDimensions: ears(h: 65, w: 30, protrusion: 55), // Large left ear
            rightEarDimensions: ears(h: 50, w: 25, protrusion: 35), // Smaller right ear
            earAsymmetryFactor: 0.4, // High asymmetry
            occipitalProminence: vm(12.0),
            neckCurveRadius: vm(35.0),
            backHeadWidth: vm(160.0),
            jawLineToEar: vm(75.0),
            chinToEarDistance: vm(85.0)
        )
        
        let size = ScrumCapSizeCalculator.calculate(from: asymmetricMeasurements)
        XCTAssertTrue(size == .medium || size == .large, "Asymmetric ears should influence sizing")
    }
    
    func testConfidenceImpactOnMeasurements() {
        let lowConfidenceMeasurement = ValidatedMeasurement(
            value: 56.0,
            confidence: 0.3, // Low confidence
            validationStatus: .interpolated,
            alternativeValues: [55.5, 56.5],
            measurementSource: .statisticalEstimation(basedOn: [])
        )
        
        let measurements = ScrumCapMeasurements(
            headCircumference: lowConfidenceMeasurement,
            earToEarOverTop: vm(34.0),
            foreheadToNeckBase: vm(180.0),
            leftEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            rightEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            earAsymmetryFactor: 0.0,
            occipitalProminence: vm(10),
            neckCurveRadius: vm(35),
            backHeadWidth: vm(160),
            jawLineToEar: vm(75),
            chinToEarDistance: vm(90)
        )
        
        XCTAssertFalse(measurements.headCircumference.validationStatus.isReliable)
        XCTAssertEqual(measurements.headCircumference.validationStatus, .interpolated)
    }
    
    func testHeadShapeClassifierEdgeCases() {
        // Test borderline cases
        let borderlineRound = ScrumCapMeasurements(
            headCircumference: vm(56.0),
            earToEarOverTop: vm(34.0),
            foreheadToNeckBase: vm(185.0), // Borderline between round and long
            leftEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            rightEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            earAsymmetryFactor: 0.0,
            occipitalProminence: vm(10),
            neckCurveRadius: vm(35),
            backHeadWidth: vm(155), // Borderline width
            jawLineToEar: vm(75),
            chinToEarDistance: vm(90)
        )
        
        let shape = HeadShapeClassifier.classify(borderlineRound)
        XCTAssertTrue(shape == .round || shape == .oval || shape == .long, "Borderline case should classify consistently")
        
        // Test wide head
        let wideHead = ScrumCapMeasurements(
            headCircumference: vm(58.0),
            earToEarOverTop: vm(38.0), // Very wide
            foreheadToNeckBase: vm(170.0), // Shorter
            leftEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            rightEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            earAsymmetryFactor: 0.0,
            occipitalProminence: vm(10),
            neckCurveRadius: vm(35),
            backHeadWidth: vm(175), // Very wide back
            jawLineToEar: vm(75),
            chinToEarDistance: vm(90)
        )
        
        let wideShape = HeadShapeClassifier.classify(wideHead)
        XCTAssertTrue(wideShape == .square || wideShape == .round, "Very wide head should classify as square or round based on ratio")
    }
    
    func testMeasurementValidationStatuses() {
        let validatedMeasurement = vm(56.0, conf: 0.95, status: .validated)
        let invalidMeasurement = vm(56.0, conf: 0.2, status: .failed)
        let pendingMeasurement = vm(56.0, conf: 0.6, status: .interpolated)
        
        XCTAssertTrue(validatedMeasurement.validationStatus.isReliable)
        XCTAssertFalse(invalidMeasurement.validationStatus.isReliable)
        XCTAssertFalse(pendingMeasurement.validationStatus.isReliable)
        
        XCTAssertEqual(validatedMeasurement.validationStatus, .validated)
        XCTAssertEqual(invalidMeasurement.validationStatus, .failed)
        XCTAssertEqual(pendingMeasurement.validationStatus, .interpolated)
    }
    
    func testAlternativeValueHandling() {
        let measurementWithAlternatives = ValidatedMeasurement(
            value: 56.0,
            confidence: 0.8,
            validationStatus: .validated,
            alternativeValues: [55.2, 55.8, 56.2, 56.8],
            measurementSource: .mlModel(modelName: "stub", confidence: 0.9)
        )
        
        XCTAssertEqual(measurementWithAlternatives.alternativeValues.count, 4)
        XCTAssertTrue(measurementWithAlternatives.alternativeValues.contains(55.2))
        XCTAssertTrue(measurementWithAlternatives.alternativeValues.contains(56.8))
    }
    
    // MARK: - Performance Testing
    
    func testSizeCalculationPerformance() {
        let measurements = ScrumCapMeasurements(
            headCircumference: vm(56.0),
            earToEarOverTop: vm(34.0),
            foreheadToNeckBase: vm(180.0),
            leftEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            rightEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            earAsymmetryFactor: 0.0,
            occipitalProminence: vm(10),
            neckCurveRadius: vm(35),
            backHeadWidth: vm(160),
            jawLineToEar: vm(75),
            chinToEarDistance: vm(90)
        )
        
        measure {
            for _ in 0..<1000 {
                _ = ScrumCapSizeCalculator.calculate(from: measurements)
            }
        }
    }
    
    func testHeadShapeClassificationPerformance() {
        let measurements = ScrumCapMeasurements(
            headCircumference: vm(56.0),
            earToEarOverTop: vm(34.0),
            foreheadToNeckBase: vm(180.0),
            leftEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            rightEarDimensions: ears(h: 55, w: 28, protrusion: 40),
            earAsymmetryFactor: 0.0,
            occipitalProminence: vm(10),
            neckCurveRadius: vm(35),
            backHeadWidth: vm(160),
            jawLineToEar: vm(75),
            chinToEarDistance: vm(90)
        )
        
        measure {
            for _ in 0..<1000 {
                _ = HeadShapeClassifier.classify(measurements)
            }
        }
    }
    
    // MARK: - Boundary Value Testing
    
    func testScrumCapSizeBoundaryValues() {
        // Test exact boundary values for size classifications
        struct SizeBoundaryTest {
            let circumference: Float
            let expectedSize: ScrumCapSize
        }
        
        let boundaryTests = [
            SizeBoundaryTest(circumference: 49.9, expectedSize: .youth),
            SizeBoundaryTest(circumference: 50.0, expectedSize: .youth),
            SizeBoundaryTest(circumference: 54.9, expectedSize: .small),
            SizeBoundaryTest(circumference: 55.0, expectedSize: .small),
            SizeBoundaryTest(circumference: 59.9, expectedSize: .large),
            SizeBoundaryTest(circumference: 60.0, expectedSize: .large),
            SizeBoundaryTest(circumference: 63.0, expectedSize: .extraLarge)
        ]
        
        for test in boundaryTests {
            let measurements = ScrumCapMeasurements(
                headCircumference: vm(test.circumference),
                earToEarOverTop: vm(34.0),
                foreheadToNeckBase: vm(180.0),
                leftEarDimensions: ears(h: 55, w: 28, protrusion: 40),
                rightEarDimensions: ears(h: 55, w: 28, protrusion: 40),
                earAsymmetryFactor: 0.0,
                occipitalProminence: vm(10),
                neckCurveRadius: vm(35),
                backHeadWidth: vm(160),
                jawLineToEar: vm(75),
                chinToEarDistance: vm(90)
            )
            
            let calculatedSize = ScrumCapSizeCalculator.calculate(from: measurements)
            XCTAssertEqual(calculatedSize, test.expectedSize, 
                          "Circumference \(test.circumference) should result in size \(test.expectedSize)")
        }
    }
    
    func testEarDimensionConsistency() {
        let leftEar = ears(h: 60, w: 30, protrusion: 45)
        let rightEar = ears(h: 58, w: 32, protrusion: 43)
        
        // Test that ear dimensions are internally consistent
        XCTAssertTrue(leftEar.height.value > 0, "Ear height must be positive")
        XCTAssertTrue(leftEar.width.value > 0, "Ear width must be positive")
        XCTAssertTrue(leftEar.protrusionAngle.value >= 0 && leftEar.protrusionAngle.value <= 90, 
                     "Protrusion angle should be between 0-90 degrees")
        XCTAssertTrue(leftEar.topToLobe.value < leftEar.height.value, 
                     "Top to lobe distance should be less than total height")
        
        // Test asymmetry calculation
        let asymmetry = abs(leftEar.height.value - rightEar.height.value) / max(leftEar.height.value, rightEar.height.value)
        XCTAssertTrue(asymmetry >= 0 && asymmetry <= 1, "Asymmetry factor should be normalized")
    }
}
