import XCTest
@testable import CyborgRugby
import AVFoundation
import Vision

/// Comprehensive test suite for MLEnhancedPoseValidator functionality
/// Tests cover initialization, validation logic, error handling, and concurrency
final class MLEnhancedPoseValidatorTests: XCTestCase {
    
    var validator: MLEnhancedPoseValidator!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        validator = MLEnhancedPoseValidator()
    }
    
    override func tearDownWithError() throws {
        validator = nil
    }
    
    // MARK: - Initialization Tests
    
    func testValidatorInitialization() {
        XCTAssertNotNil(validator, "Validator should initialize successfully")
    }
    
    func testValidatorStartInitialization() {
        // Test that initialization can be started without throwing
        XCTAssertNoThrow({
            validator.startInitialization()
        }(), "Starting initialization should not throw")
    }
    
    // MARK: - Pixel Buffer Validation Tests
    
    func testValidateWithValidPixelBuffer() async throws {
        let pixelBuffer = try createValidPixelBuffer(width: 640, height: 480)
        
        let result = await validator.validatePose(.frontFacing, in: pixelBuffer)
        
        // Should not crash and should return a valid result structure
        XCTAssertNotNil(result, "Should return a validation result")
        XCTAssertTrue(result.confidence >= 0.0 && result.confidence <= 1.0, "Confidence should be in valid range")
        XCTAssertFalse(result.feedback.isEmpty, "Should provide feedback")
    }
    
    func testValidateWithInvalidPixelBuffer() async throws {
        // Create a very small pixel buffer that should be considered invalid
        let invalidBuffer = try createValidPixelBuffer(width: 1, height: 1)
        
        let result = await validator.validatePose(.frontFacing, in: invalidBuffer)
        
        // Should handle invalid input gracefully
        XCTAssertNotNil(result, "Should return a validation result even for invalid input")
        XCTAssertFalse(result.isValid, "Invalid pixel buffer should result in invalid pose")
        XCTAssertTrue(result.feedback.contains("input") || result.feedback.contains("invalid"), 
                     "Feedback should indicate input issue")
    }
    
    // MARK: - Vision-Based Pose Validation Tests
    
    func testValidateLookingDownUsesFaceRectangles() async throws {
        // Test the Vision-based looking down validation
        let pixelBuffer = try createValidPixelBuffer(width: 640, height: 480)
        
        let result = await validator.validatePose(.lookingDown, in: pixelBuffer)
        
        XCTAssertNotNil(result, "Should return validation result")
        XCTAssertFalse(result.isValid, "Empty pixel buffer should not show valid looking-down pose")
        XCTAssertTrue(result.feedback.contains("face") || result.feedback.contains("detect"),
                     "Should mention face detection issue")
    }
    
    func testValidateChinUpPose() async throws {
        let pixelBuffer = try createValidPixelBuffer(width: 640, height: 480)
        
        let result = await validator.validatePose(.chinUp, in: pixelBuffer)
        
        XCTAssertNotNil(result, "Should return validation result")
        // Without a real face, this should fail
        XCTAssertFalse(result.isValid, "Empty pixel buffer should not show valid chin-up pose")
    }
    
    // MARK: - All Pose Types Tests
    
    func testValidateAllPoseTypes() async throws {
        let pixelBuffer = try createValidPixelBuffer(width: 640, height: 480)
        
        let allPoses: [HeadScanningPose] = [
            .frontFacing, .leftProfile, .rightProfile,
            .leftThreeQuarter, .rightThreeQuarter,
            .lookingDown, .chinUp
        ]
        
        for pose in allPoses {
            let result = await validator.validatePose(pose, in: pixelBuffer)
            
            XCTAssertNotNil(result, "Should return result for pose \(pose.rawValue)")
            XCTAssertTrue(result.confidence >= 0.0 && result.confidence <= 1.0, 
                         "Confidence should be valid for pose \(pose.rawValue)")
            XCTAssertFalse(result.feedback.isEmpty, 
                          "Should provide feedback for pose \(pose.rawValue)")
        }
    }
    
    // MARK: - Ear Analysis Tests
    
    func testEstimateEarProtrusionWithValidBuffer() async {
        let pixelBuffer = try! createValidPixelBuffer(width: 640, height: 480)
        
        let leftProtrusion = await validator.estimateEarProtrusion(in: pixelBuffer, side: .left)
        let rightProtrusion = await validator.estimateEarProtrusion(in: pixelBuffer, side: .right)
        
        // Results may be nil if models aren't available, which is fine for testing
        if let left = leftProtrusion {
            XCTAssertTrue(left >= 0.0 && left <= 90.0, "Left ear protrusion should be valid angle")
        }
        
        if let right = rightProtrusion {
            XCTAssertTrue(right >= 0.0 && right <= 90.0, "Right ear protrusion should be valid angle")
        }
    }
    
    func testDetectEarFeaturesWithValidBuffer() async {
        let pixelBuffer = try! createValidPixelBuffer(width: 640, height: 480)
        
        let features = await validator.detectEarFeatures(in: pixelBuffer)
        
        // Features may be nil if no ears are detected, which is expected with empty buffer
        if let features = features {
            XCTAssertTrue(features.confidence >= 0.0 && features.confidence <= 1.0, 
                         "Confidence should be in valid range")
            XCTAssertTrue(features.landmarks.count >= 0, "Landmarks count should be non-negative")
        }
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentValidation() async throws {
        let pixelBuffer = try createValidPixelBuffer(width: 640, height: 480)
        let poses: [HeadScanningPose] = [.frontFacing, .leftProfile, .rightProfile]
        
        // Run multiple validations concurrently
        let results = await withTaskGroup(of: PoseValidationResult.self) { group in
            for pose in poses {
                group.addTask {
                    await self.validator.validatePose(pose, in: pixelBuffer)
                }
            }
            
            var results: [PoseValidationResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        XCTAssertEqual(results.count, poses.count, "Should complete all concurrent validations")
        
        for result in results {
            XCTAssertNotNil(result, "Each concurrent result should be valid")
            XCTAssertTrue(result.confidence >= 0.0 && result.confidence <= 1.0, 
                         "Each result should have valid confidence")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testValidationWithCorruptedPixelBuffer() async {
        // Create a pixel buffer and then simulate corruption by using wrong format
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true] as CFDictionary
        
        // Use an unusual pixel format that might cause issues
        let status = CVPixelBufferCreate(kCFAllocatorDefault, 100, 100, 
                                       kCVPixelFormatType_OneComponent8, attrs, &pixelBuffer)
        
        if status == kCVReturnSuccess, let buffer = pixelBuffer {
            let result = await validator.validatePose(.frontFacing, in: buffer)
            
            // Should handle gracefully without crashing
            XCTAssertNotNil(result, "Should handle unusual pixel format gracefully")
            XCTAssertFalse(result.isValid, "Unusual pixel format should likely be invalid")
        }
    }
    
    // MARK: - Performance Tests
    
    func testValidationPerformance() async throws {
        let pixelBuffer = try createValidPixelBuffer(width: 640, height: 480)
        
        measure {
            let group = DispatchGroup()
            
            for _ in 0..<5 {
                group.enter()
                Task {
                    let _ = await validator.validatePose(.frontFacing, in: pixelBuffer)
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
    
    func testEarAnalysisPerformance() async throws {
        let pixelBuffer = try createValidPixelBuffer(width: 640, height: 480)
        
        measure {
            let group = DispatchGroup()
            
            for _ in 0..<3 {
                group.enter()
                Task {
                    let _ = await validator.estimateEarProtrusion(in: pixelBuffer, side: .left)
                    let _ = await validator.detectEarFeatures(in: pixelBuffer)
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
    
    // MARK: - Helper Methods
    
    private func createValidPixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, 
                                       width, height, 
                                       kCVPixelFormatType_32BGRA, 
                                       attributes as CFDictionary, 
                                       &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw ValidationTestError.pixelBufferCreationFailed
        }
        
        return buffer
    }
    
    private enum ValidationTestError: Error {
        case pixelBufferCreationFailed
    }
}

