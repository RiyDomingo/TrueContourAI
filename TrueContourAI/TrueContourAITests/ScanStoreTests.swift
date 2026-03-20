import ObjectiveC.runtime
import StandardCyborgFusion
import XCTest
@testable import TrueContourAI

@MainActor
final class ScanStoreTests: XCTestCase {
    func testAuthorizationDeniedTransitionsToFailedAndAlertEffect() {
        let capture = ScanCaptureServiceFake()
        let runtime = ScanRuntimeEngineFake()
        let store = makeStore(capture: capture, runtime: runtime)
        var effects: [ScanEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.viewDidAppear)
        store.send(.startSession)
        store.send(.captureEvent(.authorizationDenied))

        guard case .failed(let failure) = store.state else {
            return XCTFail("Expected failed state")
        }
        XCTAssertEqual(failure.title, L("scan.start.cameraDenied.title"))
        XCTAssertEqual(effects.last, .alertThenDismiss(title: L("scan.start.cameraDenied.title"), message: L("scan.start.cameraDenied.message"), identifier: "cameraDenied"))
    }

    func testCaptureStartTransitionsToReady() {
        let store = makeStore()
        store.send(.viewDidAppear)
        store.send(.captureEvent(.started))

        guard case .ready(let viewData) = store.state else {
            return XCTFail("Expected ready state")
        }
        XCTAssertEqual(viewData.promptText, L("scanning.prompt.initial"))
    }

    func testViewDidAppearDoesNotTransitionToReadyBeforeCaptureStarts() {
        let capture = ScanCaptureServiceFake()
        let store = makeStore(capture: capture)

        store.send(.viewDidAppear)

        guard case .idle = store.state else {
            return XCTFail("Expected idle state until capture session starts")
        }
        XCTAssertEqual(capture.startSessionCount, 0)
    }

    func testReadyStartSessionBeginsCountdown() {
        let store = makeStore()
        store.send(.viewDidAppear)
        store.send(.captureEvent(.started))

        store.send(.startSession)

        guard case .countdown(let viewData) = store.state else {
            return XCTFail("Expected countdown state")
        }
        XCTAssertEqual(viewData.countdownText, "3")
    }

    func testRuntimeProgressTransitionsToCapturing() {
        let runtime = ScanRuntimeEngineFake()
        let store = makeStore(runtime: runtime)
        store.send(.viewDidAppear)
        store.send(.captureEvent(.started))
        store.send(.startSession)
        RunLoop.current.run(until: Date().addingTimeInterval(2.6))

        store.send(
            .runtimeEvent(
                .progress(
                    ScanProgressSnapshot(
                        capturedSeconds: 12,
                        targetSeconds: 50,
                        progressFraction: 0.24,
                        manualFinishAllowed: true,
                        developerDiagnosticsText: "diag"
                    )
                )
            )
        )

        guard case .capturing(let viewData) = store.state else {
            return XCTFail("Expected capturing state")
        }
        XCTAssertEqual(viewData.progressText, L("scanning.progress.capturing"))
        XCTAssertEqual(viewData.progressFraction, 0.24)
    }

    func testFinishTransitionsToFinishingAndThenCompleted() {
        let capture = ScanCaptureServiceFake()
        let runtime = ScanRuntimeEngineFake()
        let store = makeStore(capture: capture, runtime: runtime)
        let payload = ScanPreviewInput(
            pointCloud: runtime.pointCloud,
            meshTexturing: runtime.meshTexturing,
            earVerificationImage: nil,
            earVerificationSelectionMetadata: nil
        )

        store.send(.viewDidAppear)
        store.send(.captureEvent(.started))
        store.send(.startSession)
        RunLoop.current.run(until: Date().addingTimeInterval(2.6))
        store.send(
            .runtimeEvent(
                .progress(
                    ScanProgressSnapshot(
                        capturedSeconds: 4,
                        targetSeconds: 50,
                        progressFraction: 0.08,
                        manualFinishAllowed: true,
                        developerDiagnosticsText: nil
                    )
                )
            )
        )
        store.send(.finishTapped)

        guard case .finishing = store.state else {
            return XCTFail("Expected finishing state")
        }
        XCTAssertEqual(capture.stopSessionCount, 1)

        store.send(.runtimeEvent(.completed(payload)))
        guard case .completed = store.state else {
            return XCTFail("Expected completed state")
        }
    }

    func testDismissWhileCapturingEmitsDismissEffect() {
        let runtime = ScanRuntimeEngineFake()
        let store = makeStore(runtime: runtime)
        var effects: [ScanEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.viewDidAppear)
        store.send(.captureEvent(.started))
        store.send(.startSession)
        RunLoop.current.run(until: Date().addingTimeInterval(2.6))
        store.send(
            .runtimeEvent(
                .progress(
                    ScanProgressSnapshot(
                        capturedSeconds: 1,
                        targetSeconds: 50,
                        progressFraction: 0.02,
                        manualFinishAllowed: true,
                        developerDiagnosticsText: nil
                    )
                )
            )
        )

        store.send(.dismissTapped)
        XCTAssertEqual(effects.last, .dismiss)
    }

