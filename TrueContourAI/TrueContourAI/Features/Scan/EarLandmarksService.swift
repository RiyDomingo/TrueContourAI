import Foundation
import CoreML
import CoreImage
import UIKit
import StandardCyborgFusion

struct EarLandmarksResult: Codable {
    struct Point: Codable { let x: Double; let y: Double } // normalized 0..1
    struct Rect: Codable { let x: Double; let y: Double; let w: Double; let h: Double } // normalized 0..1

    let confidence: Double
    let earBoundingBox: Rect
    let landmarks: [Point] // 0 or 5 points
    let usedLeftEarMirroringHeuristic: Bool
}

final class EarLandmarksService {

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

    // MARK: - Tuning knobs (RELAXED + bbox-first)

    /// Very relaxed. If this were too high, you’d only get thumbnail.png.
    /// We keep it low so overlays reappear while debugging.
    private let minTrackerConfidence: Float = 0.10

    /// Crop expansion. Keep moderate.
    private let bboxExpansionFraction: CGFloat = 0.18

    /// Clamp landmark model outputs to 0..1 before mapping back.
    private let clampLandmarksToUnitRange: Bool = true

    #if DEBUG
    private let debugLogsEnabled: Bool = true
    #else
    private let debugLogsEnabled: Bool = false
    #endif

    // MARK: - Internals

    private let ciContext = CIContext()
    private let earTracker: SCEarTracking
    private let landmarkModel: MLModel

    init() throws {
        guard let trackingURL = Self.findModelURL(resource: "SCEarTrackingModel") else {
            throw ServiceError.modelNotFound("SCEarTrackingModel")
        }
        guard let landmarkURL = Self.findModelURL(resource: "SCEarLandmarking") else {
            throw ServiceError.modelNotFound("SCEarLandmarking")
        }

        self.earTracker = SCEarTracking(modelURL: trackingURL, delegate: nil)

        let config = MLModelConfiguration()
        self.landmarkModel = try MLModel(contentsOf: landmarkURL, configuration: config)
        Log.ml.info("EarLandmarksService initialized")
    }

    /// Detect ear bbox + landmarks from a UIImage.
    /// - Returns: nil only if ear tracker finds no bbox (or confidence too low).
    /// - IMPORTANT: if tracker finds a bbox but landmarking fails, this returns bbox-only (0 landmarks),
    ///   so your export still writes the green-box overlay and you can debug.
    func detect(in uiImage: UIImage) throws -> EarLandmarksResult? {
        guard let cg = uiImage.normalizedCGImage() else { throw ServiceError.cgImageMissing }

        let ciImage = CIImage(cgImage: cg)
        let W = ciImage.extent.width
        let H = ciImage.extent.height

        var bbox = CGRect.zero
        var conf: Float = 0

        do {
            Log.ml.debug("Ear detection start")
            try earTracker.synchronousAnalyze(
                ciImage,
                orientation: .up,
                boundingBoxOut: &bbox,
                confidenceOut: &conf
            )
        } catch {
            Log.ml.error("Ear tracker error: \(error.localizedDescription, privacy: .public)")
            if debugLogsEnabled {
                Log.ml.debug("Tracker threw error: \(error.localizedDescription, privacy: .public)")
            }
            return nil
        }

        if debugLogsEnabled {
            Log.ml.debug("Tracker conf=\(conf, privacy: .public), bbox=\(String(describing: bbox), privacy: .public)")
        }

        guard bbox.width > 0, bbox.height > 0 else {
            if debugLogsEnabled {
                Log.ml.debug("No bbox (zero-size)")
            }
            return nil
        }

        guard conf >= minTrackerConfidence else {
            if debugLogsEnabled {
                Log.ml.debug("Rejected: conf \(conf, privacy: .public) < min \(self.minTrackerConfidence, privacy: .public)")
            }
            return nil
        }

        // Expand and clamp normalized bbox (assuming bbox is normalized 0..1)
        let expanded = bbox.expanded(by: bboxExpansionFraction).clamped01()

        // Convert expanded normalized rect -> pixels
        let cropRectPx = CGRect(
            x: expanded.origin.x * W,
            y: expanded.origin.y * H,
            width: expanded.size.width * W,
            height: expanded.size.height * H
        )

        // Square crop around ear region
        let squareCropPx = cropRectPx
            .squaredAboutCenter()
            .clamped(to: ciImage.extent)

        var crop = ciImage.cropped(to: squareCropPx)

        // Heuristic: mirror crop if bbox is on left half
        let isLeftEarHeuristic = expanded.midX < 0.5
        if isLeftEarHeuristic { crop = crop.horizontallyFlipped() }

        // Default: bbox-only result (landmarks empty). We’ll try to fill landmarks next.
        var mappedLandmarks: [EarLandmarksResult.Point] = []

        do {
            let pb300 = try makeBGRA300(from: crop)

            let input = try MLDictionaryFeatureProvider(dictionary: [
                "inputs__image_tensor__0": MLFeatureValue(pixelBuffer: pb300)
            ])

            let out = try landmarkModel.prediction(from: input)

            guard let arr = out.featureValue(for: "normed_coordinates_yx")?.multiArrayValue else {
                throw ServiceError.predictionFailed("Missing output normed_coordinates_yx")
            }

            let pointsInCrop = try parseNormedYX(arr) // normalized 0..1 in crop space
            mappedLandmarks = Self.mapLandmarks(
                pointsInCrop: pointsInCrop,
                expandedBBox: expanded,
                squareCropPx: squareCropPx,
                imageSize: CGSize(width: W, height: H),
                isLeftEarHeuristic: isLeftEarHeuristic,
                clampToUnitRange: clampLandmarksToUnitRange
            )

            if debugLogsEnabled {
                Log.ml.debug("Landmarking OK. points=\(mappedLandmarks.count, privacy: .public)")
            }

        } catch {
            // IMPORTANT: Do NOT fail the whole detection. Return bbox-only so you still get overlays.
            Log.ml.error("Landmarking failed: \(error.localizedDescription, privacy: .public)")
            if debugLogsEnabled {
                Log.ml.debug("Landmarking failed (bbox-only): \(error.localizedDescription, privacy: .public)")
            }
            mappedLandmarks = []
        }

        return EarLandmarksResult(
            confidence: Double(conf),
            earBoundingBox: .init(
                x: Double(expanded.origin.x),
                y: Double(expanded.origin.y),
                w: Double(expanded.size.width),
                h: Double(expanded.size.height)
            ),
            landmarks: mappedLandmarks,
            usedLeftEarMirroringHeuristic: isLeftEarHeuristic
        )
    }

