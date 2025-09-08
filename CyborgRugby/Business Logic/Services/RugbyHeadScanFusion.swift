//
//  RugbyHeadScanFusion.swift
//  CyborgRugby
//
//  Placeholder fusion: selects the densest point cloud.
//  Phase 2: replace with ICP registration (scsdk) and merge.
//

import Foundation
import simd
import StandardCyborgFusion
import OSLog

struct RugbyHeadScanFusion {
    private static let log = OSSignposter(subsystem: "com.standardcyborg.CyborgRugby", category: "fusion")
    struct FusedModel {
        let referencePose: HeadScanningPose
        let referenceCloud: SCPointCloud
        let transforms: [HeadScanningPose: simd_float4x4] // transform from pose -> reference frame
    }

    /// Chooses the densest cloud as reference and estimates rigid transforms from every other cloud to the reference using ICP
    static func estimateTransforms(_ scans: [HeadScanningPose: ScanResult],
                                   maxIterations: Int = 30,
                                   tolerance: Float = 1e-4,
                                   outlierDeviationsThreshold: Float = 1.0,
                                   threadCount: Int = 2) -> FusedModel? {
        // Pick reference (densest)
        var refPose: HeadScanningPose?
        var refCloud: SCPointCloud?
        var maxPts = -1
        for (pose, result) in scans {
            guard let cloud = result.pointCloud else { continue }
            let c = Int(cloud.pointCount)
            if c > maxPts { maxPts = c; refPose = pose; refCloud = cloud }
        }
        guard let referencePose = refPose, let referenceCloud = refCloud else { return nil }

        var transforms: [HeadScanningPose: simd_float4x4] = [:]
        transforms[referencePose] = matrix_identity_float4x4
        for (pose, result) in scans {
            guard pose != referencePose, let cloud = result.pointCloud else { continue }
            var transform = matrix_identity_float4x4
            let ok = RugbyICPBridge.estimateTransform(from: cloud,
                                                         to: referenceCloud,
                                                         maxIterations: Int32(maxIterations),
                                                         tolerance: tolerance,
                                                         outlierDeviationsThreshold: outlierDeviationsThreshold,
                                                         threadCount: Int32(threadCount),
                                                         outTransform: &transform)
            if ok {
                transforms[pose] = transform
            }
        }
        return FusedModel(referencePose: referencePose, referenceCloud: referenceCloud, transforms: transforms)
    }

    /// Backward compatible single-cloud return (returns the reference cloud)
    static func fuse(_ scans: [HeadScanningPose: ScanResult]) -> SCPointCloud? {
        return estimateTransforms(scans)?.referenceCloud
    }

    /// Enumerate all points across all clouds transformed into the reference frame
    static func enumerateFusedPoints(scans: [HeadScanningPose: ScanResult], body: (SIMD3<Float>) -> Void) {
        guard let fused = estimateTransforms(scans) else { return }
        for (pose, result) in scans {
            guard let cloud = result.pointCloud else { continue }
            let transform = fused.transforms[pose] ?? matrix_identity_float4x4
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
                    let v = SIMD4<Float>(px, py, pz, 1)
                    let t = transform * v
                    body(SIMD3<Float>(t.x, t.y, t.z))
                }
            }
        }
    }

    struct FusionExportOptions {
        var cropBelowNeck: Bool = true
        var neckOffsetMeters: Float = 0.15
        var outlierSigma: Float = 3.0
        var decimateRatio: Float = 1.0
        var preScaleToMillimeters: Bool = false
    }

    /// Writes an ASCII PLY containing all fused points (position only). Returns true on success.
    static func writeFusedPLY(scans: [HeadScanningPose: ScanResult], to url: URL, options: FusionExportOptions = FusionExportOptions()) -> Bool {
        let sp = log.beginInterval("writeFusedPLY")
        // First pass: stats
        var total = 0
        var sumX: Double = 0, sumY: Double = 0, sumZ: Double = 0
        var sumXX: Double = 0, sumYY: Double = 0, sumZZ: Double = 0
        enumerateFusedPoints(scans: scans) { p in
            total += 1
            sumX += Double(p.x); sumY += Double(p.y); sumZ += Double(p.z)
            sumXX += Double(p.x) * Double(p.x)
            sumYY += Double(p.y) * Double(p.y)
            sumZZ += Double(p.z) * Double(p.z)
        }
        guard total > 0 else { return false }
        let meanX = sumX / Double(total), meanY = sumY / Double(total), meanZ = sumZ / Double(total)
        let stdX = max(1e-6, sqrt(max(0, sumXX / Double(total) - meanX * meanX)))
        let stdY = max(1e-6, sqrt(max(0, sumYY / Double(total) - meanY * meanY)))
        let stdZ = max(1e-6, sqrt(max(0, sumZZ / Double(total) - meanZ * meanZ)))

        // Filter + decimate and buffer
        var filtered: [SIMD3<Float>] = []
        filtered.reserveCapacity(total)
        let neckY = options.cropBelowNeck ? Float(meanY) - options.neckOffsetMeters : -Float.greatestFiniteMagnitude
        let sig = options.outlierSigma
        let rngMax: UInt32 = 1_000_000
        enumerateFusedPoints(scans: scans) { p in
            if options.cropBelowNeck && p.y < neckY { return }
            if sig > 0 {
                let dx = abs(Float(Double(p.x) - meanX)) / Float(stdX)
                let dy = abs(Float(Double(p.y) - meanY)) / Float(stdY)
                let dz = abs(Float(Double(p.z) - meanZ)) / Float(stdZ)
                if dx > sig || dy > sig || dz > sig { return }
            }
            if options.decimateRatio < 0.9999 {
                let threshold = UInt32(Float(rngMax) * max(0.0, min(1.0, options.decimateRatio)))
                if arc4random_uniform(rngMax) > threshold { return }
            }
            filtered.append(p)
        }
        guard !filtered.isEmpty else { return false }

        // Header
        var lines: [String] = []
        lines.append("ply")
        lines.append("format ascii 1.0")
        lines.append("element vertex \(filtered.count)")
        lines.append("property float x")
        lines.append("property float y")
        lines.append("property float z")
        lines.append("end_header")
        do {
            let out = lines.joined(separator: "\n") + "\n"
            try out.write(to: url, atomically: true, encoding: .utf8)
            let handle = try FileHandle(forWritingTo: url)
            handle.seekToEndOfFile()
            let scale: Float = options.preScaleToMillimeters ? 1000.0 : 1.0
            for p in filtered {
                let line = String(format: "%f %f %f\n", p.x * scale, p.y * scale, p.z * scale)
                if let data = line.data(using: .utf8) { handle.write(data) }
            }
            try? handle.close()
            log.endInterval("writeFusedPLY", sp)
            return true
        } catch {
            log.endInterval("writeFusedPLY", sp)
            return false
        }
    }
}
