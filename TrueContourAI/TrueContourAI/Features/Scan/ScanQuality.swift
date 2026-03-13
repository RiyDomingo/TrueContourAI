import Foundation
import UIKit
import StandardCyborgFusion

struct ScanQuality {
    let title: String
    let color: UIColor
    let tip: String
}

enum ScanRecoveryAdvice: Equatable {
    case improveLighting
    case reduceMovement
    case adjustDistance
    case rescanSlowly

    var message: String {
        switch self {
        case .improveLighting:
            return L("scan.quality.advice.improveLighting")
        case .reduceMovement:
            return L("scan.quality.advice.reduceMovement")
        case .adjustDistance:
            return L("scan.quality.advice.adjustDistance")
        case .rescanSlowly:
            return L("scan.quality.advice.rescanSlowly")
        }
    }
}

struct ScanQualityReport: Equatable {
    let pointCount: Int
    let validPointCount: Int
    let widthMeters: Float
    let heightMeters: Float
    let depthMeters: Float
    let qualityScore: Float
    let isExportRecommended: Bool
    let advice: ScanRecoveryAdvice
    let reason: String
}

enum ScanQualityValidator {
    struct ValidationConfig {
        let gateEnabled: Bool
        let minValidPoints: Int
        let minValidRatio: Float
        let minQualityScore: Float
        let minHeadDimensionMeters: Float
        let maxHeadDimensionMeters: Float

        static let `default` = ValidationConfig(
            gateEnabled: SettingsStore.ScanQualityConfig.default.gateEnabled,
            minValidPoints: SettingsStore.ScanQualityConfig.default.minValidPoints,
            minValidRatio: SettingsStore.ScanQualityConfig.default.minValidRatio,
            minQualityScore: SettingsStore.ScanQualityConfig.default.minQualityScore,
            minHeadDimensionMeters: SettingsStore.ScanQualityConfig.default.minHeadDimensionMeters,
            maxHeadDimensionMeters: SettingsStore.ScanQualityConfig.default.maxHeadDimensionMeters
        )
    }

    static func evaluate(pointCloud: SCPointCloud, config: ValidationConfig = .default) -> ScanQualityReport {
        let rawCount = Int(pointCloud.pointCount)
        guard rawCount > 0 else { return noPointsReport() }

        let stride = Int(SCPointCloud.pointStride())
        let posOffset = Int(SCPointCloud.positionOffset())
        let compSize = Int(SCPointCloud.positionComponentSize())
        if stride <= 0 || posOffset < 0 || compSize <= 0 {
            return invalidFormatReport(rawCount: rawCount)
        }

        var minX = Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        var validCount = 0

        let data = pointCloud.pointsData as Data
        let expectedSize = rawCount * stride
        guard data.count >= expectedSize else {
            return incompleteDataReport(rawCount: rawCount)
        }

        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            for i in 0..<rawCount {
                let offset = i * stride + posOffset
                if offset + 3 * compSize > data.count { break }
                let px = base.advanced(by: offset).assumingMemoryBound(to: Float.self).pointee
                let py = base.advanced(by: offset + compSize).assumingMemoryBound(to: Float.self).pointee
                let pz = base.advanced(by: offset + 2 * compSize).assumingMemoryBound(to: Float.self).pointee

                if !px.isFinite || !py.isFinite || !pz.isFinite { continue }
                if abs(px) > 10 || abs(py) > 10 || abs(pz) > 10 { continue }

                minX = min(minX, px)
                minY = min(minY, py)
                minZ = min(minZ, pz)
                maxX = max(maxX, px)
                maxY = max(maxY, py)
                maxZ = max(maxZ, pz)
                validCount += 1
            }
        }

