import Foundation
import UIKit

enum AppScanHUDState: Equatable {
    case idlePrompts
    case countdown
    case capturing
    case warning
    case critical
}

struct AppScanHUDVisibility {
    let promptHidden: Bool
    let progressHidden: Bool
    let progressBarHidden: Bool
    let statusHidden: Bool
    let autoFinishHidden: Bool
    let focusHintHidden: Bool
}

enum AppScanGuidanceState {
    case start
    case moveSlower
    case poorTracking
    case goodTracking
    case trackingLost

    var message: String {
        switch self {
        case .start:
            return L("scanning.guidance.short.start")
        case .moveSlower:
            return L("scanning.guidance.short.motion")
        case .poorTracking:
            return L("scanning.guidance.short.poorTracking")
        case .goodTracking:
            return L("scanning.guidance.short.goodTracking")
        case .trackingLost:
            return L("scanning.guidance.short.trackingLost")
        }
    }

    var priority: Int {
        switch self {
        case .start:
            return 0
        case .goodTracking:
            return 1
        case .moveSlower:
            return 2
        case .poorTracking:
            return 3
        case .trackingLost:
            return 4
        }
    }
}

enum AppScanGuidanceStatus {
    case good
    case caution
    case lost

    var title: String {
        switch self {
        case .good:
            return L("scanning.guidance.status.good")
        case .caution:
            return L("scanning.guidance.status.caution")
        case .lost:
            return L("scanning.guidance.status.lost")
        }
    }

    var backgroundColor: UIColor {
        switch self {
        case .good:
            return UIColor.systemGreen.withAlphaComponent(0.86)
        case .caution:
            return UIColor.systemOrange.withAlphaComponent(0.9)
        case .lost:
            return UIColor.systemRed.withAlphaComponent(0.9)
        }
    }

    var textColor: UIColor {
        .white
    }
}

struct AppScanGuidanceUpdate {
    let message: String
    let status: AppScanGuidanceStatus
    let hudState: AppScanHUDState
    let accessibilityLabel: String
}

struct AppScanProgressUpdate {
    let text: String
    let diagnostics: String
}

final class ScanHUDController {
    private let guidanceCooldown: TimeInterval
    private let warningGuidanceHoldWindow: TimeInterval
    private let recoveryGuidanceHoldWindow: TimeInterval
    private let goodTrackingMinimumRepeatInterval: TimeInterval

    private let idlePrompts = [
        L("scanning.prompt.1"),
        L("scanning.prompt.2"),
        L("scanning.prompt.3"),
        L("scanning.prompt.4"),
        L("scanning.prompt.5"),
        L("scanning.prompt.6")
    ]

    private(set) var currentHUDState: AppScanHUDState = .idlePrompts
    private var promptStep = 0
    private var lastGuidanceState: AppScanGuidanceState?
    private var lastGuidanceAt: Date = .distantPast
    private var pendingGuidanceState: AppScanGuidanceState?
    private var pendingGuidanceSince: Date = .distantPast

    init(
        guidanceCooldown: TimeInterval = 2.0,
        warningGuidanceHoldWindow: TimeInterval = 0.6,
        recoveryGuidanceHoldWindow: TimeInterval = 0.8,
        goodTrackingMinimumRepeatInterval: TimeInterval = 4.0
    ) {
        self.guidanceCooldown = guidanceCooldown
        self.warningGuidanceHoldWindow = warningGuidanceHoldWindow
        self.recoveryGuidanceHoldWindow = recoveryGuidanceHoldWindow
        self.goodTrackingMinimumRepeatInterval = goodTrackingMinimumRepeatInterval
    }

    func updateForSessionState(_ state: AppScanningSessionState) {
        switch state {
        case .default:
            currentHUDState = .idlePrompts
        case .countdown:
            currentHUDState = .countdown
        case .scanning:
            if currentHUDState == .idlePrompts || currentHUDState == .countdown {
                currentHUDState = .capturing
            }
        }
    }

    func resetIdlePrompts() -> String {
        promptStep = 0
        currentHUDState = .idlePrompts
        return L("scanning.prompt.initial")
    }

    func resetForNewCapture() {
        lastGuidanceState = nil
        lastGuidanceAt = .distantPast
        pendingGuidanceState = nil
        pendingGuidanceSince = .distantPast
        currentHUDState = .capturing
    }

    func resetAfterCapture() {
        lastGuidanceState = nil
        lastGuidanceAt = .distantPast
        pendingGuidanceState = nil
        pendingGuidanceSince = .distantPast
        currentHUDState = .idlePrompts
    }

