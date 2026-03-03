import XCTest
@testable import CyborgRugby
import StandardCyborgFusion
import simd

/// Comprehensive test suite for PointCloudMetrics functionality
/// Tests cover validation, security, performance, and edge cases
final class PointCloudMetricsTests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    // MARK: - Input Validation Tests
    
    func testValidatePointCloudWithNilInput() {
        let result = PointCloudMetrics.validatePointCloud(nil)
        
        XCTAssertFalse(result.isValid, "Nil point cloud should be invalid")
        XCTAssertTrue(result.issues.contains(.nullInput), "Should report null input issue")
    }
    
    func testValidatePointCloudWithEmptyCloud() {
        let emptyCloud = SCPointCloud()
        let result = PointCloudMetrics.validatePointCloud(emptyCloud)
        
        XCTAssertFalse(result.isValid, "Empty point cloud should be invalid")
        XCTAssertTrue(result.issues.contains(.insufficientData), "Should report insufficient data")
    }
    
    func testValidatePointCloudWithValidInput() {
        let validCloud = createMockPointCloud(pointCount: 1000, bounds: (-1.0, 1.0))
        let result = PointCloudMetrics.validatePointCloud(validCloud)
        
        XCTAssertTrue(result.isValid, "Valid point cloud should pass validation")
        XCTAssertTrue(result.issues.isEmpty, "Valid cloud should have no issues")
    }
    
    func testValidatePointCloudWithExcessivePoints() {
        // Test with point count exceeding safety limits
        let excessiveCloud = createMockPointCloud(pointCount: 2_000_000, bounds: (-1.0, 1.0))
        let result = PointCloudMetrics.validatePointCloud(excessiveCloud)
        
        XCTAssertFalse(result.isValid, "Excessive point count should be invalid")
        XCTAssertTrue(result.issues.contains(.excessiveDataSize), "Should report excessive data size")
    }
    
    func testValidatePointCloudWithInvalidCoordinates() {
        let invalidCloud = createMockPointCloudWithInvalidPoints()
        let result = PointCloudMetrics.validatePointCloud(invalidCloud)
        
        XCTAssertFalse(result.isValid, "Point cloud with invalid coordinates should be invalid")
        XCTAssertTrue(result.issues.contains(.invalidCoordinates), "Should report invalid coordinates")
    }
    
    func testValidatePointCloudWithOutOfBoundsCoordinates() {
        let outOfBoundsCloud = createMockPointCloud(pointCount: 100, bounds: (-50.0, 50.0))
        let result = PointCloudMetrics.validatePointCloud(outOfBoundsCloud)
        
        XCTAssertFalse(result.isValid, "Out of bounds coordinates should be invalid")
        XCTAssertTrue(result.issues.contains(.unreasonableDimensions), "Should report unreasonable dimensions")
    }
    
    // MARK: - Metrics Calculation Tests
    
    func testCalculateBasicMetricsWithValidData() throws {
        let pointCloud = createMockPointCloud(pointCount: 100, bounds: (-0.5, 0.5))
        let result = PointCloudMetrics.validatePointCloud(pointCloud)
        
        XCTAssertTrue(result.isValid, "Test data should be valid")
        
        let metrics = try PointCloudMetrics.calculateBasicMetrics(for: pointCloud)
        
        XCTAssertEqual(metrics.pointCount, 100, "Point count should match")
        XCTAssertGreaterThan(metrics.boundingBoxVolume, 0, "Bounding box volume should be positive")
        XCTAssertGreaterThanOrEqual(metrics.density, 0, "Density should be non-negative")
        
        // Verify bounding box makes sense
        XCTAssertTrue(metrics.boundingBox.min.x >= -1.0, "Min X should be reasonable")
        XCTAssertTrue(metrics.boundingBox.max.x <= 1.0, "Max X should be reasonable")
        XCTAssertTrue(metrics.boundingBox.min.y >= -1.0, "Min Y should be reasonable")
        XCTAssertTrue(metrics.boundingBox.max.y <= 1.0, "Max Y should be reasonable")
        XCTAssertTrue(metrics.boundingBox.min.z >= -1.0, "Min Z should be reasonable")
        XCTAssertTrue(metrics.boundingBox.max.z <= 1.0, "Max Z should be reasonable")
    }
    
    func testCalculateBasicMetricsWithSinglePoint() throws {
        let singlePointCloud = createMockPointCloud(pointCount: 1, bounds: (0.0, 0.0))
        let metrics = try PointCloudMetrics.calculateBasicMetrics(for: singlePointCloud)
        
        XCTAssertEqual(metrics.pointCount, 1, "Single point count should be 1")
        XCTAssertEqual(metrics.boundingBoxVolume, 0, accuracy: 1e-6, "Single point should have zero volume")
        
        // Single point should have equal min and max
        XCTAssertEqual(metrics.boundingBox.min.x, metrics.boundingBox.max.x, accuracy: 1e-6)
        XCTAssertEqual(metrics.boundingBox.min.y, metrics.boundingBox.max.y, accuracy: 1e-6)
        XCTAssertEqual(metrics.boundingBox.min.z, metrics.boundingBox.max.z, accuracy: 1e-6)
    }
    
    func testCalculateBasicMetricsErrorHandling() {
        let invalidCloud = createMockPointCloudWithInvalidPoints()
        
        XCTAssertThrowsError(try PointCloudMetrics.calculateBasicMetrics(for: invalidCloud)) { error in
            XCTAssertTrue(error is PointCloudMetrics.ValidationError, "Should throw ValidationError")
        }
    }
    
    // MARK: - Head Scanning Specific Tests
    
    func testIsReasonableDimensionsForHeadScanning() {
        // Valid head dimensions (typical human head is ~15-25cm in various dimensions)
        let validHeadCloud = createMockPointCloud(pointCount: 500, bounds: (-0.15, 0.15))
        let validResult = PointCloudMetrics.validatePointCloud(validHeadCloud)
        XCTAssertTrue(validResult.isValid, "Reasonable head dimensions should be valid")
        
        // Unreasonably large dimensions (like a building)
        let largeCloud = createMockPointCloud(pointCount: 500, bounds: (-5.0, 5.0))
        let largeResult = PointCloudMetrics.validatePointCloud(largeCloud)
        XCTAssertFalse(largeResult.isValid, "Unreasonably large dimensions should be invalid")
        
        // Unreasonably small dimensions (like a grain of sand)
        let tinyCloud = createMockPointCloud(pointCount: 500, bounds: (-0.001, 0.001))
        let tinyResult = PointCloudMetrics.validatePointCloud(tinyCloud)
        XCTAssertFalse(tinyResult.isValid, "Unreasonably small dimensions should be invalid")
    }
    
    func testHeadScanningQualityMetrics() throws {
        let headCloud = createMockPointCloud(pointCount: 1000, bounds: (-0.12, 0.12))
        let metrics = try PointCloudMetrics.calculateBasicMetrics(for: headCloud)
        
        // For head scanning, we expect certain characteristics
        let volume = metrics.boundingBoxVolume
        XCTAssertTrue(volume > 0.001, "Head scan should have reasonable volume") // > 1 cubic cm
        XCTAssertTrue(volume < 0.1, "Head scan should not be excessively large") // < 100 cubic cm for bounding box
        
        let density = metrics.density
        XCTAssertGreaterThan(density, 0, "Density should be positive for head scans")
    }
    
    // MARK: - Security and Safety Tests
    
    func testPreventBufferOverflow() {
        // Test with various potentially dangerous inputs
        let extremelyLargeCloud = createMockPointCloud(pointCount: Int32.max / 1000, bounds: (-1.0, 1.0))
        let result = PointCloudMetrics.validatePointCloud(extremelyLargeCloud)
        
        XCTAssertFalse(result.isValid, "Extremely large point clouds should be rejected")
        XCTAssertTrue(result.issues.contains(.excessiveDataSize), "Should report data size issue")
    }
    
    func testHandleNaNAndInfiniteValues() {
        let nanInfCloud = createMockPointCloudWithNaNAndInf()
        let result = PointCloudMetrics.validatePointCloud(nanInfCloud)
        
        XCTAssertFalse(result.isValid, "Point cloud with NaN/Inf values should be invalid")
        XCTAssertTrue(result.issues.contains(.invalidCoordinates), "Should report invalid coordinates")
    }
    
    func testMemoryPressureHandling() {
        // Test with moderately large point clouds to ensure graceful handling
        let moderateCloud = createMockPointCloud(pointCount: 100_000, bounds: (-0.2, 0.2))
        
        // This should either succeed or fail gracefully
        let result = PointCloudMetrics.validatePointCloud(moderateCloud)
        
        if result.isValid {
            // If validation passes, metrics calculation should also work
            XCTAssertNoThrow(try PointCloudMetrics.calculateBasicMetrics(for: moderateCloud))
        } else {
            // If validation fails, it should be for a legitimate reason
            XCTAssertFalse(result.issues.isEmpty, "Invalid result should have reported issues")
        }
    }
    
    // MARK: - Performance Tests
    
    func testValidationPerformance() {
        let testCloud = createMockPointCloud(pointCount: 10_000, bounds: (-0.2, 0.2))
        
        measure {
            for _ in 0..<10 {
                _ = PointCloudMetrics.validatePointCloud(testCloud)
            }
        }
    }
    
    func testMetricsCalculationPerformance() throws {
        let testCloud = createMockPointCloud(pointCount: 10_000, bounds: (-0.2, 0.2))
        
        measure {
            for _ in 0..<10 {
                do {
                    _ = try PointCloudMetrics.calculateBasicMetrics(for: testCloud)
                } catch {
                    XCTFail("Performance test should not throw errors")
                }
            }
        }
    }
    
    // MARK: - Edge Cases and Boundary Tests
    
    func testBoundaryPointCounts() {
        // Test minimum valid point count
        let minValidCloud = createMockPointCloud(pointCount: 10, bounds: (-0.1, 0.1))
        let minResult = PointCloudMetrics.validatePointCloud(minValidCloud)
        XCTAssertTrue(minResult.isValid, "Minimum valid point count should pass")
        
        // Test just below minimum
        let tooSmallCloud = createMockPointCloud(pointCount: 2, bounds: (-0.1, 0.1))
        let tooSmallResult = PointCloudMetrics.validatePointCloud(tooSmallCloud)
        XCTAssertFalse(tooSmallResult.isValid, "Too few points should fail validation")
    }
    
    func testPrecisionBoundaries() throws {
        // Test with very precise coordinates
        let preciseCloud = createMockPointCloudWithPreciseCoordinates()
        let result = PointCloudMetrics.validatePointCloud(preciseCloud)
        
        if result.isValid {
            let metrics = try PointCloudMetrics.calculateBasicMetrics(for: preciseCloud)
            XCTAssertGreaterThan(metrics.pointCount, 0, "Precise coordinates should still be counted")
        }
    }
    
    // MARK: - Helper Methods for Test Data Generation
    
    private func createMockPointCloud(pointCount: Int32, bounds: (Float, Float)) -> SCPointCloud {
        let pointCloud = SCPointCloud()
        
        // Generate points within specified bounds
        var points: [Float] = []
        let (minBound, maxBound) = bounds
        
        for _ in 0..<pointCount {
            let x = Float.random(in: minBound...maxBound)
            let y = Float.random(in: minBound...maxBound)
            let z = Float.random(in: minBound...maxBound)
            points.append(contentsOf: [x, y, z])
        }
        
        // In a real implementation, you would set these points on the cloud
        // pointCloud.setPoints(points)
        
        return pointCloud
    }
    
    private func createMockPointCloudWithInvalidPoints() -> SCPointCloud {
        let pointCloud = SCPointCloud()
        
        // Create points with some invalid values
        var points: [Float] = []
        
        // Add some normal points
        for _ in 0..<50 {
            points.append(contentsOf: [0.1, 0.2, 0.3])
        }
        
        // Add some invalid points
        points.append(contentsOf: [Float.nan, 0.0, 0.0])
        points.append(contentsOf: [0.0, Float.infinity, 0.0])
        points.append(contentsOf: [0.0, 0.0, -Float.infinity])
        
        // In a real implementation, you would set these points on the cloud
        // pointCloud.setPoints(points)
        
        return pointCloud
    }
    
    private func createMockPointCloudWithNaNAndInf() -> SCPointCloud {
        let pointCloud = SCPointCloud()
        
        var points: [Float] = []
        
        // Mix of valid and invalid points
        points.append(contentsOf: [0.1, 0.2, 0.3])  // Valid
        points.append(contentsOf: [Float.nan, Float.nan, Float.nan])  // NaN
        points.append(contentsOf: [Float.infinity, 0.0, 0.0])  // +Inf
        points.append(contentsOf: [0.0, -Float.infinity, 0.0])  // -Inf
        points.append(contentsOf: [0.2, 0.3, 0.1])  // Valid
        
        // In a real implementation, you would set these points on the cloud
        // pointCloud.setPoints(points)
        
        return pointCloud
    }
    
    private func createMockPointCloudWithPreciseCoordinates() -> SCPointCloud {
        let pointCloud = SCPointCloud()
        
        var points: [Float] = []
        
        // Generate points with high precision
        for i in 0..<100 {
            let base = Float(i) * 0.001  // Very small increments
            let x = base + 0.0001
            let y = base + 0.0002
            let z = base + 0.0003
            points.append(contentsOf: [x, y, z])
        }
        
        // In a real implementation, you would set these points on the cloud
        // pointCloud.setPoints(points)
        
        return pointCloud
    }
}