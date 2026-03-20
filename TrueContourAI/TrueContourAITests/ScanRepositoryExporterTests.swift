import XCTest
import UIKit
@testable import TrueContourAI

final class ScanRepositoryExporterTests: XCTestCase {

    private var tempDir: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var repository: ScanRepository!
    private var exporter: ScanExporterService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        suiteName = "ScanRepositoryExporterTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        repository = ScanRepository(scansRootURL: tempDir, defaults: defaults)
        exporter = ScanExporterService(scansRootURL: tempDir, defaults: defaults)
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        exporter = nil
        repository = nil
        defaults = nil
        tempDir = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeScanFolder(
        name: String,
        date: Date,
        withOverlay: Bool = false,
        withThumbnail: Bool = false,
        withScene: Bool = true
    ) throws -> URL {
        let folder = tempDir.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: folder.path)

        if withOverlay {
            let url = folder.appendingPathComponent("thumbnail_ear_overlay.png")
            try writeDummyPNG(to: url)
        }
        if withThumbnail {
            let url = folder.appendingPathComponent("thumbnail.png")
            try writeDummyPNG(to: url)
        }
        if withScene {
            let url = folder.appendingPathComponent("scene.gltf")
            try writeDummyGLTF(to: url)
        }

        return folder
    }

    private func writeDummyPNG(to url: URL) throws {
        let size = CGSize(width: 4, height: 4)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let data = image?.pngData() ?? Data()
        try data.write(to: url, options: [.atomic])
    }

    private func writeDummyGLTF(to url: URL) throws {
        let gltf = """
        {"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[]}]}
        """
        try gltf.data(using: .utf8)?.write(to: url, options: [.atomic])
    }

    func testSanitizeFolderName() {
        let input = "  My/Scan?  "
        let cleaned = repository.sanitizeFolderName(input)
        XCTAssertEqual(cleaned, "My-Scan-")
    }

    func testListScansEmptyReturnsEmpty() {
        let items = repository.listScans()
        XCTAssertTrue(items.isEmpty)
    }

    func testEnsureScansRootFolderFailureIsReported() throws {
        let fileURL = tempDir.appendingPathComponent("not-a-directory")
        try Data("x".utf8).write(to: fileURL, options: [.atomic])
        let badRepository = ScanRepository(scansRootURL: fileURL, defaults: defaults)

        let result = badRepository.ensureScansRootFolder()
        switch result {
        case .success:
            XCTFail("Expected ensureScansRootFolder to fail when scans root is a file")
        case .failure:
            break
        }
    }

    func testListScansSortedByDate() throws {
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 200)
        _ = try makeScanFolder(name: "older", date: oldDate)
        _ = try makeScanFolder(name: "newer", date: newDate)

        let items = repository.listScans()
        XCTAssertEqual(items.first?.folderURL.lastPathComponent, "newer")
        XCTAssertEqual(items.last?.folderURL.lastPathComponent, "older")
    }

    func testListScansPrefersOverlayThumbnail() throws {
        let date = Date(timeIntervalSince1970: 100)
        let folder = try makeScanFolder(name: "scan", date: date, withOverlay: true, withThumbnail: true)

        let items = repository.listScans()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.thumbnailURL?.lastPathComponent, "thumbnail_ear_overlay.png")
        XCTAssertEqual(items.first?.folderURL, folder)
    }

    func testListScansUsesThumbnailWhenOverlayMissing() throws {
        let date = Date(timeIntervalSince1970: 150)
        _ = try makeScanFolder(name: "scan", date: date, withOverlay: false, withThumbnail: true)

        let items = repository.listScans()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.thumbnailURL?.lastPathComponent, "thumbnail.png")
    }

    func testListScansWithNoThumbnailsReturnsNilThumbnailURL() throws {
        let date = Date(timeIntervalSince1970: 160)
        _ = try makeScanFolder(name: "scan", date: date)

        let items = repository.listScans()
        XCTAssertEqual(items.count, 1)
        XCTAssertNil(items.first?.thumbnailURL)
    }

    func testResolveGLTFFromFolderMissingReturnsNil() throws {
        let date = Date(timeIntervalSince1970: 170)
        let folder = try makeScanFolder(name: "scan", date: date, withScene: false)

        let gltf = repository.resolveGLTFFromFolder(folder)
        XCTAssertNil(gltf)

        let items = repository.listScans()
        XCTAssertTrue(items.isEmpty)
    }

    func testListScansExcludesIncompleteFolders() throws {
        let date = Date(timeIntervalSince1970: 171)
        _ = try makeScanFolder(name: "incomplete", date: date, withScene: false)

        let items = repository.listScans()

        XCTAssertTrue(items.isEmpty)
    }

    func testListScansIncludesSceneWhenPresent() throws {
        let date = Date(timeIntervalSince1970: 175)
        let folder = try makeScanFolder(name: "scan", date: date, withScene: true)

        let items = repository.listScans()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.folderURL, folder)
        XCTAssertEqual(items.first?.sceneGLTFURL?.lastPathComponent, "scene.gltf")
    }

    func testResolveLastScanGLTFURLReturnsNilWhenMissing() throws {
        let date = Date(timeIntervalSince1970: 178)
        let folder = try makeScanFolder(name: "scan", date: date, withScene: false)
        repository.setLastScanFolder(folder)

        XCTAssertNil(repository.resolveLastScanGLTFURL())
    }

    func testResolveLastScanItemReturnsStoredScanMetadata() throws {
        let date = Date(timeIntervalSince1970: 179)
        let folder = try makeScanFolder(name: "scan", date: date, withThumbnail: true, withScene: true)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: folder.path)
        repository.setLastScanFolder(folder)

        let item = repository.resolveLastScanItem()
        XCTAssertEqual(item?.folderURL, folder)
        XCTAssertEqual(item?.displayName, "scan")
        XCTAssertEqual(item?.thumbnailURL?.lastPathComponent, "thumbnail.png")
        XCTAssertEqual(item?.sceneGLTFURL?.lastPathComponent, "scene.gltf")
        XCTAssertEqual(item?.date, date)
    }

    func testRenameScanFolderSanitizesName() throws {
        let date = Date(timeIntervalSince1970: 190)
        let folder = try makeScanFolder(name: "scan", date: date)
        let item = ScanItem(
            folderURL: folder,
            displayName: "scan",
            date: date,
            thumbnailURL: nil,
            sceneGLTFURL: nil
        )

        let result = repository.renameScanFolder(item, to: "Bad/Name")
        switch result {
        case .success(let newURL):
            XCTAssertEqual(newURL.lastPathComponent, "Bad-Name")
        default:
            XCTFail("Expected sanitized rename to succeed, got \(result)")
        }
    }

    func testResolveLastScanFolderFallsBackToNewestWhenStoredMissing() throws {
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 200)
        _ = try makeScanFolder(name: "older", date: oldDate)
        let newer = try makeScanFolder(name: "newer", date: newDate)

        let missing = tempDir.appendingPathComponent("missing", isDirectory: true)
        repository.setLastScanFolder(missing)

        let resolved = repository.resolveLastScanFolderURL()
        XCTAssertEqual(resolved, newer)
    }

    func testResolveLastScanFolderFallsBackToNewestWhenStoredFolderIsInvalid() throws {
        let valid = try makeScanFolder(name: "valid", date: Date(timeIntervalSince1970: 210))
        let invalid = try makeScanFolder(name: "invalid", date: Date(timeIntervalSince1970: 220), withScene: false)
        repository.setLastScanFolder(invalid)

        let resolved = repository.resolveLastScanFolderURL()

        XCTAssertEqual(resolved, valid)
    }

    func testRenameInvalidNameReturnsInvalidName() throws {
        let date = Date(timeIntervalSince1970: 100)
        _ = try makeScanFolder(name: "scan", date: date)
        let item = repository.listScans().first { $0.folderURL.lastPathComponent == "scan" }
        XCTAssertNotNil(item)

        if let item {
            let result = repository.renameScanFolder(item, to: "   ")
            switch result {
            case .invalidName:
                break
            default:
                XCTFail("Expected invalidName, got \(result)")
            }
        }
    }

    func testSetLastScanFolderPersistsAndResolves() throws {
        let date = Date(timeIntervalSince1970: 100)
        let folder = try makeScanFolder(name: "scan", date: date)
        repository.setLastScanFolder(folder)

        let resolved = repository.resolveLastScanFolderURL()
        XCTAssertEqual(resolved, folder)
    }

    func testRenameScanFolderNameExists() throws {
        let date = Date(timeIntervalSince1970: 100)
        _ = try makeScanFolder(name: "scan-a", date: date)
        _ = try makeScanFolder(name: "scan-b", date: date.addingTimeInterval(10))

        let item = repository.listScans().first { $0.folderURL.lastPathComponent == "scan-a" }
        XCTAssertNotNil(item)

        if let item {
            let result = repository.renameScanFolder(item, to: "scan-b")
            switch result {
            case .nameExists:
                break
            default:
                XCTFail("Expected nameExists, got \(result)")
            }
        }
    }

    func testDeleteClearsLastScan() throws {
        let date = Date(timeIntervalSince1970: 100)
        let folder = try makeScanFolder(name: "scan-to-delete", date: date)
        repository.setLastScanFolder(folder)

        let item = repository.listScans().first { $0.folderURL == folder }
        XCTAssertNotNil(item)

        if let item {
            let result = repository.deleteScanFolder(item)
            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("Delete failed: \(error)")
            }
        }

        XCTAssertNil(repository.resolveLastScanFolderURL())
    }

    func testDeleteMissingFolderSucceedsAndClearsLastScan() {
        let missing = tempDir.appendingPathComponent("missing-folder", isDirectory: true)
        repository.setLastScanFolder(missing)
        let item = ScanItem(
            folderURL: missing,
            displayName: "missing-folder",
            date: Date(),
            thumbnailURL: nil,
            sceneGLTFURL: nil
        )

        let result = repository.deleteScanFolder(item)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Delete missing folder should succeed: \(error)")
        }

        XCTAssertNil(repository.resolveLastScanFolderURL())
    }

    func testWriteEarArtifactsCreatesFiles() throws {
        let folder = tempDir.appendingPathComponent("ear-artifacts", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let image = makeDummyImage(color: .blue)
        let overlay = makeDummyImage(color: .green)
        let result = EarLandmarksResult(
            confidence: 0.9,
            earBoundingBox: .init(x: 0.1, y: 0.2, w: 0.3, h: 0.4),
            landmarks: [.init(x: 0.1, y: 0.2)],
            usedLeftEarMirroringHeuristic: false
        )
        let cropOverlay = makeDummyImage(color: .yellow)
        let artifacts = ScanEarArtifacts(earImage: image, earResult: result, earOverlay: overlay, earCropOverlay: cropOverlay)

        exporter._writeEarArtifactsForTest(folderURL: folder, artifacts: artifacts)

        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("ear_view.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("thumbnail_ear_overlay.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("ear_crop_overlay.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("ear_landmarks.json").path))
    }

    func testUITestSeedPreviewableScanCreatesEarVerificationImage() {
        let seedRepository = ScanUITestSeedRepository(scansRootURL: tempDir, fileManager: .default)

        seedRepository.seedPreviewableScanIfNeeded()

        let folder = tempDir.appendingPathComponent("UITest-Seed", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("scene.gltf").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("ear_view.png").path))
    }

    func testRepositoryResolvesSeededEarVerificationImage() {
        let seedRepository = ScanUITestSeedRepository(scansRootURL: tempDir, fileManager: .default)
        seedRepository.seedPreviewableScanIfNeeded()

        let folder = tempDir.appendingPathComponent("UITest-Seed", isDirectory: true)
        let image = repository.resolveEarVerificationImage(from: folder)

        XCTAssertNotNil(image)
        XCTAssertGreaterThan(image?.size.width ?? 0, 0)
        XCTAssertGreaterThan(image?.size.height ?? 0, 0)
    }

    private func makeDummyImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 2, height: 2)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }

    func testListScansAsyncReturnsOnMainThread() throws {
        let date = Date(timeIntervalSince1970: 100)
        _ = try makeScanFolder(name: "scan", date: date)

        let exp = expectation(description: "listScansAsync")
        repository.listScansAsync { items in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(items.count, 1)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testSimulatedExportFailureReturnsFailure() {
        let exporter = ScanExporterService(scansRootURL: tempDir, defaults: defaults)
        let result = exporter._exportScanFolderSimulatedFailure(message: "Simulated failure")
        switch result {
        case .failure(let message):
            XCTAssertEqual(message, "Simulated failure")
        case .success:
            XCTFail("Expected failure")
        }
    }

    func testResolveScanSummaryReadsJSON() throws {
        let folder = try makeScanFolder(name: "scan", date: Date())
        let summary = ScanSummary(
            schemaVersion: 2,
            startedAt: Date(timeIntervalSince1970: 100),
            finishedAt: Date(timeIntervalSince1970: 130),
            durationSeconds: 30,
            overallConfidence: 0.88,
            completedPoses: 4,
            skippedPoses: 0,
            poseRecords: [
                .init(pose: "frontFacing", confidence: 0.9, status: "completed")
            ],
            pointCountEstimate: 123456,
            hadEarVerification: true,
            processingProfile: .init(
                outlierSigma: 3.0,
                decimateRatio: 1.0,
                cropBelowNeck: true,
                meshResolution: 6,
                meshSmoothness: 3
            ),
            derivedMeasurements: .init(
                sliceHeightNormalized: 0.62,
                circumferenceMm: 560.0,
                widthMm: 165.0,
                depthMm: 190.0,
                confidence: 0.82,
                status: "validated"
            )
        )
        let summaryURL = folder.appendingPathComponent("scan_summary.json")
        let data = try JSONEncoder().encode(summary)
        try data.write(to: summaryURL, options: [.atomic])

        let decoded = repository.resolveScanSummary(from: folder)
        XCTAssertEqual(decoded, summary)
    }

    func testResolveScanSummaryLegacyJSONDefaultsSchemaVersion() throws {
        let folder = try makeScanFolder(name: "scan-legacy", date: Date())
        let startedAt = Date(timeIntervalSince1970: 100)
        let finishedAt = Date(timeIntervalSince1970: 130)

        let payload: [String: Any] = [
            "startedAt": startedAt.timeIntervalSinceReferenceDate,
            "finishedAt": finishedAt.timeIntervalSinceReferenceDate,
            "durationSeconds": 30.0,
            "overallConfidence": 0.88,
            "completedPoses": 0,
            "skippedPoses": 0,
            "poseRecords": [],
            "pointCountEstimate": 123_456,
            "hadEarVerification": true
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let summaryURL = folder.appendingPathComponent("scan_summary.json")
        try data.write(to: summaryURL, options: [.atomic])

        let decoded = repository.resolveScanSummary(from: folder)
        XCTAssertEqual(decoded?.schemaVersion, 1)
        XCTAssertNil(decoded?.processingProfile)
        XCTAssertNil(decoded?.derivedMeasurements)
        XCTAssertEqual(decoded?.pointCountEstimate, 123_456)
    }

    func testExportArtifactsRespectSettingsToggleMatrix() {
        let matrix: [(includeGLTF: Bool, includeOBJ: Bool)] = [
            (true, true),
            (true, false)
        ]

        for entry in matrix {
            guard let folderURL = exporter._exportArtifactMatrixForTest(includeGLTF: entry.includeGLTF, includeOBJ: entry.includeOBJ) else {
                XCTFail("Expected test export folder creation")
                return
            }
            let gltfPath = folderURL.appendingPathComponent("scene.gltf").path
            let objPath = folderURL.appendingPathComponent("head_mesh.obj").path
            XCTAssertEqual(FileManager.default.fileExists(atPath: gltfPath), entry.includeGLTF)
            XCTAssertEqual(FileManager.default.fileExists(atPath: objPath), entry.includeOBJ)
        }
    }

    func testExportArtifactMatrixRejectsMissingGLTF() {
        XCTAssertNil(exporter._exportArtifactMatrixForTest(includeGLTF: false, includeOBJ: true))
        XCTAssertNil(exporter._exportArtifactMatrixForTest(includeGLTF: false, includeOBJ: false))
    }

    func testLastScanPointerUpdatesAcrossRenameThenDeleteSequence() throws {
        let oldDate = Date(timeIntervalSince1970: 100)
        let folder = try makeScanFolder(name: "rename-me", date: oldDate)
        repository.setLastScanFolder(folder)
        XCTAssertEqual(repository.resolveLastScanFolderURL(), folder)

        let item = ScanItem(
            folderURL: folder,
            displayName: "rename-me",
            date: oldDate,
            thumbnailURL: nil,
            sceneGLTFURL: nil
        )

        let renamedURL: URL
        switch repository.renameScanFolder(item, to: "renamed-scan") {
        case .success(let url):
            renamedURL = url
        default:
            XCTFail("Expected rename success")
            return
        }
        XCTAssertEqual(repository.resolveLastScanFolderURL(), renamedURL)

        let renamedItem = ScanItem(
            folderURL: renamedURL,
            displayName: "renamed-scan",
            date: oldDate,
            thumbnailURL: nil,
            sceneGLTFURL: nil
        )
        switch repository.deleteScanFolder(renamedItem) {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected delete success, got \(error)")
        }
        XCTAssertNil(repository.resolveLastScanFolderURL())
    }
}
