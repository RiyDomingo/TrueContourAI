import Foundation
import simd

struct FitPoint3MM: Codable, Equatable {
    let x: Float
    let y: Float
    let z: Float

    init(_ v: SIMD3<Float>) {
        self.x = v.x
        self.y = v.y
        self.z = v.z
    }
}

struct FitQualityFlags: Codable, Equatable {
    let holes_detected: Bool
    let mesh_closed: Bool
    let triangle_count: Int
    let scan_coverage_score: Float
    let confidence_score: Float
}

struct FitDataJSON: Codable, Equatable {
    let head_circumference_brow_mm: Float
    let head_width_max_mm: Float
    let head_length_max_mm: Float
    let ear_to_ear_over_top_mm: Float
    let ear_left_xyz_mm: FitPoint3MM?
    let ear_right_xyz_mm: FitPoint3MM?
    let occipital_offset_mm: Float
    let quality_flags: FitQualityFlags
}

struct FitMetadataJSON: Codable, Equatable {
    let units: String
    let coordinate_frame: String
    let up_axis: String
    let scale_factor_used: Float
    let timestamp_iso8601: String
    let app_version: String
    let device_model: String
    let brow_plane_drop_from_top_fraction: Float
    let axis_sign_convention: String
}

struct FitModelCheckResult: Equatable {
    let fitData: FitDataJSON
    let metadata: FitMetadataJSON
    let warnings: [String]
}
