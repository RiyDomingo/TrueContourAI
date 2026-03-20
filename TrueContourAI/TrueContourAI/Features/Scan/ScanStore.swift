import Foundation

final class ScanStore {
    private(set) var state: ScanState = .idle {
        didSet {
            guard oldValue != state else { return }
            dispatchOnMain { [state] in
                self.onStateChange?(state)
            }
        }
    }

    var onStateChange: ((ScanState) -> Void)?
    var onEffect: ((ScanEffect) -> Void)?

    private let captureService: ScanCaptureServicing
    private let runtimeEngine: ScanRuntimeEngining
    private let sessionController: ScanSessionController
    private let dispatchOnMain: (@escaping () -> Void) -> Void
    private let initialFailure: ScanFailureViewData?
    private let initialFailureAlertIdentifier: String?

    private var autoFinishSeconds: Int
    private var requiresManualFinish: Bool
    private var developerModeEnabled: Bool
    private var latestGuidance: ScanGuidanceSignal?
    private var latestProgress: ScanProgressSnapshot?
    private var thermalWarningVisible = false
    private var hasCaptureSession = false
    private var hasPresentedInitialFailureAlert = false

    init(
        captureService: ScanCaptureServicing,
        runtimeEngine: ScanRuntimeEngining,
        autoFinishSeconds: Int,
        requiresManualFinish: Bool,
        developerModeEnabled: Bool,
        initialFailure: ScanFailureViewData? = nil,
        initialFailureAlertIdentifier: String? = nil,
        hapticEngine: ScanningHapticFeedbackProviding,
        dispatchOnMain: @escaping (@escaping () -> Void) -> Void = { work in
            if Thread.isMainThread {
                work()
            } else {
                DispatchQueue.main.async(execute: work)
            }
        }
    ) {
        self.captureService = captureService
        self.runtimeEngine = runtimeEngine
        self.autoFinishSeconds = autoFinishSeconds
        self.requiresManualFinish = requiresManualFinish
        self.developerModeEnabled = developerModeEnabled
        self.initialFailure = initialFailure
        self.initialFailureAlertIdentifier = initialFailureAlertIdentifier
        self.dispatchOnMain = dispatchOnMain
        self.sessionController = ScanSessionController(hapticEngine: hapticEngine)
        self.sessionController.autoFinishSeconds = autoFinishSeconds

        captureService.onEvent = { [weak self] in self?.send(.captureEvent($0)) }
        runtimeEngine.onEvent = { [weak self] in self?.send(.runtimeEvent($0)) }
        sessionController.onCountdownChange = { [weak self] seconds in
            self?.handleCountdownChanged(seconds)
        }
        sessionController.onScanningChanged = { [weak self] isScanning in
            self?.handleScanningChanged(isScanning)
        }
        sessionController.onAutoFinishRemainingChange = { [weak self] _ in
            self?.refreshScanningState(currentStateKind: .capturing)
        }
        sessionController.onAutoFinishTriggered = { [weak self] in
            self?.send(.finishTapped)
        }

        if let initialFailure {
            state = .failed(initialFailure)
        }
    }

    func send(_ action: ScanAction) {
        switch action {
        case .viewDidAppear:
            if let initialFailure {
                guard !hasPresentedInitialFailureAlert else { return }
                hasPresentedInitialFailureAlert = true
                emitEffect(
                    .alertThenDismiss(
                        title: initialFailure.title,
                        message: initialFailure.message,
                        identifier: initialFailureAlertIdentifier ?? "scanUnavailable"
                    )
                )
                return
            }
            runtimeEngine.activate()
        case .viewWillDisappear:
            runtimeEngine.deactivate()
        case .startSession:
            handleStartOrShutterTapped()
        case .dismissTapped:
            handleDismissTapped()
        case .finishTapped:
            handleFinishTapped()
        case let .focusRequested(point):
            guard case .ready = state else { return }
            captureService.focus(at: point)
        case .countdownTick:
            break
        case let .captureEvent(event):
            handleCaptureEvent(event)
        case let .runtimeEvent(event):
            handleRuntimeEvent(event)
        }
    }

    private func handleStartOrShutterTapped() {
        if !hasCaptureSession {
            state = .requestingPermission
            captureService.startSession()
            return
        }

        switch state {
        case .idle, .requestingPermission:
            break
        case .ready:
            sessionController.startCountdown { [weak self] in
                self?.beginCapture()
            }
        case .countdown:
            sessionController.cancelCountdown()
        case .failed(let failure) where failure.allowsRetry:
            state = .requestingPermission
            captureService.startSession()
        default:
            break
        }
    }

