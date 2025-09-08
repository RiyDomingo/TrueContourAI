//
//  RugbyEarProtectionCalculator.swift
//  CyborgRugby
//
//  Rugby-specific ear protection calculations and scrum cap recommendations
//

import Foundation
import CoreML

class RugbyEarProtectionCalculator {
    private var earLandmarkingModel: MLModel?
    private var earTrackingModel: MLModel?
    
    // Rugby-specific protection standards
    private struct RugbyProtectionStandards {
        static let minimumPaddingThickness: Float = 6.0 // mm
        static let recommendedPaddingThickness: Float = 8.0 // mm
        static let maximumPaddingThickness: Float = 12.0 // mm
        static let criticalProtectionAngle: Float = 45.0 // degrees
        static let minimumCoverageArea: Float = 20.0 // square mm
    }
    
    init() {
        loadMLModels()
    }
    
    private func loadMLModels() {
        func loadModel(named name: String) -> MLModel? {
            if let compiledURL = Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
               let compiled = try? MLModel(contentsOf: compiledURL) { return compiled }
            if let srcURL = Bundle.main.url(forResource: name, withExtension: "mlmodel"),
               let compiledAtRuntime = try? MLModel.compileModel(at: srcURL),
               let compiled = try? MLModel(contentsOf: compiledAtRuntime) { return compiled }
            return nil
        }
        earLandmarkingModel = loadModel(named: "SCEarLandmarking")
        earTrackingModel = loadModel(named: "SCEarTrackingModel")
        if earLandmarkingModel == nil || earTrackingModel == nil {
            print("⚠️ Ear protection ML models not fully initialized")
        }
    }
    
    // MARK: - Main Protection Analysis
    
    func calculateEarProtection(from measurements: ScrumCapMeasurements) -> EarProtectionAnalysis {
        let leftAnalysis = analyzeEarProtection(measurements.leftEarDimensions, side: .left)
        let rightAnalysis = analyzeEarProtection(measurements.rightEarDimensions, side: .right)
        
        return EarProtectionAnalysis(
            leftEar: leftAnalysis,
            rightEar: rightAnalysis,
            asymmetryFactor: measurements.earAsymmetryFactor,
            overallRisk: calculateOverallRisk(left: leftAnalysis, right: rightAnalysis),
            recommendedScrumCapType: determineScrumCapType(measurements),
            customizationNeeded: determineCustomizationNeeds(measurements),
            protectionEffectiveness: calculateProtectionEffectiveness(left: leftAnalysis, right: rightAnalysis)
        )
    }
    
    private func analyzeEarProtection(_ earDimensions: ValidatedEarDimensions, side: EarSide) -> SingleEarAnalysis {
        let vulnerabilityScore = calculateVulnerabilityScore(earDimensions)
        let requiredProtection = calculateRequiredProtection(earDimensions, vulnerabilityScore: vulnerabilityScore)
        let riskFactors = identifyRiskFactors(earDimensions)
        
        return SingleEarAnalysis(
            side: side,
            vulnerabilityScore: vulnerabilityScore,
            requiredPaddingThickness: requiredProtection.paddingThickness,
            protectionZones: requiredProtection.zones,
            riskFactors: riskFactors,
            confidence: earDimensions.overallConfidence,
            specificRecommendations: generateSpecificRecommendations(earDimensions, side: side)
        )
    }
    
    // MARK: - Vulnerability Assessment
    
    private func calculateVulnerabilityScore(_ earDimensions: ValidatedEarDimensions) -> Float {
        var score: Float = 0.0
        
        // Ear protrusion increases vulnerability
        let protrusionFactor = min(earDimensions.protrusionAngle.value / 90.0, 1.0)
        score += protrusionFactor * 0.4
        
        // Larger ears are more vulnerable in scrums
        let sizeFactor = calculateEarSizeFactor(earDimensions)
        score += sizeFactor * 0.3
        
        // Ear shape analysis
        let shapeFactor = calculateShapeVulnerability(earDimensions)
        score += shapeFactor * 0.2
        
        // Position relative to head
        let positionFactor = calculatePositionVulnerability(earDimensions)
        score += positionFactor * 0.1
        
        return min(score, 1.0)
    }
    
    private func calculateEarSizeFactor(_ earDimensions: ValidatedEarDimensions) -> Float {
        let avgEarHeight: Float = 60.0 // mm average
        let avgEarWidth: Float = 30.0 // mm average
        
        let heightRatio = earDimensions.height.value / avgEarHeight
        let widthRatio = earDimensions.width.value / avgEarWidth
        
        // Larger ears = higher vulnerability in rugby
        return min((heightRatio + widthRatio) / 2.0, 1.5) / 1.5
    }
    
