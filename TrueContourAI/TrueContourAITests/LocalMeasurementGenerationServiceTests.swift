import XCTest
import StandardCyborgFusion
@testable import TrueContourAI

@MainActor
final class LocalMeasurementGenerationServiceTests: XCTestCase {
    func testGenerateFailsWhenInsufficientData() {
        let service = LocalMeasurementGenerationService(estimator: { _ in nil })
        let pointCloud = placeholderPointCloud()

        var progressValues: [Float] = []
        let exp = expectation(description: "completion")

        service.generate(
            from: pointCloud,
            progress: { progressValues.append($0) },
            completion: { result in
                if case .failure(let error) = result {
                    XCTAssertTrue(error.localizedDescription.contains("Not enough point cloud data"))
                } else {
                    XCTFail("Expected insufficient data failure")
                }
                exp.fulfill()
            }
        )

        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(progressValues, [0.1, 0.5])
    }

    func testGenerateReturnsValidatedStatusForHighConfidenceMeasurement() {
        let measurement = HeadMeasurements(
            sliceHeightNormalized: 0.62,
            circumferenceMm: 650,
            widthMm: 240,
            depthMm: 240
        )
        let service = LocalMeasurementGenerationService(estimator: { _ in measurement })

        let exp = expectation(description: "completion")
        service.generate(
            from: placeholderPointCloud(),
            progress: { _ in },
            completion: { result in
                switch result {
                case .success(let summary):
                    XCTAssertEqual(summary.status, "validated")
                    XCTAssertGreaterThanOrEqual(summary.confidence, 0.75)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                exp.fulfill()
            }
        )

        wait(for: [exp], timeout: 2.0)
    }

    func testGenerateReturnsEstimatedStatusForLowerConfidenceMeasurement() {
        let measurement = HeadMeasurements(
            sliceHeightNormalized: 0.62,
            circumferenceMm: 470,
            widthMm: 130,
            depthMm: 130
        )
        let service = LocalMeasurementGenerationService(estimator: { _ in measurement })

        let exp = expectation(description: "completion")
        service.generate(
            from: placeholderPointCloud(),
            progress: { _ in },
            completion: { result in
                switch result {
                case .success(let summary):
                    XCTAssertEqual(summary.status, "estimated")
                    XCTAssertLessThan(summary.confidence, 0.75)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                exp.fulfill()
            }
        )

        wait(for: [exp], timeout: 2.0)
    }

    func testProgressCallbackOrderIsDeterministic() {
        let measurement = HeadMeasurements(
            sliceHeightNormalized: 0.62,
            circumferenceMm: 620,
            widthMm: 210,
            depthMm: 205
        )
        let service = LocalMeasurementGenerationService(estimator: { _ in measurement })
        var observed: [Float] = []
        let exp = expectation(description: "completion")

        service.generate(
            from: placeholderPointCloud(),
            progress: { observed.append($0) },
            completion: { _ in exp.fulfill() }
        )

        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(observed, [0.1, 0.5, 1.0])
    }

    private func placeholderPointCloud() -> SCPointCloud {
        // Tests only validate service branching/progress, not point cloud internals.
        placeholderObject(SCPointCloud.self)
    }

    private func placeholderObject<T: AnyObject>(_ type: T.Type) -> T {
        unsafeBitCast(NSObject(), to: T.self)
    }
}
