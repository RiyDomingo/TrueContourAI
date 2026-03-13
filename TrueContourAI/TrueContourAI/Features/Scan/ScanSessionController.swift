import Foundation

enum AppScanningSessionState: Equatable {
    case `default`
    case countdown(Int)
    case scanning
}

enum AppScanningTerminationReason {
    case canceled
    case finished
}

final class ScanSessionController {
    private let hapticEngine: ScanningHapticFeedbackProviding
    private let countdownStartCount: Int
    private let countdownPerSecondDuration: TimeInterval

    var autoFinishSeconds: Int = 0

    var onStateChange: ((AppScanningSessionState) -> Void)?
    var onAutoFinishRemainingChange: ((Int) -> Void)?
    var onAutoFinishTriggered: (() -> Void)?

    private(set) var state: AppScanningSessionState = .default {
        didSet {
            onStateChange?(state)
        }
    }

    private(set) var autoFinishRemaining: Int = 0 {
        didSet {
            onAutoFinishRemainingChange?(autoFinishRemaining)
        }
    }

    private var countdownTimer: Timer?
    private var autoFinishTimer: Timer?
    private var autoFinishCountdownTimer: Timer?

    init(
        hapticEngine: ScanningHapticFeedbackProviding,
        countdownStartCount: Int = 3,
        countdownPerSecondDuration: TimeInterval = 0.75
    ) {
        self.hapticEngine = hapticEngine
        self.countdownStartCount = countdownStartCount
        self.countdownPerSecondDuration = countdownPerSecondDuration
    }

    func startCountdown(completion: @escaping () -> Void) {
        invalidateCountdownTimer()
        var remaining = countdownStartCount
        state = .countdown(remaining)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: countdownPerSecondDuration, repeats: true) { [weak self] timer in
            guard let self else { return }
            hapticEngine.countdownCountedDown()
            remaining -= 1
            if remaining <= 0 {
                timer.invalidate()
                countdownTimer = nil
                state = .default
                completion()
            } else {
                state = .countdown(remaining)
            }
        }
    }

    func cancelCountdown() {
        invalidateCountdownTimer()
        hapticEngine.scanningCanceled()
        state = .default
    }

    func beginScanning() {
        hapticEngine.scanningBegan()
        state = .scanning
        startAutoFinishTimerIfNeeded()
    }

    @discardableResult
    func stopScanning(reason: AppScanningTerminationReason) -> Bool {
        guard state == .scanning else { return false }
        state = .default
        stopAutoFinishTimers()

        switch reason {
        case .canceled:
            hapticEngine.scanningCanceled()
        case .finished:
            hapticEngine.scanningFinished()
        }

        return true
    }

    func invalidate() {
        invalidateCountdownTimer()
        stopAutoFinishTimers()
        state = .default
    }

#if DEBUG
    func debug_setStateScanning() {
        state = .scanning
    }

    func debug_setStateDefault() {
        state = .default
    }

    func debug_setStateCountdown(seconds: Int) {
        state = .countdown(seconds)
    }

    func debug_setAutoFinish(seconds: Int, remaining: Int) {
        autoFinishSeconds = seconds
        autoFinishRemaining = remaining
    }
#endif

    private func startAutoFinishTimerIfNeeded() {
        stopAutoFinishTimers()
        guard autoFinishSeconds > 0 else {
            autoFinishRemaining = 0
            return
        }

        autoFinishRemaining = autoFinishSeconds
        autoFinishTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(autoFinishSeconds), repeats: false) { [weak self] _ in
            self?.onAutoFinishTriggered?()
        }
        autoFinishCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { return }
            autoFinishRemaining = max(0, autoFinishRemaining - 1)
            if autoFinishRemaining <= 0 {
                timer.invalidate()
                autoFinishCountdownTimer = nil
            }
        }
    }

    private func stopAutoFinishTimers() {
        autoFinishTimer?.invalidate()
        autoFinishTimer = nil
        autoFinishCountdownTimer?.invalidate()
        autoFinishCountdownTimer = nil
        autoFinishRemaining = 0
    }

    private func invalidateCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}
