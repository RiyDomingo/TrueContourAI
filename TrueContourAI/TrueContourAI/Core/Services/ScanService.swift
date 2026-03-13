import Foundation
import UIKit
import StandardCyborgFusion

protocol ScanListing {
    func listScansAsync(completion: @escaping ([ScanItem]) -> Void)
    func resolveScanSummary(from folder: URL) -> ScanSummary?
    func resolveLastScanItem() -> ScanItem?
    func resolveLastScanGLTFURL() -> URL?
}

protocol ScanSummaryReading {
    func resolveScanSummary(from folder: URL) -> ScanSummary?
}

protocol LastScanReading {
    func resolveLastScanItem() -> ScanItem?
}

protocol ScansRootEnsuring {
    func ensureScansRootFolder() -> Result<Void, Error>
}

protocol ScanFolderSharing {
    func shareItems(for folderURL: URL) -> [Any]
    func shareItemsForScansRoot() -> [Any]
    func resolveOBJFromFolder(_ folder: URL) -> URL?
}

protocol ScanItemListing {
    func listScans() -> [ScanItem]
}

protocol ScanFolderEditing {
    func renameScanFolder(_ item: ScanItem, to newNameRaw: String) -> ScanRenameResult
    func deleteScanFolder(_ item: ScanItem) -> Result<Void, Error>
}

protocol ScanLibraryManaging:
    ScansRootEnsuring,
    ScanFolderSharing,
    ScanItemListing,
    ScanSummaryReading,
    LastScanReading,
    ScanFolderEditing {}

protocol HomeScanManaging:
    ScansRootEnsuring,
    ScanFolderSharing,
    ScanItemListing,
    ScanSummaryReading,
    LastScanReading,
    ScanFolderEditing {}

protocol ScanHistoryReading: ScanItemListing, ScanSummaryReading {}

protocol PreviewScanLibraryReading:
    ScanSummaryReading,
    LastScanReading,
    ScanFolderSharing {}

protocol ScanRootSharing: ScansRootEnsuring, ScanFolderSharing {}

protocol ScanStorageManaging: ScansRootEnsuring, LastScanReading {}

extension ScanService:
    ScanListing,
    ScanLibraryManaging,
    HomeScanManaging,
    ScanHistoryReading,
    PreviewScanLibraryReading,
    ScanRootSharing,
    ScanStorageManaging {}

final class ScanService {
    typealias ScanSummary = StoredScanSummary
    typealias ScanItem = StoredScanItem
    typealias EarArtifacts = StoredScanEarArtifacts
    typealias ExportResult = StoredScanExportResult
    typealias RenameResult = StoredScanRenameResult

    let scansRootURL: URL
    private let defaults: UserDefaults
    private let environment: AppEnvironment
    private let lastScanFolderPathKey = "tc_last_scan_folder_path"
    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private var storageRepository: ScanStorageRepository {
        ScanStorageRepository(
            scansRootURL: scansRootURL,
            defaults: defaults,
            lastScanFolderPathKey: lastScanFolderPathKey
        )
    }

    private var folderExporter: ScanFolderExporter {
        ScanFolderExporter(
            scansRootURL: scansRootURL,
            timestampFormatter: Self.timestampFormatter,
            writeOBJ: { mesh, url in try self.writeOBJWithoutUV(mesh: mesh, to: url) },
            writeEarArtifacts: { folderURL, artifacts in self.writeEarArtifacts(folderURL: folderURL, artifacts: artifacts) },
            writeScanSummary: { folderURL, summary in self.writeScanSummary(folderURL: folderURL, summary: summary) },
            cleanupFolder: { folderURL in self.cleanupIncompleteExportFolder(folderURL) }
        )
    }

    private var uiTestSeedRepository: ScanUITestSeedRepository {
        ScanUITestSeedRepository(
            scansRootURL: scansRootURL,
            fileManager: .default
        )
    }

    init(
        scansRootURL: URL? = nil,
        defaults: UserDefaults = .standard,
        environment: AppEnvironment = .current
    ) {
        self.defaults = defaults
        self.environment = environment
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
        let result = storageRepository.ensureScansRootFolder()
        if case .failure(let error) = result {
            Log.persistence.error("Failed to ensure scans root folder: \(error.localizedDescription, privacy: .public)")
        }
        return result
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

        #if DEBUG
        if environment.seedsScan {
            uiTestSeedRepository.seedPreviewableScanIfNeeded()
        }
        if environment.seedsMissingSceneScan {
            uiTestSeedRepository.seedMissingSceneScanIfNeeded()
        }
        #endif
        let items = storageRepository.listScans()
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
        storageRepository.resolveLastScanFolderURL()
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
        storageRepository.setLastScanFolder(folderURL)
    }

    func clearLastScanFolderIfMatches(_ folderURL: URL) {
        storageRepository.clearLastScanFolderIfMatches(folderURL)
    }

    func updateLastScanFolderIfMatches(oldURL: URL, newURL: URL) {
        storageRepository.updateLastScanFolderIfMatches(oldURL: oldURL, newURL: newURL)
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

        switch storageRepository.renameScanFolder(item, to: newURL) {
        case .success:
            return .success(newURL: newURL)
        case .failure(let error):
            return .failure(error)
        }
    }

    func deleteScanFolder(_ item: ScanItem) -> Result<Void, Error> {
        storageRepository.deleteScanFolder(item)
    }

    func deleteAllScans() -> Result<Void, Error> {
        if case .failure(let error) = ensureScansRootFolder() {
            return .failure(error)
        }
        return storageRepository.deleteAllScans()
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
        return folderExporter.export(
            mesh: mesh,
            scene: scene,
            thumbnail: thumbnail,
            earArtifacts: earArtifacts,
            scanSummary: scanSummary,
            includeGLTF: includeGLTF,
            includeOBJ: includeOBJ
        )
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
