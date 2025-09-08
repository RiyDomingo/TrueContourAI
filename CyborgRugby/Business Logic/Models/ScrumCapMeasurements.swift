//
//  ScrumCapMeasurements.swift
//  CyborgRugby
//
//  Rugby scrum cap measurement models with ML validation
//

import Foundation
import CoreML

// MARK: - Validated Measurement System

struct ValidatedMeasurement {
    let value: Float
    let confidence: Float        // 0.0 to 1.0
    let validationStatus: ValidationStatus
    let alternativeValues: [Float]  // If confidence is low
    let measurementSource: MeasurementSource
    
    enum ValidationStatus {
        case validated      // High confidence, cross-verified
        case estimated     // Medium confidence, single source
        case interpolated  // Low confidence, calculated from other measurements
        case failed        // Measurement could not be obtained
        
        var description: String {
            switch self {
            case .validated: return "Validated"
            case .estimated: return "Estimated"
            case .interpolated: return "Interpolated"
            case .failed: return "Failed"
            }
        }
        
        var isReliable: Bool {
            switch self {
            case .validated, .estimated: return true
            case .interpolated, .failed: return false
            }
        }
    }
    
    enum MeasurementSource {
        case directScan(poses: [HeadScanningPose])
        case mlModel(modelName: String, confidence: Float)
        case statisticalEstimation(basedOn: [String])
        case userInput(verified: Bool)
        
        var description: String {
            switch self {
            case .directScan(let poses):
                return "Direct scan from \(poses.count) poses"
            case .mlModel(let name, let conf):
                return "ML Model: \(name) (conf: \(String(format: "%.1f", conf * 100))%)"
            case .statisticalEstimation(let factors):
                return "Estimated from \(factors.joined(separator: ", "))"
            case .userInput(let verified):
                return "User input\(verified ? " (verified)" : "")"
            }
        }
    }
    
    var isHighQuality: Bool {
        return confidence > 0.8 && validationStatus.isReliable
    }
    
    var qualityDescription: String {
        switch (confidence, validationStatus) {
        case (0.9..., .validated):
            return "Excellent"
        case (0.8..., .validated), (0.9..., .estimated):
            return "Very Good"
        case (0.7..., _), (0.8..., .estimated):
            return "Good"
        case (0.6..., _):
            return "Fair"
        default:
            return "Poor"
        }
    }
}

// MARK: - Ear Dimensions with ML Validation

struct ValidatedEarDimensions {
    let height: ValidatedMeasurement          // Ear height (mm)
    let width: ValidatedMeasurement           // Ear width (mm)
    let protrusionAngle: ValidatedMeasurement // How much ear sticks out (degrees)
    let topToLobe: ValidatedMeasurement       // Ear length (mm)
    
    var overallConfidence: Float {
        let confidences = [height.confidence, width.confidence, 
                          protrusionAngle.confidence, topToLobe.confidence]
        return confidences.reduce(0, +) / Float(confidences.count)
    }
    
    var isReliable: Bool {
        return overallConfidence > 0.7 && 
               height.validationStatus.isReliable &&
               width.validationStatus.isReliable
    }
    
    // Rugby-specific ear protection calculations
    var requiredPaddingThickness: Float {
        // Base padding + adjustment for protrusion
        let basePadding: Float = 8.0 // mm
        let protrusionAdjustment: Float = protrusionAngle.value > 45.0 ? 3.0 : 0.0
        return basePadding + protrusionAdjustment
    }
    
    var protectionZones: [ProtectionZone] {
        return [
            ProtectionZone(
                area: .earCanal,
                priority: .critical,
                thickness: requiredPaddingThickness,
                coverage: calculateCanalCoverage()
            ),
            ProtectionZone(
                area: .earLobe,
                priority: .important,
                thickness: requiredPaddingThickness * 0.7,
                coverage: calculateLobeCoverage()
            ),
            ProtectionZone(
                area: .upperEar,
                priority: .important,
                thickness: requiredPaddingThickness * 0.8,
                coverage: calculateUpperEarCoverage()
            )
        ]
    }
    
