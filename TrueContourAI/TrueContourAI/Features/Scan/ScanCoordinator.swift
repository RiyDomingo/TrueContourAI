import AVFoundation
import UIKit
import StandardCyborgUI

final class ScanCoordinator {
    typealias DeviceCapabilityProvider = () -> Bool
    typealias ScanningViewControllerFactory = () -> AppScanningViewController
    typealias SimulatorProvider = () -> Bool
    typealias CameraAuthorizationStatusProvider = () -> AVAuthorizationStatus
    typealias CameraAccessRequester = (@escaping (Bool) -> Void) -> Void

    private let settingsStore: SettingsStore
    private let deviceCapabilityProvider: DeviceCapabilityProvider
    private let scanningViewControllerFactory: ScanningViewControllerFactory
    private let simulatorProvider: SimulatorProvider
    private let cameraAuthorizationStatusProvider: CameraAuthorizationStatusProvider
    private let cameraAccessRequester: CameraAccessRequester
    private weak var activeScanVC: AppScanningViewController?

    init(
        settingsStore: SettingsStore,
        deviceCapabilityProvider: @escaping DeviceCapabilityProvider = ScanCoordinator.defaultTrueDepthAvailability,
        scanningViewControllerFactory: @escaping ScanningViewControllerFactory = { AppScanningViewController() },
        simulatorProvider: @escaping SimulatorProvider = ScanCoordinator.defaultSimulatorState,
        cameraAuthorizationStatusProvider: @escaping CameraAuthorizationStatusProvider = ScanCoordinator.defaultCameraAuthorizationStatus,
        cameraAccessRequester: @escaping CameraAccessRequester = ScanCoordinator.defaultRequestCameraAccess
    ) {
        self.settingsStore = settingsStore
        self.deviceCapabilityProvider = deviceCapabilityProvider
        self.scanningViewControllerFactory = scanningViewControllerFactory
        self.simulatorProvider = simulatorProvider
        self.cameraAuthorizationStatusProvider = cameraAuthorizationStatusProvider
        self.cameraAccessRequester = cameraAccessRequester
    }

    func startScanFlow(
        from presenter: UIViewController,
        delegate: AppScanningViewControllerDelegate,
        scanFlowState: ScanFlowState,
        onPresented: @escaping (AppScanningViewController) -> Void
    ) {
        if simulatorProvider() {
            presenter.present(
                alert(title: L("scan.start.simulator.title"), message: L("scan.start.simulator.message")),
                animated: true
            )
            return
        }

        guard isTrueDepthAvailable else {
            presenter.present(
                alert(title: L("scan.start.unavailable.title"), message: L("scan.start.unavailable.message")),
                animated: true
            )
            return
        }
        let cameraStatus = cameraAuthorizationStatusProvider()
        switch cameraStatus {
        case .authorized:
            break
        case .notDetermined:
            cameraAccessRequester { [weak self, weak presenter] granted in
                DispatchQueue.main.async {
                    guard let self, let presenter else { return }
                    guard granted else {
                        presenter.present(
                            self.alert(
                                title: L("scan.start.cameraDenied.title"),
                                message: L("scan.start.cameraDenied.message")
                            ),
                            animated: true
                        )
                        return
                    }
                    self.startAuthorizedScanFlow(from: presenter, delegate: delegate, scanFlowState: scanFlowState, onPresented: onPresented)
                }
            }
            return
        case .denied, .restricted:
            presenter.present(
                alert(title: L("scan.start.cameraDenied.title"), message: L("scan.start.cameraDenied.message")),
                animated: true
            )
            return
        @unknown default:
            presenter.present(
                alert(title: L("scan.start.cameraUnavailable.title"), message: L("scan.start.cameraUnavailable.message")),
                animated: true
            )
            return
        }
        startAuthorizedScanFlow(from: presenter, delegate: delegate, scanFlowState: scanFlowState, onPresented: onPresented)
    }

