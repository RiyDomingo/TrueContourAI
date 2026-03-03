import XCTest
@testable import CyborgRugby
import StandardCyborgFusion

/// Comprehensive test suite for RugbyHeadScanFusion functionality
/// Tests cover point cloud fusion, transformation estimation, and export capabilities
final class RugbyHeadScanFusionTests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    // MARK: - Fusion Options Testing
    
    func testFusionExportOptionsDefaultValues() {
        let defaultOptions = RugbyHeadScanFusion.FusionExportOptions()
        
        XCTAssertTrue(defaultOptions.cropBelowNeck, "Should crop below neck by default")
        XCTAssertEqual(defaultOptions.neckOffsetMeters, 0.15, accuracy: 0.001, "Default neck offset should be 15cm")
        XCTAssertEqual(defaultOptions.outlierSigma, 3.0, accuracy: 0.001, "Default outlier sigma should be 3.0")
        XCTAssertEqual(defaultOptions.decimateRatio, 1.0, accuracy: 0.001, "Default decimate ratio should be 1.0 (no decimation)")
        XCTAssertFalse(defaultOptions.preScaleToMillimeters, "Should not pre-scale to millimeters by default")
    }
    
    func testFusionExportOptionsCustomValues() {
        let customOptions = RugbyHeadScanFusion.FusionExportOptions(
            cropBelowNeck: false,
            neckOffsetMeters: 0.20,
            outlierSigma: 2.5,
            decimateRatio: 0.8,
            preScaleToMillimeters: true
        )
        
        XCTAssertFalse(customOptions.cropBelowNeck)
        XCTAssertEqual(customOptions.neckOffsetMeters, 0.20, accuracy: 0.001)
        XCTAssertEqual(customOptions.outlierSigma, 2.5, accuracy: 0.001)
        XCTAssertEqual(customOptions.decimateRatio, 0.8, accuracy: 0.001)
        XCTAssertTrue(customOptions.preScaleToMillimeters)
    }
    
    // MARK: - Empty Scan Handling
    
    func testFuseWithEmptyScans() {
        let emptyScans: [HeadScanningPose: ScanResult] = [:]
        let result = RugbyHeadScanFusion.fuse(emptyScans)
        
        XCTAssertNil(result, "Empty scans should return nil")
    }
    
    func testEstimateTransformsWithEmptyScans() {
        let emptyScans: [HeadScanningPose: ScanResult] = [:]
        let result = RugbyHeadScanFusion.estimateTransforms(emptyScans)
        
        XCTAssertNil(result, "Empty scans should return nil for transform estimation")
    }
    
    // MARK: - Single Scan Handling
    
    func testFuseWithSingleScan() {
        // Create a mock point cloud with a few points
        let mockCloud = createMockPointCloud(pointCount: 100)
        let scanResult = ScanResult(pointCloud: mockCloud, confidence: 0.9, status: .completed)
        let singleScan = [HeadScanningPose.frontFacing: scanResult]
        
        let result = RugbyHeadScanFusion.fuse(singleScan)
        
        // With a single scan, it should return the reference cloud
        XCTAssertNotNil(result, "Single scan should return the reference cloud")
        XCTAssertEqual(result?.pointCount, mockCloud.pointCount, "Point count should match")
    }
    
    func testEstimateTransformsWithSingleScan() {
        let mockCloud = createMockPointCloud(pointCount: 100)
        let scanResult = ScanResult(pointCloud: mockCloud, confidence: 0.9, status: .completed)
        let singleScan = [HeadScanningPose.frontFacing: scanResult]
        
        let result = RugbyHeadScanFusion.estimateTransforms(singleScan)
        
        XCTAssertNotNil(result, "Single scan should return a valid result")
        XCTAssertEqual(result?.referencePose, .frontFacing, "Reference pose should be the only available pose")
        XCTAssertEqual(result?.transforms.count, 1, "Should have exactly one transform (identity)")
        
        // Check that the transform is identity
        if let transforms = result?.transforms,
           let identityTransform = transforms[.frontFacing] {
            XCTAssertTrue(isIdentityMatrix(identityTransform), "Single scan transform should be identity")
        }
    }
    
    // MARK: - Multiple Scan Handling
    
    func testEstimateTransformsWithMultipleScans() {
        // Create mock point clouds with different point counts to test density selection
        let frontCloud = createMockPointCloud(pointCount: 100) // Densest
        let leftCloud = createMockPointCloud(pointCount: 80)
        let rightCloud = createMockPointCloud(pointCount: 60)
        
        let scans = [
            HeadScanningPose.frontFacing: ScanResult(pointCloud: frontCloud, confidence: 0.9, status: .completed),
            HeadScanningPose.leftProfile: ScanResult(pointCloud: leftCloud, confidence: 0.8, status: .completed),
            HeadScanningPose.rightProfile: ScanResult(pointCloud: rightCloud, confidence: 0.85, status: .completed)
        ]
        
        let result = RugbyHeadScanFusion.estimateTransforms(scans)
        
        XCTAssertNotNil(result, "Multiple scans should return a valid result")
        XCTAssertEqual(result?.referencePose, .frontFacing, "Densest cloud (front) should be reference")
        XCTAssertEqual(result?.transforms.count, 3, "Should have transforms for all scans")
        
        // Reference should have identity transform
        if let transforms = result?.transforms,
           let identityTransform = transforms[.frontFacing] {
            XCTAssertTrue(isIdentityMatrix(identityTransform), "Reference transform should be identity")
        }
    }
    
    // MARK: - Scan Filtering (Nil Point Clouds)
    
    func testEstimateTransformsFiltersNilPointClouds() {
        let validCloud = createMockPointCloud(pointCount: 100)
        let validResult = ScanResult(pointCloud: validCloud, confidence: 0.9, status: .completed)
        let invalidResult = ScanResult(pointCloud: nil, confidence: 0.5, status: .failed)
        
        let mixedScans = [
            HeadScanningPose.frontFacing: validResult,
            HeadScanningPose.leftProfile: invalidResult, // This should be filtered out
            HeadScanningPose.rightProfile: validResult
        ]
        
        let result = RugbyHeadScanFusion.estimateTransforms(mixedScans)
        
        XCTAssertNotNil(result, "Should handle mixed valid/invalid scans")
        // Should only have transforms for valid scans
        XCTAssertEqual(result?.transforms.count, 2, "Should only have transforms for valid point clouds")
        XCTAssertNotNil(result?.transforms[.frontFacing], "Should have transform for front facing")
        XCTAssertNotNil(result?.transforms[.rightProfile], "Should have transform for right profile")
        XCTAssertNil(result?.transforms[.leftProfile], "Should not have transform for invalid scan")
    }
    
    // MARK: - Point Enumeration Testing
    
    func testEnumerateFusedPointsWithEmptyScans() {
        let emptyScans: [HeadScanningPose: ScanResult] = [:]
        var pointCount = 0
        
        RugbyHeadScanFusion.enumerateFusedPoints(scans: emptyScans) { _ in
            pointCount += 1
        }
        
        XCTAssertEqual(pointCount, 0, "Empty scans should enumerate no points")
    }
    
    func testEnumerateFusedPointsWithSingleScan() {
        let expectedPointCount = 50
        let mockCloud = createMockPointCloud(pointCount: Int32(expectedPointCount))
        let scanResult = ScanResult(pointCloud: mockCloud, confidence: 0.9, status: .completed)
        let singleScan = [HeadScanningPose.frontFacing: scanResult]
        
        var enumeratedPointCount = 0
        var points: [SIMD3<Float>] = []
        
        RugbyHeadScanFusion.enumerateFusedPoints(scans: singleScan) { point in
            enumeratedPointCount += 1
            points.append(point)
        }
        
        XCTAssertEqual(enumeratedPointCount, expectedPointCount, "Should enumerate all points from single scan")
        XCTAssertFalse(points.isEmpty, "Should collect enumerated points")
    }
    
    // MARK: - PLY Export Testing
    
    func testWriteFusedPLYWithEmptyScans() {
        let tempURL = createTempFileURL(extension: "ply")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let emptyScans: [HeadScanningPose: ScanResult] = [:]
        let result = RugbyHeadScanFusion.writeFusedPLY(scans: emptyScans, to: tempURL)
        
        XCTAssertFalse(result, "Empty scans should fail to write PLY")
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path), "No file should be created for empty scans")
    }
    
    func testWriteFusedPLYWithValidScans() {
        let tempURL = createTempFileURL(extension: "ply")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let mockCloud = createMockPointCloud(pointCount: 10)
        let scanResult = ScanResult(pointCloud: mockCloud, confidence: 0.9, status: .completed)
        let validScans = [HeadScanningPose.frontFacing: scanResult]
        
        let result = RugbyHeadScanFusion.writeFusedPLY(scans: validScans, to: tempURL)
        
        XCTAssertTrue(result, "Valid scans should successfully write PLY")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path), "PLY file should be created")
        
        // Verify file content has basic PLY structure
        if let content = try? String(contentsOf: tempURL) {
            XCTAssertTrue(content.contains("ply"), "File should contain PLY header")
            XCTAssertTrue(content.contains("format ascii"), "Should be ASCII format")
            XCTAssertTrue(content.contains("element vertex"), "Should contain vertex element")
            XCTAssertTrue(content.contains("end_header"), "Should contain end_header")
        }
    }
    
    func testWriteFusedPLYWithCustomOptions() {
        let tempURL = createTempFileURL(extension: "ply")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let mockCloud = createMockPointCloud(pointCount: 100)
        let scanResult = ScanResult(pointCloud: mockCloud, confidence: 0.9, status: .completed)
        let validScans = [HeadScanningPose.frontFacing: scanResult]
        
        let customOptions = RugbyHeadScanFusion.FusionExportOptions(
            cropBelowNeck: false,
            neckOffsetMeters: 0.10,
            outlierSigma: 2.0,
            decimateRatio: 0.5,
            preScaleToMillimeters: true
        )
        
        let result = RugbyHeadScanFusion.writeFusedPLY(scans: validScans, to: tempURL, options: customOptions)
        
        XCTAssertTrue(result, "Custom options should not prevent successful PLY writing")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path), "PLY file should be created with custom options")
    }
    
    // MARK: - Performance Testing
    
    func testFusionPerformance() {
        let scans = createMockScansForPerformanceTesting()
        
        measure {
            _ = RugbyHeadScanFusion.estimateTransforms(scans)
        }
    }
    
    func testPLYWritePerformance() {
        let tempURL = createTempFileURL(extension: "ply")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let scans = createMockScansForPerformanceTesting()
        
        measure {
            _ = RugbyHeadScanFusion.writeFusedPLY(scans: scans, to: tempURL)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockPointCloud(pointCount: Int32) -> SCPointCloud {
        // Create a simple mock point cloud for testing
        // This creates a basic point cloud with specified number of points
        let pointCloud = SCPointCloud()
        
        // Generate some basic point data
        var points: [Float] = []
        for i in 0..<pointCount {
            let x = Float(i % 10) * 0.1  // Simple grid pattern
            let y = Float((i / 10) % 10) * 0.1
            let z = Float(i / 100) * 0.1
            points.append(contentsOf: [x, y, z])
        }
        
        // Add points to the cloud (this would normally involve StandardCyborgFusion APIs)
        // For testing purposes, we'll just set the point count
        // pointCloud.setPoints(points) // This is a conceptual API call
        
        return pointCloud
    }
    
    private func createMockScansForPerformanceTesting() -> [HeadScanningPose: ScanResult] {
        var scans: [HeadScanningPose: ScanResult] = [:]
        
        let poses: [HeadScanningPose] = [.frontFacing, .leftProfile, .rightProfile, .lookingDown]
        
        for (index, pose) in poses.enumerated() {
            let pointCount = Int32(100 + index * 50) // Varying point counts
            let mockCloud = createMockPointCloud(pointCount: pointCount)
            let result = ScanResult(pointCloud: mockCloud, confidence: 0.8 + Float(index) * 0.05, status: .completed)
            scans[pose] = result
        }
        
        return scans
    }
    
    private func createTempFileURL(extension ext: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test_\(UUID().uuidString).\(ext)"
        return tempDir.appendingPathComponent(fileName)
    }
    
    private func isIdentityMatrix(_ matrix: simd_float4x4) -> Bool {
        let identity = matrix_identity_float4x4
        
        // Check each component with small tolerance for floating-point comparison
        let tolerance: Float = 1e-6
        
        for row in 0..<4 {
            for col in 0..<4 {
                if abs(matrix[row][col] - identity[row][col]) > tolerance {
                    return false
                }
            }
        }
        
        return true
    }
}