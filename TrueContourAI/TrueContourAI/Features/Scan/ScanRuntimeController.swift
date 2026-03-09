import Foundation
import UIKit

protocol IdleTimerManaging: AnyObject {
    var isIdleTimerDisabled: Bool { get set }
}

extension UIApplication: IdleTimerManaging {}

final class ScanRuntimeController {
    private weak var idleTimerManager: IdleTimerManaging?
    private let notificationCenter: NotificationCenter

    var onCriticalThermalState: (() -> Void)?

    private var isObservingThermalState = false

    init(
        idleTimerManager: IdleTimerManaging = UIApplication.shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.idleTimerManager = idleTimerManager
        self.notificationCenter = notificationCenter
    }

    func activate() {
        guard !isObservingThermalState else { return }
        notificationCenter.addObserver(
            self,
            selector: #selector(handleThermalStateChanged(_:)),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        isObservingThermalState = true
    }

    func deactivate() {
        guard isObservingThermalState else { return }
        notificationCenter.removeObserver(
            self,
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        isObservingThermalState = false
        idleTimerManager?.isIdleTimerDisabled = false
    }

    func updateScanningState(isScanning: Bool) {
        idleTimerManager?.isIdleTimerDisabled = isScanning
    }

    @objc private func handleThermalStateChanged(_ notification: Notification) {
        guard let processInfo = notification.object as? ProcessInfo else { return }
        guard processInfo.thermalState == .serious || processInfo.thermalState == .critical else { return }
        onCriticalThermalState?()
    }
}
