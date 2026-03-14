import Foundation
import CoreImage
import CoreML
import UIKit
import Vision
import StandardCyborgFusion

struct EarLandmarksResult: Codable {
    struct Point: Codable, Equatable { let x: Double; let y: Double } // normalized 0..1, top-left origin
    struct Rect: Codable, Equatable { let x: Double; let y: Double; let w: Double; let h: Double } // normalized 0..1, detector/native origin (bottom-left)

    let confidence: Double
    let earBoundingBox: Rect
    let landmarks: [Point] // 0 or 5 points
    let usedLeftEarMirroringHeuristic: Bool
}

final class EarLandmarksService {
    struct VerificationArtifacts {
        let result: EarLandmarksResult
        let verificationImage: UIImage
        let fullSceneOverlay: UIImage
        let cropOverlay: UIImage
    }

    struct OverlayLayout: Equatable {
        let boundingBoxRect: CGRect?
        let landmarkPoints: [CGPoint]
    }

    enum ServiceError: Error, LocalizedError {
        case modelNotFound(String)
        case cgImageMissing
        case predictionFailed(String)
        case pixelBufferCreateFailed

        var errorDescription: String? {
            switch self {
            case .modelNotFound(let name):
                return String(format: L("ear.service.modelMissing"), name)
            case .cgImageMissing:
                return L("ear.service.cgImageMissing")
            case .predictionFailed(let msg):
                return String(format: L("ear.service.predictionFailed"), msg)
            case .pixelBufferCreateFailed:
                return L("ear.service.pixelBufferCreateFailed")
            }
        }
    }

    private enum LandmarkValidationFailure: String {
        case landmarkModelError
        case unexpectedOutputShape
        case mappedPointsOutsideBoundingBox
        case bboxOnlyFallback
    }

    private struct DetectionStageResult {
        let boundingBox: CGRect // detector/native normalized coordinates
        let confidence: Float
    }

    private struct LandmarkPreparationResult {
        let inputImage: CIImage
        let normalizedCropRect: CGRect // detector/native normalized coordinates
        let pixelBuffer: CVPixelBuffer
    }

    private struct DetectionArtifacts {
        let result: EarLandmarksResult
        let landmarkCropImage: UIImage?
        let landmarkCropPoints: [(x: CGFloat, y: CGFloat)]
    }

    private struct DebugArtifactPayload: Codable {
        struct RectPayload: Codable {
            let x: Double
            let y: Double
            let width: Double
            let height: Double
        }

        struct PointPayload: Codable {
            let x: Double
            let y: Double
        }

        let detectorBoundingBox: RectPayload
        let displayBoundingBox: RectPayload
        let landmarkCropRect: RectPayload?
        let rawLandmarkPreview: String?
        let mappedLandmarks: [PointPayload]
        let renderedLandmarks: [PointPayload]
        let renderedBoundingBox: RectPayload?
        let overlayFlipX: Bool?
        let landmarkRenderOrigin: String?
        let verificationSource: String?
        let usedPreviewSnapshotFallback: Bool?
        let verificationImageWidth: Double?
        let verificationImageHeight: Double?
        let validationFailure: String?
        let outputPath: String
    }

    private static let landmarkInputSize = CGSize(width: 300, height: 300)

    // Keep the current bounding-box MVP behavior unchanged for overlays/exports.
    private let minTrackerConfidence: Float = 0.10
    private let displayBBoxExpansionFraction: CGFloat = 0.18

    // Match the legacy StandardCyborg landmark crop contract first.
    private let landmarkBBoxExpansionFraction: CGFloat = 0.15
    private let minimumMappedInsideRatio: Double = 0.6

    #if DEBUG
    private let debugLogsEnabled: Bool = true
    #else
    private let debugLogsEnabled: Bool = false
    #endif

    private let ciContext = CIContext()
    private let earTracker: SCEarTracking
    private let vnModel: VNCoreMLModel

