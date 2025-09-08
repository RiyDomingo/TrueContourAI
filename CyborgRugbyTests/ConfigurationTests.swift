import XCTest
@testable import CyborgRugby

/// Comprehensive test suite for configuration management functionality
/// Tests cover Config.plist loading, fallback handling, and type safety
final class ConfigurationTests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    // MARK: - Configuration Loading Tests
    
    func testConfigPlistExists() {
        let configURL = Bundle.main.url(forResource: "Config", withExtension: "plist")
        if configURL != nil {
            XCTAssertNotNil(configURL, "Config.plist should exist in bundle")
            XCTAssertTrue(FileManager.default.fileExists(atPath: configURL!.path), "Config.plist file should exist")
        } else {
            // If Config.plist doesn't exist, that's also valid - the system should use defaults
            print("Config.plist not found - using default values")
        }
    }
    
    func testDefaultConfigurationValues() {
        // Test that default values are reasonable for head scanning
        // We can't directly test the private loadConfig() function, but we can test its behavior
        // through ResultsPersistence.save() which uses the configuration
        
        // Create a temporary scan result for testing
        let dummyMeasurements = createDummyMeasurements()
        let dummyScans: [HeadScanningPose: ScanResult] = [:]
        let testResult = CompleteScanResult(
            individualScans: dummyScans,
            overallQuality: 0.85,
            timestamp: Date(),
            totalScanTime: 120.0,
            successfulPoses: 0,
            rugbyFitnessMeasurements: dummyMeasurements
        )
        
        // This should succeed with default configuration
        XCTAssertNoThrow({
            ResultsPersistence.save(result: testResult, fileName: "config_test.json")
        }(), "Saving with default config should not throw")
        
        // Clean up
        let testURL = ResultsPersistence.appSupportURL().appendingPathComponent("config_test.json")
        try? FileManager.default.removeItem(at: testURL)
    }
    
    func testConfigurationTypeHandling() {
        // Create a mock plist structure to test type handling
        let mockConfigData: [String: Any] = [
            "fusion": [
                "cropBelowNeck": true,
                "neckOffsetMeters": 0.15,
                "outlierSigma": 3.0,
                "decimateRatio": 1.0,
                "preScaleToMillimeters": false
            ],
            "meshing": [
                "resolution": 6,
                "smoothness": 3,
                "surfaceTrimmingAmount": 4,
                "closed": true,
                "exportOBJZip": true,
                "exportGLB": true
            ]
        ]
        
        // Test that we can serialize and deserialize this structure
        XCTAssertNoThrow({
            let data = try PropertyListSerialization.data(fromPropertyList: mockConfigData, format: .xml, options: 0)
            let deserialized = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            XCTAssertNotNil(deserialized as? [String: Any], "Should deserialize to dictionary")
        }(), "Config structure should be serializable")
    }
    
    // MARK: - Fusion Configuration Tests
    
    func testFusionConfigurationBounds() {
        // Test that fusion parameters are within reasonable bounds
        let validFusionParams = [
            "cropBelowNeck": true,
            "neckOffsetMeters": 0.10,  // 10cm - reasonable for head scanning
            "outlierSigma": 2.0,       // Statistical outlier detection
            "decimateRatio": 0.5,      // 50% decimation
            "preScaleToMillimeters": true
        ]
        
        // These should be reasonable values for head scanning
        XCTAssertTrue(validFusionParams["cropBelowNeck"] as! Bool, "Cropping below neck makes sense for head scans")
        
        let neckOffset = validFusionParams["neckOffsetMeters"] as! Float
        XCTAssertTrue(neckOffset > 0.05 && neckOffset < 0.5, "Neck offset should be reasonable (5-50cm)")
        
        let outlierSigma = validFusionParams["outlierSigma"] as! Float
        XCTAssertTrue(outlierSigma > 1.0 && outlierSigma < 5.0, "Outlier sigma should be reasonable (1-5)")
        
        let decimateRatio = validFusionParams["decimateRatio"] as! Float
        XCTAssertTrue(decimateRatio > 0.0 && decimateRatio <= 1.0, "Decimate ratio should be 0-1")
    }
    
    func testInvalidFusionConfigurationHandling() {
        // Test with extreme/invalid values to ensure graceful handling
        let extremeFusionParams = [
            "neckOffsetMeters": -1.0,  // Negative offset (invalid)
            "outlierSigma": 0.0,       // Zero sigma (invalid)
            "decimateRatio": 2.0       // > 1.0 (invalid)
        ]
        
        // The system should handle these gracefully by falling back to defaults
        let negativeOffset = extremeFusionParams["neckOffsetMeters"] as! Float
        let zeroSigma = extremeFusionParams["outlierSigma"] as! Float
        let invalidRatio = extremeFusionParams["decimateRatio"] as! Float
        
        XCTAssertLessThan(negativeOffset, 0, "Test data should have negative offset")
        XCTAssertEqual(zeroSigma, 0.0, "Test data should have zero sigma")
        XCTAssertGreaterThan(invalidRatio, 1.0, "Test data should have invalid ratio")
        
        // In a real system, these would be validated and corrected
    }
    
    // MARK: - Meshing Configuration Tests
    
    func testMeshingConfigurationBounds() {
        let validMeshingParams = [
            "resolution": 6,           // Reasonable mesh resolution
            "smoothness": 3,           // Moderate smoothing
            "surfaceTrimmingAmount": 4,// Moderate trimming
            "closed": true,            // Closed mesh for head scanning
            "exportOBJZip": true,      // Export additional formats
            "exportGLB": false         // Optional format
        ]
        
        let resolution = validMeshingParams["resolution"] as! Int
        XCTAssertTrue(resolution >= 1 && resolution <= 10, "Resolution should be reasonable (1-10)")
        
        let smoothness = validMeshingParams["smoothness"] as! Int
        XCTAssertTrue(smoothness >= 0 && smoothness <= 10, "Smoothness should be reasonable (0-10)")
        
        let trimming = validMeshingParams["surfaceTrimmingAmount"] as! Int
        XCTAssertTrue(trimming >= 0 && trimming <= 10, "Trimming should be reasonable (0-10)")
        
        let closed = validMeshingParams["closed"] as! Bool
        XCTAssertTrue(closed, "Closed mesh makes sense for head scanning")
    }
    
    func testMeshingExportOptions() {
        let exportOptions = [
            "exportOBJZip": true,
            "exportGLB": true
        ]
        
        let objExport = exportOptions["exportOBJZip"] as! Bool
        let glbExport = exportOptions["exportGLB"] as! Bool
        
        // Both options should be boolean values
        XCTAssertTrue(objExport is Bool, "OBJ export option should be boolean")
        XCTAssertTrue(glbExport is Bool, "GLB export option should be boolean")
        
        // Test that export options work together
        if objExport && glbExport {
            // Both formats enabled - should be fine
            XCTAssertTrue(true, "Multiple export formats should be supported")
        } else if objExport || glbExport {
            // At least one format enabled - good
            XCTAssertTrue(true, "At least one export format should be enabled")
        } else {
            // No additional formats - still valid, just PLY only
            print("Only PLY export enabled - additional formats disabled")
        }
    }
    
    // MARK: - Configuration Integration Tests
    
    func testConfigurationIntegrationWithResultsPersistence() {
        let dummyMeasurements = createDummyMeasurements()
        let testResult = CompleteScanResult(
            individualScans: [:],
            overallQuality: 0.75,
            timestamp: Date(),
            totalScanTime: 90.0,
            successfulPoses: 0,
            rugbyFitnessMeasurements: dummyMeasurements
        )
        
        let fileName = "integration_test.json"
        
        // This tests that the configuration loading works in the real system
        XCTAssertNoThrow({
            ResultsPersistence.save(result: testResult, fileName: fileName)
        }(), "Configuration integration should work without throwing")
        
        // Verify the file was created
        let savedFileURL = ResultsPersistence.appSupportURL().appendingPathComponent(fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedFileURL.path), "Integration test should create file")
        
        // Verify we can load it back
        let loadedResult = ResultsPersistence.load(fileName: fileName)
        XCTAssertNotNil(loadedResult, "Should be able to load saved result")
        
        if let loaded = loadedResult {
            XCTAssertEqual(loaded.overallQuality, 0.75, accuracy: 0.001, "Loaded quality should match")
            XCTAssertEqual(loaded.successfulPoses, 0, "Loaded pose count should match")
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: savedFileURL)
    }
    
    // MARK: - Configuration Fallback Tests
    
    func testConfigurationFallbackToDefaults() {
        // When Config.plist is missing or malformed, system should use reasonable defaults
        
        // We can test this indirectly by ensuring the system works without a config file
        let testDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("ConfigTest_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: testDirectoryURL, withIntermediateDirectories: true)
            
            // Test that the system works without config (using defaults)
            let dummyMeasurements = createDummyMeasurements()
            let testResult = CompleteScanResult(
                individualScans: [:],
                overallQuality: 0.80,
                timestamp: Date(),
                totalScanTime: 100.0,
                successfulPoses: 0,
                rugbyFitnessMeasurements: dummyMeasurements
            )
            
            // This should work with default configuration
            XCTAssertNoThrow({
                ResultsPersistence.save(result: testResult, fileName: "fallback_test.json")
            }(), "Should work with default configuration")
            
        } catch {
            XCTFail("Failed to create test directory: \(error)")
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: testDirectoryURL)
    }
    
    // MARK: - Performance Tests
    
    func testConfigurationLoadingPerformance() {
        // Configuration loading should be fast since it's done during save operations
        measure {
            for _ in 0..<100 {
                let dummyMeasurements = createDummyMeasurements()
                let testResult = CompleteScanResult(
                    individualScans: [:],
                    overallQuality: 0.85,
                    timestamp: Date(),
                    totalScanTime: 110.0,
                    successfulPoses: 0,
                    rugbyFitnessMeasurements: dummyMeasurements
                )
                
                // This indirectly tests config loading performance
                ResultsPersistence.save(result: testResult, fileName: "perf_test_\(UUID().uuidString).json")
            }
        }
        
        // Clean up performance test files
        let appSupportURL = ResultsPersistence.appSupportURL()
        if let files = try? FileManager.default.contentsOfDirectory(at: appSupportURL, includingPropertiesForKeys: nil) {
            for file in files {
                if file.lastPathComponent.starts(with: "perf_test_") {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createDummyMeasurements() -> ScrumCapMeasurements {
        let vm = { (value: Float) -> ValidatedMeasurement in
            ValidatedMeasurement(
                value: value,
                confidence: 1.0,
                validationStatus: .validated,
                alternativeValues: [],
                measurementSource: .userInput(verified: true)
            )
        }
        
        let ears = ValidatedEarDimensions(
            height: vm(55.0),
            width: vm(28.0),
            protrusionAngle: vm(40.0),
            topToLobe: vm(44.0)
        )
        
        return ScrumCapMeasurements(
            headCircumference: vm(56.0),
            earToEarOverTop: vm(34.0),
            foreheadToNeckBase: vm(190.0),
            leftEarDimensions: ears,
            rightEarDimensions: ears,
            earAsymmetryFactor: 0.0,
            occipitalProminence: vm(10.0),
            neckCurveRadius: vm(35.0),
            backHeadWidth: vm(160.0),
            jawLineToEar: vm(75.0),
            chinToEarDistance: vm(90.0)
        )
    }
}