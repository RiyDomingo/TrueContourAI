//
//  MeasurementCalculator.swift
//  CyborgRugby
//
//  Computes rugby-relevant measurements from captured SCPointClouds.
//

import Foundation
import simd
import StandardCyborgFusion

struct RugbyMeasurementCalculator {
    static func compute(from scans: [HeadScanningPose: ScanResult]) -> ScrumCapMeasurements {
        // Fused (placeholder) cloud: densest point cloud among poses
        let fused = RugbyHeadScanFusion.fuse(scans)
        // Overall metrics across all poses (prefer fused aggregate if available)
        let overallFused = fusedAggregate(scans: scans)
        let overall = PointCloudMetricsCalculator.aggregate(from: scans)

        func mm(_ meters: Float) -> Float { meters * 1000.0 }

        // Helper to get metrics for a pose
        func metrics(for pose: HeadScanningPose) -> PointCloudMetrics? {
            guard let cloud = scans[pose]?.pointCloud else { return nil }
            return PointCloudMetricsCalculator.compute(for: cloud)
        }

        // Head circumference (prefer fused horizontal slice in reference frame)
        let headCircVM: ValidatedMeasurement = {
            if let slice = computeHorizontalSliceFused(scans: scans) {
                let perimeter = convexHullPerimeter(slice.points2D)
                return ValidatedMeasurement(
                    value: mm(perimeter) / 10.0, // cm
                    confidence: 0.9,
                    validationStatus: .validated,
                    alternativeValues: [],
                    measurementSource: .directScan(poses: Array(scans.keys))
                )
            } else if let fused = fused, let slice = computeHorizontalSliceOfCloud(fused) {
                // Prefer convex hull perimeter over ellipse approximation
                let perimeter = convexHullPerimeter(slice.points2D)
                return ValidatedMeasurement(
                    value: mm(perimeter) / 10.0, // cm
                    confidence: 0.85,
                    validationStatus: .validated,
                    alternativeValues: [],
                    measurementSource: .directScan(poses: Array(scans.keys))
                )
            } else if let o = overall {
                let a = max(0, o.width) / 2.0
                let b = max(0, o.depth) / 2.0
                let perimeter = 2.0 * Float.pi * sqrtf((a * a + b * b) / 2.0)
                return ValidatedMeasurement(
                    value: mm(perimeter) / 10.0,
                    confidence: 0.75,
                    validationStatus: .estimated,
                    alternativeValues: [],
                    measurementSource: .directScan(poses: Array(scans.keys))
                )
            } else {
                return ValidatedMeasurement(value: 56.0, confidence: 0.3, validationStatus: .interpolated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["defaults"]))
            }
        }()