    private func calculateShapeVulnerability(_ earDimensions: ValidatedEarDimensions) -> Float {
        let aspectRatio = earDimensions.height.value / earDimensions.width.value
        
        // Ears with high aspect ratio (tall/narrow) are more vulnerable
        switch aspectRatio {
        case 2.5...: return 0.9
        case 2.0..<2.5: return 0.7
        case 1.5..<2.0: return 0.5
        default: return 0.3
        }
    }
    
    private func calculatePositionVulnerability(_ earDimensions: ValidatedEarDimensions) -> Float {
        // Ears that stick out more are more vulnerable
        let protrusionNormalized = min(earDimensions.protrusionAngle.value / 90.0, 1.0)
        return protrusionNormalized
    }
    
    // MARK: - Protection Requirements
    
    private func calculateRequiredProtection(_ earDimensions: ValidatedEarDimensions, vulnerabilityScore: Float) -> RequiredProtection {
        let basePadding = RugbyProtectionStandards.recommendedPaddingThickness
        let adjustedPadding = basePadding + (vulnerabilityScore * 4.0) // Up to 4mm extra
        
        let zones = earDimensions.protectionZones.map { zone in
            RugbyProtectionZone(
                area: zone.area,
                priority: enhancePriorityForRugby(zone.priority, vulnerabilityScore: vulnerabilityScore),
                thickness: max(adjustedPadding * getZoneMultiplier(zone.area), RugbyProtectionStandards.minimumPaddingThickness),
                coverage: zone.coverage,
                rugbySpecific: getRugbySpecificRequirements(zone.area)
            )
        }
        
        return RequiredProtection(
            paddingThickness: min(adjustedPadding, RugbyProtectionStandards.maximumPaddingThickness),
            zones: zones
        )
    }
    
    private func enhancePriorityForRugby(_ priority: ProtectionPriority, vulnerabilityScore: Float) -> RugbyProtectionPriority {
        switch priority {
        case .critical:
            return .essential // Always essential in rugby
        case .important:
            return vulnerabilityScore > 0.7 ? .essential : .critical
        case .optional:
            return vulnerabilityScore > 0.5 ? .critical : .important
        }
    }
    
    private func getZoneMultiplier(_ area: ProtectionZone.EarArea) -> Float {
        switch area {
        case .earCanal: return 1.2 // Extra protection for canal
        case .upperEar: return 1.1 // Important cartilage area
        case .earEdge: return 1.0 // Standard protection
        case .earLobe: return 0.8 // Less critical but still important
        }
    }
    
    private func getRugbySpecificRequirements(_ area: ProtectionZone.EarArea) -> RugbySpecificRequirement {
        switch area {
        case .earCanal:
            return RugbySpecificRequirement(
                reason: "Critical protection against scrum compression",
                additionalPadding: 2.0,
                reinforcement: .doubleLayer
            )
        case .upperEar:
            return RugbySpecificRequirement(
                reason: "High impact area during tackles and rucks",
                additionalPadding: 1.5,
                reinforcement: .reinforced
            )
        case .earEdge:
            return RugbySpecificRequirement(
                reason: "Prone to cuts from contact",
                additionalPadding: 1.0,
                reinforcement: .standard
            )
        case .earLobe:
            return RugbySpecificRequirement(
                reason: "Secondary protection zone",
                additionalPadding: 0.5,
                reinforcement: .light
            )
        }
    }
    
    // MARK: - Risk Factor Analysis
    
    private func identifyRiskFactors(_ earDimensions: ValidatedEarDimensions) -> [EarRiskFactor] {
        var riskFactors: [EarRiskFactor] = []
        
        // High protrusion angle
        if earDimensions.protrusionAngle.value > 60.0 {
            riskFactors.append(.highProtrusionAngle(earDimensions.protrusionAngle.value))
        }
        
        // Large ear size
        if earDimensions.height.value > 65.0 || earDimensions.width.value > 35.0 {
            riskFactors.append(.largeEarSize(
                height: earDimensions.height.value,
                width: earDimensions.width.value
            ))
        }
        
        // Thin cartilage (estimated from measurements)
        let cartilageThickness = estimateCartilageThickness(earDimensions)
        if cartilageThickness < 2.0 {
            riskFactors.append(.thinCartilage(cartilageThickness))
        }
        
        // Previous injury indicators (would come from user input)
        // riskFactors.append(.previousInjury("Cauliflower ear history"))
        
        return riskFactors
    }
    
