import Foundation
import UIKit
import StandardCyborgFusion

final class ScanExporterService: ScanExporting {
    let scansRootURL: URL

    private let defaults: UserDefaults
    private let lastScanFolderPathKey = "tc_last_scan_folder_path"

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
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
            writeOBJ: { mesh, url in
                try Self.writeOBJWithoutUV(mesh: mesh, to: url)
            },
            writeEarArtifacts: { folderURL, artifacts in
                Self.writeEarArtifacts(folderURL: folderURL, artifacts: artifacts)
            },
            writeScanSummary: { folderURL, summary in
                Self.writeScanSummary(folderURL: folderURL, summary: summary)
            },
            cleanupFolder: { folderURL in
                Self.cleanupIncompleteExportFolder(folderURL)
            }
        )
    }

    init(
        scansRootURL: URL,
        defaults: UserDefaults = .standard
    ) {
        self.scansRootURL = scansRootURL
        self.defaults = defaults
    }

    func exportScanFolder(
        mesh: SCMesh,
        scene: SCScene,
        thumbnail: UIImage?,
        earArtifacts: ScanEarArtifacts?,
        scanSummary: ScanSummary?,
        includeGLTF: Bool,
        includeOBJ: Bool
    ) -> ScanExportResult {
        if case .failure(let error) = storageRepository.ensureScansRootFolder() {
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

    func setLastScanFolder(_ folderURL: URL) {
        storageRepository.setLastScanFolder(folderURL)
    }

    private static func writeEarArtifacts(folderURL: URL, artifacts: ScanEarArtifacts) {
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

    private static func writeScanSummary(folderURL: URL, summary: ScanSummary) {
        do {
            let summaryURL = folderURL.appendingPathComponent("scan_summary.json")
            let data = try JSONEncoder().encode(summary)
            try data.write(to: summaryURL, options: [.atomic])
        } catch {
            Log.export.error("Failed to write scan_summary.json (non-fatal): \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func cleanupIncompleteExportFolder(_ folderURL: URL) {
        do {
            try FileManager.default.removeItem(at: folderURL)
        } catch {
            Log.export.error("Failed to clean incomplete export folder: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static let objLocale = Locale(identifier: "en_US_POSIX")

    private static func formatOBJVector(prefix: String, x: Float, y: Float, z: Float) -> String {
        String(format: "%@ %.6f %.6f %.6f", locale: objLocale, prefix, x, y, z)
    }

    func _writeEarArtifactsForTest(folderURL: URL, artifacts: ScanEarArtifacts) {
        Self.writeEarArtifacts(folderURL: folderURL, artifacts: artifacts)
    }

    #if DEBUG
    func _exportScanFolderSimulatedFailure(message: String) -> ScanExportResult {
        .failure(message)
    }

    func _exportArtifactMatrixForTest(includeGLTF: Bool, includeOBJ: Bool) -> URL? {
        guard includeGLTF else {
            return nil
        }
        if case .failure = storageRepository.ensureScansRootFolder() {
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

    static func _formatOBJVectorForTest(prefix: String, x: Float, y: Float, z: Float) -> String {
        formatOBJVector(prefix: prefix, x: x, y: y, z: z)
    }
    #endif

    private static func writeOBJWithoutUV(mesh: SCMesh, to url: URL) throws {
        let vertexCount = Int(mesh.vertexCount)
        let faceCount = Int(mesh.faceCount)
        if vertexCount <= 0 || faceCount <= 0 {
            throw NSError(domain: "TrueContourAI", code: 1)
        }

        let expectedFaceInts = faceCount * 3
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        func writeLine(_ value: String) throws {
            if let data = (value + "\n").data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
        }

        try writeLine("# TrueContour / untextured OBJ")
        try writeLine("o head_mesh")

        try mesh.positionData.withUnsafeBytes { raw in
            let floats = raw.bindMemory(to: Float.self)
            let stride: Int
            if floats.count >= vertexCount * 4 {
                stride = 4
            } else if floats.count >= vertexCount * 3 {
                stride = 3
            } else {
                throw NSError(domain: "TrueContourAI", code: 2)
            }

            for index in 0..<vertexCount {
                try writeLine(
                    formatOBJVector(
                        prefix: "v",
                        x: floats[stride * index + 0],
                        y: floats[stride * index + 1],
                        z: floats[stride * index + 2]
                    )
                )
            }
        }

        try mesh.normalData.withUnsafeBytes { raw in
            let floats = raw.bindMemory(to: Float.self)
            let stride: Int
            if floats.count >= vertexCount * 4 {
                stride = 4
            } else if floats.count >= vertexCount * 3 {
                stride = 3
            } else {
                throw NSError(domain: "TrueContourAI", code: 3)
            }

            for index in 0..<vertexCount {
                try writeLine(
                    formatOBJVector(
                        prefix: "vn",
                        x: floats[stride * index + 0],
                        y: floats[stride * index + 1],
                        z: floats[stride * index + 2]
                    )
                )
            }
        }

        try mesh.facesData.withUnsafeBytes { raw in
            let ints = raw.bindMemory(to: Int32.self)
            guard ints.count >= expectedFaceInts else {
                throw NSError(domain: "TrueContourAI", code: 4)
            }

            for faceIndex in 0..<faceCount {
                let i0 = Int(ints[faceIndex * 3 + 0]) + 1
                let i1 = Int(ints[faceIndex * 3 + 1]) + 1
                let i2 = Int(ints[faceIndex * 3 + 2]) + 1
                try writeLine("f \(i0)//\(i0) \(i1)//\(i1) \(i2)//\(i2)")
            }
        }
    }
}