    private func calculateCanalCoverage() -> Float {
        // Critical area around ear canal
        return min(width.value * 0.6, 15.0) // Max 15mm coverage
    }
    
    private func calculateLobeCoverage() -> Float {
        // Ear lobe protection area
        return min(height.value * 0.3, 12.0) // Max 12mm coverage
    }
    
    private func calculateUpperEarCoverage() -> Float {
        // Upper ear cartilage protection
        return min(height.value * 0.4, 18.0) // Max 18mm coverage
    }
}

// MARK: - Protection Zone Definition

struct ProtectionZone {
    let area: EarArea
    let priority: ProtectionPriority
    let thickness: Float      // Padding thickness in mm
    let coverage: Float       // Coverage area in mm
    
    enum EarArea: String, CaseIterable {
        case earCanal = "ear_canal"
        case earLobe = "ear_lobe"  
        case upperEar = "upper_ear"
        case earEdge = "ear_edge"
        
        var displayName: String {
            switch self {
            case .earCanal: return "Ear Canal"
            case .earLobe: return "Ear Lobe"
            case .upperEar: return "Upper Ear"
            case .earEdge: return "Ear Edge"
            }
        }
        
        var rugbyVulnerability: Float {
            switch self {
            case .earCanal: return 1.0      // Most vulnerable in scrums
            case .upperEar: return 0.9      // High contact area
            case .earEdge: return 0.8       // Prone to cuts
            case .earLobe: return 0.6       // Less vulnerable but still needs protection
            }
        }
    }
}

enum ProtectionPriority: Int, CaseIterable {
    case critical = 3    // Must be protected (ear canal, cartilage edges)
    case important = 2   // Should be protected (ear lobe, upper ear)
    case optional = 1    // Nice to protect (general ear surface)
    
    var description: String {
        switch self {
        case .critical: return "Critical"
        case .important: return "Important"
        case .optional: return "Optional"
        }
    }
    
    var color: String {
        switch self {
        case .critical: return "systemRed"
        case .important: return "systemOrange"
        case .optional: return "systemYellow"
        }
    }
}

// MARK: - Complete Scrum Cap Measurements

struct ScrumCapMeasurements {
    // Basic head dimensions with validation
    let headCircumference: ValidatedMeasurement    // Around temples/forehead (mm)
    let earToEarOverTop: ValidatedMeasurement     // Over-head ear-to-ear distance (mm)
    let foreheadToNeckBase: ValidatedMeasurement  // Front-to-back coverage needed (mm)
    
    // Ear protection specific with asymmetry handling
    let leftEarDimensions: ValidatedEarDimensions
    let rightEarDimensions: ValidatedEarDimensions
    let earAsymmetryFactor: Float                 // 0.0 = perfectly symmetric, 1.0 = very asymmetric
    
    // Back of head coverage with confidence
    let occipitalProminence: ValidatedMeasurement // Back of head bump (mm)
    let neckCurveRadius: ValidatedMeasurement     // Curve where head meets neck (mm)
    let backHeadWidth: ValidatedMeasurement       // Width at back of head (mm)
    
    // Chin strap positioning
    let jawLineToEar: ValidatedMeasurement        // Chin strap path (mm)
    let chinToEarDistance: ValidatedMeasurement   // Each side (mm)
    
    // Measurement quality metrics
    var overallConfidence: Float {
        let criticalMeasurements = [
            headCircumference.confidence,
            leftEarDimensions.overallConfidence,
            rightEarDimensions.overallConfidence,
            occipitalProminence.confidence
        ]
        return criticalMeasurements.reduce(0, +) / Float(criticalMeasurements.count)
    }
    
    var criticalMeasurementsValid: Bool {
        return headCircumference.confidence > 0.8 &&
               leftEarDimensions.overallConfidence > 0.7 &&
               rightEarDimensions.overallConfidence > 0.7 &&
               occipitalProminence.confidence > 0.6
    }
    
    var measurementQuality: MeasurementQuality {
        switch overallConfidence {
        case 0.9...: return .excellent
        case 0.8..<0.9: return .veryGood
        case 0.7..<0.8: return .good
        case 0.6..<0.7: return .fair
        default: return .poor
        }
    }
    
