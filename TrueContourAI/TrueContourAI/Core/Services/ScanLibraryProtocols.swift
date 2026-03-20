import Foundation
import UIKit

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
    ScanFolderSharing {
    func resolveEarVerificationImage(from folder: URL) -> UIImage?
}

protocol ScanRootSharing: ScansRootEnsuring, ScanFolderSharing {}

protocol ScanStorageManaging: ScansRootEnsuring, LastScanReading {}
