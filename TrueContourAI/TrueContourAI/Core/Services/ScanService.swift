import Foundation
import UIKit
import StandardCyborgFusion

final class ScanService {
    struct ScanSummary: Codable, Equatable {
        struct ProcessingProfile: Codable, Equatable {
            let outlierSigma: Float
            let decimateRatio: Float
            let cropBelowNeck: Bool
            let meshResolution: Int
            let meshSmoothness: Int
        }

        struct PoseRecord: Codable, Equatable {
            let pose: String
            let confidence: Float
            let status: String
        }

        struct DerivedMeasurements: Codable, Equatable {
            let sliceHeightNormalized: Float
            let circumferenceMm: Float
            let widthMm: Float
            let depthMm: Float
            let confidence: Float
            let status: String
        }

        let schemaVersion: Int
        let startedAt: Date
        let finishedAt: Date
        let durationSeconds: Double
        let overallConfidence: Float
        let completedPoses: Int?
        let skippedPoses: Int?
        let poseRecords: [PoseRecord]?
        let pointCountEstimate: Int
        let hadEarVerification: Bool
        let processingProfile: ProcessingProfile?
        let derivedMeasurements: DerivedMeasurements?

        enum CodingKeys: String, CodingKey {
            case schemaVersion
            case startedAt
            case finishedAt
            case durationSeconds
            case overallConfidence
            case completedPoses
            case skippedPoses
            case poseRecords
            case pointCountEstimate
            case hadEarVerification
            case processingProfile
            case derivedMeasurements
        }

        init(
            schemaVersion: Int = 2,
            startedAt: Date,
            finishedAt: Date,
            durationSeconds: Double,
            overallConfidence: Float,
            completedPoses: Int? = nil,
            skippedPoses: Int? = nil,
            poseRecords: [PoseRecord]? = nil,
            pointCountEstimate: Int,
            hadEarVerification: Bool,
            processingProfile: ProcessingProfile? = nil,
            derivedMeasurements: DerivedMeasurements? = nil
        ) {
            self.schemaVersion = schemaVersion
            self.startedAt = startedAt
            self.finishedAt = finishedAt
            self.durationSeconds = durationSeconds
            self.overallConfidence = overallConfidence
            self.completedPoses = completedPoses
            self.skippedPoses = skippedPoses
            self.poseRecords = poseRecords
            self.pointCountEstimate = pointCountEstimate
            self.hadEarVerification = hadEarVerification
            self.processingProfile = processingProfile
            self.derivedMeasurements = derivedMeasurements
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
            startedAt = try container.decode(Date.self, forKey: .startedAt)
            finishedAt = try container.decode(Date.self, forKey: .finishedAt)
            durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
            overallConfidence = try container.decode(Float.self, forKey: .overallConfidence)
            completedPoses = try container.decodeIfPresent(Int.self, forKey: .completedPoses)
            skippedPoses = try container.decodeIfPresent(Int.self, forKey: .skippedPoses)
            poseRecords = try container.decodeIfPresent([PoseRecord].self, forKey: .poseRecords)
            pointCountEstimate = try container.decode(Int.self, forKey: .pointCountEstimate)
            hadEarVerification = try container.decode(Bool.self, forKey: .hadEarVerification)
            processingProfile = try container.decodeIfPresent(ProcessingProfile.self, forKey: .processingProfile)
            derivedMeasurements = try container.decodeIfPresent(DerivedMeasurements.self, forKey: .derivedMeasurements)
        }
    }

    struct ScanItem {
        let folderURL: URL
        let displayName: String
        let date: Date
        let thumbnailURL: URL?
        let sceneGLTFURL: URL?
    }

    struct EarArtifacts {
        let earImage: UIImage
        let earResult: EarLandmarksResult
        let earOverlay: UIImage
    }

    enum ExportResult {
        case success(folderURL: URL)
        case failure(String)
    }