    private func handleDismissTapped() {
        switch state {
        case .countdown:
            sessionController.cancelCountdown()
            emitEffect(.dismiss)
        case .capturing, .finishing:
            captureService.stopSession(completion: nil)
            runtimeEngine.cancelCapture()
            emitEffect(.dismiss)
        case .ready, .failed, .unavailable, .idle, .requestingPermission:
            emitEffect(.dismiss)
        case .completed:
            break
        }
    }

    private func handleFinishTapped() {
        switch state {
        case .capturing:
            sessionController.stopScanning(reason: .finished)
            state = .finishing(makeCapturingViewData())
            captureService.stopSession { [weak self] in
                self?.runtimeEngine.finishCapture()
            }
        case .ready:
            sessionController.startCountdown { [weak self] in
                self?.beginCapture()
            }
        default:
            break
        }
    }

    private func beginCapture() {
        runtimeEngine.beginCapture(autoFinishSeconds: autoFinishSeconds)
        latestGuidance = ScanGuidanceSignal(
            promptText: L("scanning.guidance.short.start"),
            chipText: L("scanning.guidance.status.caution"),
            chipStyle: .caution,
            focusHintText: nil
        )
        latestProgress = makeInitialProgressSnapshot()
        thermalWarningVisible = false
        sessionController.beginScanning()
    }

    private func handleCaptureEvent(_ event: ScanCaptureEvent) {
        switch event {
        case .started:
            hasCaptureSession = true
            state = .ready(makeReadyViewData())
        case .authorizationDenied:
            state = .failed(
                ScanFailureViewData(
                    title: L("scan.start.cameraDenied.title"),
                    message: L("scan.start.cameraDenied.message"),
                    allowsRetry: false
                )
            )
            emitEffect(
                .alertThenDismiss(
                    title: L("scan.start.cameraDenied.title"),
                    message: L("scan.start.cameraDenied.message"),
                    identifier: "cameraDenied"
                )
            )
        case let .configurationFailed(message):
            state = .failed(
                ScanFailureViewData(
                    title: L("scan.start.cameraUnavailable.title"),
                    message: message,
                    allowsRetry: false
                )
            )
            emitEffect(
                .alertThenDismiss(
                    title: L("scan.start.cameraUnavailable.title"),
                    message: message,
                    identifier: "cameraUnavailable"
                )
            )
        case let .frame(payload):
            runtimeEngine.processFrame(payload, isScanning: isActiveScanningState)
        case .stopped:
            break
        case .interrupted, .resumed:
            break
        }
    }

    private func handleRuntimeEvent(_ event: ScanRuntimeEvent) {
        switch event {
        case .sessionReady:
            if case .idle = state {
                state = .ready(makeReadyViewData())
            }
        case let .guidance(signal):
            latestGuidance = signal
            if isActiveScanningState {
                refreshScanningState(currentStateKind: .capturing)
            }
        case let .progress(snapshot):
            latestProgress = snapshot
            if isActiveScanningState {
                refreshScanningState(currentStateKind: .capturing)
            }
        case .thermalWarning:
            thermalWarningVisible = true
            if isActiveScanningState {
                refreshScanningState(currentStateKind: .capturing)
            }
        case .thermalShutdown:
            thermalWarningVisible = true
            emitEffect(
                .alertThenDismiss(
                    title: L("scanning.thermal.title"),
                    message: L("scanning.thermal.message"),
                    identifier: "thermalShutdown"
                )
            )
            if isActiveScanningState {
                handleFinishTapped()
            }
        case let .completed(payload):
            thermalWarningVisible = false
            state = .completed(payload)
        case let .failed(failure):
            thermalWarningVisible = false
            runtimeEngine.cancelCapture()
            switch failure {
            case .canceled:
                emitEffect(.dismiss)
            case .cameraAccessDenied:
                state = .failed(
                    ScanFailureViewData(
                        title: L("scan.start.cameraDenied.title"),
                        message: L("scan.start.cameraDenied.message"),
                        allowsRetry: false
                    )
                )
            case .thermalShutdown:
                state = .failed(
                    ScanFailureViewData(
                        title: L("scanning.thermal.title"),
                        message: L("scanning.thermal.message"),
                        allowsRetry: false
                    )
                )
            case let .captureConfigurationFailed(message), let .reconstructionFailed(message):
                state = .failed(
                    ScanFailureViewData(
                        title: L("scan.start.cameraUnavailable.title"),
                        message: message,
                        allowsRetry: true
                    )
                )
            }
        }
    }

