//
//  PointCloudMetrics.swift
//  CyborgRugby
//
//  Enhanced point cloud metrics with proper validation and error handling
//

import Foundation
import StandardCyborgFusion
import OSLog

struct PointCloudMetrics {
    let totalPoints: Int
    let minX: Float
    let minY: Float
    let minZ: Float
    let maxX: Float
    let maxY: Float
    let maxZ: Float

    var width: Float { maxX - minX }
    var height: Float { maxY - minY }
    var depth: Float { maxZ - minZ }
    
    /// Validates the metrics for reasonableness
    var isValid: Bool {
        return totalPoints > 0 && 
               width >= 0 && height >= 0 && depth >= 0 &&
               width.isFinite && height.isFinite && depth.isFinite &&
               minX.isFinite && minY.isFinite && minZ.isFinite &&
               maxX.isFinite && maxY.isFinite && maxZ.isFinite
    }
    
    /// Checks if dimensions are within reasonable bounds for head scanning (in meters)
    var isReasonableForHead: Bool {
        // Reasonable head dimensions: 0.1m to 0.5m in each dimension
        let reasonableRange: ClosedRange<Float> = 0.1...0.5
        return reasonableRange.contains(width) &&
               reasonableRange.contains(height) &&
               reasonableRange.contains(depth)
    }
}

enum PointCloudMetricsCalculator {
    private static let logger = Logger(subsystem: "com.standardcyborg.CyborgRugby", category: "pointcloud")
    
    static func compute(for cloud: SCPointCloud) -> PointCloudMetrics? {
        let count = Int(cloud.pointCount)
        
        // Validate input
        guard count > 0 else {
            logger.warning("Point cloud is empty")
            return nil
        }
        
        guard count <= 1_000_000 else {
            logger.error("Point cloud too large: \(count) points")
            return nil
        }

        let stride = SCPointCloud.pointStride()
        let posOffset = SCPointCloud.positionOffset()
        let compSize = SCPointCloud.positionComponentSize()
        
        // Validate stride and offset parameters
        guard stride > 0 && posOffset >= 0 && compSize > 0 else {
            logger.error("Invalid point cloud format parameters")
            return nil
        }

        var minX = Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        
        var validPointCount = 0

        let data = cloud.pointsData as Data
        
        // Validate data size
        let expectedDataSize = count * Int(stride)
        guard data.count >= expectedDataSize else {
            logger.error("Point cloud data size mismatch: expected \(expectedDataSize), got \(data.count)")
            return nil
        }
        
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                logger.error("Failed to get point cloud data base address")
                return
            }
            
            for i in 0..<count {
                let offset = i * Int(stride) + Int(posOffset)
                
                // Bounds checking
                guard offset + 3 * Int(compSize) <= data.count else {
                    logger.warning("Point \(i) exceeds data bounds, stopping")
                    break
                }
                
                let px = baseAddress.advanced(by: offset + 0 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee
                let py = baseAddress.advanced(by: offset + 1 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee
                let pz = baseAddress.advanced(by: offset + 2 * Int(compSize)).assumingMemoryBound(to: Float.self).pointee
                
                // Validate point coordinates
                guard px.isFinite && py.isFinite && pz.isFinite else {
                    logger.debug("Skipping invalid point \(i): (\(px), \(py), \(pz))")
                    continue
                }
                
                // Reasonable bounds checking (±10 meters)
                guard abs(px) < 10.0 && abs(py) < 10.0 && abs(pz) < 10.0 else {
                    logger.debug("Skipping outlier point \(i): (\(px), \(py), \(pz))")
                    continue
                }

                // Update bounds
                if px < minX { minX = px }
                if py < minY { minY = py }
                if pz < minZ { minZ = pz }
                if px > maxX { maxX = px }
                if py > maxY { maxY = py }
                if pz > maxZ { maxZ = pz }
                
                validPointCount += 1
            }
        }
        
        guard validPointCount > 0 else {
            logger.error("No valid points found in point cloud")
            return nil
        }
        
        let metrics = PointCloudMetrics(
            totalPoints: validPointCount, 
            minX: minX, minY: minY, minZ: minZ, 
            maxX: maxX, maxY: maxY, maxZ: maxZ
        )
        
        // Final validation
        guard metrics.isValid else {
            logger.error("Computed metrics are invalid")
            return nil
        }
        
        if !metrics.isReasonableForHead {
            logger.warning("Point cloud dimensions seem unreasonable for head scanning: \(metrics.width)x\(metrics.height)x\(metrics.depth)m")
        }
        
        logger.info("Computed metrics for \(validPointCount) points: \(metrics.width)x\(metrics.height)x\(metrics.depth)m")
        
        return metrics
    }

    static func aggregate(from results: [HeadScanningPose: ScanResult]) -> PointCloudMetrics? {
        var totalPoints = 0
        var minX = Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        var foundAny = false

        for (pose, result) in results {
            guard let cloud = result.pointCloud else {
                logger.debug("Skipping pose \(pose.displayName) - no point cloud")
                continue
            }
            
            guard let metrics = compute(for: cloud) else {
                logger.warning("Failed to compute metrics for pose \(pose.displayName)")
                continue
            }
            
            foundAny = true
            totalPoints += metrics.totalPoints
            
            if metrics.minX < minX { minX = metrics.minX }
            if metrics.minY < minY { minY = metrics.minY }
            if metrics.minZ < minZ { minZ = metrics.minZ }
            if metrics.maxX > maxX { maxX = metrics.maxX }
            if metrics.maxY > maxY { maxY = metrics.maxY }
            if metrics.maxZ > maxZ { maxZ = metrics.maxZ }
        }

        guard foundAny else {
            logger.warning("No valid point clouds found for aggregation")
            return nil
        }
        
        let aggregated = PointCloudMetrics(
            totalPoints: totalPoints, 
            minX: minX, minY: minY, minZ: minZ, 
            maxX: maxX, maxY: maxY, maxZ: maxZ
        )
        
        logger.info("Aggregated metrics from \(results.count) poses: \(totalPoints) total points, \(aggregated.width)x\(aggregated.height)x\(aggregated.depth)m")
        
        return aggregated.isValid ? aggregated : nil
    }
}