    let scansRootURL: URL
    private let defaults: UserDefaults
    private let lastScanFolderPathKey = "tc_last_scan_folder_path"
    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init(scansRootURL: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let scansRootURL {
            self.scansRootURL = scansRootURL
        } else {
            let documentsURL: URL
            if let resolvedDocumentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                documentsURL = resolvedDocumentsURL
            } else {
                let fallback = FileManager.default.temporaryDirectory
                Log.persistence.error("Document directory unavailable; using temporary directory for scans root: \(fallback.path, privacy: .public)")
                documentsURL = fallback
            }
            self.scansRootURL = documentsURL.appendingPathComponent("Scans", isDirectory: true)
        }
    }

    @discardableResult
    func ensureScansRootFolder() -> Result<Void, Error> {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: scansRootURL.path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                let error = NSError(
                    domain: "ScanService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Scans root path exists but is not a directory."]
                )
                Log.persistence.error("Scans root exists but is not a directory: \(self.scansRootURL.path, privacy: .public)")
                return .failure(error)
            }
            return .success(())
        }
        do {
            try FileManager.default.createDirectory(at: scansRootURL, withIntermediateDirectories: true)
            return .success(())
        } catch {
            Log.persistence.error("Failed to create scans root folder: \(error.localizedDescription, privacy: .public)")
            return .failure(error)
        }
    }

    func resolveGLTFFromFolder(_ folder: URL) -> URL? {
        let gltf = folder.appendingPathComponent("scene.gltf")
        return FileManager.default.fileExists(atPath: gltf.path) ? gltf : nil
    }

    func resolveOBJFromFolder(_ folder: URL) -> URL? {
        let obj = folder.appendingPathComponent("head_mesh.obj")
        return FileManager.default.fileExists(atPath: obj.path) ? obj : nil
    }

    func resolveScanSummary(from folder: URL) -> ScanSummary? {
        let summaryURL = folder.appendingPathComponent("scan_summary.json")
        guard FileManager.default.fileExists(atPath: summaryURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: summaryURL)
            return try JSONDecoder().decode(ScanSummary.self, from: data)
        } catch {
            Log.export.error("Failed to decode scan summary: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func listScans() -> [ScanItem] {
        if case .failure = ensureScansRootFolder() {
            return []
        }

        let fm = FileManager.default
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("ui-test-seed-scan") {
            _seedScanForUITestIfNeeded(fileManager: fm)
        }
        if ProcessInfo.processInfo.arguments.contains("ui-test-seed-missing-scene") {
            _seedMissingSceneScanForUITestIfNeeded(fileManager: fm)
        }
        #endif
        let urls = (try? fm.contentsOfDirectory(
            at: scansRootURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var items: [ScanItem] = []

        for folder in urls where folder.hasDirectoryPath {
            let values = try? folder.resourceValues(forKeys: [.contentModificationDateKey])
            let date = values?.contentModificationDate ?? Date.distantPast
            let displayName = folder.lastPathComponent

            let overlay = folder.appendingPathComponent("thumbnail_ear_overlay.png")
            let thumb = folder.appendingPathComponent("thumbnail.png")
            let thumbURL: URL?
            if fm.fileExists(atPath: overlay.path) { thumbURL = overlay }
            else if fm.fileExists(atPath: thumb.path) { thumbURL = thumb }
            else { thumbURL = nil }

            let gltfURL = resolveGLTFFromFolder(folder)

            items.append(.init(
                folderURL: folder,
                displayName: displayName,
                date: date,
                thumbnailURL: thumbURL,
                sceneGLTFURL: gltfURL
            ))
        }

        items.sort { $0.date > $1.date }
        Log.scan.info("Listed scans: \(items.count, privacy: .public)")
        return items
    }

    func listScansAsync(completion: @escaping ([ScanItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let items = self.listScans()
            DispatchQueue.main.async {
                completion(items)
            }
        }
    }

    private func _seedScanForUITestIfNeeded(fileManager fm: FileManager) {
        let seedFolder = scansRootURL.appendingPathComponent("UITest-Seed", isDirectory: true)
        if fm.fileExists(atPath: seedFolder.path) { return }
        try? fm.createDirectory(at: seedFolder, withIntermediateDirectories: true)
        let gltfURL = seedFolder.appendingPathComponent("scene.gltf")
        let gltf = """
        {"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[]}]}
        """
        try? gltf.data(using: .utf8)?.write(to: gltfURL, options: [.atomic])
    }

    private func _seedMissingSceneScanForUITestIfNeeded(fileManager fm: FileManager) {
        let seedFolder = scansRootURL.appendingPathComponent("UITest-MissingScene", isDirectory: true)
        if fm.fileExists(atPath: seedFolder.path) { return }
        try? fm.createDirectory(at: seedFolder, withIntermediateDirectories: true)
        let thumbURL = seedFolder.appendingPathComponent("thumbnail.png")
        if let png = _makeUITestThumbnailPNG() {
            try? png.write(to: thumbURL, options: [.atomic])
        }
    }

    private func _makeUITestThumbnailPNG() -> Data? {
        let size = CGSize(width: 2, height: 2)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.systemTeal.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image?.pngData()
    }

    func sceneForScan(_ item: ScanItem) -> SCScene? {
        let gltfURL = item.sceneGLTFURL ?? resolveGLTFFromFolder(item.folderURL)
        guard let gltfURL else { return nil }
        return SCScene(gltfAtPath: gltfURL.path)
    }

    func shareItems(for folderURL: URL) -> [Any] {
        [folderURL]
    }

    func shareItemsForScansRoot() -> [Any] {
        _ = ensureScansRootFolder()
        return [scansRootURL]
    }

    func resolveLastScanFolderURL() -> URL? {
        if let path = defaults.string(forKey: lastScanFolderPathKey) {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: scansRootURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var newestURL: URL?
        var newestDate = Date.distantPast
        for folder in urls where folder.hasDirectoryPath {
            let values = try? folder.resourceValues(forKeys: [.contentModificationDateKey])
            let date = values?.contentModificationDate ?? Date.distantPast
            if date > newestDate {
                newestDate = date
                newestURL = folder
            }
        }
        return newestURL
    }

    func resolveLastScanGLTFURL() -> URL? {
        if let folder = resolveLastScanFolderURL() {
            return resolveGLTFFromFolder(folder)
        }
        return nil
    }

    func resolveLastScanItem() -> ScanItem? {
        guard let folder = resolveLastScanFolderURL() else { return nil }
        return listScans().first { $0.folderURL == folder }
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

    enum RenameResult {
        case success(newURL: URL)
        case nameExists
        case invalidName
        case failure(Error)
    }

    func sanitizeFolderName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let comps = trimmed.components(separatedBy: invalid)
        let cleaned = comps.joined(separator: "-")
        return cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    func renameScanFolder(_ item: ScanItem, to newNameRaw: String) -> RenameResult {
        let newName = sanitizeFolderName(newNameRaw)
        guard !newName.isEmpty else { return .invalidName }

        let newURL = item.folderURL
            .deletingLastPathComponent()
            .appendingPathComponent(newName, isDirectory: true)

        if FileManager.default.fileExists(atPath: newURL.path) {
            return .nameExists
        }

        do {
            try FileManager.default.moveItem(at: item.folderURL, to: newURL)
            updateLastScanFolderIfMatches(oldURL: item.folderURL, newURL: newURL)
            return .success(newURL: newURL)
        } catch {
            return .failure(error)
        }
    }

    func deleteScanFolder(_ item: ScanItem) -> Result<Void, Error> {
        do {
            try FileManager.default.removeItem(at: item.folderURL)
            clearLastScanFolderIfMatches(item.folderURL)
            return .success(())
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain,
               nsError.code == NSFileNoSuchFileError {
                clearLastScanFolderIfMatches(item.folderURL)
                return .success(())
            }
            return .failure(error)
        }
    }

    func deleteAllScans() -> Result<Void, Error> {
        if case .failure(let error) = ensureScansRootFolder() {
            return .failure(error)
        }
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: scansRootURL, includingPropertiesForKeys: nil)
            for url in contents {
                try FileManager.default.removeItem(at: url)
            }
            defaults.removeObject(forKey: lastScanFolderPathKey)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func exportScanFolder(
        mesh: SCMesh,
        scene: SCScene,
        thumbnail: UIImage?,
        earArtifacts: EarArtifacts?,
        scanSummary: ScanSummary? = nil,
        includeGLTF: Bool,
        includeOBJ: Bool
    ) -> ExportResult {
        if case .failure(let error) = ensureScansRootFolder() {
            return .failure(String(format: L("scan.service.createFolderFailed"), error.localizedDescription))
        }
        guard includeGLTF else {
            return .failure(L("settings.export.minimum.message"))
        }

        let timestamp = Self.timestampFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let folderURL = scansRootURL.appendingPathComponent(timestamp, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            Log.export.error("Failed to create scan folder: \(error.localizedDescription, privacy: .public)")
            return .failure(String(format: L("scan.service.createFolderFailed"), error.localizedDescription))
        }

        // 1) Save scene.gltf
        if includeGLTF {
            let gltfURL = folderURL.appendingPathComponent("scene.gltf")
            scene.writeToGLTF(atPath: gltfURL.path)
            if !FileManager.default.fileExists(atPath: gltfURL.path) {
                Log.export.error("Failed to write scene.gltf at \(gltfURL.path, privacy: .private)")
                cleanupIncompleteExportFolder(folderURL)
                return .failure(L("scan.service.writeGLTFFailed"))
            }
        }

        // 2) Save thumbnail.png
        autoreleasepool {
            if let thumbnail, let png = thumbnail.pngData() {
                let tURL = folderURL.appendingPathComponent("thumbnail.png")
                do { try png.write(to: tURL, options: [.atomic]) }
                catch {
                    Log.export.error("Failed to write thumbnail.png: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        // 3) Save OBJ
        if includeOBJ {
            let objURL = folderURL.appendingPathComponent("head_mesh.obj")
            do {
                try writeOBJWithoutUV(mesh: mesh, to: objURL)
            } catch {
                Log.export.error("Failed to write OBJ: \(error.localizedDescription, privacy: .public)")
                cleanupIncompleteExportFolder(folderURL)
                return .failure(String(format: L("scan.service.writeOBJFailed"), error.localizedDescription))
            }
        }

        // 4) Ear verification artifacts (user-driven only)
        if let artifacts = earArtifacts {
            Log.ml.info("Writing ear artifacts")
            writeEarArtifacts(folderURL: folderURL, artifacts: artifacts)
        }

        if let scanSummary {
            writeScanSummary(folderURL: folderURL, summary: scanSummary)
        }

        Log.export.info("Export completed: \(folderURL.lastPathComponent, privacy: .public)")
        return .success(folderURL: folderURL)
    }

    private func writeEarArtifacts(folderURL: URL, artifacts: EarArtifacts) {
        autoreleasepool {
            if let png = artifacts.earImage.pngData() {
                let url = folderURL.appendingPathComponent("ear_view.png")
                try? png.write(to: url, options: [.atomic])
            }

            if let png = artifacts.earOverlay.pngData() {
                let url = folderURL.appendingPathComponent("thumbnail_ear_overlay.png")
                try? png.write(to: url, options: [.atomic])
            }

            do {
                let jsonURL = folderURL.appendingPathComponent("ear_landmarks.json")
                let jsonData = try JSONEncoder().encode(artifacts.earResult)
                try jsonData.write(to: jsonURL, options: [.atomic])
            } catch {
                Log.ml.error("Failed to write ear_landmarks.json (non-fatal): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func writeScanSummary(folderURL: URL, summary: ScanSummary) {
        do {
            let summaryURL = folderURL.appendingPathComponent("scan_summary.json")
            let data = try JSONEncoder().encode(summary)
            try data.write(to: summaryURL, options: [.atomic])
        } catch {
            Log.export.error("Failed to write scan_summary.json (non-fatal): \(error.localizedDescription, privacy: .public)")
        }
    }

    func _writeEarArtifactsForTest(folderURL: URL, artifacts: EarArtifacts) {
        writeEarArtifacts(folderURL: folderURL, artifacts: artifacts)
    }

    #if DEBUG
    func _exportScanFolderSimulatedFailure(message: String) -> ExportResult {
        .failure(message)
    }

    @discardableResult
    func _exportArtifactMatrixForTest(includeGLTF: Bool, includeOBJ: Bool) -> URL? {
        guard includeGLTF else {
            return nil
        }
        if case .failure = ensureScansRootFolder() {
            return nil
        }

        let folderName = "test-export-\(UUID().uuidString)"
        let folderURL = scansRootURL.appendingPathComponent(folderName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            if includeGLTF {
                let gltf = """
                {"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[]}]}
                """
                try gltf.data(using: .utf8)?.write(to: folderURL.appendingPathComponent("scene.gltf"), options: [.atomic])
            }
            if includeOBJ {
                let obj = """
                # test obj
                o head_mesh
                v 0.0 0.0 0.0
                vn 0.0 1.0 0.0
                """
                try obj.data(using: .utf8)?.write(to: folderURL.appendingPathComponent("head_mesh.obj"), options: [.atomic])
            }
            return folderURL
        } catch {
            return nil
        }
    }
    #endif

    private func cleanupIncompleteExportFolder(_ folderURL: URL) {
        do {
            try FileManager.default.removeItem(at: folderURL)
        } catch {
            Log.export.error("Failed to clean incomplete export folder: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func writeOBJWithoutUV(mesh: SCMesh, to url: URL) throws {
        let vCount = Int(mesh.vertexCount)
        let fCount = Int(mesh.faceCount)
        if vCount <= 0 || fCount <= 0 { throw NSError(domain: "TrueContourAI", code: 1) }
        let expectedFaceInts = fCount * 3

        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        func writeLine(_ s: String) throws {
            if let d = (s + "\n").data(using: .utf8) {
                try handle.write(contentsOf: d)
            }
        }

        try writeLine("# TrueContour / untextured OBJ")
        try writeLine("o head_mesh")

        try mesh.positionData.withUnsafeBytes { raw in
            let floats = raw.bindMemory(to: Float.self)
            let stride: Int
            if floats.count >= vCount * 4 {
                stride = 4
            } else if floats.count >= vCount * 3 {
                stride = 3
            } else {
                throw NSError(domain: "TrueContourAI", code: 2)
            }
            for i in 0..<vCount {
                try writeLine(Self.formatOBJVector(prefix: "v",
                                                   x: floats[stride*i+0],
                                                   y: floats[stride*i+1],
                                                   z: floats[stride*i+2]))
            }
        }

        try mesh.normalData.withUnsafeBytes { raw in
            let floats = raw.bindMemory(to: Float.self)
            let stride: Int
            if floats.count >= vCount * 4 {
                stride = 4
            } else if floats.count >= vCount * 3 {
                stride = 3
            } else {
                throw NSError(domain: "TrueContourAI", code: 3)
            }
            for i in 0..<vCount {
                try writeLine(Self.formatOBJVector(prefix: "vn",
                                                   x: floats[stride*i+0],
                                                   y: floats[stride*i+1],
                                                   z: floats[stride*i+2]))
            }
        }

        try mesh.facesData.withUnsafeBytes { raw in
            let ints = raw.bindMemory(to: Int32.self)
            guard ints.count >= expectedFaceInts else { throw NSError(domain: "TrueContourAI", code: 4) }
            for iFace in 0..<fCount {
                let i0 = Int(ints[iFace*3+0]) + 1
                let i1 = Int(ints[iFace*3+1]) + 1
                let i2 = Int(ints[iFace*3+2]) + 1
                try writeLine("f \(i0)//\(i0) \(i1)//\(i1) \(i2)//\(i2)")
            }
        }
    }

    private static let objLocale = Locale(identifier: "en_US_POSIX")

    private static func formatOBJVector(prefix: String, x: Float, y: Float, z: Float) -> String {
        String(format: "%@ %.6f %.6f %.6f", locale: objLocale, prefix, x, y, z)
    }

    static func _formatOBJVectorForTest(prefix: String, x: Float, y: Float, z: Float) -> String {
        formatOBJVector(prefix: prefix, x: x, y: y, z: z)
    }
}