    private func estimateCartilageThickness(_ earDimensions: ValidatedEarDimensions) -> Float {
        // Rough estimation based on ear dimensions and shape
        // In production, this might use additional ML models
        let baseThickness: Float = 2.5
        let sizeAdjustment = min(earDimensions.width.value / 35.0, 1.0) * 0.5
        return baseThickness + sizeAdjustment
    }
    
    // MARK: - Overall Analysis
    
    private func calculateOverallRisk(left: SingleEarAnalysis, right: SingleEarAnalysis) -> RugbyRiskLevel {
        let avgVulnerability = (left.vulnerabilityScore + right.vulnerabilityScore) / 2.0
        let maxVulnerability = max(left.vulnerabilityScore, right.vulnerabilityScore)
        
        // Overall risk considers both average and maximum vulnerability
        let riskScore = (avgVulnerability * 0.7) + (maxVulnerability * 0.3)
        
        switch riskScore {
        case 0.8...: return .veryHigh
        case 0.6..<0.8: return .high
        case 0.4..<0.6: return .medium
        case 0.2..<0.4: return .low
        default: return .minimal
        }
    }
    
    private func determineScrumCapType(_ measurements: ScrumCapMeasurements) -> RecommendedScrumCapType {
        let leftVulnerability = calculateVulnerabilityScore(measurements.leftEarDimensions)
        let rightVulnerability = calculateVulnerabilityScore(measurements.rightEarDimensions)
        let avgVulnerability = (leftVulnerability + rightVulnerability) / 2.0
        
        if measurements.earAsymmetryFactor > 0.3 {
            return .custom("Significant asymmetry requires custom fitting")
        } else if avgVulnerability > 0.8 {
            return .heavyDuty("High vulnerability requires maximum protection")
        } else if avgVulnerability > 0.6 {
            return .reinforced("Moderate vulnerability benefits from reinforced design")
        } else {
            return .standard("Standard protection sufficient")
        }
    }
    
    private func determineCustomizationNeeds(_ measurements: ScrumCapMeasurements) -> CustomizationNeeds {
        var needs: [CustomizationRequirement] = []
        
        // Asymmetry customization
        if measurements.earAsymmetryFactor > 0.2 {
            needs.append(.asymmetricPadding("Different padding thickness for each ear"))
        }
        
        // Size customization
        if measurements.headCircumference.value > 62.0 || measurements.headCircumference.value < 52.0 {
            needs.append(.sizeAdjustment("Non-standard head size requires custom sizing"))
        }
        
        // Back head coverage
        if measurements.occipitalProminence.value > 15.0 {
            needs.append(.backHeadReinforcement("Prominent back of head needs extra coverage"))
        }
        
        return CustomizationNeeds(requirements: needs)
    }
    
    private func calculateProtectionEffectiveness(left: SingleEarAnalysis, right: SingleEarAnalysis) -> ProtectionEffectiveness {
        let leftEffectiveness = calculateSingleEarEffectiveness(left)
        let rightEffectiveness = calculateSingleEarEffectiveness(right)
        
        return ProtectionEffectiveness(
            leftEar: leftEffectiveness,
            rightEar: rightEffectiveness,
            overall: (leftEffectiveness + rightEffectiveness) / 2.0
        )
    }
    
    private func calculateSingleEarEffectiveness(_ analysis: SingleEarAnalysis) -> Float {
        let baseEffectiveness: Float = 0.85 // Standard scrum cap effectiveness
        
        // Adjust based on confidence in measurements
        let confidenceAdjustment = analysis.confidence * 0.1
        
        // Adjust based on vulnerability (higher vulnerability = lower effectiveness without adequate protection)
        let vulnerabilityAdjustment = analysis.vulnerabilityScore * -0.2
        
        // Adjust based on required padding adequacy
        let paddingAdjustment = min(analysis.requiredPaddingThickness / RugbyProtectionStandards.maximumPaddingThickness, 1.0) * 0.15
        
        return min(baseEffectiveness + confidenceAdjustment + vulnerabilityAdjustment + paddingAdjustment, 1.0)
    }
    
