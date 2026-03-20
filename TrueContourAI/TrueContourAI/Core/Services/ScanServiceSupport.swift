import Foundation
import UIKit
import StandardCyborgFusion

struct ScanFolderValidator {
    let fileManager: FileManager = .default

    func sceneGLTFURL(in folderURL: URL) -> URL? {
        let gltfURL = folderURL.appendingPathComponent("scene.gltf")
        return fileManager.fileExists(atPath: gltfURL.path) ? gltfURL : nil
    }

    func isValidScanFolder(_ folderURL: URL) -> Bool {
        sceneGLTFURL(in: folderURL) != nil
    }
}

struct ScanStorageRepository {
    let scansRootURL: URL
    let defaults: UserDefaults
    let lastScanFolderPathKey: String
    let fileManager: FileManager = .default
    let folderValidator = ScanFolderValidator()

    func ensureScansRootFolder() -> Result<Void, Error> {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: scansRootURL.path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                let error = NSError(
                    domain: "ScanStorageRepository",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Scans root path exists but is not a directory."]
                )
                return .failure(error)
            }
            return .success(())
        }
        do {
            try fileManager.createDirectory(at: scansRootURL, withIntermediateDirectories: true)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func listScans() -> [ScanItem] {
        let urls = (try? fileManager.contentsOfDirectory(
            at: scansRootURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var items: [ScanItem] = []
        for folder in urls where folder.hasDirectoryPath {
            guard let gltfURL = folderValidator.sceneGLTFURL(in: folder) else { continue }
            let values = try? folder.resourceValues(forKeys: [.contentModificationDateKey])
            let date = values?.contentModificationDate ?? Date.distantPast
            let overlay = folder.appendingPathComponent("thumbnail_ear_overlay.png")
            let thumb = folder.appendingPathComponent("thumbnail.png")
            let thumbURL: URL?
            if fileManager.fileExists(atPath: overlay.path) { thumbURL = overlay }
            else if fileManager.fileExists(atPath: thumb.path) { thumbURL = thumb }
            else { thumbURL = nil }

            items.append(.init(
                folderURL: folder,
                displayName: folder.lastPathComponent,
                date: date,
                thumbnailURL: thumbURL,
                sceneGLTFURL: gltfURL
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    func resolveLastScanFolderURL() -> URL? {
        if let path = defaults.string(forKey: lastScanFolderPathKey) {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if folderValidator.isValidScanFolder(url) { return url }
            defaults.removeObject(forKey: lastScanFolderPathKey)
        }

        return listScans().first?.folderURL
    }

    func setLastScanFolder(_ folderURL: URL) {
        defaults.set(folderURL.path, forKey: lastScanFolderPathKey)
    }

    func clearLastScanFolderIfMatches(_ folderURL: URL) {
        if defaults.string(forKey: lastScanFolderPathKey) == folderURL.path {
            defaults.removeObject(forKey: lastScanFolderPathKey)
        }
    }

    func updateLastScanFolderIfMatches(oldURL: URL, newURL: URL) {
        if defaults.string(forKey: lastScanFolderPathKey) == oldURL.path {
            setLastScanFolder(newURL)
        }
    }

    func renameScanFolder(_ item: ScanItem, to newURL: URL) -> Result<Void, Error> {
        do {
            try fileManager.moveItem(at: item.folderURL, to: newURL)
            updateLastScanFolderIfMatches(oldURL: item.folderURL, newURL: newURL)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func deleteScanFolder(_ item: ScanItem) -> Result<Void, Error> {
        do {
            try fileManager.removeItem(at: item.folderURL)
            clearLastScanFolderIfMatches(item.folderURL)
            return .success(())
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError {
                clearLastScanFolderIfMatches(item.folderURL)
                return .success(())
            }
            return .failure(error)
        }
    }

    func deleteAllScans() -> Result<Void, Error> {
        do {
            let contents = try fileManager.contentsOfDirectory(at: scansRootURL, includingPropertiesForKeys: nil)
            for url in contents {
                try fileManager.removeItem(at: url)
            }
            defaults.removeObject(forKey: lastScanFolderPathKey)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}

struct ScanFolderExporter {
    let scansRootURL: URL
    let timestampFormatter: ISO8601DateFormatter
    let writeOBJ: (SCMesh, URL) throws -> Void
    let writeEarArtifacts: (URL, ScanEarArtifacts) -> Void
    let writeScanSummary: (URL, ScanSummary) -> Void
    let cleanupFolder: (URL) -> Void

    func export(
        mesh: SCMesh,
        scene: SCScene,
        thumbnail: UIImage?,
        earArtifacts: ScanEarArtifacts?,
        scanSummary: ScanSummary?,
        includeGLTF: Bool,
        includeOBJ: Bool
    ) -> ScanExportResult {
#if DEBUG
        let exportStart = CFAbsoluteTimeGetCurrent()
        var createFolderMs = 0
        var gltfWriteMs = 0
        var thumbnailWriteMs: Int?
        var objWriteMs: Int?
        var earArtifactsWriteMs: Int?
        var summaryWriteMs: Int?
#endif
        guard includeGLTF else {
            return .failure(L("settings.export.minimum.message"))
        }

        let timestamp = timestampFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let folderURL = scansRootURL.appendingPathComponent(timestamp, isDirectory: true)

        do {
#if DEBUG
            let createFolderStart = CFAbsoluteTimeGetCurrent()
#endif
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
#if DEBUG
            createFolderMs = Int((CFAbsoluteTimeGetCurrent() - createFolderStart) * 1000)
#endif
        } catch {
            Log.export.error("Failed to create scan folder: \(error.localizedDescription, privacy: .public)")
            return .failure(String(format: L("scan.service.createFolderFailed"), error.localizedDescription))
        }

        let gltfURL = folderURL.appendingPathComponent("scene.gltf")
#if DEBUG
        let gltfWriteStart = CFAbsoluteTimeGetCurrent()
#endif
        scene.writeToGLTF(atPath: gltfURL.path)
#if DEBUG
        gltfWriteMs = Int((CFAbsoluteTimeGetCurrent() - gltfWriteStart) * 1000)
#endif
        if !FileManager.default.fileExists(atPath: gltfURL.path) {
            Log.export.error("Failed to write scene.gltf at \(gltfURL.path, privacy: .private)")
            cleanupFolder(folderURL)
            return .failure(L("scan.service.writeGLTFFailed"))
        }

        autoreleasepool {
            if let thumbnail, let png = thumbnail.pngData() {
                let thumbnailURL = folderURL.appendingPathComponent("thumbnail.png")
#if DEBUG
                let thumbnailWriteStart = CFAbsoluteTimeGetCurrent()
#endif
                do { try png.write(to: thumbnailURL, options: [.atomic]) }
                catch {
                    Log.export.error("Failed to write thumbnail.png: \(error.localizedDescription, privacy: .public)")
                }
#if DEBUG
                thumbnailWriteMs = Int((CFAbsoluteTimeGetCurrent() - thumbnailWriteStart) * 1000)
#endif
            }
        }

        if includeOBJ {
            let objURL = folderURL.appendingPathComponent("head_mesh.obj")
            do {
#if DEBUG
                let objWriteStart = CFAbsoluteTimeGetCurrent()
#endif
                try writeOBJ(mesh, objURL)
#if DEBUG
                objWriteMs = Int((CFAbsoluteTimeGetCurrent() - objWriteStart) * 1000)
#endif
            } catch {
                Log.export.error("Failed to write OBJ: \(error.localizedDescription, privacy: .public)")
                cleanupFolder(folderURL)
                return .failure(String(format: L("scan.service.writeOBJFailed"), error.localizedDescription))
            }
        }

        if let earArtifacts {
#if DEBUG
            let earArtifactsWriteStart = CFAbsoluteTimeGetCurrent()
#endif
            writeEarArtifacts(folderURL, earArtifacts)
#if DEBUG
            earArtifactsWriteMs = Int((CFAbsoluteTimeGetCurrent() - earArtifactsWriteStart) * 1000)
#endif
        }
        if let scanSummary {
#if DEBUG
            let summaryWriteStart = CFAbsoluteTimeGetCurrent()
#endif
            writeScanSummary(folderURL, scanSummary)
#if DEBUG
            summaryWriteMs = Int((CFAbsoluteTimeGetCurrent() - summaryWriteStart) * 1000)
#endif
        }

#if DEBUG
        ScanDiagnostics.recordExportTimings(
            .init(
                totalMs: Int((CFAbsoluteTimeGetCurrent() - exportStart) * 1000),
                createFolderMs: createFolderMs,
                gltfWriteMs: gltfWriteMs,
                thumbnailWriteMs: thumbnailWriteMs,
                objWriteMs: objWriteMs,
                earArtifactsWriteMs: earArtifactsWriteMs,
                summaryWriteMs: summaryWriteMs
            )
        )
#endif
        Log.export.info("Export completed: \(folderURL.lastPathComponent, privacy: .public)")
        return .success(folderURL: folderURL)
    }
}

struct ScanUITestSeedRepository {
    let scansRootURL: URL
    let fileManager: FileManager

    func seedPreviewableScanIfNeeded() {
        let seedFolder = scansRootURL.appendingPathComponent("UITest-Seed", isDirectory: true)
        if fileManager.fileExists(atPath: seedFolder.path) { return }
        try? fileManager.createDirectory(at: seedFolder, withIntermediateDirectories: true)
        let gltfURL = seedFolder.appendingPathComponent("scene.gltf")
        let gltf = """
        {"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[]}]}
        """
        try? gltf.data(using: .utf8)?.write(to: gltfURL, options: [.atomic])
        let summaryURL = seedFolder.appendingPathComponent("scan_summary.json")
        let summary = ScanSummary(
            schemaVersion: 2,
            startedAt: Date(timeIntervalSince1970: 1_725_200_000),
            finishedAt: Date(timeIntervalSince1970: 1_725_200_005),
            durationSeconds: 5,
            overallConfidence: 0.7,
            completedPoses: 0,
            skippedPoses: 0,
            poseRecords: [],
            pointCountEstimate: 20_000,
            hadEarVerification: false,
            processingProfile: nil,
            derivedMeasurements: .init(
                sliceHeightNormalized: 0.5,
                circumferenceMm: 560,
                widthMm: 170,
                depthMm: 190,
                confidence: 0.7,
                status: "ok"
            )
        )
        if let summaryData = try? JSONEncoder().encode(summary) {
            try? summaryData.write(to: summaryURL, options: [.atomic])
        }
        let earViewURL = seedFolder.appendingPathComponent("ear_view.png")
        if let png = Self.makeEarVerificationPNG() {
            try? png.write(to: earViewURL, options: [.atomic])
        }
        let thumbnailURL = seedFolder.appendingPathComponent("thumbnail.png")
        if let png = makeThumbnailPNG() {
            try? png.write(to: thumbnailURL, options: [.atomic])
        }
        try? fileManager.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_725_200_005)],
            ofItemAtPath: seedFolder.path
        )
    }

    func seedMissingSceneScanIfNeeded() {
        let seedFolder = scansRootURL.appendingPathComponent("UITest-MissingScene", isDirectory: true)
        if fileManager.fileExists(atPath: seedFolder.path) { return }
        try? fileManager.createDirectory(at: seedFolder, withIntermediateDirectories: true)
        let thumbURL = seedFolder.appendingPathComponent("thumbnail.png")
        if let png = makeThumbnailPNG() {
            try? png.write(to: thumbURL, options: [.atomic])
        }
    }

    static func makeEarVerificationPNG() -> Data? {
        let size = CGSize(width: 320, height: 320)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(red: 0.90, green: 0.91, blue: 0.94, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor(red: 0.63, green: 0.45, blue: 0.34, alpha: 1).setFill()
            let outer = UIBezierPath(ovalIn: CGRect(x: 56, y: 28, width: 208, height: 260))
            outer.fill()

            UIColor(red: 0.83, green: 0.67, blue: 0.55, alpha: 1).setFill()
            let inner = UIBezierPath(ovalIn: CGRect(x: 86, y: 58, width: 148, height: 200))
            inner.fill()

            UIColor(red: 0.56, green: 0.33, blue: 0.26, alpha: 1).setStroke()
            let helix = UIBezierPath()
            helix.move(to: CGPoint(x: 103, y: 88))
            helix.addCurve(to: CGPoint(x: 122, y: 228), controlPoint1: CGPoint(x: 82, y: 124), controlPoint2: CGPoint(x: 80, y: 194))
            helix.addCurve(to: CGPoint(x: 210, y: 234), controlPoint1: CGPoint(x: 152, y: 250), controlPoint2: CGPoint(x: 188, y: 246))
            helix.lineWidth = 12
            helix.lineCapStyle = .round
            helix.stroke()

            let concha = UIBezierPath()
            concha.move(to: CGPoint(x: 182, y: 114))
            concha.addCurve(to: CGPoint(x: 142, y: 183), controlPoint1: CGPoint(x: 206, y: 136), controlPoint2: CGPoint(x: 185, y: 182))
            concha.addCurve(to: CGPoint(x: 202, y: 216), controlPoint1: CGPoint(x: 162, y: 189), controlPoint2: CGPoint(x: 188, y: 204))
            concha.lineWidth = 10
            concha.lineCapStyle = .round
            concha.stroke()
        }
        return image.pngData()
    }

    private func makeThumbnailPNG() -> Data? {
        let size = CGSize(width: 2, height: 2)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.systemTeal.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image?.pngData()
    }
}
