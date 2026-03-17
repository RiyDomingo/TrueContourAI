import Foundation
import UIKit

final class PreviewSessionController {
    let viewModel: PreviewViewModel
    let sessionState: PreviewSessionState

    init(
        viewModel: PreviewViewModel = PreviewViewModel(),
        sessionState: PreviewSessionState = PreviewSessionState()
    ) {
        self.viewModel = viewModel
        self.sessionState = sessionState
    }

    @discardableResult
    func beginExistingScanSession(
        preservedEarVerificationImage: UIImage? = nil,
        preservedEarVerificationSelectionMetadata: EarVerificationSelectionMetadata? = nil
    ) -> UUID {
        viewModel.beginExistingScanSession(
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
        viewModel.beginPreviewSession(
            sessionMetrics: sessionMetrics,
            preservedEarVerificationImage: preservedEarVerificationImage,
            preservedEarVerificationSelectionMetadata: preservedEarVerificationSelectionMetadata
        )
    }

    func invalidateSession() {
        viewModel.invalidateSession()
    }

    func isCurrentSession(_ sessionID: UUID) -> Bool {
        viewModel.isCurrentSession(sessionID)
    }

    var sessionID: UUID {
        viewModel.sessionID
    }

    var currentPreviewedFolderURL: URL? {
        get { sessionState.currentPreviewedFolderURL }
        set { sessionState.currentPreviewedFolderURL = newValue }
    }

    func clearPreviewArtifacts() {
        viewModel.clearPreviewArtifacts()
    }
}
