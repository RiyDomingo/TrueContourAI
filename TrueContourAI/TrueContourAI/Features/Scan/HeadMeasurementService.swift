import Foundation
import simd
import StandardCyborgFusion

struct HeadMeasurements: Codable {
    let sliceHeightNormalized: Float
    let circumferenceMm: Float
    let widthMm: Float
    let depthMm: Float
}

enum HeadMeasurementService {

    /// Estimates circumference/width/depth using a thin horizontal band of points.
    /// - sliceHeightNormalized: 0..1 from bottom to top of aligned point cloud bounds.
    /// - bandThicknessMm: thickness of the sample band around that slice.
    static func estimate(
        from pointCloud: SCPointCloud,
        sliceHeightNormalized: Float = 0.62,
        bandThicknessMm: Float = 8
    ) -> HeadMeasurements? {

        let points = extractPositions(pointCloud: pointCloud)
        guard points.count > 100 else { return nil }

        // Align so +Y is up (opposite gravity)
        let up = normalizeSafe(-pointCloud.gravity, fallback: SIMD3<Float>(0, 1, 0))
        let R = rotation(from: up, to: SIMD3<Float>(0, 1, 0))
        let com = pointCloud.centerOfMass()

        let aligned: [SIMD3<Float>] = points.map { R * ($0 - com) }
        guard let first = aligned.first else { return nil }

        // Bounds
        var minV = first
        var maxV = first
        for p in aligned {
            minV = SIMD3(Swift.min(minV.x, p.x), Swift.min(minV.y, p.y), Swift.min(minV.z, p.z))
            maxV = SIMD3(Swift.max(maxV.x, p.x), Swift.max(maxV.y, p.y), Swift.max(maxV.z, p.z))
        }

        let height = maxV.y - minV.y
        guard height > 0 else { return nil }

        let t = clamp(sliceHeightNormalized, 0, 1)
        let targetY = minV.y + t * height
        let halfBandMeters = (bandThicknessMm / 1000.0) * 0.5

        // Select a thin band of points around targetY
        let band = aligned.filter { abs($0.y - targetY) <= halfBandMeters }
        guard band.count > 80 else { return nil }

        // Project to XZ plane
        let pts2D: [SIMD2<Float>] = band.map { SIMD2<Float>($0.x, $0.z) }

        // Width/depth via bbox
        var minX = pts2D[0].x, maxX = pts2D[0].x
        var minZ = pts2D[0].y, maxZ = pts2D[0].y
        for p in pts2D {
            minX = Swift.min(minX, p.x); maxX = Swift.max(maxX, p.x)
            minZ = Swift.min(minZ, p.y); maxZ = Swift.max(maxZ, p.y)
        }

        // Circumference via convex hull perimeter
        guard let hull = convexHull(pts2D), hull.count >= 3 else { return nil }
        let perimeterMeters = polygonPerimeter(hull)

        return HeadMeasurements(
            sliceHeightNormalized: t,
            circumferenceMm: perimeterMeters * 1000.0,
            widthMm: (maxX - minX) * 1000.0,
            depthMm: (maxZ - minZ) * 1000.0
        )
    }

    // MARK: - Point extraction

    private static func extractPositions(pointCloud: SCPointCloud) -> [SIMD3<Float>] {
        let count = pointCloud.pointCount
        guard count > 0 else { return [] }

        // FIX: pointsData is optional in your build
        guard let data = pointCloud.pointsData else { return [] }

        let stride = Int(SCPointCloud.pointStride())
        let posOffset = Int(SCPointCloud.positionOffset())

        return data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return [] }
            var out: [SIMD3<Float>] = []
            out.reserveCapacity(count)

            for i in 0..<count {
                let ptr = base
                    .advanced(by: i * stride + posOffset)
                    .assumingMemoryBound(to: Float.self)

                out.append(SIMD3<Float>(ptr[0], ptr[1], ptr[2]))
            }
            return out
        }
    }

    // MARK: - Math helpers

    private static func normalizeSafe(_ v: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let len = simd_length(v)
        return len > 1e-6 ? (v / len) : fallback
    }

    private static func rotation(from a: SIMD3<Float>, to b: SIMD3<Float>) -> simd_float3x3 {
        let v = simd_cross(a, b)
        let c = simd_dot(a, b)
        let s = simd_length(v)
        if s < 1e-6 {
            if c > 0 { return matrix_identity_float3x3 }
            let axis = normalizeSafe(simd_cross(a, abs(a.x) < 0.9 ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)),
                                     fallback: SIMD3<Float>(0, 0, 1))
            let x = axis.x, y = axis.y, z = axis.z
            return simd_float3x3(
                SIMD3<Float>(-1 + 2 * x * x, 2 * x * y, 2 * x * z),
                SIMD3<Float>(2 * x * y, -1 + 2 * y * y, 2 * y * z),
                SIMD3<Float>(2 * x * z, 2 * y * z, -1 + 2 * z * z)
            )
        }

        let vx = simd_float3x3(
            SIMD3<Float>(  0, -v.z,  v.y),
            SIMD3<Float>( v.z,   0, -v.x),
            SIMD3<Float>(-v.y,  v.x,   0)
        )
        return matrix_identity_float3x3 + vx + (vx * vx) * ((1 - c) / (s * s))
    }

    static func _rotationForTest(from a: SIMD3<Float>, to b: SIMD3<Float>) -> simd_float3x3 {
        rotation(from: a, to: b)
    }

    private static func clamp(_ x: Float, _ lo: Float, _ hi: Float) -> Float {
        Swift.max(lo, Swift.min(hi, x))
    }

    // MARK: - Convex hull + perimeter

    private static func convexHull(_ points: [SIMD2<Float>]) -> [SIMD2<Float>]? {
        let uniq = Array(Set(points.map { Key2D($0) })).map { $0.p }
        if uniq.count < 3 { return nil }

        let pts = uniq.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }

        func cross(_ o: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }

        var lower: [SIMD2<Float>] = []
        for p in pts {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
                lower.removeLast()
            }
            lower.append(p)
        }

        var upper: [SIMD2<Float>] = []
        for p in pts.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }

        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    private static func polygonPerimeter(_ poly: [SIMD2<Float>]) -> Float {
        guard poly.count >= 2 else { return 0 }
        var sum: Float = 0
        for i in 0..<poly.count {
            let a = poly[i]
            let b = poly[(i + 1) % poly.count]
            sum += simd_length(b - a)
        }
        return sum
    }

    private struct Key2D: Hashable {
        let x: Int
        let y: Int
        let p: SIMD2<Float>

        init(_ p: SIMD2<Float>) {
            let q: Float = 10000 // quantize (helps reduce noisy duplicates)
            self.x = Int((p.x * q).rounded())
            self.y = Int((p.y * q).rounded())
            self.p = p
        }

        static func == (lhs: Key2D, rhs: Key2D) -> Bool {
            lhs.x == rhs.x && lhs.y == rhs.y
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(x)
            hasher.combine(y)
        }
    }
}
