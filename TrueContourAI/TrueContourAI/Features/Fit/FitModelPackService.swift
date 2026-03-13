import Foundation
import StandardCyborgFusion
import simd

final class FitModelPackService {
    struct MeshData: Equatable {
        let verticesMeters: [SIMD3<Float>]
        let faces: [SIMD3<Int32>]
    }

    static let metersToMillimeters: Float = 1000.0

    func checkFromMesh(
        mesh: SCMesh,
        manualEarLeftMeters: SIMD3<Float>?,
        manualEarRightMeters: SIMD3<Float>?,
        browPlaneDropFromTopFraction: Float = 0.25,
        appVersion: String,
        deviceModel: String
    ) -> FitModelCheckResult? {
        guard let meshData = Self.extractMeshData(from: mesh) else { return nil }
        return buildCheck(
            meshData: meshData,
            manualEarLeftMeters: manualEarLeftMeters,
            manualEarRightMeters: manualEarRightMeters,
            browPlaneDropFromTopFraction: browPlaneDropFromTopFraction,
            appVersion: appVersion,
            deviceModel: deviceModel
        )
    }

    func checkFromOBJ(
        objURL: URL,
        manualEarLeftMeters: SIMD3<Float>?,
        manualEarRightMeters: SIMD3<Float>?,
        browPlaneDropFromTopFraction: Float = 0.25,
        appVersion: String,
        deviceModel: String
    ) -> FitModelCheckResult? {
        guard let meshData = Self.readOBJMeshData(from: objURL) else { return nil }
        return buildCheck(
            meshData: meshData,
            manualEarLeftMeters: manualEarLeftMeters,
            manualEarRightMeters: manualEarRightMeters,
            browPlaneDropFromTopFraction: browPlaneDropFromTopFraction,
            appVersion: appVersion,
            deviceModel: deviceModel
        )
    }

    func checkFromOBJMeshData(
        meshData: MeshData,
        manualEarLeftMeters: SIMD3<Float>?,
        manualEarRightMeters: SIMD3<Float>?,
        browPlaneDropFromTopFraction: Float = 0.25,
        appVersion: String,
        deviceModel: String
    ) -> FitModelCheckResult? {
        buildCheck(
            meshData: meshData,
            manualEarLeftMeters: manualEarLeftMeters,
            manualEarRightMeters: manualEarRightMeters,
            browPlaneDropFromTopFraction: browPlaneDropFromTopFraction,
            appVersion: appVersion,
            deviceModel: deviceModel
        )
    }

    func exportPack(
        meshData: MeshData,
        fitCheckResult: FitModelCheckResult,
        parentFolderURL: URL
    ) throws -> URL {
        let packURL = parentFolderURL.appendingPathComponent("FitModelPack", isDirectory: true)
        let fm = FileManager.default
        if fm.fileExists(atPath: packURL.path) {
            try fm.removeItem(at: packURL)
        }
        try fm.createDirectory(at: packURL, withIntermediateDirectories: true)

        let meshURL = packURL.appendingPathComponent("reference_mesh.obj")
        try Self.writeReferenceOBJInMillimeters(meshData: meshData, to: meshURL)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let fitDataURL = packURL.appendingPathComponent("fit_data.json")
        let metadataURL = packURL.appendingPathComponent("metadata.json")
        try encoder.encode(fitCheckResult.fitData).write(to: fitDataURL, options: [.atomic])
        try encoder.encode(fitCheckResult.metadata).write(to: metadataURL, options: [.atomic])

        return packURL
    }

