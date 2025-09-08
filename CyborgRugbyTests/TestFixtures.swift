import Foundation
@testable import CyborgRugby
import StandardCyborgFusion

/// Test fixtures and mock data for CyborgRugby unit tests
/// Provides reusable test data and helper methods across test suites
struct TestFixtures {
    
    // MARK: - Mock Data Creation
    
    /// Creates a ValidatedMeasurement with specified parameters
    static func validatedMeasurement(
        value: Float,
        confidence: Float = 0.9,
        status: ValidatedMeasurement.ValidationStatus = .validated,
        alternatives: [Float] = [],
        source: ValidatedMeasurement.MeasurementSource = .mlModel(modelName: "TestModel", confidence: 0.9)
    ) -> ValidatedMeasurement {
        return ValidatedMeasurement(
            value: value,
            confidence: confidence,
            validationStatus: status,
            alternativeValues: alternatives,
            measurementSource: source
        )
    }
    
    /// Creates ValidatedEarDimensions with typical values
    static func validatedEarDimensions(
        height: Float = 55.0,
        width: Float = 28.0,
        protrusion: Float = 40.0,
        topToLobe: Float = 44.0
    ) -> ValidatedEarDimensions {
        return ValidatedEarDimensions(
            height: validatedMeasurement(value: height),
            width: validatedMeasurement(value: width),
            protrusionAngle: validatedMeasurement(value: protrusion),
            topToLobe: validatedMeasurement(value: topToLobe)
        )
    }
    
    /// Creates typical ScrumCapMeasurements for testing
    static func typicalScrumCapMeasurements() -> ScrumCapMeasurements {
        return ScrumCapMeasurements(
            headCircumference: validatedMeasurement(value: 56.0),
            earToEarOverTop: validatedMeasurement(value: 34.0),
            foreheadToNeckBase: validatedMeasurement(value: 190.0),
            leftEarDimensions: validatedEarDimensions(),
            rightEarDimensions: validatedEarDimensions(),
            earAsymmetryFactor: 0.05,
            occipitalProminence: validatedMeasurement(value: 12.0),
            neckCurveRadius: validatedMeasurement(value: 35.0),
            backHeadWidth: validatedMeasurement(value: 160.0),
            jawLineToEar: validatedMeasurement(value: 75.0),
            chinToEarDistance: validatedMeasurement(value: 90.0)
        )
    }
    
    /// Creates measurements for a small head (youth size)
    static func smallHeadMeasurements() -> ScrumCapMeasurements {
        return ScrumCapMeasurements(
            headCircumference: validatedMeasurement(value: 48.0),
            earToEarOverTop: validatedMeasurement(value: 28.0),
            foreheadToNeckBase: validatedMeasurement(value: 160.0),
            leftEarDimensions: validatedEarDimensions(height: 45.0, width: 22.0, protrusion: 30.0),
            rightEarDimensions: validatedEarDimensions(height: 45.0, width: 22.0, protrusion: 30.0),
            earAsymmetryFactor: 0.02,
            occipitalProminence: validatedMeasurement(value: 8.0),
            neckCurveRadius: validatedMeasurement(value: 25.0),
            backHeadWidth: validatedMeasurement(value: 140.0),
            jawLineToEar: validatedMeasurement(value: 65.0),
            chinToEarDistance: validatedMeasurement(value: 75.0)
        )
    }
    
    /// Creates measurements for a large head (XL size)
    static func largeHeadMeasurements() -> ScrumCapMeasurements {
        return ScrumCapMeasurements(
            headCircumference: validatedMeasurement(value: 63.0),
            earToEarOverTop: validatedMeasurement(value: 38.0),
            foreheadToNeckBase: validatedMeasurement(value: 210.0),
            leftEarDimensions: validatedEarDimensions(height: 65.0, width: 32.0, protrusion: 50.0),
            rightEarDimensions: validatedEarDimensions(height: 65.0, width: 32.0, protrusion: 50.0),
            earAsymmetryFactor: 0.03,
            occipitalProminence: validatedMeasurement(value: 18.0),
            neckCurveRadius: validatedMeasurement(value: 45.0),
            backHeadWidth: validatedMeasurement(value: 180.0),
            jawLineToEar: validatedMeasurement(value: 85.0),
            chinToEarDistance: validatedMeasurement(value: 100.0)
        )
    }
    
