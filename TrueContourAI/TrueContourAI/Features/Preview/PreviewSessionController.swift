import Foundation

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
    func beginExistingScanSession() -> UUID {
        viewModel.beginExistingScanSession()
    }

    @discardableResult
    func beginPreviewSession(sessionMetrics: ScanFlowState.ScanSessionMetrics?) -> UUID {
        viewModel.beginPreviewSession(sessionMetrics: sessionMetrics)
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