    func testDismissDuringCountdownEmitsDismissEffect() {
        let store = makeStore()
        var effects: [ScanEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.viewDidAppear)
        store.send(.captureEvent(.started))
        store.send(.startSession)

        guard case .countdown = store.state else {
            return XCTFail("Expected countdown state before dismiss")
        }

        store.send(.dismissTapped)

        XCTAssertEqual(effects.last, .dismiss)
        guard case .ready = store.state else {
            return XCTFail("Expected ready state after countdown cancel")
        }
    }

    func testConfigurationFailureTransitionsToFailedAndDismissAlertEffect() {
        let store = makeStore()
        var effects: [ScanEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.viewDidAppear)
        store.send(.startSession)
        store.send(.captureEvent(.configurationFailed("camera unavailable")))

        guard case .failed(let failure) = store.state else {
            return XCTFail("Expected failed state")
        }
        XCTAssertEqual(failure.message, "camera unavailable")
        XCTAssertEqual(
            effects.last,
            .alertThenDismiss(
                title: L("scan.start.cameraUnavailable.title"),
                message: "camera unavailable",
                identifier: "cameraUnavailable"
            )
        )
    }

    func testThermalShutdownWhileCapturingEmitsDismissAlertAndFinishes() {
        let capture = ScanCaptureServiceFake()
        let runtime = ScanRuntimeEngineFake()
        let store = makeStore(capture: capture, runtime: runtime)
        var effects: [ScanEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.viewDidAppear)
        store.send(.captureEvent(.started))
        store.send(.startSession)
        RunLoop.current.run(until: Date().addingTimeInterval(2.6))
        store.send(
            .runtimeEvent(
                .progress(
                    ScanProgressSnapshot(
                        capturedSeconds: 2,
                        targetSeconds: 50,
                        progressFraction: 0.04,
                        manualFinishAllowed: true,
                        developerDiagnosticsText: nil
                    )
                )
            )
        )

        store.send(.runtimeEvent(.thermalShutdown))

        guard case .finishing = store.state else {
            return XCTFail("Expected finishing state after thermal shutdown")
        }
        XCTAssertEqual(capture.stopSessionCount, 1)
        XCTAssertEqual(
            effects.last,
            .alertThenDismiss(
                title: L("scanning.thermal.title"),
                message: L("scanning.thermal.message"),
                identifier: "thermalShutdown"
            )
        )
    }

    func testFocusIsForwardedOnlyWhenReady() {
        let capture = ScanCaptureServiceFake()
        let store = makeStore(capture: capture)

        store.send(.focusRequested(CGPoint(x: 4, y: 8)))
        XCTAssertNil(capture.lastFocusPoint)

        store.send(.viewDidAppear)
        store.send(.captureEvent(.started))
        store.send(.focusRequested(CGPoint(x: 4, y: 8)))

        XCTAssertEqual(capture.lastFocusPoint, CGPoint(x: 4, y: 8))
    }

    private func makeStore(
        capture: ScanCaptureServiceFake = ScanCaptureServiceFake(),
        runtime: ScanRuntimeEngineFake = ScanRuntimeEngineFake()
    ) -> ScanStore {
        ScanStore(
            captureService: capture,
            runtimeEngine: runtime,
            autoFinishSeconds: 0,
            requiresManualFinish: true,
            developerModeEnabled: false,
            hapticEngine: HapticsFake()
        )
    }
}

private final class ScanCaptureServiceFake: ScanCaptureServicing {
    var onEvent: ((ScanCaptureEvent) -> Void)?
    var diagnosticsSnapshot = CameraDiagnosticsSnapshot()
    var isSessionRunning = true
    private(set) var startSessionCount = 0
    private(set) var stopSessionCount = 0
    private(set) var lastFocusPoint: CGPoint?

    func startSession() {
        startSessionCount += 1
    }

    func stopSession(completion: (() -> Void)?) {
        stopSessionCount += 1
        completion?()
    }

    func focus(at location: CGPoint) {
        lastFocusPoint = location
    }
}

private final class ScanRuntimeEngineFake: ScanRuntimeEngining {
    var onEvent: ((ScanRuntimeEvent) -> Void)?
    var onRenderFrame: ((ScanRenderFrame) -> Void)?
    var diagnosticsSnapshot = ScanRuntimeDiagnosticsSnapshot(succeededCount: 0, lostTrackingCount: 0, droppedFrameCount: 0)
    let pointCloud: SCPointCloud
    let meshTexturing = SCMeshTexturing()

    init() {
        guard let placeholder = class_createInstance(SCPointCloud.self, 0) as? SCPointCloud else {
            fatalError("Failed to allocate SCPointCloud placeholder")
        }
        pointCloud = placeholder
    }

    func activate() {}
    func deactivate() {}
    func beginCapture(autoFinishSeconds: Int) {}
    func processFrame(_ frame: ScanFramePayload, isScanning: Bool) {}
    func finishCapture() {}
    func cancelCapture() {}
}

private final class HapticsFake: ScanningHapticFeedbackProviding {
    func countdownCountedDown() {}
    func scanningBegan() {}
    func scanningFinished() {}
    func scanningCanceled() {}
}
