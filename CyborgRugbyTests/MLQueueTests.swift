import XCTest
@testable import CyborgRugby
import CoreML

/// Comprehensive test suite for MLQueue functionality
/// Tests cover resource management, concurrency, timeout handling, and error scenarios
final class MLQueueTests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        // Reset any static state if needed
    }
    
    // MARK: - Basic Functionality Tests
    
    func testMLQueueSingleton() {
        let queue1 = MLQueue.shared
        let queue2 = MLQueue.shared
        
        XCTAssertTrue(queue1 === queue2, "MLQueue should be a singleton")
    }
    
    func testBasicOperationExecution() async throws {
        let expectation = XCTestExpectation(description: "Operation should execute")
        var executed = false
        
        let result: Bool = try await MLQueue.shared.runWithTimeout {
            executed = true
            expectation.fulfill()
            return true
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(executed, "Operation should have been executed")
        XCTAssertTrue(result, "Operation should return expected result")
    }
    
    func testOperationWithReturnValue() async throws {
        let expectedValue = 42
        
        let result: Int = try await MLQueue.shared.runWithTimeout {
            return expectedValue
        }
        
        XCTAssertEqual(result, expectedValue, "Operation should return the expected value")
    }
    
    // MARK: - Timeout Testing
    
    func testOperationTimeout() async {
        do {
            let _: Void = try await MLQueue.shared.runWithTimeout(timeoutSeconds: 0.1) {
                // Simulate a long-running operation
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
            XCTFail("Operation should have timed out")
        } catch MLQueueError.timeout {
            // Expected timeout error
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testOperationWithinTimeout() async throws {
        let expectation = XCTestExpectation(description: "Fast operation should complete")
        
        let result: String = try await MLQueue.shared.runWithTimeout(timeoutSeconds: 1.0) {
            expectation.fulfill()
            return "completed"
        }
        
        await fulfillment(of: [expectation], timeout: 0.5)
        XCTAssertEqual(result, "completed", "Fast operation should complete successfully")
    }
    
    // MARK: - Error Handling Tests
    
    func testOperationThrowingError() async {
        struct TestError: Error, Equatable {}
        
        do {
            let _: Void = try await MLQueue.shared.runWithTimeout {
                throw TestError()
            }
            XCTFail("Operation should have thrown an error")
        } catch MLQueueError.executionFailed(let underlyingError) {
            XCTAssertTrue(underlyingError is TestError, "Should wrap the underlying error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testOperationCancellation() async {
        let task = Task {
            try await MLQueue.shared.runWithTimeout {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                return "should not complete"
            }
        }
        
        // Cancel the task immediately
        task.cancel()
        
        do {
            let result: String = try await task.value
            XCTFail("Cancelled operation should not complete: \(result)")
        } catch is CancellationError {
            // Expected cancellation
        } catch {
            // Task cancellation might manifest as different error types
            // This is acceptable for this test
        }
    }
    
    // MARK: - Concurrency and Resource Management Tests
    
    func testConcurrentOperations() async throws {
        let operationCount = 5
        let expectations = (0..<operationCount).map { index in
            XCTestExpectation(description: "Operation \(index) should complete")
        }
        
        let tasks = expectations.enumerated().map { (index, expectation) in
            Task {
                let result: Int = try await MLQueue.shared.runWithTimeout {
                    // Small delay to simulate work
                    try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                    expectation.fulfill()
                    return index
                }
                return result
            }
        }
        
        // Wait for all operations to complete
        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }
            
            var results: [Int] = []
            for try await result in group {
                results.append(result)
            }
            return results.sorted()
        }
        
        await fulfillment(of: expectations, timeout: 2.0)
        XCTAssertEqual(results, Array(0..<operationCount), "All operations should complete with correct results")
    }
    
    func testResourcePressureHandling() async {
        // This test simulates high memory pressure conditions
        // Note: This is a conceptual test as we can't easily trigger real memory pressure in unit tests
        
        let heavyOperationCount = 10
        let expectations = (0..<heavyOperationCount).map { index in
            XCTestExpectation(description: "Heavy operation \(index)")
        }
        
        let tasks = expectations.enumerated().map { (index, expectation) in
            Task {
                let result: Int = try await MLQueue.shared.runWithTimeout {
                    // Simulate memory-intensive work
                    let data = Array(0..<1000) // Small array to avoid actual memory issues
                    expectation.fulfill()
                    return data.reduce(0, +) + index
                }
                return result
            }
        }
        
        // All operations should complete even under simulated pressure
        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }
            
            var results: [Int] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        
        await fulfillment(of: expectations, timeout: 5.0)
        XCTAssertEqual(results.count, heavyOperationCount, "All operations should complete despite resource pressure")
    }
    
    // MARK: - Performance Tests
    
    func testMLQueuePerformance() {
        measure {
            let group = DispatchGroup()
            
            for _ in 0..<100 {
                group.enter()
                Task {
                    do {
                        let _: Int = try await MLQueue.shared.runWithTimeout {
                            return Int.random(in: 1...1000)
                        }
                    } catch {
                        // Handle errors in performance test
                    }
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
    
    func testSequentialOperationPerformance() {
        measure {
            Task {
                for _ in 0..<50 {
                    do {
                        let _: Bool = try await MLQueue.shared.runWithTimeout {
                            return true
                        }
                    } catch {
                        // Handle errors
                    }
                }
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testZeroTimeoutOperation() async {
        do {
            let _: Void = try await MLQueue.shared.runWithTimeout(timeoutSeconds: 0) {
                // Even instant operations might not complete with zero timeout
            }
            // If it completes, that's fine too
        } catch MLQueueError.timeout {
            // Expected for zero timeout
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testVeryShortTimeoutOperation() async {
        do {
            let result: String = try await MLQueue.shared.runWithTimeout(timeoutSeconds: 0.001) {
                return "quick"
            }
            // If it completes within 1ms, that's actually impressive
            XCTAssertEqual(result, "quick")
        } catch MLQueueError.timeout {
            // Also acceptable for such a short timeout
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testLongTimeoutOperation() async throws {
        let startTime = Date()
        
        let result: String = try await MLQueue.shared.runWithTimeout(timeoutSeconds: 5.0) {
            // Short operation with long timeout
            return "completed"
        }
        
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertEqual(result, "completed")
        XCTAssertLessThan(duration, 1.0, "Short operation should complete quickly even with long timeout")
    }
    
    // MARK: - Integration with Mock ML Operations
    
    func testMockMLModelOperation() async throws {
        // Simulate a typical ML model operation pattern
        let result: (confidence: Float, prediction: String) = try await MLQueue.shared.runWithTimeout {
            // Simulate model loading delay
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            
            // Simulate prediction computation
            let confidence = Float.random(in: 0.5...1.0)
            let prediction = confidence > 0.8 ? "high_confidence" : "low_confidence"
            
            return (confidence: confidence, prediction: prediction)
        }
        
        XCTAssertTrue(result.confidence >= 0.5 && result.confidence <= 1.0, "Confidence should be in valid range")
        XCTAssertTrue(["high_confidence", "low_confidence"].contains(result.prediction), "Prediction should be valid")
    }
    
    func testBatchMLOperations() async throws {
        let batchSize = 3
        let expectations = (0..<batchSize).map { index in
            XCTestExpectation(description: "Batch operation \(index)")
        }
        
        let results = try await withThrowingTaskGroup(of: Float.self) { group in
            for (index, expectation) in expectations.enumerated() {
                group.addTask {
                    let confidence: Float = try await MLQueue.shared.runWithTimeout {
                        // Simulate batch processing delay
                        try await Task.sleep(nanoseconds: 20_000_000) // 0.02 seconds
                        expectation.fulfill()
                        return Float(index + 1) / Float(batchSize)
                    }
                    return confidence
                }
            }
            
            var results: [Float] = []
            for try await result in group {
                results.append(result)
            }
            return results.sorted()
        }
        
        await fulfillment(of: expectations, timeout: 2.0)
        XCTAssertEqual(results.count, batchSize, "All batch operations should complete")
        
        // Verify results are in expected range
        for result in results {
            XCTAssertTrue(result > 0 && result <= 1.0, "Each result should be in valid confidence range")
        }
    }
}