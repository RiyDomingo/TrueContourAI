import Foundation
import UIKit
import StandardCyborgFusion

final class ScanRepository:
    ScanListing,
    ScanLibraryManaging,
    HomeScanManaging,
    ScanHistoryReading,
    PreviewScanLibraryReading,
    ScanRootSharing,
    ScanStorageManaging,
    SettingsScanServicing
{
    let scansRootURL: URL

    private let defaults: UserDefaults
    private let testSeedService: ScanTestSeedService?
    private let lastScanFolderPathKey = "tc_last_scan_folder_path"

    private var storageRepository: ScanStorageRepository {
        ScanStorageRepository(
            scansRootURL: scansRootURL,
            defaults: defaults,
            lastScanFolderPathKey: lastScanFolderPathKey
        )
    }

    init(
        scansRootURL: URL,
        defaults: UserDefaults = .standard,
        testSeedService: ScanTestSeedService? = nil
    ) {
        self.scansRootURL = scansRootURL
        self.defaults = defaults
        self.testSeedService = testSeedService
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

    func resolveEarVerificationImage(from folder: URL) -> UIImage? {
        let imageURL = folder.appendingPathComponent("ear_view.png")
        guard FileManager.default.fileExists(atPath: imageURL.path),
              let data = try? Data(contentsOf: imageURL),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    func listScans() -> [ScanItem] {
        if case .failure = ensureScansRootFolder() {
            return []
        }

        testSeedService?.seedIfNeeded()

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
        guard let folder = resolveLastScanFolderURL() else { return nil }
        return resolveGLTFFromFolder(folder)
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

    func renameScanFolder(_ item: ScanItem, to newNameRaw: String) -> ScanRenameResult {
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
}
