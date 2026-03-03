//
//  ResultsPersistence.swift
//  CyborgRugby
//
//  Saves/loads CompleteScanResult summaries and per-pose point clouds.
//

import Foundation
import StandardCyborgFusion
import OSLog

struct ResultsPersistence {
    struct SavedScanResult: Codable {
        struct PoseEntry: Codable { let pose: String; let confidence: Float; let status: String; let plyPath: String? }
        let timestamp: Date
        let overallQuality: Float
        let successfulPoses: Int
        let totalScanTime: Double
        let headCircumferenceCM: Float
        let backHeadWidthMM: Float
        let occipitalProminenceMM: Float
        let poses: [PoseEntry]
        let fusedPointCloudPLY: String?
        let fusedMeshPLY: String?
        let fusedMeshOBJZip: String?
        let fusedMeshGLB: String?
    }

    static func appSupportURL() -> URL {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            AppLog.persistence.error("Could not access application support directory")
            // Fallback to documents directory
            return fm.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("CyborgRugby", isDirectory: true)
        }
        
        let dir = base.appendingPathComponent("CyborgRugby", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            do { 
                try fm.createDirectory(at: dir, withIntermediateDirectories: true) 
                AppLog.persistence.info("Created app support directory: \(dir.path)")
            } catch {
                AppLog.persistence.error("Failed to create app support dir: \(String(describing: error))")
                // Don't fail silently - this is a critical error
                fatalError("Unable to create required application directory: \(error)")
            }
        }
        return dir
    }

    static func save(result: CompleteScanResult, fileName: String = "last_scan.json") {
        let base = appSupportURL()
        // Save per-pose clouds as PLY
        var entries: [SavedScanResult.PoseEntry] = []
        for (pose, entry) in result.individualScans {
            var plyPath: String? = nil
            if let cloud = entry.pointCloud {
                let name = "pose_\(pose.rawValue).ply"
                var url = base.appendingPathComponent(name)
                if cloud.writeToPLY(atPath: url.path) {
                    var rv = URLResourceValues()
                    rv.isExcludedFromBackup = true
                    try? url.setResourceValues(rv)
                    plyPath = url.lastPathComponent
                }
            }
            entries.append(.init(pose: pose.rawValue, confidence: entry.confidence, status: "\(entry.status)", plyPath: plyPath))
        }
        // Save fused union as PLY
        var fusedPointPLYName: String? = nil
        var fusedPointsURL = base.appendingPathComponent("fused_points.ply")
        let config = loadConfig()
        let fusionOpts = RugbyHeadScanFusion.FusionExportOptions(cropBelowNeck: config.fusionCropBelowNeck,
                                                                 neckOffsetMeters: config.fusionNeckOffsetMeters,
                                                                 outlierSigma: config.fusionOutlierSigma,
                                                                 decimateRatio: config.fusionDecimateRatio,
                                                                 preScaleToMillimeters: config.fusionPreScaleToMillimeters)
        if RugbyHeadScanFusion.writeFusedPLY(scans: result.individualScans, to: fusedPointsURL, options: fusionOpts) {
            var rv = URLResourceValues()
            rv.isExcludedFromBackup = true
            try? fusedPointsURL.setResourceValues(rv)
            fusedPointPLYName = fusedPointsURL.lastPathComponent
        }

        // Mesh fused PLY into a printable surface
        var fusedMeshPLYName: String? = nil
        var fusedMeshOBJZipName: String? = nil
        var fusedMeshGLBName: String? = nil
        if fusedPointPLYName != nil {
            let sp = OSSignposter(subsystem: "com.standardcyborg.CyborgRugby", category: "meshing").beginInterval("meshFusedPLY")
            var fusedMeshURL = base.appendingPathComponent("fused_mesh.ply")
            let op = SCMeshingOperation(inputPLYPath: fusedPointsURL.path, outputPLYPath: fusedMeshURL.path)
            let params = SCMeshingParameters()
            params.resolution = Int32(config.meshingResolution)
            params.smoothness = Int32(config.meshingSmoothness)
            params.surfaceTrimmingAmount = Int32(config.meshingSurfaceTrimmingAmount)
            params.closed = config.meshingClosed
            op.parameters = params
            let q = OperationQueue()
            q.addOperations([op], waitUntilFinished: true)
            if FileManager.default.fileExists(atPath: fusedMeshURL.path) {
                var rv = URLResourceValues()
                rv.isExcludedFromBackup = true
                try? fusedMeshURL.setResourceValues(rv)
                fusedMeshPLYName = fusedMeshURL.lastPathComponent

                // Optional: write OBJ-zip and GLB
                var objZipURL = base.appendingPathComponent("fused_mesh.obj.zip")
                var glbURL = base.appendingPathComponent("fused_mesh.glb")
                if config.meshingExportOBJZip, RugbyMeshExporter.exportOBJZip(fromPLY: fusedMeshURL.path, toPath: objZipURL.path) {
                    var rv2 = URLResourceValues(); rv2.isExcludedFromBackup = true; try? objZipURL.setResourceValues(rv2)
                    fusedMeshOBJZipName = objZipURL.lastPathComponent
                }
                if config.meshingExportGLB, RugbyMeshExporter.exportGLB(fromPLY: fusedMeshURL.path, toPath: glbURL.path) {
                    var rv3 = URLResourceValues(); rv3.isExcludedFromBackup = true; try? glbURL.setResourceValues(rv3)
                    fusedMeshGLBName = glbURL.lastPathComponent
                }
            }
            OSSignposter(subsystem: "com.standardcyborg.CyborgRugby", category: "meshing").endInterval("meshFusedPLY", sp)
        }

        // Summary metrics (subset)
        let hcCM = result.rugbyFitnessMeasurements.headCircumference.value
        let bwidth = result.rugbyFitnessMeasurements.backHeadWidth.value
        let occ = result.rugbyFitnessMeasurements.occipitalProminence.value
        let saved = SavedScanResult(timestamp: result.timestamp,
                                    overallQuality: result.overallQuality,
                                    successfulPoses: result.successfulPoses,
                                    totalScanTime: result.totalScanTime,
                                    headCircumferenceCM: hcCM,
                                    backHeadWidthMM: bwidth,
                                    occipitalProminenceMM: occ,
                                    poses: entries,
                                    fusedPointCloudPLY: fusedPointPLYName,
                                    fusedMeshPLY: fusedMeshPLYName,
                                    fusedMeshOBJZip: fusedMeshOBJZipName,
                                    fusedMeshGLB: fusedMeshGLBName)
        do {
            let data = try JSONEncoder().encode(saved)
            var url = base.appendingPathComponent(fileName)
            try data.write(to: url, options: .completeFileProtection)
            var rv = URLResourceValues()
            rv.isExcludedFromBackup = true
            try? url.setResourceValues(rv)
        } catch {
            AppLog.persistence.error("Failed to save results: \(String(describing: error))")
        }
    }

    static func load(fileName: String = "last_scan.json") -> SavedScanResult? {
        let url = appSupportURL().appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SavedScanResult.self, from: data)
        } catch {
            AppLog.persistence.error("Failed to load results: \(String(describing: error))")
            return nil
        }
    }

    private static func loadConfig() -> (fusionCropBelowNeck: Bool, fusionNeckOffsetMeters: Float, fusionOutlierSigma: Float, fusionDecimateRatio: Float, fusionPreScaleToMillimeters: Bool, meshingResolution: Int, meshingSmoothness: Int, meshingSurfaceTrimmingAmount: Int, meshingClosed: Bool, meshingExportOBJZip: Bool, meshingExportGLB: Bool) {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return (true, 0.15, 3.0, 1.0, true, 6, 3, 4, true, true, true)
        }
        
        let fusion = plist["fusion"] as? [String: Any] ?? [:]
        let meshing = plist["meshing"] as? [String: Any] ?? [:]
        
        return (
            fusion["cropBelowNeck"] as? Bool ?? true,
            fusion["neckOffsetMeters"] as? Float ?? 0.15,
            fusion["outlierSigma"] as? Float ?? 3.0,
            fusion["decimateRatio"] as? Float ?? 1.0,
            fusion["preScaleToMillimeters"] as? Bool ?? true,
            meshing["resolution"] as? Int ?? 6,
            meshing["smoothness"] as? Int ?? 3,
            meshing["surfaceTrimmingAmount"] as? Int ?? 4,
            meshing["closed"] as? Bool ?? true,
            meshing["exportOBJZip"] as? Bool ?? true,
            meshing["exportGLB"] as? Bool ?? true
        )
    }

}