    private func startAuthorizedScanFlow(
        from presenter: UIViewController,
        delegate: AppScanningViewControllerDelegate,
        scanFlowState: ScanFlowState,
        onPresented: @escaping (AppScanningViewController) -> Void
    ) {
        scanFlowState.startScanSession()
        let scanningVC = scanningViewControllerFactory()
        let processingConfig = settingsStore.processingConfig
        scanningVC.autoFinishSeconds = settingsStore.scanDurationSeconds
        scanningVC.delegate = delegate
        scanningVC.generatesTexturedMeshes = true
        scanningVC.requiresManualFinish = true
        scanningVC.developerModeEnabled = settingsStore.developerModeEnabled
        scanningVC.maxDepthResolution = suggestedDepthResolution(for: processingConfig)
        scanningVC.texturedMeshColorBufferSaveInterval = suggestedColorBufferInterval(for: processingConfig)
        scanningVC.modalPresentationStyle = .fullScreen
        scanningVC.onRealtimeGuidance = { [weak scanFlowState] hint in
            guard let scanFlowState else { return }
            if !hint.isEmpty {
                scanFlowState.setPhase(.scanning)
            }
        }
        Log.scanning.info(
            """
            Applied processing config: outlierSigma=\(processingConfig.outlierSigma, privacy: .public) \
            decimateRatio=\(processingConfig.decimateRatio, privacy: .public) \
            cropBelowNeck=\(processingConfig.cropBelowNeck, privacy: .public) \
            meshResolution=\(processingConfig.meshResolution, privacy: .public) \
            meshSmoothness=\(processingConfig.meshSmoothness, privacy: .public) \
            maxDepthResolution=\(scanningVC.maxDepthResolution, privacy: .public) \
            textureSaveInterval=\(scanningVC.texturedMeshColorBufferSaveInterval, privacy: .public)
            """
        )

        activeScanVC = scanningVC
        addFinishButton(to: scanningVC)

        presenter.present(scanningVC, animated: true) {
            onPresented(scanningVC)
        }
    }

    private func addFinishButton(to scanningVC: AppScanningViewController) {
        let finishButton = UIButton(type: .system)
        DesignSystem.applyButton(finishButton, title: L("common.finish"), style: .primary, size: .regular)
        finishButton.accessibilityIdentifier = "finishScanNowButton"
        finishButton.translatesAutoresizingMaskIntoConstraints = false
        finishButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        finishButton.addTarget(self, action: #selector(finishScanNowTapped(_:)), for: .touchUpInside)
        scanningVC.view.addSubview(finishButton)

        NSLayoutConstraint.activate([
            finishButton.topAnchor.constraint(equalTo: scanningVC.view.safeAreaLayoutGuide.topAnchor, constant: 12),
            finishButton.trailingAnchor.constraint(equalTo: scanningVC.view.safeAreaLayoutGuide.trailingAnchor, constant: -12)
        ])
    }

    @objc private func finishScanNowTapped(_ sender: UIButton) {
        activeScanVC?.finishScanNow()
    }

    private func alert(title: String, message: String) -> UIAlertController {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: L("common.ok"), style: .default))
        return a
    }

    private var isTrueDepthAvailable: Bool {
        deviceCapabilityProvider()
    }

    private static func defaultTrueDepthAvailability() -> Bool {
        if ProcessInfo.processInfo.arguments.contains("ui-test-force-unavailable-truedepth") {
            return false
        }
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera],
            mediaType: .video,
            position: .front
        )
        return !session.devices.isEmpty
    }

    private static func defaultSimulatorState() -> Bool {
#if targetEnvironment(simulator)
        true
#else
        false
#endif
    }

    private static func defaultCameraAuthorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    private static func defaultRequestCameraAccess(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
    }

    private func suggestedDepthResolution(for config: SettingsStore.ProcessingConfig) -> Int {
        if config.decimateRatio > 1.25 || config.meshResolution <= 5 {
            return 256
        }
        return 320
    }

    private func suggestedColorBufferInterval(for config: SettingsStore.ProcessingConfig) -> Int {
        let scaled = Int(round(8.0 * Double(max(0.5, config.decimateRatio))))
        return max(4, min(16, scaled))
    }

#if DEBUG
    func debug_suggestedDepthResolution(for config: SettingsStore.ProcessingConfig) -> Int {
        suggestedDepthResolution(for: config)
    }

    func debug_suggestedColorBufferInterval(for config: SettingsStore.ProcessingConfig) -> Int {
        suggestedColorBufferInterval(for: config)
    }
#endif
}