    /// Creates asymmetric ear measurements for testing edge cases
    static func asymmetricEarMeasurements() -> ScrumCapMeasurements {
        let leftEar = validatedEarDimensions(height: 65.0, width: 30.0, protrusion: 55.0)
        let rightEar = validatedEarDimensions(height: 50.0, width: 25.0, protrusion: 35.0)
        
        return ScrumCapMeasurements(
            headCircumference: validatedMeasurement(value: 56.0),
            earToEarOverTop: validatedMeasurement(value: 34.0),
            foreheadToNeckBase: validatedMeasurement(value: 180.0),
            leftEarDimensions: leftEar,
            rightEarDimensions: rightEar,
            earAsymmetryFactor: 0.4, // High asymmetry
            occipitalProminence: validatedMeasurement(value: 12.0),
            neckCurveRadius: validatedMeasurement(value: 35.0),
            backHeadWidth: validatedMeasurement(value: 160.0),
            jawLineToEar: validatedMeasurement(value: 75.0),
            chinToEarDistance: validatedMeasurement(value: 85.0)
        )
    }
    
    /// Creates a complete scan result for testing
    static func completeScanResult(
        quality: Float = 0.85,
        scans: [HeadScanningPose: ScanResult] = [:],
        measurements: ScrumCapMeasurements? = nil
    ) -> CompleteScanResult {
        return CompleteScanResult(
            individualScans: scans,
            overallQuality: quality,
            timestamp: Date(),
            totalScanTime: 120.0,
            successfulPoses: scans.count,
            rugbyFitnessMeasurements: measurements ?? typicalScrumCapMeasurements()
        )
    }
    
    /// Creates a mock scan result with specified parameters
    static func scanResult(
        confidence: Float = 0.9,
        status: ScanResult.ScanStatus = .completed,
        hasPointCloud: Bool = true,
        pointCount: Int32 = 1000
    ) -> ScanResult {
        let pointCloud = hasPointCloud ? mockPointCloud(pointCount: pointCount) : nil
        return ScanResult(pointCloud: pointCloud, confidence: confidence, status: status)
    }
    
    /// Creates a mock point cloud for testing
    static func mockPointCloud(pointCount: Int32) -> SCPointCloud {
        let pointCloud = SCPointCloud()
        
        // Generate realistic head-like point distribution
        var points: [Float] = []
        let radius: Float = 0.1 // 10cm radius approximation
        
        for i in 0..<pointCount {
            let theta = Float(i) * 2.0 * Float.pi / Float(pointCount)
            let phi = Float.random(in: 0...Float.pi)
            
            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)
            
            points.append(contentsOf: [x, y, z])
        }
        
        // In a real implementation, you would set these points
        // pointCloud.setPoints(points)
        
