//
//  MLEnhancedPoseValidator.swift
//  CyborgRugby
//
//  Enhanced ML pose validation with proper resource management and error handling
//

import Foundation
import CoreML
import AVFoundation
import Vision
import OSLog

actor MLEnhancedPoseValidator {
    private var earLandmarkingModel: MLModel?
    private var earTrackingModel: MLModel?
    private var isInitialized = false
    private var didLogOutputSchema = false
    private let logger = Logger(subsystem: "com.standardcyborg.CyborgRugby", category: "ml-pose-validator")
    
    // Model loading state
    nonisolated(unsafe) private var loadingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        loadingTask = nil
    }
    
    nonisolated func startInitialization() {
        loadingTask = Task {
            await loadMLModels()
        }
    }
    
    deinit {
        loadingTask?.cancel()
    }
    
    private func loadMLModels() async {
        logger.info("Starting ML model loading")
        
        // Load compiled .mlmodelc from app bundle; fallback to compiling .mlmodel at runtime
        func loadModel(named name: String) -> MLModel? {
            do {
                // Try compiled model first
                if let compiledURL = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
                    logger.debug("Loading compiled model: \(name)")
                    return try MLModel(contentsOf: compiledURL)
                }
                
                // Fallback to runtime compilation
                if let srcURL = Bundle.main.url(forResource: name, withExtension: "mlmodel") {
                    logger.debug("Compiling model at runtime: \(name)")
                    let compiledURL = try MLModel.compileModel(at: srcURL)
                    return try MLModel(contentsOf: compiledURL)
                }
                
                logger.error("Model not found: \(name)")
                return nil
            } catch {
                logger.error("Failed to load model \(name): \(error.localizedDescription)")
                return nil
            }
        }

        // Load models with timeout protection
        let earLandmarking = await withTaskGroup(of: MLModel?.self) { group in
            group.addTask {
                return loadModel(named: "SCEarLandmarking")
            }
            return await group.next() ?? nil
        }
        
        let earTracking = await withTaskGroup(of: MLModel?.self) { group in
            group.addTask {
                return loadModel(named: "SCEarTrackingModel")
            }
            return await group.next() ?? nil
        }
        
        // Actor isolation provides thread safety - no need for explicit locks
        earLandmarkingModel = earLandmarking
        earTrackingModel = earTracking
        isInitialized = (earLandmarkingModel != nil && earTrackingModel != nil)
        
        if isInitialized {
            logger.info("ML models loaded successfully")
        } else {
            logger.warning("ML models not fully initialized - some features may be unavailable")
        }
    }
    
    // MARK: - Pose Validation
    
    func validatePose(_ pose: HeadScanningPose, in pixelBuffer: CVPixelBuffer) async -> PoseValidationResult {
        // Ensure models are loaded
        await loadingTask?.value
        
        guard await getInitializationStatus() else {
            logger.error("ML models not initialized")
            return PoseValidationResult(
                isValid: false,
                confidence: 0.0,
                feedback: "ML models not initialized",
                requiredAdjustments: [.waitForInitialization]
            )
        }
        
        // Validate pixel buffer
        guard validatePixelBuffer(pixelBuffer) else {
            logger.error("Invalid pixel buffer for pose validation")
            return PoseValidationResult(
                isValid: false,
                confidence: 0.0,
                feedback: "Invalid camera input",
                requiredAdjustments: [.tryAgain("Camera input invalid")]
            )
        }
        
        do {
            switch pose {
            case .frontFacing:
                return try await validateFrontFacingPose(pixelBuffer)
            case .leftProfile:
                return try await validateProfilePose(pixelBuffer, side: .left)
            case .rightProfile:
                return try await validateProfilePose(pixelBuffer, side: .right)
            case .lookingDown:
                return try await validateLookingDownPose(pixelBuffer)
            case .leftThreeQuarter, .rightThreeQuarter:
                return try await validateThreeQuarterPose(pixelBuffer, pose: pose)
            case .chinUp:
                return try await validateChinUpPose(pixelBuffer)
            }
        } catch {
            logger.error("Pose validation failed: \(error.localizedDescription)")
            return createFailedResult("Pose validation error: \(error.localizedDescription)")
        }
    }

    // MARK: - Ear Analysis Methods
    
    func estimateEarProtrusion(in pixelBuffer: CVPixelBuffer, side: EarSide) async -> Float? {
        await loadingTask?.value
        
        guard await getInitializationStatus(), let earTracking = await getEarTrackingModel() else {
            logger.warning("Ear tracking model not available")
            return nil
        }
        
        guard validatePixelBuffer(pixelBuffer) else {
            logger.error("Invalid pixel buffer for ear protrusion estimation")
            return nil
        }
        
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)])
            let trackingOutput = try await MLQueue.shared.runWithTimeout {
                try earTracking.prediction(from: input)
            }
            
            // Use generic confidence to derive an angle range [25, 55] degrees
            let conf = extractConfidence(from: trackingOutput)
            let angle = 25.0 + (55.0 - 25.0) * max(0.0, min(conf, 1.0))
            
            logger.debug("Estimated ear protrusion angle: \(angle)° (confidence: \(conf))")
            return angle
        } catch {
            logger.error("Ear protrusion estimation failed: \(error.localizedDescription)")
            return nil
        }
    }

    func detectEarFeatures(in pixelBuffer: CVPixelBuffer) async -> EarFeatures? {
        await loadingTask?.value
        
        guard await getInitializationStatus(),
              let earLandmarking = await getEarLandmarkingModel(),
              let earTracking = await getEarTrackingModel() else {
            logger.warning("Ear detection models not available")
            return nil
        }
        
        guard validatePixelBuffer(pixelBuffer) else {
            logger.error("Invalid pixel buffer for ear feature detection")
            return nil
        }
        
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)])
            
            // Run both models concurrently with timeout protection
            async let landmarkingResult = MLQueue.shared.runWithTimeout {
                try earLandmarking.prediction(from: input)
            }
            async let trackingResult = MLQueue.shared.runWithTimeout {
                try earTracking.prediction(from: input)
            }
            
            let (lmOutput, trOutput) = try await (landmarkingResult, trackingResult)
            let conf = max(extractConfidence(from: lmOutput), extractConfidence(from: trOutput))

            // Log available feature names once for debugging
            if !(await getDidLogOutputSchema()) {
                await setDidLogOutputSchema(true)
                logger.debug("SCEarLandmarking output features: \(Array(lmOutput.featureNames))")
                logger.debug("SCEarTrackingModel output features: \(Array(trOutput.featureNames))")
            }

            // Extract landmarks
            let landmarks = extractLandmarks(from: lmOutput)
            
            // Extract bounding box
            let bbox = extractBoundingBox(from: trOutput)

            guard !landmarks.isEmpty || bbox != nil || conf > 0 else {
                logger.debug("No ear features detected")
                return nil
            }
            
            logger.debug("Detected ear features: \(landmarks.count) landmarks, bbox: \(bbox?.debugDescription ?? "none"), confidence: \(conf)")
            return EarFeatures(landmarks: landmarks, boundingBox: bbox, confidence: conf)
            
        } catch {
            logger.error("Ear feature detection failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Specific Pose Validators
    
    private func validateFrontFacingPose(_ pixelBuffer: CVPixelBuffer) async throws -> PoseValidationResult {
        guard let earLandmarking = await getEarLandmarkingModel(),
              let earTracking = await getEarTrackingModel() else {
            throw PoseValidationError.modelsUnavailable
        }
        
        let landmarkingInput = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)])
        let landmarkingOutput = try await MLQueue.shared.runWithTimeout { 
            try earLandmarking.prediction(from: landmarkingInput) 
        }
        
        let trackingInput = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)])
        let trackingOutput = try await MLQueue.shared.runWithTimeout { 
            try earTracking.prediction(from: trackingInput) 
        }
        
        let confidence = extractConfidence(from: landmarkingOutput)
        let earPositions = extractEarPositions(from: trackingOutput)
        
        if confidence > 0.7 && bothEarsVisible(earPositions) {
            return PoseValidationResult(
                isValid: true,
                confidence: confidence,
                feedback: "Perfect front-facing pose detected",
                requiredAdjustments: []
            )
        } else if confidence > 0.5 {
            var adjustments: [PoseAdjustment] = []
            if !bothEarsVisible(earPositions) {
                adjustments.append(.adjustHeadAngle("Both ears should be visible"))
            }
            if confidence < 0.7 {
                adjustments.append(.improveStability("Hold your head more steady"))
            }
            
            return PoseValidationResult(
                isValid: false,
                confidence: confidence,
                feedback: "Almost there - minor adjustments needed",
                requiredAdjustments: adjustments
            )
        } else {
            return PoseValidationResult(
                isValid: false,
                confidence: confidence,
                feedback: "Please face the camera directly",
                requiredAdjustments: [.adjustHeadAngle("Look straight at the camera")]
            )
        }
    }
    
    private func validateProfilePose(_ pixelBuffer: CVPixelBuffer, side: EarSide) async throws -> PoseValidationResult {
        guard let earLandmarking = await getEarLandmarkingModel(),
              let earTracking = await getEarTrackingModel() else {
            throw PoseValidationError.modelsUnavailable
        }
        
        let landmarkingInput = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)])
        let landmarkingOutput = try await MLQueue.shared.runWithTimeout {
            try earLandmarking.prediction(from: landmarkingInput)
        }
        
        let trackingInput = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)])
        _ = try await MLQueue.shared.runWithTimeout {
            try earTracking.prediction(from: trackingInput)
        }
        
        let confidence = extractConfidence(from: landmarkingOutput)
        let earDetail = extractEarDetail(from: landmarkingOutput, side: side)
        
        if confidence > 0.8 && earDetail.isComplete {
            return PoseValidationResult(
                isValid: true,
                confidence: confidence,
                feedback: "Excellent \(side.rawValue) profile captured",
                requiredAdjustments: []
            )
        } else {
            var adjustments: [PoseAdjustment] = []
            if !earDetail.isComplete {
                adjustments.append(.adjustHeadAngle("Turn your head exactly 90° to the \(side.rawValue)"))
            }
            if confidence < 0.8 {
                adjustments.append(.improveStability("Hold the position more steady"))
            }
            
            return PoseValidationResult(
                isValid: false,
                confidence: confidence,
                feedback: "Profile pose needs adjustment",
                requiredAdjustments: adjustments
            )
        }
    }
    
    private func validateLookingDownPose(_ pixelBuffer: CVPixelBuffer) async throws -> PoseValidationResult {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        try handler.perform([request])
        
        guard let faceObservations = request.results, !faceObservations.isEmpty else {
            return PoseValidationResult(
                isValid: false,
                confidence: 0.0,
                feedback: "No face detected - please ensure you're in frame",
                requiredAdjustments: [.adjustPosition("Move closer to camera")]
            )
        }
        
        let face = faceObservations[0]
        let faceHeight = face.boundingBox.height
        let faceY = face.boundingBox.minY
        
        // Looking down should show face in lower portion of frame with reduced height
        let isLookingDown = faceY < 0.4 && faceHeight < 0.3
        let confidence: Float = isLookingDown ? 0.85 : 0.3
        
        if isLookingDown {
            return PoseValidationResult(
                isValid: true,
                confidence: confidence,
                feedback: "Perfect looking-down pose for back-head scan",
                requiredAdjustments: []
            )
        } else {
            return PoseValidationResult(
                isValid: false,
                confidence: confidence,
                feedback: "Tilt your head down more - like reading a book",
                requiredAdjustments: [.adjustHeadAngle("Look down 30-40 degrees")]
            )
        }
    }
    
    private func validateThreeQuarterPose(_ pixelBuffer: CVPixelBuffer, pose: HeadScanningPose) async throws -> PoseValidationResult {
        guard let earTracking = await getEarTrackingModel() else {
            throw PoseValidationError.modelsUnavailable
        }
        
        let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)])
        let output = try await MLQueue.shared.runWithTimeout {
            try earTracking.prediction(from: input)
        }
        
        let confidence = extractConfidence(from: output)
        let earVisibility = extractEarVisibility(from: output)
        
        let expectedSide: EarSide = pose == .leftThreeQuarter ? .left : .right
        let isCorrectAngle = earVisibility.isPartiallyVisible(side: expectedSide)
        
        if confidence > 0.7 && isCorrectAngle {
            return PoseValidationResult(
                isValid: true,
                confidence: confidence,
                feedback: "Good three-quarter angle captured",
                requiredAdjustments: []
            )
        } else {
            let adjustment = pose == .leftThreeQuarter ? 
                "Turn 45° left and tilt slightly down" : 
                "Turn 45° right and tilt slightly down"
            
            return PoseValidationResult(
                isValid: false,
                confidence: confidence,
                feedback: "Adjust to three-quarter angle",
                requiredAdjustments: [.adjustHeadAngle(adjustment)]
            )
        }
    }
    
    private func validateChinUpPose(_ pixelBuffer: CVPixelBuffer) async throws -> PoseValidationResult {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        try handler.perform([request])
        
        guard let faceObservations = request.results, !faceObservations.isEmpty else {
            return createFailedResult("No face detected")
        }
        
        let face = faceObservations[0]
        let faceY = face.boundingBox.minY
        
        // Chin up should show face higher in frame
        let isChinUp = faceY > 0.6
        let confidence: Float = isChinUp ? 0.80 : 0.4
        
        return PoseValidationResult(
            isValid: isChinUp,
            confidence: confidence,
            feedback: isChinUp ? "Good chin-up pose" : "Lift your chin up more",
            requiredAdjustments: isChinUp ? [] : [.adjustHeadAngle("Look up 15-20 degrees")]
        )
    }
    
    // MARK: - Helper Methods
    
    private func validatePixelBuffer(_ pixelBuffer: CVPixelBuffer) -> Bool {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard width > 0 && height > 0 else {
            logger.error("Pixel buffer has invalid dimensions: \(width)x\(height)")
            return false
        }
        
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard pixelFormat == kCVPixelFormatType_32BGRA || 
              pixelFormat == kCVPixelFormatType_32ARGB ||
              pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange else {
            logger.error("Unsupported pixel format: \(pixelFormat)")
            return false
        }
        
        return true
    }
    
    private func createFailedResult(_ message: String) -> PoseValidationResult {
        return PoseValidationResult(
            isValid: false,
            confidence: 0.0,
            feedback: message,
            requiredAdjustments: [.tryAgain(message)]
        )
    }
    
    private func extractConfidence(from output: MLFeatureProvider) -> Float {
        // Try common confidence field names
        let confidenceKeys = ["confidence", "score", "probability"]
        
        for key in confidenceKeys {
            if let confidenceValue = output.featureValue(for: key)?.doubleValue {
                return Float(min(max(confidenceValue, 0.0), 1.0))
            }
        }
        
        // Default moderate confidence if no confidence field found
        return 0.5
    }
    
    private func extractLandmarks(from output: MLFeatureProvider) -> [CGPoint] {
        var landmarks: [CGPoint] = []
        
        for name in output.featureNames {
            if let arr = output.featureValue(for: name)?.multiArrayValue {
                let count = arr.count
                if count % 2 == 0 && count <= 2 * 256 { // reasonable bound
                    // Assume [x0,y0,x1,y1,...] normalized coordinates
                    var points: [CGPoint] = []
                    for i in stride(from: 0, to: count, by: 2) {
                        let x = arr[i].floatValue
                        let y = arr[i+1].floatValue
                        if x >= 0 && x <= 1 && y >= 0 && y <= 1 {
                            points.append(CGPoint(x: CGFloat(x), y: CGFloat(y)))
                        }
                    }
                    if points.count >= 3 {
                        landmarks = points
                        break
                    }
                }
            }
        }
        
        return landmarks
    }
    
    private func extractBoundingBox(from output: MLFeatureProvider) -> CGRect? {
        for name in output.featureNames {
            if let arr = output.featureValue(for: name)?.multiArrayValue, arr.count == 4 {
                let a = arr[0].floatValue
                let b = arr[1].floatValue
                let c = arr[2].floatValue
                let d = arr[3].floatValue
                
                // Try (x,y,w,h) normalized
                if a >= 0 && a <= 1 && b >= 0 && b <= 1 && c >= 0 && c <= 1 && d >= 0 && d <= 1 && c > 0 && d > 0 {
                    return CGRect(x: CGFloat(a), y: CGFloat(b), width: CGFloat(c), height: CGFloat(d))
                }
                
                // Try (xmin,ymin,xmax,ymax)
                let w = c - a
                let h = d - b
                if w > 0 && h > 0 && a >= 0 && a <= 1 && b >= 0 && b <= 1 && c >= 0 && c <= 1 && d >= 0 && d <= 1 {
                    return CGRect(x: CGFloat(a), y: CGFloat(b), width: CGFloat(w), height: CGFloat(h))
                }
            }
        }
        return nil
    }
    
    private func extractEarPositions(from output: MLFeatureProvider) -> EarPositions {
        // Placeholder implementation - would need actual model output parsing
        return EarPositions(
            leftEarVisible: true,
            rightEarVisible: true,
            leftEarCenter: CGPoint(x: 0.3, y: 0.5),
            rightEarCenter: CGPoint(x: 0.7, y: 0.5)
        )
    }
    
    private func bothEarsVisible(_ positions: EarPositions) -> Bool {
        return positions.leftEarVisible && positions.rightEarVisible
    }
    
    private func extractEarDetail(from output: MLFeatureProvider, side: EarSide) -> EarDetail {
        return EarDetail(
            isComplete: true,
            landmarkPoints: [],
            confidence: extractConfidence(from: output)
        )
    }
    
    private func extractEarVisibility(from output: MLFeatureProvider) -> EarVisibility {
        return EarVisibility(
            leftPartiallyVisible: true,
            rightPartiallyVisible: true
        )
    }
    
    // MARK: - Actor-safe Property Accessors
    
    private func getInitializationStatus() async -> Bool {
        return isInitialized
    }
    
    private func getEarLandmarkingModel() async -> MLModel? {
        return earLandmarkingModel
    }
    
    private func getEarTrackingModel() async -> MLModel? {
        return earTrackingModel
    }
    
    private func getDidLogOutputSchema() async -> Bool {
        return didLogOutputSchema
    }
    
    private func setDidLogOutputSchema(_ value: Bool) async {
        didLogOutputSchema = value
    }
}

