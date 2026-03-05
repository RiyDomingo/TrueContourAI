import XCTest
import simd
@testable import TrueContourAI

final class FitModelPackServiceTests: XCTestCase {
    func testUnitConversionMetersToMillimeters() {
        XCTAssertEqual(FitModelPackService.convertMetersToMillimeters(1.0), 1000, accuracy: 0.0001)
        XCTAssertEqual(FitModelPackService.convertMetersToMillimeters(0.152), 152, accuracy: 0.0001)
    }

    func testPCAAxisAlignmentFollowsDominantDirection() {
        var points: [SIMD3<Float>] = []
        for i in -100...100 {
            let x = Float(i) * 0.005
            let y = Float(i) * 0.0004
            let z = Float(i % 7) * 0.0002
            points.append(SIMD3<Float>(x, y, z))
        }

        let frame = FitModelPackService.computePrincipalAxesForTest(points: points)
        let xDot = abs(simd_dot(frame.x, SIMD3<Float>(1, 0, 0)))
        XCTAssertGreaterThan(xDot, 0.9)
        XCTAssertGreaterThan(simd_dot(frame.y, SIMD3<Float>(0, 1, 0)), 0.0)
    }

    func testFitDataJSONSchemaEncodesRequiredFields() throws {
        let fitData = FitDataJSON(
            head_circumference_brow_mm: 560,
            head_width_max_mm: 155,
            head_length_max_mm: 190,
            ear_to_ear_over_top_mm: 320,
            ear_left_xyz_mm: FitPoint3MM(SIMD3<Float>(-70, 20, 10)),
            ear_right_xyz_mm: FitPoint3MM(SIMD3<Float>(70, 20, 10)),
            occipital_offset_mm: 82,
            quality_flags: FitQualityFlags(
                holes_detected: false,
                mesh_closed: true,
                triangle_count: 1000,
                scan_coverage_score: 0.8,
                confidence_score: 0.84
            )
        )
        let data = try JSONEncoder().encode(fitData)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = object as? [String: Any] else {
            XCTFail("Expected dictionary")
            return
        }

        XCTAssertNotNil(dict["head_circumference_brow_mm"])
        XCTAssertNotNil(dict["head_width_max_mm"])
        XCTAssertNotNil(dict["head_length_max_mm"])
        XCTAssertNotNil(dict["ear_to_ear_over_top_mm"])
        XCTAssertNotNil(dict["ear_left_xyz_mm"])
        XCTAssertNotNil(dict["ear_right_xyz_mm"])
        XCTAssertNotNil(dict["occipital_offset_mm"])
        XCTAssertNotNil(dict["quality_flags"])
    }
}