    private func buildCheck(
        meshData: MeshData,
        manualEarLeftMeters: SIMD3<Float>?,
        manualEarRightMeters: SIMD3<Float>?,
        browPlaneDropFromTopFraction: Float,
        appVersion: String,
        deviceModel: String
    ) -> FitModelCheckResult? {
        let vertices = meshData.verticesMeters
        guard vertices.count > 100 else { return nil }

        let centroid = Self.mean(vertices)
        let centered = vertices.map { $0 - centroid }
        let frame = Self.computeFrame(points: centered)
        let aligned = centered.map { p in SIMD3<Float>(simd_dot(p, frame.x), simd_dot(p, frame.y), simd_dot(p, frame.z)) }
        guard let bounds = Self.bounds(of: aligned) else { return nil }

        let browFraction = min(0.30, max(0.20, browPlaneDropFromTopFraction))
        let browY = bounds.max.y - browFraction * (bounds.max.y - bounds.min.y)
        let bandHalfThicknessMeters: Float = 0.004
        let browSection = aligned.filter { abs($0.y - browY) <= bandHalfThicknessMeters }

        var warnings: [String] = []
        let browPerimeterMM: Float
        if let perimeter = Self.convexHullPerimeterXZ(points: browSection) {
            browPerimeterMM = perimeter * Self.metersToMillimeters
        } else {
            browPerimeterMM = 0
            warnings.append("Brow section was too sparse for perimeter estimation.")
        }

        let widthMM = (bounds.max.x - bounds.min.x) * Self.metersToMillimeters
        let lengthMM = (bounds.max.z - bounds.min.z) * Self.metersToMillimeters
        let occipitalOffsetMM = max(0, -bounds.min.z) * Self.metersToMillimeters

        let topPoint = aligned.max(by: { $0.y < $1.y }) ?? SIMD3<Float>(0, 0, 0)
        let alignedLeftEar = manualEarLeftMeters.map { ear in
            let p = ear - centroid
            return SIMD3<Float>(simd_dot(p, frame.x), simd_dot(p, frame.y), simd_dot(p, frame.z))
        }
        let alignedRightEar = manualEarRightMeters.map { ear in
            let p = ear - centroid
            return SIMD3<Float>(simd_dot(p, frame.x), simd_dot(p, frame.y), simd_dot(p, frame.z))
        }
        let earToEarOverTopMM: Float
        if let left = alignedLeftEar, let right = alignedRightEar {
            earToEarOverTopMM = (simd_distance(left, topPoint) + simd_distance(topPoint, right)) * Self.metersToMillimeters
        } else {
            earToEarOverTopMM = 0
            warnings.append("Ear landmarks are missing; use manual ear pick for full fit data.")
        }

        let edgeStats = Self.computeBoundaryEdgeStats(faces: meshData.faces)
        let meshClosed = edgeStats.boundaryEdgeCount == 0
        let holesDetected = !meshClosed

        let coverage = Self.computeCoverageScore(points: aligned)
        let bboxSane = Self.isBoundingBoxSane(widthMM: widthMM, lengthMM: lengthMM, heightMM: (bounds.max.y - bounds.min.y) * Self.metersToMillimeters)
        if !bboxSane {
            warnings.append("Bounding box is outside expected human head ranges.")
        }
        let confidence = Self.computeConfidence(
            coverage: coverage,
            meshClosed: meshClosed,
            bboxSane: bboxSane,
            hasEarPoints: alignedLeftEar != nil && alignedRightEar != nil
        )

        let fitData = FitDataJSON(
            head_circumference_brow_mm: browPerimeterMM,
            head_width_max_mm: widthMM,
            head_length_max_mm: lengthMM,
            ear_to_ear_over_top_mm: earToEarOverTopMM,
            ear_left_xyz_mm: alignedLeftEar.map { FitPoint3MM($0 * Self.metersToMillimeters) },
            ear_right_xyz_mm: alignedRightEar.map { FitPoint3MM($0 * Self.metersToMillimeters) },
            occipital_offset_mm: occipitalOffsetMM,
            quality_flags: FitQualityFlags(
                holes_detected: holesDetected,
                mesh_closed: meshClosed,
                triangle_count: meshData.faces.count,
                scan_coverage_score: coverage,
                confidence_score: confidence
            )
        )

        let metadata = FitMetadataJSON(
            units: "mm",
            coordinate_frame: "PCA-aligned local frame with origin at mesh centroid",
            up_axis: "+Y",
            scale_factor_used: Self.metersToMillimeters,
            timestamp_iso8601: ISO8601DateFormatter().string(from: Date()),
            app_version: appVersion,
            device_model: deviceModel,
            brow_plane_drop_from_top_fraction: browFraction,
            axis_sign_convention: "+X right, +Y up, +Z front"
        )

        return FitModelCheckResult(fitData: fitData, metadata: metadata, warnings: warnings)
    }