        // Back-of-head metrics from looking-down pose if available
        let ldMetrics = metrics(for: .lookingDown)
        let backHeadWidthVM: ValidatedMeasurement = {
            if let f = overallFused {
                return ValidatedMeasurement(value: mm(f.width), confidence: 0.9, validationStatus: .validated, alternativeValues: [], measurementSource: .directScan(poses: Array(scans.keys)))
            } else if let m = ldMetrics {
                return ValidatedMeasurement(value: mm(m.width), confidence: 0.8, validationStatus: .validated, alternativeValues: [], measurementSource: .directScan(poses: [.lookingDown]))
            } else if let o = overall {
                return ValidatedMeasurement(value: mm(o.width), confidence: 0.6, validationStatus: .estimated, alternativeValues: [], measurementSource: .directScan(poses: Array(scans.keys)))
            } else {
                return ValidatedMeasurement(value: 160.0, confidence: 0.3, validationStatus: .interpolated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["defaults"]))
            }
        }()

        let occipitalProminenceVM: ValidatedMeasurement = {
            if let f = overallFused {
                let comZ = f.centerZ
                let prominence = max(0, f.maxZ - comZ)
                return ValidatedMeasurement(value: mm(prominence), confidence: 0.75, validationStatus: .validated, alternativeValues: [], measurementSource: .directScan(poses: Array(scans.keys)))
            } else if let scan = scans[.lookingDown]?.pointCloud, let m = ldMetrics {
                let com = scan.centerOfMass()
                let prominence = max(0, m.maxZ - com.z)
                return ValidatedMeasurement(value: mm(prominence), confidence: 0.7, validationStatus: .estimated, alternativeValues: [], measurementSource: .directScan(poses: [.lookingDown]))
            } else if let o = overall {
                return ValidatedMeasurement(value: mm(o.depth * 0.25), confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .directScan(poses: Array(scans.keys)))
            } else {
                return ValidatedMeasurement(value: 12.0, confidence: 0.3, validationStatus: .interpolated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["defaults"]))
            }
        }()

        // Ear dimensions (approximate from profile pose bounding boxes)
        func earDimensions(for pose: HeadScanningPose) -> ValidatedEarDimensions {
            // Prefer stored ear metrics from ScanResult if available
            if let em = scans[pose]?.earMetrics {
                return ValidatedEarDimensions(
                    height: ValidatedMeasurement(value: em.heightMM, confidence: em.confidence, validationStatus: .validated, alternativeValues: [], measurementSource: .directScan(poses: [pose])),
                    width: ValidatedMeasurement(value: em.widthMM, confidence: em.confidence, validationStatus: .validated, alternativeValues: [], measurementSource: .directScan(poses: [pose])),
                    protrusionAngle: ValidatedMeasurement(value: em.protrusionAngleDeg, confidence: em.confidence, validationStatus: .estimated, alternativeValues: [], measurementSource: .mlModel(modelName: "SCEarLandmarking", confidence: em.confidence)),
                    topToLobe: ValidatedMeasurement(value: em.topToLobeMM, confidence: em.confidence, validationStatus: .validated, alternativeValues: [], measurementSource: .directScan(poses: [pose]))
                )
            } else if let m = metrics(for: pose) {
                let height = ValidatedMeasurement(value: mm(m.height), confidence: 0.7, validationStatus: .estimated, alternativeValues: [], measurementSource: .directScan(poses: [pose]))
                let width = ValidatedMeasurement(value: mm(m.width * 0.5), confidence: 0.6, validationStatus: .estimated, alternativeValues: [], measurementSource: .directScan(poses: [pose]))
                let protrusion = ValidatedMeasurement(value: 40.0, confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["profile bbox"]))
                let topToLobe = ValidatedMeasurement(value: mm(m.height * 0.95), confidence: 0.6, validationStatus: .estimated, alternativeValues: [], measurementSource: .directScan(poses: [pose]))
                return ValidatedEarDimensions(height: height, width: width, protrusionAngle: protrusion, topToLobe: topToLobe)
            } else {
                let fallback = ValidatedMeasurement(value: 60.0, confidence: 0.3, validationStatus: .interpolated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["defaults"]))
                return ValidatedEarDimensions(height: fallback, width: fallback, protrusionAngle: ValidatedMeasurement(value: 40.0, confidence: 0.3, validationStatus: .interpolated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["defaults"])) , topToLobe: fallback)
            }
        }

        let leftEar = earDimensions(for: .leftProfile)
        let rightEar = earDimensions(for: .rightProfile)

        // Neck curve radius (very approximate from depth extent)
        let neckCurveRadiusVM: ValidatedMeasurement = {
            if let o = overall {
                return ValidatedMeasurement(value: mm(o.depth * 0.4), confidence: 0.5, validationStatus: .estimated, alternativeValues: [], measurementSource: .directScan(poses: Array(scans.keys)))
            } else {
                return ValidatedMeasurement(value: 9.0, confidence: 0.3, validationStatus: .interpolated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["defaults"]))
            }
        }()

        // Forehead-to-neck base (front-to-back) from overall depth
        let foreheadToNeckBaseVM: ValidatedMeasurement = {
            if let o = overall {
                return ValidatedMeasurement(value: mm(o.depth), confidence: 0.6, validationStatus: .estimated, alternativeValues: [], measurementSource: .directScan(poses: Array(scans.keys)))
            } else {
                return ValidatedMeasurement(value: 190.0, confidence: 0.3, validationStatus: .interpolated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["defaults"]))
            }
        }()

        // Ear asymmetry factor (relative difference of heights)
        let leftH = leftEar.height.value
        let rightH = rightEar.height.value
        let asymmetry: Float = {
            let denom = max(leftH, rightH)
            return denom > 0 ? abs(leftH - rightH) / denom : 0
        }()

        // Jaw line and chin distances (coarse estimates for MVP)
        let jawLineToEarVM = ValidatedMeasurement(value: 100.0, confidence: 0.4, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["defaults"]))
        let chinToEarDistanceVM = ValidatedMeasurement(value: 110.0, confidence: 0.4, validationStatus: .estimated, alternativeValues: [], measurementSource: .statisticalEstimation(basedOn: ["defaults"]))

        return ScrumCapMeasurements(
            headCircumference: headCircVM,
            earToEarOverTop: headCircVM, // placeholder tie-in until specific over-top path is computed
            foreheadToNeckBase: foreheadToNeckBaseVM,
            leftEarDimensions: leftEar,
            rightEarDimensions: rightEar,
            earAsymmetryFactor: asymmetry,
            occipitalProminence: occipitalProminenceVM,
            neckCurveRadius: neckCurveRadiusVM,
            backHeadWidth: backHeadWidthVM,
            jawLineToEar: jawLineToEarVM,
            chinToEarDistance: chinToEarDistanceVM
        )
    }
}