    private func generateSpecificRecommendations(_ earDimensions: ValidatedEarDimensions, side: EarSide) -> [SpecificRecommendation] {
        var recommendations: [SpecificRecommendation] = []
        
        if earDimensions.protrusionAngle.value > 50.0 {
            recommendations.append(SpecificRecommendation(
                category: .padding,
                description: "Extra padding recommended for \(side.rawValue) ear due to high protrusion angle",
                priority: .high,
                implementation: "Add 2-3mm additional padding thickness"
            ))
        }
        
        if !earDimensions.isReliable {
            recommendations.append(SpecificRecommendation(
                category: .measurement,
                description: "Consider remeasuring \(side.rawValue) ear for better accuracy",
                priority: .medium,
                implementation: "Rescan with better positioning"
            ))
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

struct EarProtectionAnalysis {
    let leftEar: SingleEarAnalysis
    let rightEar: SingleEarAnalysis
    let asymmetryFactor: Float
    let overallRisk: RugbyRiskLevel
    let recommendedScrumCapType: RecommendedScrumCapType
    let customizationNeeded: CustomizationNeeds
    let protectionEffectiveness: ProtectionEffectiveness
}

struct SingleEarAnalysis {
    let side: EarSide
    let vulnerabilityScore: Float
    let requiredPaddingThickness: Float
    let protectionZones: [RugbyProtectionZone]
    let riskFactors: [EarRiskFactor]
    let confidence: Float
    let specificRecommendations: [SpecificRecommendation]
}

struct RequiredProtection {
    let paddingThickness: Float
    let zones: [RugbyProtectionZone]
}

struct RugbyProtectionZone {
    let area: ProtectionZone.EarArea
    let priority: RugbyProtectionPriority
    let thickness: Float
    let coverage: Float
    let rugbySpecific: RugbySpecificRequirement
}

enum RugbyProtectionPriority: Int {
    case essential = 4
    case critical = 3
    case important = 2
    case optional = 1
    
    var description: String {
        switch self {
        case .essential: return "Essential"
        case .critical: return "Critical"
        case .important: return "Important"
        case .optional: return "Optional"
        }
    }
}

struct RugbySpecificRequirement {
    let reason: String
    let additionalPadding: Float
    let reinforcement: ReinforcementType
    
    enum ReinforcementType {
        case light, standard, reinforced, doubleLayer
    }
}

enum EarRiskFactor {
    case highProtrusionAngle(Float)
    case largeEarSize(height: Float, width: Float)
    case thinCartilage(Float)
    case previousInjury(String)
    
    var description: String {
        switch self {
        case .highProtrusionAngle(let angle):
            return "High ear protrusion angle: \(String(format: "%.1f", angle))°"
        case .largeEarSize(let height, let width):
            return "Large ear size: \(String(format: "%.1f", height))x\(String(format: "%.1f", width))mm"
        case .thinCartilage(let thickness):
            return "Thin cartilage estimated: \(String(format: "%.1f", thickness))mm"
        case .previousInjury(let description):
            return "Previous injury: \(description)"
        }
    }
}

enum RugbyRiskLevel {
    case minimal, low, medium, high, veryHigh
    
    var description: String {
        switch self {
        case .minimal: return "Minimal Risk"
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        case .veryHigh: return "Very High Risk"
        }
    }
    
    var color: String {
        switch self {
        case .minimal: return "systemGreen"
        case .low: return "systemYellow"
        case .medium: return "systemOrange"
        case .high: return "systemRed"
        case .veryHigh: return "systemPurple"
        }
    }
}

enum RecommendedScrumCapType {
    case standard(String)
    case reinforced(String)
    case heavyDuty(String)
    case custom(String)
    
    var name: String {
        switch self {
        case .standard: return "Standard"
        case .reinforced: return "Reinforced"
        case .heavyDuty: return "Heavy Duty"
        case .custom: return "Custom"
        }
    }
    
    var description: String {
        switch self {
        case .standard(let reason): return reason
        case .reinforced(let reason): return reason
        case .heavyDuty(let reason): return reason
        case .custom(let reason): return reason
        }
    }
}

struct CustomizationNeeds {
    let requirements: [CustomizationRequirement]
    
    var hasCustomization: Bool {
        return !requirements.isEmpty
    }
}

enum CustomizationRequirement {
    case asymmetricPadding(String)
    case sizeAdjustment(String)
    case backHeadReinforcement(String)
    
    var description: String {
        switch self {
        case .asymmetricPadding(let desc): return desc
        case .sizeAdjustment(let desc): return desc
        case .backHeadReinforcement(let desc): return desc
        }
    }
}

struct ProtectionEffectiveness {
    let leftEar: Float
    let rightEar: Float
    let overall: Float
    
    var overallDescription: String {
        switch overall {
        case 0.9...: return "Excellent Protection"
        case 0.8..<0.9: return "Very Good Protection"
        case 0.7..<0.8: return "Good Protection"
        case 0.6..<0.7: return "Fair Protection"
        default: return "Limited Protection"
        }
    }
}

struct SpecificRecommendation {
    let category: RecommendationCategory
    let description: String
    let priority: RecommendationPriority
    let implementation: String
    
    enum RecommendationCategory {
        case padding, measurement, fit, safety
    }
    
    enum RecommendationPriority {
        case low, medium, high
    }
}
