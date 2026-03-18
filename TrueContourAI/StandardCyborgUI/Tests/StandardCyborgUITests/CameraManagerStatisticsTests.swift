import XCTest
@testable import StandardCyborgUI

final class CameraManagerStatisticsTests: XCTestCase {
    func testDeliveredPairIncrementsDeliveryOnly() {
        let stats = CameraManagerStatistics()
        let updated = stats.byRecording(.delivered)

        XCTAssertEqual(updated.deliveredSynchronizedPairCount, 1)
        XCTAssertEqual(updated.droppedSynchronizedPairCount, 0)
        XCTAssertEqual(updated.droppedDepthDataCount, 0)
        XCTAssertEqual(updated.droppedVideoDataCount, 0)
        XCTAssertEqual(updated.missingSynchronizedDataCount, 0)
    }

    func testDroppedDepthAndVideoPairsAreCounted() {
        let stats = CameraManagerStatistics()
            .byRecording(.droppedDepth)
            .byRecording(.droppedVideo)
            .byRecording(.droppedDepthAndVideo)

        XCTAssertEqual(stats.deliveredSynchronizedPairCount, 0)
        XCTAssertEqual(stats.droppedSynchronizedPairCount, 3)
        XCTAssertEqual(stats.droppedDepthDataCount, 2)
        XCTAssertEqual(stats.droppedVideoDataCount, 2)
        XCTAssertEqual(stats.missingSynchronizedDataCount, 0)
    }

    func testMissingSynchronizedDataIncrementsOnlyMissingCount() {
        let stats = CameraManagerStatistics(
            deliveredSynchronizedPairCount: 4,
            droppedSynchronizedPairCount: 2,
            droppedDepthDataCount: 1,
            droppedVideoDataCount: 1,
            missingSynchronizedDataCount: 0
        )

        let updated = stats.byRecording(.missingSynchronizedData)

        XCTAssertEqual(updated.deliveredSynchronizedPairCount, 4)
        XCTAssertEqual(updated.droppedSynchronizedPairCount, 2)
        XCTAssertEqual(updated.droppedDepthDataCount, 1)
        XCTAssertEqual(updated.droppedVideoDataCount, 1)
        XCTAssertEqual(updated.missingSynchronizedDataCount, 1)
    }

    func testMultipleEventsAccumulateIndependently() {
        let stats = CameraManagerStatistics()
            .byRecording(.delivered)
            .byRecording(.droppedDepth)
            .byRecording(.delivered)
            .byRecording(.missingSynchronizedData)
            .byRecording(.droppedVideo)

        XCTAssertEqual(stats.deliveredSynchronizedPairCount, 2)
        XCTAssertEqual(stats.droppedSynchronizedPairCount, 2)
        XCTAssertEqual(stats.droppedDepthDataCount, 1)
        XCTAssertEqual(stats.droppedVideoDataCount, 1)
        XCTAssertEqual(stats.missingSynchronizedDataCount, 1)
    }
}