// Backward-compatible alias so call sites using the old name still compile
typealias MeasurementCalculator = RugbyMeasurementCalculator

// MARK: - Horizontal slice helpers

private extension MeasurementCalculator {
    struct SliceData { let width: Float; let depth: Float; let points2D: [SIMD2<Float>] }
    struct FusedAggregate { let totalPoints: Int; let minX: Float; let minY: Float; let minZ: Float; let maxX: Float; let maxY: Float; let maxZ: Float; let centerX: Float; let centerY: Float; let centerZ: Float; var width: Float { maxX - minX }; var height: Float { maxY - minY }; var depth: Float { maxZ - minZ } }

    static func computeHorizontalSlice(scans: [HeadScanningPose: ScanResult], bandHalfThickness: Float = 0.015) -> SliceData? {
        // Average center Y across available clouds
        var centersY: [Float] = []
        for (_, r) in scans { if let c = r.pointCloud { centersY.append(c.centerOfMass().y) } }
        guard !centersY.isEmpty else { return nil }
        let centerY = centersY.reduce(0, +) / Float(centersY.count)

        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        var found = false
        var points2D: [SIMD2<Float>] = []

        for (_, result) in scans {
            guard let cloud = result.pointCloud else { continue }
            let data = cloud.pointsData as Data
            let stride = SCPointCloud.pointStride()
            let posOffset = SCPointCloud.positionOffset()
            let compSize = SCPointCloud.positionComponentSize()
            let count = Int(cloud.pointCount)

            data.withUnsafeBytes { rawBuf in
                guard let base = rawBuf.baseAddress else { return }
                for i in 0..<count {
                    let offset = i * Int(stride) + Int(posOffset)
                    let px = base.advanced(by: offset + 0 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee
                    let py = base.advanced(by: offset + 1 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee
                    let pz = base.advanced(by: offset + 2 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee

                    if abs(py - centerY) <= bandHalfThickness {
                        found = true
                        if px < minX { minX = px }
                        if px > maxX { maxX = px }
                        if pz < minZ { minZ = pz }
                        if pz > maxZ { maxZ = pz }
                        points2D.append(SIMD2<Float>(px, pz))
                    }
                }
            }
        }
        guard found else { return nil }
        return SliceData(width: maxX - minX, depth: maxZ - minZ, points2D: points2D)
    }

    // Fused horizontal slice: uses ICP-aligned union of all pose clouds without creating a new cloud
    static func computeHorizontalSliceFused(scans: [HeadScanningPose: ScanResult], bandHalfThickness: Float = 0.015) -> SliceData? {
        // Estimate center using reference cloud center
        guard let fused = RugbyHeadScanFusion.estimateTransforms(scans) else { return nil }
        let centerY = fused.referenceCloud.centerOfMass().y
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        var found = false
        var points2D: [SIMD2<Float>] = []

        RugbyHeadScanFusion.enumerateFusedPoints(scans: scans) { p in
            if abs(p.y - centerY) <= bandHalfThickness {
                found = true
                if p.x < minX { minX = p.x }
                if p.x > maxX { maxX = p.x }
                if p.z < minZ { minZ = p.z }
                if p.z > maxZ { maxZ = p.z }
                points2D.append(SIMD2<Float>(p.x, p.z))
            }
        }
        guard found else { return nil }
        return SliceData(width: maxX - minX, depth: maxZ - minZ, points2D: points2D)
    }

    static func fusedAggregate(scans: [HeadScanningPose: ScanResult]) -> FusedAggregate? {
        // Center from reference cloud to avoid bias from sparsity
        guard let fused = RugbyHeadScanFusion.estimateTransforms(scans) else { return nil }
        var minX = Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        var count = 0
        var sumX: Float = 0
        var sumY: Float = 0
        var sumZ: Float = 0
        RugbyHeadScanFusion.enumerateFusedPoints(scans: scans) { p in
            count += 1
            sumX += p.x; sumY += p.y; sumZ += p.z
            if p.x < minX { minX = p.x }
            if p.y < minY { minY = p.y }
            if p.z < minZ { minZ = p.z }
            if p.x > maxX { maxX = p.x }
            if p.y > maxY { maxY = p.y }
            if p.z > maxZ { maxZ = p.z }
        }
        guard count > 0 else { return nil }
        let cx = sumX / Float(count)
        let cy = sumY / Float(count)
        let cz = sumZ / Float(count)
        return FusedAggregate(totalPoints: count, minX: minX, minY: minY, minZ: minZ, maxX: maxX, maxY: maxY, maxZ: maxZ, centerX: cx, centerY: cy, centerZ: cz)
    }

    static func computeHorizontalSliceOfCloud(_ cloud: SCPointCloud, bandHalfThickness: Float = 0.015) -> SliceData? {
        let centerY = cloud.centerOfMass().y
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        var found = false
        var points2D: [SIMD2<Float>] = []
        let data = cloud.pointsData as Data
        let stride = SCPointCloud.pointStride()
        let posOffset = SCPointCloud.positionOffset()
        let compSize = SCPointCloud.positionComponentSize()
        let count = Int(cloud.pointCount)
        data.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.baseAddress else { return }
            for i in 0..<count {
                let offset = i * Int(stride) + Int(posOffset)
                let px = base.advanced(by: offset + 0 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee
                let py = base.advanced(by: offset + 1 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee
                let pz = base.advanced(by: offset + 2 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee
                if abs(py - centerY) <= bandHalfThickness {
                    found = true
                    if px < minX { minX = px }
                    if px > maxX { maxX = px }
                    if pz < minZ { minZ = pz }
                    if pz > maxZ { maxZ = pz }
                    points2D.append(SIMD2<Float>(px, pz))
                }
            }
        }
        guard found else { return nil }
        return SliceData(width: maxX - minX, depth: maxZ - minZ, points2D: points2D)
    }

    // Compute convex hull (Graham scan) perimeter of 2D points
    static func convexHullPerimeter(_ points: [SIMD2<Float>]) -> Float {
        guard points.count >= 3 else { return 0 }
        // Sort points by y, then x
        let pts = points.sorted { (a, b) in (a.y == b.y) ? (a.x < b.x) : (a.y < b.y) }
        var lower: [SIMD2<Float>] = []
        for p in pts {
            while lower.count >= 2 && cross(lower[lower.count-2], lower[lower.count-1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        var upper: [SIMD2<Float>] = []
        for p in pts.reversed() {
            while upper.count >= 2 && cross(upper[upper.count-2], upper[upper.count-1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        var hull = lower
        hull.removeLast()
        var upp = upper
        upp.removeLast()
        hull.append(contentsOf: upp)
        guard hull.count >= 2 else { return 0 }
        var perim: Float = 0
        for i in 0..<hull.count {
            let a = hull[i]
            let b = hull[(i+1) % hull.count]
            perim += distance(a, b)
        }
        return perim
    }

    static func cross(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Float {
        let ab = SIMD2<Float>(b.x - a.x, b.y - a.y)
        let ac = SIMD2<Float>(c.x - a.x, c.y - a.y)
        return ab.x * ac.y - ab.y * ac.x
    }
}