    static func extractMeshData(from mesh: SCMesh) -> MeshData? {
        let vertexCount = Int(mesh.vertexCount)
        let faceCount = Int(mesh.faceCount)
        guard vertexCount > 2, faceCount > 0 else { return nil }

        let vertices: [SIMD3<Float>]
        do {
            vertices = try mesh.positionData.withUnsafeBytes { raw -> [SIMD3<Float>] in
                let floats = raw.bindMemory(to: Float.self)
                let stride: Int
                if floats.count >= vertexCount * 4 {
                    stride = 4
                } else if floats.count >= vertexCount * 3 {
                    stride = 3
                } else {
                    throw NSError(domain: "FitModelPackService", code: 1)
                }
                var out: [SIMD3<Float>] = []
                out.reserveCapacity(vertexCount)
                for i in 0..<vertexCount {
                    out.append(SIMD3<Float>(
                        floats[stride * i + 0],
                        floats[stride * i + 1],
                        floats[stride * i + 2]
                    ))
                }
                return out
            }
        } catch {
            return nil
        }

        let faces: [SIMD3<Int32>]
        do {
            faces = try mesh.facesData.withUnsafeBytes { raw -> [SIMD3<Int32>] in
                let ints = raw.bindMemory(to: Int32.self)
                guard ints.count >= faceCount * 3 else {
                    throw NSError(domain: "FitModelPackService", code: 2)
                }
                var out: [SIMD3<Int32>] = []
                out.reserveCapacity(faceCount)
                for i in 0..<faceCount {
                    out.append(SIMD3<Int32>(
                        ints[i * 3 + 0],
                        ints[i * 3 + 1],
                        ints[i * 3 + 2]
                    ))
                }
                return out
            }
        } catch {
            return nil
        }

        return MeshData(verticesMeters: vertices, faces: faces)
    }

    static func readOBJMeshData(from objURL: URL) -> MeshData? {
        guard let text = try? String(contentsOf: objURL, encoding: .utf8) else { return nil }
        var vertices: [SIMD3<Float>] = []
        var faces: [SIMD3<Int32>] = []

        for line in text.split(separator: "\n") {
            if line.hasPrefix("v ") {
                let comps = line.split(separator: " ")
                guard comps.count >= 4,
                      let x = Float(comps[1]),
                      let y = Float(comps[2]),
                      let z = Float(comps[3]) else { continue }
                vertices.append(SIMD3<Float>(x, y, z))
            } else if line.hasPrefix("f ") {
                let comps = line.split(separator: " ")
                guard comps.count >= 4 else { continue }
                var idx: [Int32] = []
                idx.reserveCapacity(3)
                for token in comps[1...3] {
                    let first = token.split(separator: "/").first ?? ""
                    if let i = Int32(first), i > 0 {
                        idx.append(i - 1)
                    }
                }
                if idx.count == 3 {
                    faces.append(SIMD3<Int32>(idx[0], idx[1], idx[2]))
                }
            }
        }

        guard vertices.count > 2, !faces.isEmpty else { return nil }
        return MeshData(verticesMeters: vertices, faces: faces)
    }

    static func writeReferenceOBJInMillimeters(meshData: MeshData, to url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        func writeLine(_ value: String) throws {
            guard let data = (value + "\n").data(using: .utf8) else { return }
            try handle.write(contentsOf: data)
        }

        try writeLine("# FitModelPack reference mesh")
        try writeLine("# units: mm")
        try writeLine("o reference_mesh")
        for v in meshData.verticesMeters {
            let mm = v * metersToMillimeters
            try writeLine(String(
                format: "v %.6f %.6f %.6f",
                locale: Locale(identifier: "en_US_POSIX"),
                mm.x, mm.y, mm.z
            ))
        }
        for f in meshData.faces {
            let i0 = Int(f.x) + 1
            let i1 = Int(f.y) + 1
            let i2 = Int(f.z) + 1
            try writeLine("f \(i0) \(i1) \(i2)")
        }
    }

    static func convertMetersToMillimeters(_ value: Float) -> Float {
        value * metersToMillimeters
    }

    static func computePrincipalAxesForTest(points: [SIMD3<Float>]) -> (x: SIMD3<Float>, y: SIMD3<Float>, z: SIMD3<Float>) {
        computeFrame(points: points)
    }

    private static func mean(_ points: [SIMD3<Float>]) -> SIMD3<Float> {
        guard !points.isEmpty else { return SIMD3<Float>(0, 0, 0) }
        var sum = SIMD3<Float>(0, 0, 0)
        for p in points { sum += p }
        return sum / Float(points.count)
    }

