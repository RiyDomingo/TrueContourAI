import XCTest
import UIKit
@testable import TrueContourAI

final class ScanFlowStateTests: XCTestCase {

    func testResetForNewScanClearsState() {
        let state = ScanFlowState()
        state.currentlyPreviewedFolderURL = URL(fileURLWithPath: "/tmp/scan")

        state.resetForNewScan()

        XCTAssertNil(state.currentlyPreviewedFolderURL)
        XCTAssertEqual(state.phase, .scanning)
    }

    func testPhaseTransitionsNotifyObserver() {
        let state = ScanFlowState()
        var phases: [ScanFlowState.Phase] = []
        state.onPhaseChanged = { phases.append($0) }

        state.setPhase(.scanning)
        state.setPhase(.preview)
        state.setPhase(.saving)
        state.setPhase(.idle)

        XCTAssertEqual(phases, [.scanning, .preview, .saving, .idle])
    }

    func testScanSessionCompletionMetrics() {
        let state = ScanFlowState()
        state.startScanSession()
        XCTAssertEqual(state.phase, .scanning)

        let metrics = state.completeScanSession(estimatedConfidence: 0.85)

        XCTAssertNotNil(metrics)
        XCTAssertEqual(state.phase, .completed)
        XCTAssertEqual(metrics?.overallConfidence, 0.85)
        XCTAssertGreaterThanOrEqual(metrics?.durationSeconds ?? 0, 0)
    }

    func testTransitionMatrixCancelFailSavePermutations() {
        let permutations: [[ScanFlowState.Phase]] = [
            [.scanning, .failed, .idle],            // cancel path
            [.scanning, .failed, .preview, .idle],  // fail then recover to preview
            [.scanning, .preview, .saving, .idle],  // successful save path
            [.scanning, .preview, .saving, .preview, .idle] // save error then recover
        ]

        for sequence in permutations {
            let state = ScanFlowState()
            var observed: [ScanFlowState.Phase] = []
            state.onPhaseChanged = { observed.append($0) }
            for phase in sequence {
                state.setPhase(phase)
            }
            XCTAssertEqual(observed, sequence)
            XCTAssertEqual(state.phase, sequence.last)
        }
    }
}

final class PreviewViewModelTests: XCTestCase {
    func testVerificationRequiresAllArtifacts() {
        let viewModel = PreviewViewModel()
        XCTAssertFalse(viewModel.hasVerifiedEar)

        viewModel.setVerifiedEar(
            image: UIImage(),
            result: EarLandmarksResult(
                confidence: 0.9,
                earBoundingBox: .init(x: 0, y: 0, w: 1, h: 1),
                landmarks: [],
                usedLeftEarMirroringHeuristic: false
            ),
            overlay: UIImage()
        )
        XCTAssertTrue(viewModel.hasVerifiedEar)

        viewModel.clearVerification()
        XCTAssertFalse(viewModel.hasVerifiedEar)
    }

    func testPhaseChanges() {
        let viewModel = PreviewViewModel()
        XCTAssertEqual(viewModel.phase, .preview)
        viewModel.setPhase(.saving)
        XCTAssertEqual(viewModel.phase, .saving)
        viewModel.setPhase(.idle)
        XCTAssertEqual(viewModel.phase, .idle)
    }

    func testEvaluateScanQualityThresholds() {
        let viewModel = PreviewViewModel()

        let low = viewModel.evaluateScanQuality(pointCount: 50_000)
        XCTAssertEqual(low.title, L("scan.preview.quality.tryagain"))

        let ok = viewModel.evaluateScanQuality(pointCount: 120_000)
        XCTAssertEqual(ok.title, L("scan.preview.quality.ok"))

        let great = viewModel.evaluateScanQuality(pointCount: 220_000)
        XCTAssertEqual(great.title, L("scan.preview.quality.great"))
    }
}