        return pointCloud
    }
    
    /// Creates a set of mock scans for different poses
    static func mockScansForAllPoses() -> [HeadScanningPose: ScanResult] {
        let poses: [HeadScanningPose] = [
            .frontFacing,
            .leftProfile,
            .rightProfile,
            .leftThreeQuarter,
            .rightThreeQuarter,
            .lookingDown,
            .chinUp
        ]
        
        var scans: [HeadScanningPose: ScanResult] = [:]
        
        for (index, pose) in poses.enumerated() {
            let pointCount = Int32(800 + index * 100) // Varying density
            let confidence = 0.75 + Float(index) * 0.03 // Varying quality
            scans[pose] = scanResult(confidence: confidence, pointCount: pointCount)
        }
        
        return scans
    }
    
    // MARK: - Validation Helpers
    
    /// Validates that measurements are within reasonable bounds for head scanning
    static func validateMeasurementBounds(_ measurements: ScrumCapMeasurements) -> [String] {
        var issues: [String] = []
        
        // Head circumference should be 40-70cm
        let hc = measurements.headCircumference.value
        if hc < 40.0 || hc > 70.0 {
            issues.append("Head circumference \(hc)cm is outside normal range (40-70cm)")
        }
        
        // Ear height should be 40-80mm
        let leftEarHeight = measurements.leftEarDimensions.height.value
        let rightEarHeight = measurements.rightEarDimensions.height.value
        
        if leftEarHeight < 40.0 || leftEarHeight > 80.0 {
            issues.append("Left ear height \(leftEarHeight)mm is outside normal range (40-80mm)")
        }
        
        if rightEarHeight < 40.0 || rightEarHeight > 80.0 {
            issues.append("Right ear height \(rightEarHeight)mm is outside normal range (40-80mm)")
        }
        
        // Protrusion angles should be 15-70 degrees
        let leftProtrusion = measurements.leftEarDimensions.protrusionAngle.value
        let rightProtrusion = measurements.rightEarDimensions.protrusionAngle.value
        
        if leftProtrusion < 15.0 || leftProtrusion > 70.0 {
            issues.append("Left ear protrusion \(leftProtrusion)° is outside normal range (15-70°)")
        }
        
        if rightProtrusion < 15.0 || rightProtrusion > 70.0 {
            issues.append("Right ear protrusion \(rightProtrusion)° is outside normal range (15-70°)")
        }
        
        return issues
    }
    
    /// Validates that a complete scan result is well-formed
    static func validateScanResult(_ result: CompleteScanResult) -> [String] {
        var issues: [String] = []
        
        // Quality should be 0-1
        if result.overallQuality < 0.0 || result.overallQuality > 1.0 {
            issues.append("Overall quality \(result.overallQuality) should be between 0-1")
        }
        
        // Scan time should be reasonable (30 seconds to 10 minutes)
        if result.totalScanTime < 30.0 || result.totalScanTime > 600.0 {
            issues.append("Total scan time \(result.totalScanTime)s is outside reasonable range (30-600s)")
        }
        
        // Successful poses should not exceed total possible poses
        let maxPoses = 7 // Total number of HeadScanningPose cases
        if result.successfulPoses > maxPoses {
            issues.append("Successful poses \(result.successfulPoses) exceeds maximum possible (\(maxPoses))")
        }
        
        // Validate measurements
        issues.append(contentsOf: validateMeasurementBounds(result.rugbyFitnessMeasurements))
        
        return issues
    }
    
    // MARK: - Test Utilities
    
    /// Creates a temporary directory for test file operations
    static func createTemporaryDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("CyborgRugbyTests_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
            return testDir
        } catch {
            fatalError("Failed to create temporary test directory: \(error)")
        }
    }
    
    /// Cleans up a temporary directory created for testing
    static func cleanupTemporaryDirectory(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Warning: Failed to cleanup temporary directory: \(error)")
        }
    }
    
    /// Creates a temporary file URL with specified extension
    static func temporaryFileURL(extension ext: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test_\(UUID().uuidString).\(ext)"
        return tempDir.appendingPathComponent(fileName)
    }
    
    // MARK: - Performance Test Helpers
    
    /// Measures the time taken to execute a block of code
    static func measureTime<T>(block: () throws -> T) rethrows -> (result: T, timeInterval: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, timeElapsed)
    }
    
    /// Generates test data for performance benchmarks
    static func generatePerformanceTestData(count: Int) -> [ScrumCapMeasurements] {
        return (0..<count).map { index in
            let baseCircumference: Float = 50.0 + Float(index % 20) // 50-70cm range
            let measurements = typicalScrumCapMeasurements()
            
            // Create variation by modifying the base measurements
            return ScrumCapMeasurements(
                headCircumference: validatedMeasurement(value: baseCircumference),
                earToEarOverTop: measurements.earToEarOverTop,
                foreheadToNeckBase: measurements.foreheadToNeckBase,
                leftEarDimensions: measurements.leftEarDimensions,
                rightEarDimensions: measurements.rightEarDimensions,
                earAsymmetryFactor: measurements.earAsymmetryFactor,
                occipitalProminence: measurements.occipitalProminence,
                neckCurveRadius: measurements.neckCurveRadius,
                backHeadWidth: measurements.backHeadWidth,
                jawLineToEar: measurements.jawLineToEar,
                chinToEarDistance: measurements.chinToEarDistance
            )
        }
    }
}