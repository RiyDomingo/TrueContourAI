import Foundation
import UIKit
import StandardCyborgFusion

struct ScanStorageRepository {
    let scansRootURL: URL
    let defaults: UserDefaults
    let lastScanFolderPathKey: String
    let fileManager: FileManager = .default

    func ensureScansRootFolder() -> Result<Void, Error> {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: scansRootURL.path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                let error = NSError(
                    domain: "ScanService",
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
            let values = try? folder.resourceValues(forKeys: [.contentModificationDateKey])
            let date = values?.contentModificationDate ?? Date.distantPast
            let overlay = folder.appendingPathComponent("thumbnail_ear_overlay.png")
            let thumb = folder.appendingPathComponent("thumbnail.png")
            let thumbURL: URL?
            if fileManager.fileExists(atPath: overlay.path) { thumbURL = overlay }
            else if fileManager.fileExists(atPath: thumb.path) { thumbURL = thumb }
            else { thumbURL = nil }

            let gltf = folder.appendingPathComponent("scene.gltf")
            let gltfURL = fileManager.fileExists(atPath: gltf.path) ? gltf : nil

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
            if fileManager.fileExists(atPath: url.path) { return url }
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
        guard includeGLTF else {
            return .failure(L("settings.export.minimum.message"))
        }

        let timestamp = timestampFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let folderURL = scansRootURL.appendingPathComponent(timestamp, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            Log.export.error("Failed to create scan folder: \(error.localizedDescription, privacy: .public)")
            return .failure(String(format: L("scan.service.createFolderFailed"), error.localizedDescription))
        }

        let gltfURL = folderURL.appendingPathComponent("scene.gltf")
        scene.writeToGLTF(atPath: gltfURL.path)
        if !FileManager.default.fileExists(atPath: gltfURL.path) {
            Log.export.error("Failed to write scene.gltf at \(gltfURL.path, privacy: .private)")
            cleanupFolder(folderURL)
            return .failure(L("scan.service.writeGLTFFailed"))
        }

        autoreleasepool {
            if let thumbnail, let png = thumbnail.pngData() {
                let thumbnailURL = folderURL.appendingPathComponent("thumbnail.png")
                do { try png.write(to: thumbnailURL, options: [.atomic]) }
                catch {
                    Log.export.error("Failed to write thumbnail.png: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        if includeOBJ {
            let objURL = folderURL.appendingPathComponent("head_mesh.obj")
            do {
                try writeOBJ(mesh, objURL)
            } catch {
                Log.export.error("Failed to write OBJ: \(error.localizedDescription, privacy: .public)")
                cleanupFolder(folderURL)
                return .failure(String(format: L("scan.service.writeOBJFailed"), error.localizedDescription))
            }
        }

        if let earArtifacts {
            writeEarArtifacts(folderURL, earArtifacts)
        }
        if let scanSummary {
            writeScanSummary(folderURL, scanSummary)
        }

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