    private static func computeFrame(points: [SIMD3<Float>]) -> (x: SIMD3<Float>, y: SIMD3<Float>, z: SIMD3<Float>) {
        let cov = covariance(points: points)

        var e1 = powerIteration(cov, initial: SIMD3<Float>(1, 0, 0))
        if simd_length(e1) < 1e-6 { e1 = SIMD3<Float>(1, 0, 0) }
        let lambda1 = simd_dot(e1, cov * e1)

        let deflated = cov - lambda1 * simd_float3x3(columns: (
            e1 * e1.x,
            e1 * e1.y,
            e1 * e1.z
        ))
        var e2 = powerIteration(deflated, initial: SIMD3<Float>(0, 1, 0))
        if simd_length(e2) < 1e-6 || abs(simd_dot(e2, e1)) > 0.95 {
            e2 = normalizeSafe(SIMD3<Float>(0, 1, 0) - simd_dot(SIMD3<Float>(0, 1, 0), e1) * e1, fallback: SIMD3<Float>(0, 0, 1))
        }
        let e3 = normalizeSafe(simd_cross(e1, e2), fallback: SIMD3<Float>(0, 0, 1))

        // Anchor orientation to a stable world convention.
        let worldUp = SIMD3<Float>(0, 1, 0)
        let worldRight = SIMD3<Float>(1, 0, 0)
        let candidates = [e1, e2, e3]

        var yAxis = candidates.max(by: { abs(simd_dot($0, worldUp)) < abs(simd_dot($1, worldUp)) }) ?? e2
        if simd_dot(yAxis, worldUp) < 0 { yAxis = -yAxis }

        let remaining = candidates.filter { abs(simd_dot($0, yAxis)) < 0.95 }
        var xAxis = remaining.max(by: { abs(simd_dot($0, worldRight)) < abs(simd_dot($1, worldRight)) }) ?? e1
        xAxis = normalizeSafe(xAxis - simd_dot(xAxis, yAxis) * yAxis, fallback: SIMD3<Float>(1, 0, 0))
        if simd_dot(xAxis, worldRight) < 0 { xAxis = -xAxis }

        var zAxis = normalizeSafe(simd_cross(xAxis, yAxis), fallback: SIMD3<Float>(0, 0, 1))
        if zAxis.z < 0 { zAxis = -zAxis }
        xAxis = normalizeSafe(simd_cross(yAxis, zAxis), fallback: xAxis)

        return (xAxis, yAxis, zAxis)
    }

    private static func covariance(points: [SIMD3<Float>]) -> simd_float3x3 {
        guard !points.isEmpty else { return matrix_identity_float3x3 }
        var c00: Float = 0, c01: Float = 0, c02: Float = 0
        var c11: Float = 0, c12: Float = 0, c22: Float = 0
        for p in points {
            c00 += p.x * p.x
            c01 += p.x * p.y
            c02 += p.x * p.z
            c11 += p.y * p.y
            c12 += p.y * p.z
            c22 += p.z * p.z
        }
        let n = max(1, points.count)
        let invN = 1.0 / Float(n)
        return simd_float3x3(columns: (
            SIMD3<Float>(c00 * invN, c01 * invN, c02 * invN),
            SIMD3<Float>(c01 * invN, c11 * invN, c12 * invN),
            SIMD3<Float>(c02 * invN, c12 * invN, c22 * invN)
        ))
    }

    private static func powerIteration(_ matrix: simd_float3x3, initial: SIMD3<Float>, iterations: Int = 20) -> SIMD3<Float> {
        var v = normalizeSafe(initial, fallback: SIMD3<Float>(1, 0, 0))
        for _ in 0..<iterations {
            v = normalizeSafe(matrix * v, fallback: v)
        }
        return v
    }

    private static func normalizeSafe(_ v: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let l = simd_length(v)
        if l < 1e-6 { return fallback }
        return v / l
    }

    private static func bounds(of points: [SIMD3<Float>]) -> (min: SIMD3<Float>, max: SIMD3<Float>)? {
        guard var minV = points.first else { return nil }
        var maxV = minV
        for p in points {
            minV = SIMD3<Float>(Swift.min(minV.x, p.x), Swift.min(minV.y, p.y), Swift.min(minV.z, p.z))
            maxV = SIMD3<Float>(Swift.max(maxV.x, p.x), Swift.max(maxV.y, p.y), Swift.max(maxV.z, p.z))
        }
        return (minV, maxV)
    }