    init() throws {
        guard let trackingURL = Self.findModelURL(resource: "SCEarTrackingModel") else {
            throw ServiceError.modelNotFound("SCEarTrackingModel")
        }
        guard let landmarkURL = Self.findModelURL(resource: "SCEarLandmarking") else {
            throw ServiceError.modelNotFound("SCEarLandmarking")
        }

        self.earTracker = SCEarTracking(modelURL: trackingURL, delegate: nil)

        let config = MLModelConfiguration()
        let model = try MLModel(contentsOf: landmarkURL, configuration: config)
        self.vnModel = try VNCoreMLModel(for: model)
        Log.ml.info("EarLandmarksService initialized")
    }

    /// Detect ear bbox + landmarks from a UIImage.
    /// - Returns: nil only if the ear detector finds no bbox (or confidence too low).
    /// - IMPORTANT: if the detector finds a bbox but landmarking fails, this returns bbox-only (0 landmarks),
    ///   so your export still writes the green-box overlay and you can debug.
    func detect(in uiImage: UIImage) throws -> EarLandmarksResult? {
        try detectArtifacts(in: uiImage)?.result
    }

    func verify(in uiImage: UIImage,
                drawBoundingBox: Bool = true,
                flipY: Bool = true,
                flipX: Bool = false,
                verificationSource: String? = nil,
                usedPreviewSnapshotFallback: Bool? = nil) throws -> VerificationArtifacts? {
        guard let detectionArtifacts = try detectArtifacts(
            in: uiImage,
            verificationSource: verificationSource,
            usedPreviewSnapshotFallback: usedPreviewSnapshotFallback
        ) else { return nil }
        let fullSceneOverlay = renderOverlay(
            on: uiImage,
            result: detectionArtifacts.result,
            drawBoundingBox: drawBoundingBox,
            flipY: flipY,
            flipX: flipX
        )
        let cropOverlay: UIImage
        if let landmarkCropImage = detectionArtifacts.landmarkCropImage {
            cropOverlay = Self.renderCropOverlay(
                on: landmarkCropImage,
                cropNormalizedLandmarks: detectionArtifacts.landmarkCropPoints
            )
        } else {
            cropOverlay = UIImage()
        }

        return VerificationArtifacts(
            result: detectionArtifacts.result,
            verificationImage: uiImage,
            fullSceneOverlay: fullSceneOverlay,
            cropOverlay: cropOverlay
        )
    }

