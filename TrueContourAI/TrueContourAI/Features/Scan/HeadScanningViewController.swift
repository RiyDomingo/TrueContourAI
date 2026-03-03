import MediaPlayer
import UIKit
import StandardCyborgUI

final class HeadScanningViewController: ScanningViewController {

    private let promptLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = DesignSystem.Typography.button()
        label.textColor = DesignSystem.Colors.textPrimary
        label.backgroundColor = DesignSystem.Colors.overlay
        label.layer.cornerRadius = DesignSystem.CornerRadius.medium
        label.layer.masksToBounds = true
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("scanning.prompt.initial")
        return label
    }()

    private let focusHintLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = DesignSystem.Typography.caption()
        label.textColor = DesignSystem.Colors.textSecondary
        label.adjustsFontForContentSizeCategory = true
        label.text = L("scanning.focusHint")
        label.alpha = 0
        return label
    }()

    private let progressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = DesignSystem.Typography.caption()
        label.textColor = DesignSystem.Colors.textPrimary
        label.adjustsFontForContentSizeCategory = true
        label.text = L("scanning.progress")
        return label
    }()

    private let autoFinishLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = DesignSystem.Typography.caption()
        label.textColor = DesignSystem.Colors.textSecondary
        label.adjustsFontForContentSizeCategory = true
        label.text = ""
        label.isHidden = true
        return label
    }()

    private var promptTimer: Timer?
    private var promptStep = 0
    private var autoFinishTimer: Timer?
    private var autoFinishCountdownTimer: Timer?
    private var autoFinishRemaining: Int = 0
    var autoFinishSeconds: Int = 0
    private var volumeView: MPVolumeView?
    private var isObservingVolumeButtons = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Head-scan-friendly defaults
        countdownStartCount = 3
        countdownPerSecondDuration = 1.0
        maxDepthResolution = 320
        texturedMeshColorBufferSaveInterval = 8

        view.addSubview(promptLabel)
        view.addSubview(progressLabel)
        view.addSubview(focusHintLabel)
        view.addSubview(autoFinishLabel)

        // Instructions at bottom, above the scanning UI controls.
        NSLayoutConstraint.activate([
            promptLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            promptLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            promptLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -90)
        ])

        NSLayoutConstraint.activate([
            progressLabel.leadingAnchor.constraint(equalTo: promptLabel.leadingAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: promptLabel.trailingAnchor),
            progressLabel.bottomAnchor.constraint(equalTo: promptLabel.topAnchor, constant: -10)
        ])

        NSLayoutConstraint.activate([
            focusHintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            focusHintLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12)
        ])

        NSLayoutConstraint.activate([
            autoFinishLabel.leadingAnchor.constraint(equalTo: progressLabel.leadingAnchor),
            autoFinishLabel.trailingAnchor.constraint(equalTo: progressLabel.trailingAnchor),
            autoFinishLabel.bottomAnchor.constraint(equalTo: progressLabel.topAnchor, constant: -6)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startPromptLoop()
        showFocusHintIfIdle()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        startAutoFinishTimerIfNeeded()
        installVolumeShutterIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        promptTimer?.invalidate()
        promptTimer = nil
        autoFinishTimer?.invalidate()
        autoFinishTimer = nil
        autoFinishCountdownTimer?.invalidate()
        autoFinishCountdownTimer = nil
        NotificationCenter.default.removeObserver(self, name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        removeVolumeShutterObserver()
    }

    private func startPromptLoop() {
        promptTimer?.invalidate()
        promptStep = 0

        let prompts = [
            L("scanning.prompt.1"),
            L("scanning.prompt.2"),
            L("scanning.prompt.3"),
            L("scanning.prompt.4"),
            L("scanning.prompt.5"),
            L("scanning.prompt.6")
        ]

        promptTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.promptLabel.text = prompts[self.promptStep % prompts.count]
            self.promptStep += 1
        }
    }

    private func showFocusHintIfIdle() {
        UIView.animate(withDuration: 0.2) {
            self.focusHintLabel.alpha = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            UIView.animate(withDuration: 0.2) {
                self?.focusHintLabel.alpha = 0
            }
        }
    }

    private func startAutoFinishTimerIfNeeded() {
        autoFinishTimer?.invalidate()
        guard autoFinishSeconds > 0 else { return }
        autoFinishRemaining = autoFinishSeconds
        autoFinishLabel.isHidden = false
        updateAutoFinishLabel()
        autoFinishTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(autoFinishSeconds), repeats: false) { [weak self] _ in
            self?.finishScanNow()
        }

        autoFinishCountdownTimer?.invalidate()
        autoFinishCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.autoFinishRemaining = max(0, self.autoFinishRemaining - 1)
            self.updateAutoFinishLabel()
            if self.autoFinishRemaining <= 0 {
                self.autoFinishCountdownTimer?.invalidate()
                self.autoFinishCountdownTimer = nil
            }
        }
    }

    private func updateAutoFinishLabel() {
        autoFinishLabel.text = String(format: L("scanning.autofinish"), autoFinishRemaining)
    }

    @objc private func thermalStateChanged(_ notification: Notification) {
        guard let processInfo = notification.object as? ProcessInfo else { return }
        if processInfo.thermalState == .serious || processInfo.thermalState == .critical {
            let alert = UIAlertController(
                title: L("scanning.thermal.title"),
                message: L("scanning.thermal.message"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L("common.ok"), style: .default, handler: { [weak self] _ in
                self?.dismiss(animated: true)
            }))
            present(alert, animated: true)
        }
    }

    private func installVolumeShutterIfNeeded() {
        guard !isObservingVolumeButtons else { return }
        let volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 0, height: 0))
        volumeView.isHidden = true
        view.addSubview(volumeView)
        self.volumeView = volumeView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(volumeChanged(_:)),
            name: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil
        )
        isObservingVolumeButtons = true
    }

    private func removeVolumeShutterObserver() {
        guard isObservingVolumeButtons else { return }
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil
        )
        isObservingVolumeButtons = false
        volumeView?.removeFromSuperview()
        volumeView = nil
    }

    @objc private func volumeChanged(_ notification: Notification) {
        guard view.window != nil else { return }
        guard let userInfo = notification.userInfo,
              let reason = userInfo["AVSystemController_AudioVolumeChangeReasonNotificationParameter"] as? String,
              reason == "ExplicitVolumeChange"
        else { return }
        shutterTapped(nil)
    }

    private func startProgressLoop() {}
}
