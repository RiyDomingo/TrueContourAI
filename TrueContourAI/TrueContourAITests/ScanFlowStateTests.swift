import XCTest
import UIKit
@testable import TrueContourAI

final class ScanFlowStateTests: XCTestCase {

    func testResetForNewScanClearsState() {
        let state = ScanFlowState()

        state.resetForNewScan()

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

        let metrics = state.completeScanSession()

        XCTAssertNotNil(metrics)
        XCTAssertEqual(state.phase, .completed)
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