    private func detectArtifacts(
        in uiImage: UIImage,
        verificationSource: String? = nil,
        usedPreviewSnapshotFallback: Bool? = nil
    ) throws -> DetectionArtifacts? {
        guard let cgImage = uiImage.normalizedCGImage() else { throw ServiceError.cgImageMissing }

        let ciImage = CIImage(cgImage: cgImage)
        guard let detection = detectBoundingBox(in: ciImage) else { return nil }

        let displayBoundingBox = detection.boundingBox
            .expanded(by: displayBBoxExpansionFraction)
            .clamped01()
        var debugCropRect: CGRect?
        var debugRawPreview: String?
        var debugValidationFailure: LandmarkValidationFailure?
        var debugCropImage: UIImage?
        var cropNormalizedPoints: [(x: CGFloat, y: CGFloat)] = []

        let mappedLandmarks: [EarLandmarksResult.Point]
        do {
            let preparation = try prepareLandmarkCrop(from: ciImage, boundingBox: detection.boundingBox)
            debugCropRect = preparation.normalizedCropRect
            let rawPoints = try runLandmarkInference(with: preparation.pixelBuffer)
            debugRawPreview = Self.previewValues(from: rawPoints, limit: 6)
            cropNormalizedPoints = rawPoints
            let remapped = Self.remapLegacyLandmarks(
                rawPoints,
                normalizedCropRect: preparation.normalizedCropRect,
                mirroredHorizontally: false
            )
            mappedLandmarks = Self.validateMappedLandmarks(
                remapped,
                within: preparation.normalizedCropRect,
                minimumInsideRatio: minimumMappedInsideRatio
            ) ? remapped : {
                debugValidationFailure = .mappedPointsOutsideBoundingBox
                return handleLandmarkValidationFailure(.mappedPointsOutsideBoundingBox)
            }()

            if debugLogsEnabled {
                debugCropImage = Self.uiImage(from: preparation.inputImage)
                Self.debugWrite(preparation.inputImage, named: "ear-landmark-input")
                Log.ml.debug("Landmark crop rect=\(String(describing: preparation.normalizedCropRect), privacy: .public)")
                Log.ml.debug("Mapped landmark count=\(mappedLandmarks.count, privacy: .public)")
            }
            if !debugLogsEnabled {
                debugCropImage = Self.uiImage(from: preparation.inputImage)
            }
        } catch let error as ServiceError {
            Log.ml.error("Landmarking failed: \(error.localizedDescription, privacy: .public)")
            if debugLogsEnabled {
                Log.ml.debug("Landmarking failed (bbox-only): \(error.localizedDescription, privacy: .public)")
            }
            debugValidationFailure = .bboxOnlyFallback
            mappedLandmarks = handleLandmarkValidationFailure(.bboxOnlyFallback)
        } catch {
            Log.ml.error("Landmarking failed: \(error.localizedDescription, privacy: .public)")
            if debugLogsEnabled {
                Log.ml.debug("Landmarking failed (bbox-only): \(error.localizedDescription, privacy: .public)")
            }
            debugValidationFailure = .landmarkModelError
            mappedLandmarks = handleLandmarkValidationFailure(.landmarkModelError)
        }

        if debugLogsEnabled {
            let payload = DebugArtifactPayload(
                detectorBoundingBox: Self.payloadRect(from: detection.boundingBox),
                displayBoundingBox: Self.payloadRect(from: displayBoundingBox),
                landmarkCropRect: debugCropRect.map(Self.payloadRect(from:)),
                rawLandmarkPreview: debugRawPreview,
                mappedLandmarks: mappedLandmarks.map { .init(x: $0.x, y: $0.y) },
                renderedLandmarks: [],
                renderedBoundingBox: nil,
                overlayFlipX: nil,
                landmarkRenderOrigin: nil,
                verificationSource: verificationSource,
                usedPreviewSnapshotFallback: usedPreviewSnapshotFallback,
                verificationImageWidth: Double(uiImage.size.width),
                verificationImageHeight: Double(uiImage.size.height),
                validationFailure: debugValidationFailure?.rawValue,
                outputPath: Self.debugArtifactsDirectory().path
            )
            Self.writeDebugPayload(payload)
        }

        let result = EarLandmarksResult(
            confidence: Double(detection.confidence),
            earBoundingBox: .init(
                x: Double(displayBoundingBox.origin.x),
                y: Double(displayBoundingBox.origin.y),
                w: Double(displayBoundingBox.size.width),
                h: Double(displayBoundingBox.size.height)
            ),
            landmarks: mappedLandmarks,
            usedLeftEarMirroringHeuristic: false
        )

        return DetectionArtifacts(
            result: result,
            landmarkCropImage: debugCropImage,
            landmarkCropPoints: mappedLandmarks.isEmpty ? [] : cropNormalizedPoints
        )
    }