    // Rugby-specific calculations
    var recommendedSize: ScrumCapSize {
        return ScrumCapSizeCalculator.calculate(from: self)
    }
    
    var headShapeClassification: HeadShape {
        return HeadShapeClassifier.classify(self)
    }
    
    var asymmetryLevel: AsymmetryLevel {
        return AsymmetryAnalyzer.analyze(leftEarDimensions, rightEarDimensions)
    }
    
    // Protection analysis
    var allProtectionZones: [ProtectionZone] {
        return leftEarDimensions.protectionZones + rightEarDimensions.protectionZones
    }
    
    var criticalProtectionZones: [ProtectionZone] {
        return allProtectionZones.filter { $0.priority == .critical }
    }
    
    // Validation methods
    func validate() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check head circumference plausibility
        if headCircumference.value < 48.0 || headCircumference.value > 67.0 {
            issues.append(.unusualHeadSize(headCircumference.value))
        }
        
        // Check ear asymmetry
        if earAsymmetryFactor > 0.3 {
            issues.append(.significantAsymmetry(earAsymmetryFactor))
        }
        
        // Check measurement quality
        if !criticalMeasurementsValid {
            issues.append(.lowMeasurementQuality(overallConfidence))
        }
        
        // Check missing data
        if occipitalProminence.validationStatus == .failed {
            issues.append(.missingBackHeadData)
        }
        
        return issues
    }
}

// MARK: - Supporting Enums and Types

enum MeasurementQuality: String, CaseIterable {
    case excellent = "excellent"
    case veryGood = "very_good"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .veryGood: return "Very Good"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "systemGreen"
        case .veryGood: return "systemBlue"
        case .good: return "systemYellow"
        case .fair: return "systemOrange"
        case .poor: return "systemRed"
        }
    }
}

enum ValidationIssue: Equatable {
    case unusualHeadSize(Float)
    case significantAsymmetry(Float)
    case lowMeasurementQuality(Float)
    case missingBackHeadData
    case mlModelFailed(String)
    
    var description: String {
        switch self {
        case .unusualHeadSize(let size):
            return "Unusual head circumference: \(String(format: "%.1f", size))cm"
        case .significantAsymmetry(let factor):
            return "Significant ear asymmetry detected: \(String(format: "%.1f", factor * 100))%"
        case .lowMeasurementQuality(let quality):
            return "Low measurement quality: \(String(format: "%.1f", quality * 100))%"
        case .missingBackHeadData:
            return "Back of head data could not be captured"
        case .mlModelFailed(let model):
            return "ML model failed: \(model)"
        }
    }
    
    var severity: Severity {
        switch self {
        case .unusualHeadSize, .missingBackHeadData:
            return .high
        case .significantAsymmetry, .lowMeasurementQuality:
            return .medium
        case .mlModelFailed:
            return .low
        }
    }
    
    enum Severity {
        case low, medium, high
        
        var color: String {
            switch self {
            case .low: return "systemYellow"
            case .medium: return "systemOrange"
            case .high: return "systemRed"
            }
        }
    }
}

// MARK: - Size and Shape Classifications

enum ScrumCapSize: String, CaseIterable, Comparable {
    case youth = "Youth"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "XL"
    case doubleXL = "XXL"
    
    var circumferenceRange: ClosedRange<Float> {
        switch self {
        case .youth: return 48.0...52.0
        case .small: return 51.0...55.0
        case .medium: return 54.0...58.0
        case .large: return 57.0...61.0
        case .extraLarge: return 60.0...64.0
        case .doubleXL: return 63.0...67.0
        }
    }
    
    static func < (lhs: ScrumCapSize, rhs: ScrumCapSize) -> Bool {
        return lhs.circumferenceRange.lowerBound < rhs.circumferenceRange.lowerBound
    }
}

enum HeadShape: String, CaseIterable {
    case round = "round"
    case oval = "oval"
    case long = "long"
    case square = "square"
    case unusual = "unusual"
    