    private func handleCountdownChanged(_ seconds: Int?) {
        guard let seconds else {
            guard !isActiveScanningState else { return }
            if hasCaptureSession {
                state = .ready(makeReadyViewData())
            } else {
                state = .idle
            }
            return
        }
        state = .countdown(makeCountdownViewData(seconds: seconds))
    }

    private func handleScanningChanged(_ isScanning: Bool) {
        guard isScanning else {
            if case .finishing = state {
                return
            }
            if hasCaptureSession {
                state = .ready(makeReadyViewData())
            } else {
                state = .idle
            }
            return
        }
        refreshScanningState(currentStateKind: .capturing)
    }

    private var isActiveScanningState: Bool {
        switch state {
        case .capturing, .finishing:
            return true
        default:
            return false
        }
    }

    private func refreshScanningState(currentStateKind: ScanStateKind) {
        let data = makeCapturingViewData()
        switch currentStateKind {
        case .capturing:
            state = .capturing(data)
        case .finishing:
            state = .finishing(data)
        }
    }

    private func makeReadyViewData() -> ScanReadyViewData {
        ScanReadyViewData(
            promptText: L("scanning.prompt.initial"),
            focusHintText: L("scanning.focusHint"),
            finishButtonVisible: false,
            finishButtonEnabled: false,
            dismissButtonEnabled: true,
            developerDiagnosticsText: developerModeEnabled ? makeDeveloperDiagnosticsText() : nil
        )
    }

    private func makeCountdownViewData(seconds: Int) -> ScanCapturingViewData {
        ScanCapturingViewData(
            promptText: "",
            guidanceChipText: nil,
            guidanceChipStyle: .neutral,
            focusHintText: nil,
            progressText: nil,
            progressFraction: nil,
            countdownText: "\(seconds)",
            finishButtonVisible: false,
            finishButtonEnabled: false,
            dismissButtonEnabled: true,
            developerDiagnosticsText: nil,
            thermalWarningVisible: false
        )
    }

    private func makeCapturingViewData() -> ScanCapturingViewData {
        let guidance = latestGuidance
        let progress = latestProgress ?? makeInitialProgressSnapshot()
        let progressText: String
        if autoFinishSeconds > 0 {
            progressText = String(format: L("scanning.progress.timeFormat"), progress.capturedSeconds, progress.targetSeconds)
        } else {
            progressText = L("scanning.progress.capturing")
        }
        return ScanCapturingViewData(
            promptText: guidance?.promptText ?? L("scanning.guidance.short.start"),
            guidanceChipText: guidance?.chipText,
            guidanceChipStyle: guidance?.chipStyle ?? .caution,
            focusHintText: guidance?.focusHintText,
            progressText: progressText,
            progressFraction: progress.progressFraction,
            countdownText: nil,
            finishButtonVisible: requiresManualFinish,
            finishButtonEnabled: progress.manualFinishAllowed,
            dismissButtonEnabled: true,
            developerDiagnosticsText: developerModeEnabled ? makeDeveloperDiagnosticsText(runtimeText: progress.developerDiagnosticsText) : nil,
            thermalWarningVisible: thermalWarningVisible
        )
    }

    private func makeInitialProgressSnapshot() -> ScanProgressSnapshot {
        ScanProgressSnapshot(
            capturedSeconds: 0,
            targetSeconds: autoFinishSeconds > 0 ? autoFinishSeconds : 50,
            progressFraction: 0,
            manualFinishAllowed: requiresManualFinish,
            developerDiagnosticsText: developerModeEnabled ? makeDeveloperDiagnosticsText() : nil
        )
    }

    private func makeDeveloperDiagnosticsText(runtimeText: String? = nil) -> String {
        let camera = captureService.diagnosticsSnapshot
        let runtime = runtimeEngine.diagnosticsSnapshot
        let tail = runtimeText.map { " · \($0)" } ?? ""
        return "camera pair=\(camera.deliveredSynchronizedPairCount) drop=\(camera.droppedSynchronizedPairCount) depth=\(camera.droppedDepthDataCount) video=\(camera.droppedVideoDataCount) miss=\(camera.missingSynchronizedDataCount) · recon ok=\(runtime.succeededCount) lost=\(runtime.lostTrackingCount) drop=\(runtime.droppedFrameCount)\(tail)"
    }

    private func emitEffect(_ effect: ScanEffect) {
        dispatchOnMain { [effect] in
            self.onEffect?(effect)
        }
    }

    private enum ScanStateKind {
        case capturing
        case finishing
    }
}