    func renderOverlay(on baseImage: UIImage,
                       result: EarLandmarksResult,
                       drawBoundingBox: Bool = true,
                       flipY: Bool = true,
                       flipX: Bool = false) -> UIImage {
        // Bounding boxes stay in detector/native bottom-left coordinates.
        // Landmarks are already top-left normalized coordinates after remapping.
        let layout = Self.overlayLayout(
            for: result,
            imageSize: baseImage.size,
            drawBoundingBox: drawBoundingBox,
            flipY: flipY,
            flipX: flipX
        )

        let renderer = UIGraphicsImageRenderer(size: baseImage.size)
        let overlay = renderer.image { _ in
            baseImage.draw(in: CGRect(origin: .zero, size: baseImage.size))
            if let rect = layout.boundingBoxRect {
                let path = UIBezierPath(rect: rect)
                let imageWidth = baseImage.size.width
                let imageHeight = baseImage.size.height
                UIColor.systemGreen.withAlphaComponent(0.9).setStroke()
                path.lineWidth = max(2, min(imageWidth, imageHeight) * 0.006)
                path.stroke()
            }

            guard !layout.landmarkPoints.isEmpty else { return }

            let dotRadius = max(3.5, min(baseImage.size.width, baseImage.size.height) * 0.012)
            for (index, mappedPoint) in layout.landmarkPoints.enumerated() {

                let color: UIColor = (index % 2 == 0) ? .systemYellow : .systemOrange
                color.withAlphaComponent(0.95).setFill()

                let dotRect = CGRect(
                    x: mappedPoint.x - dotRadius,
                    y: mappedPoint.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
                UIBezierPath(ovalIn: dotRect).fill()

                UIColor.black.withAlphaComponent(0.6).setStroke()
                let outline = UIBezierPath(ovalIn: dotRect)
                outline.lineWidth = 1
                outline.stroke()
            }
        }

        if debugLogsEnabled {
            Log.ml.debug("Overlay render flipX=\(flipX, privacy: .public), landmarkOrigin=topLeft")
            let payload = Self.readDebugPayload().map { Self.debugPayload($0, withRenderLayout: layout, flipX: flipX) } ?? DebugArtifactPayload(
                detectorBoundingBox: .init(x: 0, y: 0, width: 0, height: 0),
                displayBoundingBox: .init(x: 0, y: 0, width: 0, height: 0),
                landmarkCropRect: nil,
                rawLandmarkPreview: nil,
                mappedLandmarks: result.landmarks.map { .init(x: $0.x, y: $0.y) },
                renderedLandmarks: layout.landmarkPoints.map(Self.payloadPoint(from:)),
                renderedBoundingBox: layout.boundingBoxRect.map(Self.payloadRect(from:)),
                overlayFlipX: flipX,
                landmarkRenderOrigin: "topLeft",
                verificationSource: nil,
                usedPreviewSnapshotFallback: nil,
                verificationImageWidth: Double(baseImage.size.width),
                verificationImageHeight: Double(baseImage.size.height),
                validationFailure: nil,
                outputPath: Self.debugArtifactsDirectory().path
            )
            Self.writeDebugPayload(payload)
            Self.debugWrite(overlay, named: "ear-landmark-overlay")
        }

        return overlay
    }

    static func renderCropOverlay(on cropImage: UIImage,
                                  cropNormalizedLandmarks: [(x: CGFloat, y: CGFloat)]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: cropImage.size)
        let overlay = renderer.image { _ in
            cropImage.draw(in: CGRect(origin: .zero, size: cropImage.size))

            guard !cropNormalizedLandmarks.isEmpty else { return }

            let dotRadius = max(3.5, min(cropImage.size.width, cropImage.size.height) * 0.016)
            for (index, point) in cropNormalizedLandmarks.enumerated() {
                let mappedPoint = CGPoint(
                    x: point.x * cropImage.size.width,
                    y: point.y * cropImage.size.height
                )

                let color: UIColor = (index % 2 == 0) ? .systemYellow : .systemOrange
                color.withAlphaComponent(0.95).setFill()

                let dotRect = CGRect(
                    x: mappedPoint.x - dotRadius,
                    y: mappedPoint.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
                UIBezierPath(ovalIn: dotRect).fill()

                UIColor.black.withAlphaComponent(0.6).setStroke()
                let outline = UIBezierPath(ovalIn: dotRect)
                outline.lineWidth = 1
                outline.stroke()
            }
        }

        #if DEBUG
        Self.debugWrite(overlay, named: "ear-landmark-crop-overlay")
        #endif

        return overlay
    }

    static func overlayLayout(
        for result: EarLandmarksResult,
        imageSize: CGSize,
        drawBoundingBox: Bool = true,
        flipY: Bool = true,
        flipX: Bool = false
    ) -> OverlayLayout {
        let imageWidth = imageSize.width
        let imageHeight = imageSize.height

        func mapDetectorPoint(nx: Double, ny: Double) -> CGPoint {
            let fx = flipX ? (1.0 - nx) : nx
            let fy = flipY ? (1.0 - ny) : ny
            return CGPoint(x: CGFloat(fx) * imageWidth, y: CGFloat(fy) * imageHeight)
        }

        func mapLandmarkPoint(nx: Double, ny: Double) -> CGPoint {
            let fx = flipX ? (1.0 - nx) : nx
            return CGPoint(x: CGFloat(fx) * imageWidth, y: CGFloat(ny) * imageHeight)
        }

        let boundingBoxRect: CGRect?
        if drawBoundingBox {
            let boxX = flipX ? (1.0 - result.earBoundingBox.x - result.earBoundingBox.w) : result.earBoundingBox.x
            let boxY = result.earBoundingBox.y

            let topLeft = mapDetectorPoint(nx: boxX, ny: boxY + result.earBoundingBox.h)
            let bottomRight = mapDetectorPoint(nx: boxX + result.earBoundingBox.w, ny: boxY)
            boundingBoxRect = CGRect(
                x: min(topLeft.x, bottomRight.x),
                y: min(topLeft.y, bottomRight.y),
                width: abs(bottomRight.x - topLeft.x),
                height: abs(bottomRight.y - topLeft.y)
            )
        } else {
            boundingBoxRect = nil
        }

        let landmarkPoints = result.landmarks.map { point in
            mapLandmarkPoint(nx: point.x, ny: point.y)
        }

        return OverlayLayout(boundingBoxRect: boundingBoxRect, landmarkPoints: landmarkPoints)
    }

    static func cropAndScaleForLandmarks(
        _ inputImage: CIImage,
        normalizedCropRect: CGRect,
        scaledSize: CGSize = EarLandmarksService.landmarkInputSize
    ) -> CIImage {
        let inputWidth = inputImage.extent.size.width
        let inputHeight = inputImage.extent.size.height
        let cropRect = CGRect(
            x: normalizedCropRect.origin.x * inputWidth,
            y: normalizedCropRect.origin.y * inputHeight,
            width: normalizedCropRect.size.width * inputWidth,
            height: normalizedCropRect.size.height * inputHeight
        )

        var image = inputImage.cropped(to: cropRect)
        let scaleX = scaledSize.width / image.extent.width
        let scaleY = scaledSize.height / image.extent.height

        image = image.clamped(to: cropRect)
        image = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        image = image.cropped(to: CGRect(
            x: cropRect.origin.x * scaleX,
            y: cropRect.origin.y * scaleY,
            width: scaledSize.width,
            height: scaledSize.height
        ))
        image = image.transformed(by: CGAffineTransform(
            translationX: -image.extent.origin.x,
            y: -image.extent.origin.y
        ))

        return image
    }

    static func remapLegacyLandmarks(
        _ rawPoints: [(x: CGFloat, y: CGFloat)],
        normalizedCropRect: CGRect,
        mirroredHorizontally: Bool
    ) -> [EarLandmarksResult.Point] {
        let cropRectTopLeft = normalizedCropRect.flippedToTopLeft()

        return rawPoints.map { point in
            let pointX = mirroredHorizontally ? (1.0 - point.x) : point.x
            let pointY = point.y
            return EarLandmarksResult.Point(
                x: Double(pointX * cropRectTopLeft.width + cropRectTopLeft.origin.x),
                y: Double(pointY * cropRectTopLeft.height + cropRectTopLeft.origin.y)
            )
        }
    }

    static func validateMappedLandmarks(
        _ points: [EarLandmarksResult.Point],
        within normalizedCropRect: CGRect,
        minimumInsideRatio: Double = 0.6
    ) -> Bool {
        guard !points.isEmpty else { return false }

        let cropRectTopLeft = normalizedCropRect.flippedToTopLeft()
        let minX = Double(cropRectTopLeft.origin.x)
        let maxX = Double(cropRectTopLeft.maxX)
        let minY = Double(cropRectTopLeft.origin.y)
        let maxY = Double(cropRectTopLeft.maxY)

        let insideCount = points.reduce(into: 0) { partial, point in
            if point.x >= minX, point.x <= maxX, point.y >= minY, point.y <= maxY {
                partial += 1
            }
        }
        let insideRatio = Double(insideCount) / Double(points.count)
        return insideRatio >= minimumInsideRatio
    }

    static func parseLegacyLandmarkPoints(_ array: MLMultiArray) throws -> [(x: CGFloat, y: CGFloat)] {
        let shape = array.shape.map(\.intValue)
        guard shape.count == 2, shape[1] == 2 else {
            throw ServiceError.predictionFailed("Unexpected output shape: \(array.shape)")
        }

        if array.dataType != .double && array.dataType != .float32 && array.dataType != .float16 {
            throw ServiceError.predictionFailed("Unexpected output dtype: \(String(describing: array.dataType))")
        }

        var points: [(x: CGFloat, y: CGFloat)] = []
        points.reserveCapacity(shape[0])
        for index in 0..<shape[0] {
            let x = array[[NSNumber(value: index), NSNumber(value: 0)]].doubleValue
            let y = array[[NSNumber(value: index), NSNumber(value: 1)]].doubleValue
            points.append((CGFloat(x), CGFloat(y)))
        }
        return points
    }

    private func detectBoundingBox(in image: CIImage) -> DetectionStageResult? {
        var boundingBox = CGRect.zero
        var confidence: Float = 0

        do {
            Log.ml.debug("Ear detection start")
            try earTracker.synchronousAnalyze(
                image,
                orientation: .up,
                boundingBoxOut: &boundingBox,
                confidenceOut: &confidence
            )
        } catch {
            Log.ml.error("Ear tracker error: \(error.localizedDescription, privacy: .public)")
            if debugLogsEnabled {
                Log.ml.debug("Tracker threw error: \(error.localizedDescription, privacy: .public)")
            }
            return nil
        }

        if debugLogsEnabled {
            Log.ml.debug("Tracker conf=\(confidence, privacy: .public), bbox=\(String(describing: boundingBox), privacy: .public)")
        }

        guard boundingBox.width > 0, boundingBox.height > 0 else {
            if debugLogsEnabled {
                Log.ml.debug("No bbox (zero-size)")
            }
            return nil
        }

        guard confidence >= minTrackerConfidence else {
            if debugLogsEnabled {
                Log.ml.debug("Rejected: conf \(confidence, privacy: .public) < min \(self.minTrackerConfidence, privacy: .public)")
            }
            return nil
        }

        return DetectionStageResult(boundingBox: boundingBox, confidence: confidence)
    }

    private func prepareLandmarkCrop(from image: CIImage, boundingBox: CGRect) throws -> LandmarkPreparationResult {
        let normalizedCropRect = boundingBox
            .expanded(by: landmarkBBoxExpansionFraction)
            .clamped01()

        let preparedImage = Self.cropAndScaleForLandmarks(
            image,
            normalizedCropRect: normalizedCropRect,
            scaledSize: Self.landmarkInputSize
        )
        let pixelBuffer = try makeBGRA300(from: preparedImage)

        if debugLogsEnabled {
            Log.ml.debug("Prepared crop extent=\(String(describing: preparedImage.extent), privacy: .public)")
            Log.ml.debug("Prepared normalized crop=\(String(describing: normalizedCropRect), privacy: .public)")
        }

        return LandmarkPreparationResult(
            inputImage: preparedImage,
            normalizedCropRect: normalizedCropRect,
            pixelBuffer: pixelBuffer
        )
    }

    private func runLandmarkInference(with pixelBuffer: CVPixelBuffer) throws -> [(x: CGFloat, y: CGFloat)] {
        var observations: [VNCoreMLFeatureValueObservation] = []
        var requestFailure: Error?
        let request = VNCoreMLRequest(model: vnModel) { request, error in
            requestFailure = error
            observations = request.results as? [VNCoreMLFeatureValueObservation] ?? []
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw ServiceError.predictionFailed(error.localizedDescription)
        }

        if let requestFailure {
            throw ServiceError.predictionFailed(requestFailure.localizedDescription)
        }

        guard let array = observations.first?.featureValue.multiArrayValue else {
            logValidationFailure(.landmarkModelError, detail: "No VNCoreMLFeatureValueObservation results")
            throw ServiceError.predictionFailed("No landmark multi-array output")
        }

        if debugLogsEnabled {
            let preview = Self.previewValues(in: array, limit: 6)
            Log.ml.debug("Landmark output shape=\(String(describing: array.shape), privacy: .public), preview=\(preview, privacy: .public)")
        }

        do {
            return try Self.parseLegacyLandmarkPoints(array)
        } catch {
            logValidationFailure(.unexpectedOutputShape, detail: error.localizedDescription)
            throw error
        }
    }

    private func handleLandmarkValidationFailure(_ failure: LandmarkValidationFailure) -> [EarLandmarksResult.Point] {
        logValidationFailure(failure, detail: "Returning bbox-only result")
        return []
    }

    private func logValidationFailure(_ failure: LandmarkValidationFailure, detail: String) {
        Log.ml.error("Ear landmark validation failure [\(failure.rawValue, privacy: .public)]: \(detail, privacy: .public)")
    }

    private static func findModelURL(resource: String) -> URL? {
        if let url = Bundle.main.url(forResource: resource, withExtension: "mlmodelc") { return url }
        let fusionBundle = Bundle(for: SCEarTracking.self)
        if let url = fusionBundle.url(forResource: resource, withExtension: "mlmodelc") { return url }
        return nil
    }

    private func makeBGRA300(from image: CIImage) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(Self.landmarkInputSize.width),
            Int(Self.landmarkInputSize.height),
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw ServiceError.pixelBufferCreateFailed
        }

