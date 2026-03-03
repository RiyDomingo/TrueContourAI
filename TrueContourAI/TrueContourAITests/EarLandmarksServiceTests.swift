import XCTest
import UIKit
@testable import TrueContourAI

final class EarLandmarksServiceTests: XCTestCase {

    func testMapLandmarksPrefersSwapWhenInsideRatioHigher() {
        let points: [(x: CGFloat, y: CGFloat)] = [
            (0.1, 0.5),
            (0.9, 0.5),
            (0.8, 0.5)
        ]

        let expandedBBox = CGRect(x: 0.45, y: 0.0, width: 0.1, height: 1.0)
        let squareCropPx = CGRect(x: 0, y: 0, width: 100, height: 100)
        let imageSize = CGSize(width: 100, height: 100)

        let mapped = EarLandmarksService.mapLandmarks(
            pointsInCrop: points,
            expandedBBox: expandedBBox,
            squareCropPx: squareCropPx,
            imageSize: imageSize,
            isLeftEarHeuristic: false,
            clampToUnitRange: true
        )

        XCTAssertEqual(mapped.count, points.count)
        for p in mapped {
            XCTAssertGreaterThanOrEqual(p.x, 0.45)
            XCTAssertLessThanOrEqual(p.x, 0.55)
        }
    }
}
