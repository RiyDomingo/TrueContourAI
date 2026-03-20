import AVFoundation
import UIKit
import StandardCyborgUI

struct ScanCaptureTuning: Equatable {
    let maxDepthResolution: Int
    let textureSaveInterval: Int
}

final class ScanCoordinator {
    typealias DeviceCapabilityProvider = () -> Bool
    typealias ScanningViewControllerFactory = () -> AppScanningViewController
    typealias SimulatorProvider = () -> Bool
    typealias CameraAuthorizationStatusProvider = () -> AVAuthorizationStatus
    typealias CameraAccessRequester = (@escaping (Bool) -> Void) -> Void

    private let environment: AppEnvironment
    private let deviceCapabilityProvider: DeviceCapabilityProvider
    private let scanningViewControllerFactory: ScanningViewControllerFactory
    private let simulatorProvider: SimulatorProvider
    private let cameraAuthorizationStatusProvider: CameraAuthorizationStatusProvider
    private let cameraAccessRequester: CameraAccessRequester

    init(
        environment: AppEnvironment = .current,
        deviceCapabilityProvider: @escaping DeviceCapabilityProvider,
        scanningViewControllerFactory: @escaping ScanningViewControllerFactory = { AppScanningViewController() },
        simulatorProvider: @escaping SimulatorProvider = ScanCoordinator.defaultSimulatorState,
        cameraAuthorizationStatusProvider: @escaping CameraAuthorizationStatusProvider = ScanCoordinator.defaultCameraAuthorizationStatus,
        cameraAccessRequester: @escaping CameraAccessRequester = ScanCoordinator.defaultRequestCameraAccess
    ) {
        self.environment = environment
        self.deviceCapabilityProvider = deviceCapabilityProvider
        self.scanningViewControllerFactory = scanningViewControllerFactory
        self.simulatorProvider = simulatorProvider
        self.cameraAuthorizationStatusProvider = cameraAuthorizationStatusProvider
        self.cameraAccessRequester = cameraAccessRequester
    }

    convenience init(
        environment: AppEnvironment = .current,
        scanningViewControllerFactory: @escaping ScanningViewControllerFactory = { AppScanningViewController() },
        simulatorProvider: @escaping SimulatorProvider = ScanCoordinator.defaultSimulatorState,
        cameraAuthorizationStatusProvider: @escaping CameraAuthorizationStatusProvider = ScanCoordinator.defaultCameraAuthorizationStatus,
        cameraAccessRequester: @escaping CameraAccessRequester = ScanCoordinator.defaultRequestCameraAccess
    ) {
        self.init(
            environment: environment,
            deviceCapabilityProvider: { ScanCoordinator.defaultTrueDepthAvailability(environment: environment) },
            scanningViewControllerFactory: scanningViewControllerFactory,
            simulatorProvider: simulatorProvider,
            cameraAuthorizationStatusProvider: cameraAuthorizationStatusProvider,
            cameraAccessRequester: cameraAccessRequester
        )
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
        scanningVC.delegate = delegate
        scanningVC.modalPresentationStyle = .fullScreen
        presenter.present(scanningVC, animated: true) {
            onPresented(scanningVC)
        }
    }

    private func alert(title: String, message: String) -> UIAlertController {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: L("common.ok"), style: .default))
        return a
    }

    private var isTrueDepthAvailable: Bool {
        deviceCapabilityProvider()
    }

    private static func defaultTrueDepthAvailability(environment: AppEnvironment) -> Bool {
        if environment.forcesUnavailableTrueDepth {
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
}