    // MARK: - Overlay rendering (verification)

    func renderOverlay(on baseImage: UIImage,
                       result: EarLandmarksResult,
                       drawBoundingBox: Bool = true,
                       flipY: Bool = true,
                       flipX: Bool = false) -> UIImage {

        let renderer = UIGraphicsImageRenderer(size: baseImage.size)
        return renderer.image { _ in
            baseImage.draw(in: CGRect(origin: .zero, size: baseImage.size))

            let W = baseImage.size.width
            let H = baseImage.size.height

            func mapPoint(nx: Double, ny: Double) -> CGPoint {
                let fx = flipX ? (1.0 - nx) : nx
                let fy = flipY ? (1.0 - ny) : ny
                return CGPoint(x: CGFloat(fx) * W, y: CGFloat(fy) * H)
            }

            if drawBoundingBox {
                let bx = flipX ? (1.0 - result.earBoundingBox.x - result.earBoundingBox.w) : result.earBoundingBox.x
                let by = result.earBoundingBox.y

                let topLeft = mapPoint(nx: bx, ny: by + result.earBoundingBox.h)
                let bottomRight = mapPoint(nx: bx + result.earBoundingBox.w, ny: by)

                let rect = CGRect(
                    x: min(topLeft.x, bottomRight.x),
                    y: min(topLeft.y, bottomRight.y),
                    width: abs(bottomRight.x - topLeft.x),
                    height: abs(bottomRight.y - topLeft.y)
                )

                let path = UIBezierPath(rect: rect)
                UIColor.systemGreen.withAlphaComponent(0.9).setStroke()
                path.lineWidth = max(2, min(W, H) * 0.006)
                path.stroke()
            }

            // Only draw dots if we actually have landmarks
            guard !result.landmarks.isEmpty else { return }

            let dotRadius = max(3.5, min(W, H) * 0.012)
            for (idx, p) in result.landmarks.enumerated() {
                let pt = mapPoint(nx: p.x, ny: p.y)

                let color: UIColor = (idx % 2 == 0) ? .systemYellow : .systemOrange
                color.withAlphaComponent(0.95).setFill()

                let dotRect = CGRect(
                    x: pt.x - dotRadius,
                    y: pt.y - dotRadius,
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
    }

    // MARK: - Helpers

    static func mapLandmarks(
        pointsInCrop: [(x: CGFloat, y: CGFloat)],
        expandedBBox: CGRect,
        squareCropPx: CGRect,
        imageSize: CGSize,
        isLeftEarHeuristic: Bool,
        clampToUnitRange: Bool
    ) -> [EarLandmarksResult.Point] {
        func mapPoints(swapXY: Bool) -> [EarLandmarksResult.Point] {
            var out: [EarLandmarksResult.Point] = []
            out.reserveCapacity(pointsInCrop.count)
            for p in pointsInCrop {
                var xInCrop = swapXY ? p.y : p.x
                var yInCrop = swapXY ? p.x : p.y

                if clampToUnitRange {
                    xInCrop = max(0, min(1, xInCrop))
                    yInCrop = max(0, min(1, yInCrop))
                }

                if isLeftEarHeuristic { xInCrop = 1.0 - xInCrop }

                let xAbs = squareCropPx.origin.x + xInCrop * squareCropPx.size.width
                let yAbs = squareCropPx.origin.y + yInCrop * squareCropPx.size.height

                out.append(.init(
                    x: Double(xAbs / imageSize.width),
                    y: Double(yAbs / imageSize.height)
                ))
            }
            return out
        }

        func insideRatio(_ points: [EarLandmarksResult.Point]) -> Double {
            guard !points.isEmpty else { return 0 }
            var inside = 0
            let minX = Double(expandedBBox.origin.x)
            let maxX = Double(expandedBBox.origin.x + expandedBBox.size.width)
            let minY = Double(expandedBBox.origin.y)
            let maxY = Double(expandedBBox.origin.y + expandedBBox.size.height)
            for p in points {
                if p.x >= minX, p.x <= maxX, p.y >= minY, p.y <= maxY { inside += 1 }
            }
            return Double(inside) / Double(points.count)
        }

        let mappedDefault = mapPoints(swapXY: false)
        let mappedSwapped = mapPoints(swapXY: true)
        let ratioDefault = insideRatio(mappedDefault)
        let ratioSwapped = insideRatio(mappedSwapped)

        return ratioSwapped > ratioDefault ? mappedSwapped : mappedDefault
    }

    private static func findModelURL(resource: String) -> URL? {
        if let url = Bundle.main.url(forResource: resource, withExtension: "mlmodelc") { return url }
        let fusionBundle = Bundle(for: SCEarTracking.self)
        if let url = fusionBundle.url(forResource: resource, withExtension: "mlmodelc") { return url }
        return nil
    }

    private func makeBGRA300(from image: CIImage) throws -> CVPixelBuffer {
        var pb: CVPixelBuffer?

        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            300, 300,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pb
        )

        guard status == kCVReturnSuccess, let pixelBuffer = pb else {
            throw ServiceError.pixelBufferCreateFailed
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let sx = 300.0 / image.extent.width
        let sy = 300.0 / image.extent.height
        let scaled = image.transformed(by: CGAffineTransform(scaleX: sx, y: sy))

        ciContext.render(
            scaled,
            to: pixelBuffer,
            bounds: CGRect(x: 0, y: 0, width: 300, height: 300),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return pixelBuffer
    }

    private func parseNormedYX(_ arr: MLMultiArray) throws -> [(x: CGFloat, y: CGFloat)] {
        let s = arr.shape.map { $0.intValue }
        guard s.count == 2, s[1] == 2 else {
            throw ServiceError.predictionFailed("Unexpected output shape: \(arr.shape)")
        }
        let n = s[0]

        func v(_ i: Int, _ j: Int) -> Double {
            arr[[NSNumber(value: i), NSNumber(value: j)]].doubleValue
        }

        var pts: [(CGFloat, CGFloat)] = []
        pts.reserveCapacity(n)
        for i in 0..<n {
            let y = v(i, 0)
            let x = v(i, 1)
            pts.append((CGFloat(x), CGFloat(y)))
        }
        return pts
    }
}

private extension CGRect {
    var midX: CGFloat { origin.x + size.width * 0.5 }

    func expanded(by fraction: CGFloat) -> CGRect {
        let dx = size.width * fraction
        let dy = size.height * fraction
        return insetBy(dx: -dx, dy: -dy)
    }

    func clamped01() -> CGRect {
        let x = max(0, min(1, origin.x))
        let y = max(0, min(1, origin.y))
        let maxW = 1 - x
        let maxH = 1 - y
        let w = max(0, min(maxW, size.width))
        let h = max(0, min(maxH, size.height))
        return CGRect(x: x, y: y, width: w, height: h)
    }

    func squaredAboutCenter() -> CGRect {
        let cx = midX
        let cy = midY
        let side = max(width, height)
        return CGRect(x: cx - side * 0.5, y: cy - side * 0.5, width: side, height: side)
    }

    func clamped(to bounds: CGRect) -> CGRect {
        var r = self
        if r.origin.x < bounds.origin.x { r.origin.x = bounds.origin.x }
        if r.origin.y < bounds.origin.y { r.origin.y = bounds.origin.y }
        if r.maxX > bounds.maxX { r.origin.x -= (r.maxX - bounds.maxX) }
        if r.maxY > bounds.maxY { r.origin.y -= (r.maxY - bounds.maxY) }

        let maxW = bounds.maxX - r.origin.x
        let maxH = bounds.maxY - r.origin.y
        r.size.width = min(r.size.width, maxW)
        r.size.height = min(r.size.height, maxH)
        return r
    }
}

private extension CIImage {
    func horizontallyFlipped() -> CIImage {
        let e = extent
        let t = CGAffineTransform(translationX: e.midX, y: 0)
            .scaledBy(x: -1, y: 1)
            .translatedBy(x: -e.midX, y: 0)
        return transformed(by: t)
    }
}

private extension UIImage {
    func normalizedCGImage() -> CGImage? {
        if imageOrientation == .up, let cgImage { return cgImage }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let img = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
        return img.cgImage
    }
}
