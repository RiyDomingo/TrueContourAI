import XCTest
import CoreImage
import CoreML
import UIKit
@testable import TrueContourAI

final class EarLandmarksServiceTests: XCTestCase {

    func testCropAndScaleForLandmarksProduces300By300ImageAtOrigin() {
        let input = CIImage(color: CIColor(red: 0.2, green: 0.4, blue: 0.8))
            .cropped(to: CGRect(x: 0, y: 0, width: 120, height: 80))

        let cropped = EarLandmarksService.cropAndScaleForLandmarks(
            input,
            normalizedCropRect: CGRect(x: 0.85, y: 0.8, width: 0.2, height: 0.3)
        )

        XCTAssertEqual(cropped.extent.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(cropped.extent.origin.y, 0, accuracy: 0.001)
        XCTAssertEqual(cropped.extent.width, 300, accuracy: 0.001)
        XCTAssertEqual(cropped.extent.height, 300, accuracy: 0.001)
    }

    func testRemapLegacyLandmarksRightEarUsesTopLeftOutputCoordinates() {
        let mapped = EarLandmarksService.remapLegacyLandmarks(
            [(x: 0.0, y: 0.0), (x: 1.0, y: 1.0)],
            normalizedCropRect: CGRect(x: 0.4, y: 0.2, width: 0.2, height: 0.2),
            mirroredHorizontally: false
        )

        XCTAssertEqual(mapped[0], .init(x: 0.4, y: 0.6))
        XCTAssertEqual(mapped[1], .init(x: 0.6, y: 0.8))
    }

    func testRemapLegacyLandmarksSupportsHorizontalMirroring() {
        let mapped = EarLandmarksService.remapLegacyLandmarks(
            [(x: 0.1, y: 0.25)],
            normalizedCropRect: CGRect(x: 0.2, y: 0.4, width: 0.3, height: 0.2),
            mirroredHorizontally: true
        )

        XCTAssertEqual(mapped[0].x, 0.47, accuracy: 0.0001)
        XCTAssertEqual(mapped[0].y, 0.45, accuracy: 0.0001)
    }

    func testValidateMappedLandmarksRequiresMostPointsInsideCrop() {
        let points: [EarLandmarksResult.Point] = [
            .init(x: 0.22, y: 0.42),
            .init(x: 0.25, y: 0.48),
            .init(x: 0.28, y: 0.50),
            .init(x: 0.31, y: 0.52),
            .init(x: 0.90, y: 0.90)
        ]

        let isValid = EarLandmarksService.validateMappedLandmarks(
            points,
            within: CGRect(x: 0.2, y: 0.3, width: 0.2, height: 0.3),
            minimumInsideRatio: 0.6
        )

        XCTAssertTrue(isValid)
    }

    func testValidateMappedLandmarksRejectsEmptyOrMostlyOutsidePoints() {
        XCTAssertFalse(
            EarLandmarksService.validateMappedLandmarks(
                [],
                within: CGRect(x: 0.2, y: 0.3, width: 0.2, height: 0.3)
            )
        )

        let invalid = EarLandmarksService.validateMappedLandmarks(
            [
                .init(x: 0.05, y: 0.05),
                .init(x: 0.15, y: 0.15),
                .init(x: 0.25, y: 0.25),
                .init(x: 0.95, y: 0.95),
                .init(x: 0.85, y: 0.85)
            ],
            within: CGRect(x: 0.2, y: 0.3, width: 0.2, height: 0.3),
            minimumInsideRatio: 0.6
        )

        XCTAssertFalse(invalid)
    }

    func testParseLegacyLandmarkPointsReadsXYPairsInLegacyOrder() throws {
        let array = try MLMultiArray(shape: [2, 2], dataType: .double)
        array[[NSNumber(value: 0), NSNumber(value: 0)]] = 0.2
        array[[NSNumber(value: 0), NSNumber(value: 1)]] = 0.3
        array[[NSNumber(value: 1), NSNumber(value: 0)]] = 0.8
        array[[NSNumber(value: 1), NSNumber(value: 1)]] = 0.9

        let points = try EarLandmarksService.parseLegacyLandmarkPoints(array)

        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].x, 0.2, accuracy: 0.0001)
        XCTAssertEqual(points[0].y, 0.3, accuracy: 0.0001)
        XCTAssertEqual(points[1].x, 0.8, accuracy: 0.0001)
        XCTAssertEqual(points[1].y, 0.9, accuracy: 0.0001)
    }

    func testParseLegacyLandmarkPointsRejectsUnexpectedShape() throws {
        let array = try MLMultiArray(shape: [5], dataType: .double)

        XCTAssertThrowsError(try EarLandmarksService.parseLegacyLandmarkPoints(array))
    }

    func testOverlayLayoutMapsTopLeftLandmarksWithoutExtraYFlip() {
        let result = EarLandmarksResult(
            confidence: 0.9,
            earBoundingBox: .init(x: 0.2, y: 0.3, w: 0.2, h: 0.2),
            landmarks: [.init(x: 0.25, y: 0.75)],
            usedLeftEarMirroringHeuristic: false
        )

        let layout = EarLandmarksService.overlayLayout(
            for: result,
            imageSize: CGSize(width: 100, height: 200),
            drawBoundingBox: false,
            flipY: true,
            flipX: false
        )

        XCTAssertEqual(layout.landmarkPoints, [CGPoint(x: 25, y: 150)])
    }

    func testOverlayLayoutMapsBoundingBoxUsingDetectorNativeCoordinates() {
        let result = EarLandmarksResult(
            confidence: 0.9,
            earBoundingBox: .init(x: 0.2, y: 0.3, w: 0.2, h: 0.2),
            landmarks: [],
            usedLeftEarMirroringHeuristic: false
        )

        let layout = EarLandmarksService.overlayLayout(
            for: result,
            imageSize: CGSize(width: 100, height: 200),
            drawBoundingBox: true,
            flipY: true,
            flipX: false
        )

        XCTAssertEqual(layout.boundingBoxRect?.origin.x, 20, accuracy: 0.001)
        XCTAssertEqual(layout.boundingBoxRect?.origin.y, 100, accuracy: 0.001)
        XCTAssertEqual(layout.boundingBoxRect?.width, 20, accuracy: 0.001)
        XCTAssertEqual(layout.boundingBoxRect?.height, 40, accuracy: 0.001)
    }

    func testOverlayLayoutKeepsLandmarksInsideBoundingBoxNeighborhoodForCurrentDebugSample() {
        let result = EarLandmarksResult(
            confidence: 0.9,
            earBoundingBox: .init(
                x: 0.3780290842056274,
                y: 0.45919121146202085,
                w: 0.038681316375732425,
                h: 0.06445787668228149
            ),
            landmarks: [
                .init(x: 0.4065547238412961, y: 0.49602787842980206),
                .init(x: 0.3931228007115166, y: 0.4909928735167723),
                .init(x: 0.3885013820019765, y: 0.5092187825463388),
                .init(x: 0.40564827248572044, y: 0.5297865149963532),
                .init(x: 0.4071525189234677, y: 0.5106486736138455)
            ],
            usedLeftEarMirroringHeuristic: false
        )

        let layout = EarLandmarksService.overlayLayout(
            for: result,
            imageSize: CGSize(width: 1000, height: 2000),
            drawBoundingBox: true,
            flipY: true,
            flipX: false
        )

        guard let boundingBoxRect = layout.boundingBoxRect else {
            return XCTFail("Expected bounding box rect")
        }

        XCTAssertEqual(layout.landmarkPoints.count, 5)
        for point in layout.landmarkPoints {
            XCTAssertGreaterThanOrEqual(point.x, boundingBoxRect.minX - 10)
            XCTAssertLessThanOrEqual(point.x, boundingBoxRect.maxX + 10)
            XCTAssertGreaterThanOrEqual(point.y, boundingBoxRect.minY - 30)
            XCTAssertLessThanOrEqual(point.y, boundingBoxRect.maxY + 30)
        }
    }

    func testRenderCropOverlayPreservesCropSize() {
        let crop = makeSolidImage(size: CGSize(width: 300, height: 300), color: .blue)

        let overlay = EarLandmarksService.renderCropOverlay(
            on: crop,
            cropNormalizedLandmarks: [(x: 0.25, y: 0.5)]
        )

        XCTAssertEqual(overlay.size.width, 300, accuracy: 0.001)
        XCTAssertEqual(overlay.size.height, 300, accuracy: 0.001)
    }

    func testCropOverlayUsesCropLocalCoordinates() {
        let layout = CGPoint(x: 0.7484 * 300.0, y: 0.2963 * 300.0)
        XCTAssertEqual(layout.x, 224.52, accuracy: 0.01)
        XCTAssertEqual(layout.y, 88.89, accuracy: 0.01)
    }

    func testCurrentDebugSampleCropLandmarksStayInsideCropBounds() {
        let points: [(x: CGFloat, y: CGFloat)] = [
            (0.7484, 0.2963),
            (0.3851, 0.2146),
            (0.2602, 0.5104),
            (0.7239, 0.8442),
            (0.7646, 0.5336)
        ]

        for point in points {
            let mapped = CGPoint(x: point.x * 300.0, y: point.y * 300.0)
            XCTAssertGreaterThanOrEqual(mapped.x, 0)
            XCTAssertLessThanOrEqual(mapped.x, 300)
            XCTAssertGreaterThanOrEqual(mapped.y, 0)
            XCTAssertLessThanOrEqual(mapped.y, 300)
        }
    }

    private func makeSolidImage(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
