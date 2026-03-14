import Foundation
import UIKit
import StandardCyborgFusion

struct StoredScanSummary: Codable, Equatable {
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

struct StoredScanItem {
    let folderURL: URL
    let displayName: String
    let date: Date
    let thumbnailURL: URL?
    let sceneGLTFURL: URL?
}

struct StoredScanEarArtifacts {
    let earImage: UIImage
    let earResult: EarLandmarksResult
    let earOverlay: UIImage
    let earCropOverlay: UIImage
}

enum StoredScanExportResult {
    case success(folderURL: URL)
    case failure(String)
}

enum StoredScanRenameResult {
    case success(newURL: URL)
    case nameExists
    case invalidName
    case failure(Error)
}

typealias ScanSummary = StoredScanSummary
typealias ScanItem = StoredScanItem
typealias ScanEarArtifacts = StoredScanEarArtifacts
typealias ScanExportResult = StoredScanExportResult
typealias ScanRenameResult = StoredScanRenameResult