    var description: String {
        switch self {
        case .round: return "Round"
        case .oval: return "Oval"
        case .long: return "Long"
        case .square: return "Square"
        case .unusual: return "Unusual"
        }
    }
    
    var fittingAdvice: String {
        switch self {
        case .round:
            return "Round head shape typically fits standard scrum caps well"
        case .oval:
            return "Oval head shape may need slightly longer cap design"
        case .long:
            return "Long head shape benefits from extended front-to-back coverage"
        case .square:
            return "Square head shape may need additional temple padding"
        case .unusual:
            return "Unusual head shape may require custom fitting adjustments"
        }
    }
}

enum AsymmetryLevel: String, CaseIterable {
    case minimal = "minimal"
    case moderate = "moderate"
    case significant = "significant"
    
    var description: String {
        switch self {
        case .minimal: return "Minimal asymmetry"
        case .moderate: return "Moderate asymmetry"
        case .significant: return "Significant asymmetry"
        }
    }
    
    var fittingImpact: String {
        switch self {
        case .minimal:
            return "Standard padding configuration will work well"
        case .moderate:
            return "May benefit from slightly different padding on each side"
        case .significant:
            return "Requires custom padding configuration for each ear"
        }
    }
}

// MARK: - Helper Classes (Forward Declarations)

class ScrumCapSizeCalculator {
    static func calculate(from measurements: ScrumCapMeasurements) -> ScrumCapSize {
        // Base size from head circumference (cm)
        let headCM = measurements.headCircumference.value
        var base: ScrumCapSize = .medium
        for size in ScrumCapSize.allCases.sorted() {
            if size.circumferenceRange.contains(headCM) { base = size; break }
        }

        // Adjustments
        // Ear protrusion: upsize if ears stick out notably
        let leftProt = measurements.leftEarDimensions.protrusionAngle.value
        let rightProt = measurements.rightEarDimensions.protrusionAngle.value
        let avgProt = (leftProt + rightProt) / 2.0

        // Back head prominence: upsize if occipital bump is pronounced
        let occMM = measurements.occipitalProminence.value

        var adjusted = base
        func upsize(_ s: ScrumCapSize) -> ScrumCapSize {
            switch s {
            case .youth: return .small
            case .small: return .medium
            case .medium: return .large
            case .large: return .extraLarge
            case .extraLarge: return .doubleXL
            case .doubleXL: return .doubleXL
            }
        }

        if avgProt > 55.0 { adjusted = upsize(adjusted) }
        else if avgProt > 45.0 && headCM >= adjusted.circumferenceRange.upperBound - 0.5 {
            adjusted = upsize(adjusted)
        }

        if occMM > 18.0 && headCM >= adjusted.circumferenceRange.lowerBound {
            adjusted = upsize(adjusted)
        }

        return adjusted
    }
}

class HeadShapeClassifier {
    static func classify(_ measurements: ScrumCapMeasurements) -> HeadShape {
        let width = measurements.backHeadWidth.value // mm
        let depth = measurements.foreheadToNeckBase.value // mm
        guard width > 0, depth > 0 else { return .unusual }
        let ratio = depth / max(width, 1)

        // Heuristics
        if ratio < 0.9 { return .square }            // wider than deep
        if ratio <= 1.1 { return .round }            // roughly equal
        if ratio <= 1.3 { return .oval }             // mildly deeper
        if ratio > 1.3 { return .long }              // significantly deeper
        return .oval
    }
}

class AsymmetryAnalyzer {
    static func analyze(_ left: ValidatedEarDimensions, _ right: ValidatedEarDimensions) -> AsymmetryLevel {
        func relDelta(_ a: Float, _ b: Float) -> Float {
            let denom = max((a + b) / 2.0, 1e-5)
            return abs(a - b) / denom
        }

        let h = relDelta(left.height.value, right.height.value)
        let w = relDelta(left.width.value, right.width.value)
        let t = relDelta(left.topToLobe.value, right.topToLobe.value)
        let combined = (h + w + t) / 3.0

        switch combined {
        case ..<0.10: return .minimal
        case 0.10..<0.20: return .moderate
        default: return .significant
        }
    }
}