    func nextIdlePromptIfNeeded(for state: AppScanningSessionState) -> String? {
        guard state == .default else { return nil }
        let prompt = idlePrompts[promptStep % idlePrompts.count]
        promptStep += 1
        return prompt
    }

    func emitGuidance(_ state: AppScanGuidanceState, force: Bool = false) -> AppScanGuidanceUpdate? {
        if state == .trackingLost {
            return applyGuidance(state, now: Date())
        }

        let now = Date()
        if !force, let last = lastGuidanceState {
            let elapsed = now.timeIntervalSince(lastGuidanceAt)
            let isPriorityUpgrade = state.priority > last.priority

            if state == .goodTracking && elapsed < goodTrackingMinimumRepeatInterval {
                return nil
            }
            if shouldHoldGuidanceTransition(from: last, to: state, now: now) {
                return nil
            }
            if !isPriorityUpgrade && elapsed < guidanceCooldown {
                return nil
            }
            if state.priority == last.priority && elapsed < (guidanceCooldown * 1.5) {
                return nil
            }
        }

        return applyGuidance(state, now: now)
    }

    func progressUpdate(
        autoFinishSeconds: Int,
        autoFinishRemaining: Int,
        assimilatedFrameIndex: Int,
        minSucceededFramesForCompletion: Int
    ) -> AppScanProgressUpdate {
        if autoFinishSeconds > 0 {
            let elapsed = max(0, autoFinishSeconds - autoFinishRemaining)
            let progress = min(max(Float(elapsed) / Float(autoFinishSeconds), 0), 1)
            return AppScanProgressUpdate(
                text: String(format: L("scanning.progress.timeFormat"), elapsed, autoFinishSeconds),
                diagnostics: String(format: "Frames: %d · Progress: %d%%", assimilatedFrameIndex, Int(round(progress * 100)))
            )
        }

        let progress = min(max(Float(assimilatedFrameIndex) / Float(minSucceededFramesForCompletion), 0), 1)
        return AppScanProgressUpdate(
            text: L("scanning.progress.capturing"),
            diagnostics: String(format: "Frames: %d · Progress: %d%%", assimilatedFrameIndex, Int(round(progress * 100)))
        )
    }

    func visibility(for state: AppScanHUDState, autoFinishSeconds: Int) -> AppScanHUDVisibility {
        switch state {
        case .idlePrompts:
            return AppScanHUDVisibility(
                promptHidden: false,
                progressHidden: true,
                progressBarHidden: true,
                statusHidden: true,
                autoFinishHidden: true,
                focusHintHidden: false
            )
        case .countdown:
            return AppScanHUDVisibility(
                promptHidden: true,
                progressHidden: true,
                progressBarHidden: true,
                statusHidden: true,
                autoFinishHidden: true,
                focusHintHidden: true
            )
        case .capturing, .warning, .critical:
            return AppScanHUDVisibility(
                promptHidden: false,
                progressHidden: false,
                progressBarHidden: true,
                statusHidden: false,
                autoFinishHidden: autoFinishSeconds <= 0,
                focusHintHidden: true
            )
        }
    }

    private func applyGuidance(_ state: AppScanGuidanceState, now: Date) -> AppScanGuidanceUpdate {
        pendingGuidanceState = nil
        let status: AppScanGuidanceStatus
        switch state {
        case .trackingLost:
            status = .lost
            currentHUDState = .critical
        case .poorTracking, .moveSlower:
            status = .caution
            currentHUDState = .warning
        case .goodTracking:
            status = .good
            currentHUDState = .capturing
        case .start:
            status = .caution
            currentHUDState = .capturing
        }

        let message = state.message
        lastGuidanceState = state
        lastGuidanceAt = now
        return AppScanGuidanceUpdate(
            message: message,
            status: status,
            hudState: currentHUDState,
            accessibilityLabel: String(format: L("scanning.guidance.status.accessibility"), status.title, message)
        )
    }

    private func shouldHoldGuidanceTransition(from previous: AppScanGuidanceState, to next: AppScanGuidanceState, now: Date) -> Bool {
        if next.priority == previous.priority { return false }
        let isUpgrade = next.priority > previous.priority
        let holdWindow = isUpgrade ? warningGuidanceHoldWindow : recoveryGuidanceHoldWindow
        if pendingGuidanceState?.priority != next.priority {
            pendingGuidanceState = next
            pendingGuidanceSince = now
            return true
        }
        return now.timeIntervalSince(pendingGuidanceSince) < holdWindow
    }
}