        ciContext.render(image, to: pixelBuffer)
        return pixelBuffer
    }

    private static func previewValues(in array: MLMultiArray, limit: Int) -> String {
        let shape = array.shape.map(\.intValue)
        guard shape.count == 2, shape[1] == 2 else { return "[]" }

        let rowCount = min(shape[0], max(0, limit / 2))
        var preview: [String] = []
        for index in 0..<rowCount {
            let x = array[[NSNumber(value: index), NSNumber(value: 0)]].doubleValue
            let y = array[[NSNumber(value: index), NSNumber(value: 1)]].doubleValue
            preview.append(String(format: "(%.4f, %.4f)", x, y))
        }
        return "[" + preview.joined(separator: ", ") + "]"
    }

    private static func previewValues(from points: [(x: CGFloat, y: CGFloat)], limit: Int) -> String {
        let preview = points.prefix(limit).map { point in
            String(format: "(%.4f, %.4f)", point.x, point.y)
        }
        return "[" + preview.joined(separator: ", ") + "]"
    }

    private static func payloadRect(from rect: CGRect) -> DebugArtifactPayload.RectPayload {
        DebugArtifactPayload.RectPayload(
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            width: Double(rect.size.width),
            height: Double(rect.size.height)
        )
    }

    private static func payloadPoint(from point: CGPoint) -> DebugArtifactPayload.PointPayload {
        DebugArtifactPayload.PointPayload(x: Double(point.x), y: Double(point.y))
    }

    #if DEBUG
    private static func uiImage(from image: CIImage) -> UIImage? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func debugWrite(_ image: CIImage, named name: String) {
        guard let image = uiImage(from: image) else { return }
        debugWrite(image, named: name)
    }

    private static func debugWrite(_ image: UIImage, named name: String) {
        let url = debugArtifactsDirectory().appendingPathComponent("\(name).png")
        guard let data = image.pngData() else { return }
        try? data.write(to: url, options: [.atomic])
        Log.ml.debug("Wrote ear landmark debug image to \(url.path, privacy: .public)")
    }

    private static func writeDebugPayload(_ payload: DebugArtifactPayload) {
        let url = debugArtifactsDirectory().appendingPathComponent("ear-landmark-debug.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: url, options: [.atomic])
        Log.ml.debug("Wrote ear landmark debug payload to \(url.path, privacy: .public)")
    }

    private static func readDebugPayload() -> DebugArtifactPayload? {
        let url = debugArtifactsDirectory().appendingPathComponent("ear-landmark-debug.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DebugArtifactPayload.self, from: data)
    }

    private static func debugPayload(
        _ payload: DebugArtifactPayload,
        withRenderLayout layout: OverlayLayout,
        flipX: Bool
    ) -> DebugArtifactPayload {
        DebugArtifactPayload(
            detectorBoundingBox: payload.detectorBoundingBox,
            displayBoundingBox: payload.displayBoundingBox,
            landmarkCropRect: payload.landmarkCropRect,
            rawLandmarkPreview: payload.rawLandmarkPreview,
            mappedLandmarks: payload.mappedLandmarks,
            renderedLandmarks: layout.landmarkPoints.map(Self.payloadPoint(from:)),
            renderedBoundingBox: layout.boundingBoxRect.map(Self.payloadRect(from:)),
            overlayFlipX: flipX,
            landmarkRenderOrigin: "topLeft",
            verificationSource: payload.verificationSource,
            usedPreviewSnapshotFallback: payload.usedPreviewSnapshotFallback,
            verificationImageWidth: payload.verificationImageWidth,
            verificationImageHeight: payload.verificationImageHeight,
            validationFailure: payload.validationFailure,
            outputPath: payload.outputPath
        )
    }

    private static func debugArtifactsDirectory() -> URL {
        let baseURL: URL
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            baseURL = documentsURL
        } else {
            baseURL = FileManager.default.temporaryDirectory
        }
        let directory = baseURL
            .appendingPathComponent("Scans", isDirectory: true)
            .appendingPathComponent("EarDebug", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    #endif
}

private extension CGRect {
    func expanded(by fraction: CGFloat) -> CGRect {
        let dx = size.width * fraction
        let dy = size.height * fraction
        return insetBy(dx: -dx, dy: -dy)
    }

    func clamped01() -> CGRect {
        let x = max(0, min(1, origin.x))
        let y = max(0, min(1, origin.y))
        let maxWidth = 1 - x
        let maxHeight = 1 - y
        let width = max(0, min(maxWidth, size.width))
        let height = max(0, min(maxHeight, size.height))
        return CGRect(x: x, y: y, width: width, height: height)
    }

    func flippedToTopLeft() -> CGRect {
        CGRect(
            x: origin.x,
            y: 1.0 - origin.y - size.height,
            width: size.width,
            height: size.height
        )
    }
}

private extension UIImage {
    func normalizedCGImage() -> CGImage? {
        if imageOrientation == .up, let cgImage { return cgImage }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return image.cgImage
    }
}
