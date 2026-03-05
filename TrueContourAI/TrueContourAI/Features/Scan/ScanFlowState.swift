import Foundation

final class ScanFlowState {
    enum Phase: String {
        case idle
        case scanning
        case preview
        case saving
        case completed
        case failed
    }

    struct ScanSessionMetrics: Codable, Equatable {
        let startedAt: Date
        let finishedAt: Date
        let durationSeconds: Double
        let overallConfidence: Float

        func withOverallConfidence(_ confidence: Float) -> ScanSessionMetrics {
            ScanSessionMetrics(
                startedAt: startedAt,
                finishedAt: finishedAt,
                durationSeconds: durationSeconds,
                overallConfidence: max(0, min(1, confidence))
            )
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var scanStartTime: Date?

    var onPhaseChanged: ((Phase) -> Void)?
    var currentlyPreviewedFolderURL: URL?

    func resetForNewScan() {
        currentlyPreviewedFolderURL = nil
        scanStartTime = nil
        setPhase(.scanning)
    }

    func startScanSession() {
        resetForNewScan()
        scanStartTime = Date()
    }

    func completeScanSession(estimatedConfidence: Float) -> ScanSessionMetrics? {
        guard let start = scanStartTime else {
            setPhase(.completed)
            return nil
        }
        let finished = Date()
        let duration = max(0, finished.timeIntervalSince(start))

        let metrics = ScanSessionMetrics(
            startedAt: start,
            finishedAt: finished,
            durationSeconds: duration,
            overallConfidence: clamp(estimatedConfidence)
        )
        setPhase(.completed)
        return metrics
    }

    func failCurrentScan() {
        setPhase(.failed)
    }

    func setPhase(_ newPhase: Phase) {
        phase = newPhase
        onPhaseChanged?(newPhase)
    }

    private func clamp(_ value: Float) -> Float {
        max(0, min(1, value))
    }
}