    private static func convexHullPerimeterXZ(points: [SIMD3<Float>]) -> Float? {
        let p2 = points.map { SIMD2<Float>($0.x, $0.z) }
        guard let hull = convexHull2D(p2), hull.count >= 3 else { return nil }
        return polygonPerimeter2D(hull)
    }

    private static func convexHull2D(_ points: [SIMD2<Float>]) -> [SIMD2<Float>]? {
        let unique = Array(Set(points.map { Quantized2D($0) })).map { $0.p }
        if unique.count < 3 { return nil }
        let sorted = unique.sorted { a, b in
            if a.x == b.x { return a.y < b.y }
            return a.x < b.x
        }

        func cross(_ o: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }

        var lower: [SIMD2<Float>] = []
        for p in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
                lower.removeLast()
            }
            lower.append(p)
        }

        var upper: [SIMD2<Float>] = []
        for p in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }

        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    private static func polygonPerimeter2D(_ poly: [SIMD2<Float>]) -> Float {
        guard poly.count >= 2 else { return 0 }
        var sum: Float = 0
        for i in 0..<poly.count {
            let a = poly[i]
            let b = poly[(i + 1) % poly.count]
            sum += simd_length(b - a)
        }
        return sum
    }

    private static func computeBoundaryEdgeStats(faces: [SIMD3<Int32>]) -> (boundaryEdgeCount: Int, uniqueEdges: Int) {
        var edgeCount: [EdgeKey: Int] = [:]
        edgeCount.reserveCapacity(faces.count * 3)
        for f in faces {
            let edges = [
                EdgeKey(f.x, f.y),
                EdgeKey(f.y, f.z),
                EdgeKey(f.z, f.x)
            ]
            for e in edges {
                edgeCount[e, default: 0] += 1
            }
        }
        let boundary = edgeCount.values.reduce(into: 0) { partial, v in
            if v == 1 { partial += 1 }
        }
        return (boundary, edgeCount.count)
    }

    private static func computeCoverageScore(points: [SIMD3<Float>]) -> Float {
        guard !points.isEmpty else { return 0 }
        let azimuthBins = 16
        let elevationBins = 8
        var occupied = Set<Int>()
        occupied.reserveCapacity(azimuthBins * elevationBins)

        for p in points {
            let n = normalizeSafe(p, fallback: SIMD3<Float>(0, 0, 1))
            let az = atan2(n.z, n.x) // -pi...pi
            let el = asin(max(-1, min(1, n.y))) // -pi/2...pi/2

            let azNorm = (az + Float.pi) / (2 * Float.pi)
            let elNorm = (el + Float.pi / 2) / Float.pi
            let azIdx = min(azimuthBins - 1, max(0, Int(azNorm * Float(azimuthBins))))
            let elIdx = min(elevationBins - 1, max(0, Int(elNorm * Float(elevationBins))))
            occupied.insert(elIdx * azimuthBins + azIdx)
        }

        let totalBins = azimuthBins * elevationBins
        return Float(occupied.count) / Float(totalBins)
    }

    private static func isBoundingBoxSane(widthMM: Float, lengthMM: Float, heightMM: Float) -> Bool {
        let widthOK = (110...260).contains(widthMM)
        let lengthOK = (130...320).contains(lengthMM)
        let heightOK = (130...320).contains(heightMM)
        return widthOK && lengthOK && heightOK
    }

    private static func computeConfidence(coverage: Float, meshClosed: Bool, bboxSane: Bool, hasEarPoints: Bool) -> Float {
        var score: Float = coverage * 0.55
        score += meshClosed ? 0.20 : 0.06
        score += bboxSane ? 0.17 : 0.02
        score += hasEarPoints ? 0.08 : 0.0
        return max(0, min(1, score))
    }
}

private struct EdgeKey: Hashable {
    let a: Int32
    let b: Int32

    init(_ i: Int32, _ j: Int32) {
        if i < j {
            self.a = i
            self.b = j
        } else {
            self.a = j
            self.b = i
        }
    }
}

private struct Quantized2D: Hashable {
    let x: Int
    let y: Int
    let p: SIMD2<Float>

    init(_ p: SIMD2<Float>) {
        let q: Float = 10_000
        self.x = Int((p.x * q).rounded())
        self.y = Int((p.y * q).rounded())
        self.p = p
    }
}