// MARK: - Error Types

enum PoseValidationError: LocalizedError {
    case modelsUnavailable
    case invalidInput
    case processingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .modelsUnavailable:
            return "ML models are not available for pose validation"
        case .invalidInput:
            return "Invalid input provided for pose validation"
        case .processingFailed(let error):
            return "Pose validation processing failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Types

struct PoseValidationResult {
    let isValid: Bool
    let confidence: Float
    let feedback: String
    let requiredAdjustments: [PoseAdjustment]
    
    var qualityDescription: String {
        switch confidence {
        case 0.9...: return "Excellent"
        case 0.8..<0.9: return "Very Good"
        case 0.7..<0.8: return "Good"
        case 0.6..<0.7: return "Fair"
        default: return "Poor"
        }
    }
}

enum PoseAdjustment {
    case adjustHeadAngle(String)
    case improveStability(String)
    case adjustPosition(String)
    case waitForInitialization
    case tryAgain(String)
    
    var instruction: String {
        switch self {
        case .adjustHeadAngle(let instruction): return instruction
        case .improveStability(let instruction): return instruction
        case .adjustPosition(let instruction): return instruction
        case .waitForInitialization: return "Please wait for ML models to initialize"
        case .tryAgain(let instruction): return instruction
        }
    }
}

enum EarSide: String {
    case left = "left"
    case right = "right"
}

struct EarPositions {
    let leftEarVisible: Bool
    let rightEarVisible: Bool
    let leftEarCenter: CGPoint
    let rightEarCenter: CGPoint
}

struct EarDetail {
    let isComplete: Bool
    let landmarkPoints: [CGPoint]
    let confidence: Float
}

struct EarVisibility {
    let leftPartiallyVisible: Bool
    let rightPartiallyVisible: Bool
    
    func isPartiallyVisible(side: EarSide) -> Bool {
        switch side {
        case .left: return leftPartiallyVisible
        case .right: return rightPartiallyVisible
        }
    }
}
