import Foundation
import UIKit

final class PreviewSessionController {
    let store: PreviewStore
    let sessionState: PreviewSessionState

    init(
        store: PreviewStore,
        sessionState: PreviewSessionState = PreviewSessionState()
    ) {
        self.store = store
        self.sessionState = sessionState
    }

    @discardableResult
    func beginExistingScanSession(
        preservedEarVerificationImage: UIImage? = nil,
        preservedEarVerificationSelectionMetadata: EarVerificationSelectionMetadata? = nil
    ) -> UUID {
        store.beginExistingScanSession(
            preservedEarVerificationImage: preservedEarVerificationImage,
            preservedEarVerificationSelectionMetadata: preservedEarVerificationSelectionMetadata
        )
    }

    @discardableResult
    func beginPreviewSession(
        sessionMetrics: ScanFlowState.ScanSessionMetrics?,
        preservedEarVerificationImage: UIImage? = nil,
        preservedEarVerificationSelectionMetadata: EarVerificationSelectionMetadata? = nil
    ) -> UUID {
        store.beginPreviewSession(
            sessionMetrics: sessionMetrics,
            preservedEarVerificationImage: preservedEarVerificationImage,
            preservedEarVerificationSelectionMetadata: preservedEarVerificationSelectionMetadata
        )
    }

    func invalidateSession() {
        store.invalidateSession()
    }

    func isCurrentSession(_ sessionID: UUID) -> Bool {
        store.isCurrentSession(sessionID)
    }

    var sessionID: UUID {
        store.sessionID
    }

    var currentPreviewedFolderURL: URL? {
        get { sessionState.currentPreviewedFolderURL }
        set { sessionState.currentPreviewedFolderURL = newValue }
    }

    func clearPreviewArtifacts() {
        store.clearPreviewArtifacts()
    }
}
