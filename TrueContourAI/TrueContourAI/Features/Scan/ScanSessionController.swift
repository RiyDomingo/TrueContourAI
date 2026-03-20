import Foundation

enum AppScanningTerminationReason {
    case canceled
    case finished
}

final class ScanSessionController {
    private let hapticEngine: ScanningHapticFeedbackProviding
    private let countdownStartCount: Int
    private let countdownPerSecondDuration: TimeInterval

    var autoFinishSeconds: Int = 0

    var onCountdownChange: ((Int?) -> Void)?
    var onScanningChanged: ((Bool) -> Void)?
    var onAutoFinishRemainingChange: ((Int) -> Void)?
    var onAutoFinishTriggered: (() -> Void)?

    private(set) var autoFinishRemaining: Int = 0 {
        didSet {
            onAutoFinishRemainingChange?(autoFinishRemaining)
        }
    }

    private var countdownTimer: Timer?
    private var autoFinishTimer: Timer?
    private var autoFinishCountdownTimer: Timer?
    private var isScanning = false
    private var countdownValue: Int?

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
        countdownValue = remaining
        onCountdownChange?(remaining)

        let timer = Timer(timeInterval: countdownPerSecondDuration, repeats: true) { [weak self] timer in
            guard let self else { return }
            hapticEngine.countdownCountedDown()
            remaining -= 1
            if remaining <= 0 {
                timer.invalidate()
                countdownTimer = nil
                countdownValue = nil
                completion()
                onCountdownChange?(nil)
            } else {
                countdownValue = remaining
                onCountdownChange?(remaining)
            }
        }
        countdownTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func cancelCountdown() {
        invalidateCountdownTimer()
        hapticEngine.scanningCanceled()
        countdownValue = nil
        onCountdownChange?(nil)
    }

    func beginScanning() {
        hapticEngine.scanningBegan()
        isScanning = true
        onScanningChanged?(true)
        startAutoFinishTimerIfNeeded()
    }

    @discardableResult
    func stopScanning(reason: AppScanningTerminationReason) -> Bool {
        guard isScanning else { return false }
        isScanning = false
        stopAutoFinishTimers()
        onScanningChanged?(false)

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
        countdownValue = nil
        isScanning = false
        onCountdownChange?(nil)
        onScanningChanged?(false)
    }

#if DEBUG
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
        let finishTimer = Timer(timeInterval: TimeInterval(autoFinishSeconds), repeats: false) { [weak self] _ in
            self?.onAutoFinishTriggered?()
        }
        autoFinishTimer = finishTimer
        RunLoop.main.add(finishTimer, forMode: .common)

        let countdownTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { return }
            autoFinishRemaining = max(0, autoFinishRemaining - 1)
            if autoFinishRemaining <= 0 {
                timer.invalidate()
                autoFinishCountdownTimer = nil
            }
        }
        autoFinishCountdownTimer = countdownTimer
        RunLoop.main.add(countdownTimer, forMode: .common)
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
