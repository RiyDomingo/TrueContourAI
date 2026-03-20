import UIKit
import SceneKit
import StandardCyborgFusion
import simd

enum PreviewState: Equatable {
    case loading
    case ready(PreviewViewData)
    case meshing(PreviewViewData)
    case saving(PreviewViewData)
    case blocked(PreviewBlockReason, PreviewViewData)
    case saved(SavedScanResult)
    case failed(PreviewFailure, PreviewViewData)
}

enum PreviewAction {
    case viewDidLoad
    case existingScanLoaded(PreviewLoadedScan)
    case postScanLoaded(ScanPreviewInput)
    case saveTapped
    case shareTapped
    case closeTapped
    case verifyEarTapped
    case fitTapped
    case fitEarPointSelected(SIMD3<Float>)
    case exportCompleted(Result<SavedScanResult, PreviewFailure>)
    case earVerificationCompleted(Result<PreviewEarVerificationResult, PreviewFailure>)
    case fitCompleted(Result<PreviewFitResult, PreviewFailure>)
}

enum PreviewEffect {
    case alert(title: String, message: String, identifier: String)
    case toast(String)
    case route(PreviewRoute)
    case hapticPrimary
}

enum PreviewRoute {
    case dismiss
    case returnHomeAfterSave(SavedScanResult)
    case presentShare(items: [Any], sourceRect: CGRect?)
}

enum PreviewExportResultEvent: Equatable {
    case success(folderName: String, formatSummary: String, earServiceUnavailable: Bool)
    case failure(message: String)
}

struct PreviewViewData: Equatable {
    let qualityTitle: String?
    let qualityColorToken: PreviewColorToken?
    let qualityTipText: String?
    let measurementSummaryText: String?
    let meshingStatusText: String
    let meshingSpinnerVisible: Bool
    let saveButtonEnabled: Bool
    let shareButtonEnabled: Bool
    let verifyEarButtonEnabled: Bool
    let fitPanelVisible: Bool
    let fitPanelExpanded: Bool
    let exportFormatSummary: String
    let earVerified: Bool
}

enum PreviewColorToken: Equatable {
    case good
    case ok
    case bad
}

struct PreviewLoadedScan: Equatable {
    let scene: SCScene?
    let scanSummary: ScanSummary?
    let earVerificationImage: UIImage?
    let folderURL: URL

    static func == (lhs: PreviewLoadedScan, rhs: PreviewLoadedScan) -> Bool {
        lhs.folderURL == rhs.folderURL &&
        lhs.scanSummary == rhs.scanSummary &&
        (lhs.scene != nil) == (rhs.scene != nil) &&
        (lhs.earVerificationImage != nil) == (rhs.earVerificationImage != nil)
    }
}

enum PreviewBlockReason: Equatable {
    case meshNotReady
    case qualityGateBlocked(reason: String, advice: String)
    case gltfRequired
    case exportUnavailable
}

enum PreviewFailure: Error, Equatable {
    case exportFailed(String)
    case loadFailed(String)
    case verificationFailed(String)
    case fitFailed(String)
}

struct SavedScanResult: Equatable {
    let folderURL: URL
    let folderName: String
    let formatSummary: String
    let earServiceUnavailable: Bool
}

struct PreviewEarVerificationResult: Equatable {
    let earImage: UIImage
    let earResult: EarLandmarksResult
    let earOverlay: UIImage
    let earCropOverlay: UIImage

    static func == (lhs: PreviewEarVerificationResult, rhs: PreviewEarVerificationResult) -> Bool {
        lhs.earResult.confidence == rhs.earResult.confidence &&
        lhs.earResult.earBoundingBox == rhs.earResult.earBoundingBox &&
        lhs.earResult.landmarks == rhs.earResult.landmarks &&
        lhs.earResult.usedLeftEarMirroringHeuristic == rhs.earResult.usedLeftEarMirroringHeuristic
    }
}

struct PreviewFitResult: Equatable {
    let summaryText: String
    let fitCheckResult: FitModelCheckResult?
    let meshDataAvailable: Bool
}

struct PreviewExportEligibilityInput: Equatable {
    let meshAvailable: Bool
    let qualityReport: ScanQualityReport?
    let exportGLTF: Bool
    let exportOBJ: Bool
    let qualityGateEnabled: Bool
}

struct PreviewSceneSnapshot {
    let scene: SCScene
    let renderedImage: UIImage?
}

struct PreviewExportSnapshot {
    let mesh: SCMesh
    let sceneSnapshot: PreviewSceneSnapshot
    let earArtifacts: ScanEarArtifacts?
    let scanSummary: ScanSummary?
    let exportGLTF: Bool
    let exportOBJ: Bool
}

struct PreviewExportRequest {
    let mesh: SCMesh
    let scene: SCScene
    let thumbnail: UIImage?
    let earArtifacts: ScanEarArtifacts?
    let scanSummary: ScanSummary?
    let includeGLTF: Bool
    let includeOBJ: Bool
}