        return report(
            rawCount: rawCount,
            validCount: validCount,
            minX: minX,
            minY: minY,
            minZ: minZ,
            maxX: maxX,
            maxY: maxY,
            maxZ: maxZ,
            config: config
        )
    }

    #if DEBUG
    static func debug_evaluate(
        rawCount: Int,
        validPositions: [SIMD3<Float>],
        config: ValidationConfig = .default
    ) -> ScanQualityReport {
        guard rawCount > 0 else { return noPointsReport() }
        guard !validPositions.isEmpty else { return invalidPointsReport(rawCount: rawCount) }

        var minX = Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude

        for p in validPositions {
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            minZ = min(minZ, p.z)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
            maxZ = max(maxZ, p.z)
        }

        return report(
            rawCount: rawCount,
            validCount: validPositions.count,
            minX: minX,
            minY: minY,
            minZ: minZ,
            maxX: maxX,
            maxY: maxY,
            maxZ: maxZ,
            config: config
        )
    }

    static func debug_evaluateDataLayout(
        rawCount: Int,
        stride: Int,
        positionOffset: Int,
        componentSize: Int,
        dataSize: Int,
        config: ValidationConfig = .default
    ) -> ScanQualityReport {
        guard rawCount > 0 else { return noPointsReport() }
        if stride <= 0 || positionOffset < 0 || componentSize <= 0 {
            return invalidFormatReport(rawCount: rawCount)
        }
        let expectedSize = rawCount * stride
        if dataSize < expectedSize {
            return incompleteDataReport(rawCount: rawCount)
        }
        return invalidPointsReport(rawCount: rawCount)
    }
    #endif

    private static func report(
        rawCount: Int,
        validCount: Int,
        minX: Float,
        minY: Float,
        minZ: Float,
        maxX: Float,
        maxY: Float,
        maxZ: Float,
        config: ValidationConfig
    ) -> ScanQualityReport {
        guard validCount > 0 else { return invalidPointsReport(rawCount: rawCount) }

        let width = max(0, maxX - minX)
        let height = max(0, maxY - minY)
        let depth = max(0, maxZ - minZ)
        let validRatio = Float(validCount) / Float(max(1, rawCount))
        let countScore = clamp(Float(validCount) / 180_000)
        let ratioScore = clamp(validRatio)
        let dimensionsReasonable = (config.minHeadDimensionMeters...config.maxHeadDimensionMeters).contains(width) &&
            (config.minHeadDimensionMeters...config.maxHeadDimensionMeters).contains(height) &&
            (config.minHeadDimensionMeters...config.maxHeadDimensionMeters).contains(depth)
        let dimensionScore: Float = dimensionsReasonable ? 1 : 0.35
        let qualityScore = clamp((countScore * 0.5) + (ratioScore * 0.3) + (dimensionScore * 0.2))

        let advice: ScanRecoveryAdvice
        let reason: String
        var exportable: Bool
        if validCount < config.minValidPoints {
            advice = .improveLighting
            reason = L("scan.quality.reason.lowCoverage")
            exportable = false
        } else if validRatio < config.minValidRatio {
            advice = .reduceMovement
            reason = L("scan.quality.reason.noisyPoints")
            exportable = false
        } else if !dimensionsReasonable {
            advice = .adjustDistance
            reason = L("scan.quality.reason.badBounds")
            exportable = false
        } else if qualityScore < config.minQualityScore {
            advice = .rescanSlowly
            reason = L("scan.quality.reason.lowScore")
            exportable = false
        } else {
            advice = .rescanSlowly
            reason = L("scan.quality.reason.acceptable")
            exportable = true
        }

        if !config.gateEnabled {
            exportable = true
        }

        return ScanQualityReport(
            pointCount: rawCount,
            validPointCount: validCount,
            widthMeters: width,
            heightMeters: height,
            depthMeters: depth,
            qualityScore: qualityScore,
            isExportRecommended: exportable,
            advice: advice,
            reason: reason
        )
    }

    private static func noPointsReport() -> ScanQualityReport {
        ScanQualityReport(
            pointCount: 0,
            validPointCount: 0,
            widthMeters: 0,
            heightMeters: 0,
            depthMeters: 0,
            qualityScore: 0,
            isExportRecommended: false,
            advice: .rescanSlowly,
            reason: L("scan.quality.reason.noPoints")
        )
    }

    private static func invalidFormatReport(rawCount: Int) -> ScanQualityReport {
        ScanQualityReport(
            pointCount: rawCount,
            validPointCount: 0,
            widthMeters: 0,
            heightMeters: 0,
            depthMeters: 0,
            qualityScore: 0,
            isExportRecommended: false,
            advice: .rescanSlowly,
            reason: L("scan.quality.reason.invalidFormat")
        )
    }

    private static func incompleteDataReport(rawCount: Int) -> ScanQualityReport {
        ScanQualityReport(
            pointCount: rawCount,
            validPointCount: 0,
            widthMeters: 0,
            heightMeters: 0,
            depthMeters: 0,
            qualityScore: 0,
            isExportRecommended: false,
            advice: .rescanSlowly,
            reason: L("scan.quality.reason.incompleteData")
        )
    }

    private static func invalidPointsReport(rawCount: Int) -> ScanQualityReport {
        ScanQualityReport(
            pointCount: rawCount,
            validPointCount: 0,
            widthMeters: 0,
            heightMeters: 0,
            depthMeters: 0,
            qualityScore: 0,
            isExportRecommended: false,
            advice: .rescanSlowly,
            reason: L("scan.quality.reason.invalidPoints")
        )
    }

    private static func clamp(_ value: Float) -> Float {
        max(0, min(1, value))
    }
}
