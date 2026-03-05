import AVFoundation
import CoreMotion
import MediaPlayer
import Metal
import StandardCyborgFusion
import StandardCyborgUI
import UIKit

protocol ReconstructionManaging: AnyObject {
    var delegate: SCReconstructionManagerDelegate? { get set }
    var includesColorBuffersInMetadata: Bool { get set }
    var latestCameraCalibrationData: AVCameraCalibrationData! { get }
    var latestCameraCalibrationFrameWidth: Int { get }
    var latestCameraCalibrationFrameHeight: Int { get }

    func reset()
    func finalize(_ completion: @escaping () -> Void)
    func buildPointCloud() -> SCPointCloud
    func reconstructSingleDepthBuffer(
        _ depthBuffer: CVPixelBuffer,
        colorBuffer: CVPixelBuffer?,
        with calibrationData: AVCameraCalibrationData,
        smoothingPoints: Bool
    ) -> SCPointCloud
    func accumulate(depthBuffer: CVPixelBuffer, colorBuffer: CVPixelBuffer, calibrationData: AVCameraCalibrationData)
    func accumulateDeviceMotion(_ motion: CMDeviceMotion)
}

protocol CameraManaging: AnyObject {
    var delegate: CameraManagerDelegate! { get set }
    var isSessionRunning: Bool { get }

    func configureCaptureSession(maxResolution: Int)
    func startSession(_ completion: ((CameraManager.SessionSetupResult) -> Void)?)
    func stopSession(_ completion: (() -> Void)?)
    func focusOnTap(at location: CGPoint)
}

protocol ScanningHapticFeedbackProviding: AnyObject {
    func countdownCountedDown()
    func scanningBegan()
    func scanningFinished()
    func scanningCanceled()
}

extension ScanningHapticFeedbackEngine: ScanningHapticFeedbackProviding {}

final class SCReconstructionManagerAdapter: ReconstructionManaging {
    private let manager: SCReconstructionManager

    init(device: MTLDevice, commandQueue: MTLCommandQueue, maxThreadCount: Int32) {
        manager = SCReconstructionManager(
            device: device,
            commandQueue: commandQueue,
            maxThreadCount: maxThreadCount
        )
    }

    var delegate: SCReconstructionManagerDelegate? {
        get { manager.delegate }
        set { manager.delegate = newValue }
    }

    var includesColorBuffersInMetadata: Bool {
        get { manager.includesColorBuffersInMetadata }
        set { manager.includesColorBuffersInMetadata = newValue }
    }

    var latestCameraCalibrationData: AVCameraCalibrationData! { manager.latestCameraCalibrationData }
    var latestCameraCalibrationFrameWidth: Int { manager.latestCameraCalibrationFrameWidth }
    var latestCameraCalibrationFrameHeight: Int { manager.latestCameraCalibrationFrameHeight }

    func reset() { manager.reset() }
    func finalize(_ completion: @escaping () -> Void) { manager.finalize(completion) }
    func buildPointCloud() -> SCPointCloud { manager.buildPointCloud() }

    func reconstructSingleDepthBuffer(
        _ depthBuffer: CVPixelBuffer,
        colorBuffer: CVPixelBuffer?,
        with calibrationData: AVCameraCalibrationData,
        smoothingPoints: Bool
    ) -> SCPointCloud {
        manager.reconstructSingleDepthBuffer(
            depthBuffer,
            colorBuffer: colorBuffer,
            with: calibrationData,
            smoothingPoints: smoothingPoints
        )
    }

    func accumulate(depthBuffer: CVPixelBuffer, colorBuffer: CVPixelBuffer, calibrationData: AVCameraCalibrationData) {
        manager.accumulate(depthBuffer: depthBuffer, colorBuffer: colorBuffer, calibrationData: calibrationData)
    }

    func accumulateDeviceMotion(_ motion: CMDeviceMotion) {
        manager.accumulateDeviceMotion(motion)
    }
}

final class CameraManagerAdapter: CameraManaging {
    private let manager = CameraManager()

    var delegate: CameraManagerDelegate! {
        get { manager.delegate }
        set { manager.delegate = newValue }
    }

    var isSessionRunning: Bool { manager.isSessionRunning }

    func configureCaptureSession(maxResolution: Int) {
        manager.configureCaptureSession(maxResolution: maxResolution)
    }

    func startSession(_ completion: ((CameraManager.SessionSetupResult) -> Void)?) {
        manager.startSession(completion)
    }

    func stopSession(_ completion: (() -> Void)?) {
        manager.stopSession(completion)
    }

    func focusOnTap(at location: CGPoint) {
        manager.focusOnTap(at: location)
    }
}

protocol AppScanningViewControllerDelegate: AnyObject {
    func appScanningViewControllerDidCancel(_ controller: AppScanningViewController)
    func appScanningViewController(
        _ controller: AppScanningViewController,
        didScan pointCloud: SCPointCloud,
        meshTexturing: SCMeshTexturing
    )
}

final class AppScanningViewController: UIViewController, CameraManagerDelegate, SCReconstructionManagerDelegate {

    enum ScanningTerminationReason {
        case canceled
        case finished
    }

    weak var delegate: AppScanningViewControllerDelegate?
    var onRealtimeGuidance: ((String) -> Void)?
    var autoFinishSeconds: Int = 0
    var requiresManualFinish: Bool = false
    var maxDepthResolution: Int = 320 {
        didSet {
            if isViewLoaded && oldValue != maxDepthResolution {
                cameraManager.configureCaptureSession(maxResolution: maxDepthResolution)
            }
        }
    }
    var generatesTexturedMeshes: Bool = true {
        didSet { reconstructionManager.includesColorBuffersInMetadata = generatesTexturedMeshes }
    }
    var texturedMeshColorBufferSaveInterval: Int = 8
    let meshTexturing = SCMeshTexturing()

    private enum State: Equatable {
        case `default`
        case countdown(Int)
        case scanning
    }

    private let metalContainerView = UIView()
    private let metalLayer = CAMetalLayer()
    private let countdownLabel = UILabel()
    private let dismissButton = UIButton(type: .system)
    private let shutterButton = ShutterButton()

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

    private let metalDevice = MTLCreateSystemDefaultDevice()!
    private lazy var algorithmCommandQueue: MTLCommandQueue = metalDevice.makeCommandQueue()!
    private lazy var visualizationCommandQueue: MTLCommandQueue = metalDevice.makeCommandQueue()!
    private lazy var reconstructionManager: ReconstructionManaging = reconstructionManagerFactory(
        metalDevice,
        algorithmCommandQueue,
        maxReconstructionThreadCount
    )
    private lazy var scanningViewRenderer: ScanningViewRenderer = DefaultScanningViewRenderer(
        device: metalDevice,
        commandQueue: visualizationCommandQueue
    )
    private let reconstructionManagerFactory: (MTLDevice, MTLCommandQueue, Int32) -> ReconstructionManaging
    private let cameraManager: CameraManaging
    private let hapticEngine: ScanningHapticFeedbackProviding
    private let motionManager = CMMotionManager()

    private var latestViewMatrix = matrix_identity_float4x4
    private var assimilatedFrameIndex = 0
    private var consecutiveFailedCount = 0
    private var state: State = .default {
        didSet { updateUI() }
    }

    private var countdownTimer: Timer?
    private var promptTimer: Timer?
    private var promptStep = 0
    private var autoFinishTimer: Timer?
    private var autoFinishCountdownTimer: Timer?
    private var autoFinishRemaining: Int = 0

    private var volumeView: MPVolumeView?
    private var isObservingVolumeButtons = false

    private let countdownStartCount = 3
    private let countdownPerSecondDuration: TimeInterval = 0.75
    private let minSucceededFramesForCompletion = 50
    private let maxReconstructionThreadCount: Int32 = 2
    private let unstableMotionThreshold = 0.12

    init(
        reconstructionManagerFactory: @escaping (MTLDevice, MTLCommandQueue, Int32) -> ReconstructionManaging = {
            SCReconstructionManagerAdapter(device: $0, commandQueue: $1, maxThreadCount: $2)
        },
        cameraManager: CameraManaging = CameraManagerAdapter(),
        hapticEngine: ScanningHapticFeedbackProviding = ScanningHapticFeedbackEngine.shared
    ) {
        self.reconstructionManagerFactory = reconstructionManagerFactory
        self.cameraManager = cameraManager
        self.hapticEngine = hapticEngine
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable, message: "Programmatic-only. Use init(reconstructionManagerFactory:cameraManager:hapticEngine:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        metalContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metalContainerView)
        view.addSubview(countdownLabel)
        view.addSubview(promptLabel)
        view.addSubview(progressLabel)
        view.addSubview(focusHintLabel)
        view.addSubview(autoFinishLabel)
        view.addSubview(dismissButton)
        view.addSubview(shutterButton)

        NSLayoutConstraint.activate([
            metalContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            metalContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            metalContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            promptLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            promptLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            promptLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -90),

            progressLabel.leadingAnchor.constraint(equalTo: promptLabel.leadingAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: promptLabel.trailingAnchor),
            progressLabel.bottomAnchor.constraint(equalTo: promptLabel.topAnchor, constant: -8),

            focusHintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            focusHintLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),

            autoFinishLabel.leadingAnchor.constraint(equalTo: progressLabel.leadingAnchor),
            autoFinishLabel.trailingAnchor.constraint(equalTo: progressLabel.trailingAnchor),
            autoFinishLabel.bottomAnchor.constraint(equalTo: progressLabel.topAnchor, constant: -6)
        ])

        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        countdownLabel.textColor = .white
        countdownLabel.font = DesignSystem.Typography.title()
        countdownLabel.textAlignment = .center
        countdownLabel.isHidden = true

        dismissButton.setTitle(L("common.close"), for: .normal)
        DesignSystem.applyButton(dismissButton, title: L("common.close"), style: .secondary, size: .regular)
        dismissButton.accessibilityIdentifier = "scanDismissButton"
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dismissButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            dismissButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        ])

        shutterButton.addTarget(self, action: #selector(shutterTapped(_:)), for: .touchUpInside)
        shutterButton.accessibilityIdentifier = "scanShutterButton"
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            shutterButton.widthAnchor.constraint(equalToConstant: 84),
            shutterButton.heightAnchor.constraint(equalTo: shutterButton.widthAnchor)
        ])

        metalLayer.isOpaque = true
        metalLayer.device = metalDevice
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalContainerView.layer.addSublayer(metalLayer)

        metalContainerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focusOnTap(_:))))

        cameraManager.delegate = self
        cameraManager.configureCaptureSession(maxResolution: maxDepthResolution)
        reconstructionManager.delegate = self
        reconstructionManager.includesColorBuffersInMetadata = generatesTexturedMeshes

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startPromptLoop()
        showFocusHintIfIdle()
        installVolumeShutterIfNeeded()
        startCameraSession()
        startMotionUpdates()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning(reason: .canceled)
        stopMotionUpdates()
        cameraManager.stopSession(nil)
        removeVolumeShutterObserver()

        promptTimer?.invalidate()
        promptTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        autoFinishTimer?.invalidate()
        autoFinishTimer = nil
        autoFinishCountdownTimer?.invalidate()
        autoFinishCountdownTimer = nil
        NotificationCenter.default.removeObserver(self, name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.disableActions()
        metalLayer.frame = metalContainerView.bounds
        let scale = view.window?.windowScene?.screen.scale ?? traitCollection.displayScale
        metalLayer.drawableSize = CGSize(width: metalLayer.frame.width * scale,
                                         height: metalLayer.frame.height * scale)
        CATransaction.commit()
    }

    @objc private func dismissTapped() {
        stopScanning(reason: .canceled)
        dismiss(animated: true)
    }

    @objc func shutterTapped(_ sender: UIButton?) {
        guard presentedViewController == nil, cameraManager.isSessionRunning else { return }

        switch state {
        case .default:
            startCountdown { [weak self] in
                self?.startScanning()
            }
        case .countdown:
            hapticEngine.scanningCanceled()
            cancelCountdown()
        case .scanning:
            stopScanning(reason: .finished)
        }
    }

    func finishScanNow() {
        if state == .scanning {
            stopScanning(reason: .finished)
        }
    }

    private func startScanning() {
        hapticEngine.scanningBegan()
        state = .scanning
        assimilatedFrameIndex = 0
        consecutiveFailedCount = 0
        meshTexturing.reset()
        emitGuidance(L("scanning.guidance.start"))
        startAutoFinishTimerIfNeeded()
    }

    private func stopScanning(reason: ScanningTerminationReason) {
        guard state == .scanning else { return }
        state = .default
        latestViewMatrix = matrix_identity_float4x4
        meshTexturing.reset()
        stopAutoFinishTimers()

        switch reason {
        case .canceled:
            hapticEngine.scanningCanceled()
            reconstructionManager.reset()
            delegate?.appScanningViewControllerDidCancel(self)
        case .finished:
            hapticEngine.scanningFinished()
            cameraManager.stopSession(nil)
            if let calibrationData = reconstructionManager.latestCameraCalibrationData {
                meshTexturing.cameraCalibrationData = calibrationData
                meshTexturing.cameraCalibrationFrameWidth = reconstructionManager.latestCameraCalibrationFrameWidth
                meshTexturing.cameraCalibrationFrameHeight = reconstructionManager.latestCameraCalibrationFrameHeight
            } else {
                Log.scan.error("Missing camera calibration data at scan finalize; continuing without calibration metadata")
            }
            reconstructionManager.finalize { [weak self] in
                guard let self else { return }
                let pointCloud = self.reconstructionManager.buildPointCloud()
                self.reconstructionManager.reset()
                self.delegate?.appScanningViewController(
                    self,
                    didScan: pointCloud,
                    meshTexturing: self.meshTexturing
                )
            }
        }
    }

    private func startCameraSession() {
        cameraManager.startSession { [weak self] result in
            guard let self else { return }
            if result != .success {
                let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                let alertTitle: String
                let alertMessage: String
                if authorizationStatus == .denied || authorizationStatus == .restricted {
                    alertTitle = L("scan.start.cameraDenied.title")
                    alertMessage = L("scan.start.cameraDenied.message")
                } else {
                    alertTitle = L("scan.start.cameraUnavailable.title")
                    alertMessage = L("scan.start.cameraUnavailable.message")
                }
                let alert = UIAlertController(
                    title: alertTitle,
                    message: alertMessage,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: L("common.ok"), style: .default, handler: { [weak self] _ in
                    self?.dismiss(animated: true)
                }))
                self.present(alert, animated: true)
            }
        }
    }

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] motion, _ in
            guard let self, let motion, self.state == .scanning else { return }
            Log.scan.debug("Motion update received")
            self.reconstructionManager.accumulateDeviceMotion(motion)
            let acceleration = motion.userAcceleration
            let magnitude = sqrt(
                acceleration.x * acceleration.x +
                acceleration.y * acceleration.y +
                acceleration.z * acceleration.z
            )
            if magnitude > self.unstableMotionThreshold {
                self.emitGuidance(L("scanning.guidance.motion"))
            }
        }
    }

    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }

    // MARK: - CameraManagerDelegate

    func cameraDidOutput(colorBuffer: CVPixelBuffer, depthBuffer: CVPixelBuffer, depthCalibrationData: AVCameraCalibrationData) {
        var isScanning = false
        DispatchQueue.main.sync {
            isScanning = self.state == .scanning
        }
        let pointCloud: SCPointCloud

        if isScanning {
            pointCloud = reconstructionManager.buildPointCloud()
        } else {
            pointCloud = reconstructionManager.reconstructSingleDepthBuffer(
                depthBuffer,
                colorBuffer: nil,
                with: depthCalibrationData,
                smoothingPoints: true
            )
        }

        scanningViewRenderer.draw(
            colorBuffer: colorBuffer,
            pointCloud: pointCloud,
            depthCameraCalibrationData: depthCalibrationData,
            viewMatrix: latestViewMatrix,
            into: metalLayer
        )

        if isScanning {
            reconstructionManager.accumulate(depthBuffer: depthBuffer, colorBuffer: colorBuffer, calibrationData: depthCalibrationData)
        }
    }

    // MARK: - SCReconstructionManagerDelegate

    func reconstructionManager(
        _ manager: SCReconstructionManager,
        didProcessWith metadata: SCAssimilatedFrameMetadata,
        statistics: SCReconstructionManagerStatistics
    ) {
        guard state == .scanning else { return }
        latestViewMatrix = metadata.viewMatrix

        switch metadata.result {
        case .succeeded, .poorTracking:
            if generatesTexturedMeshes,
               assimilatedFrameIndex % texturedMeshColorBufferSaveInterval == 0,
               let colorBuffer = metadata.colorBuffer?.takeUnretainedValue() {
                meshTexturing.saveColorBufferForReconstruction(
                    colorBuffer,
                    withViewMatrix: metadata.viewMatrix,
                    projectionMatrix: metadata.projectionMatrix
                )
            }
            assimilatedFrameIndex += 1
            consecutiveFailedCount = 0
            if metadata.result == .poorTracking {
                emitGuidance(L("scanning.guidance.poorTracking"))
            } else if assimilatedFrameIndex % 20 == 0 {
                emitGuidance(L("scanning.guidance.goodTracking"))
            }
        case .failed:
            if requiresManualFinish {
                break
            }
            consecutiveFailedCount += 1
            emitGuidance(L("scanning.guidance.trackingLost"))
            let belowMinFrames = statistics.succeededCount < minSucceededFramesForCompletion
            let exceededFailureTolerance = consecutiveFailedCount >= 5
            if belowMinFrames && exceededFailureTolerance {
                stopScanning(reason: .canceled)
            } else if !belowMinFrames {
                stopScanning(reason: .finished)
            }
        case .lostTracking:
            break
        @unknown default:
            break
        }
    }

    func reconstructionManager(_ manager: SCReconstructionManager, didEncounterAPIError error: Error) {
        handleReconstructionError(error)
    }

    // MARK: - UI helpers

    private func updateUI() {
        switch state {
        case .default:
            shutterButton.shutterButtonState = .default
            countdownLabel.isHidden = true
        case .countdown(let seconds):
            shutterButton.shutterButtonState = .countdown
            countdownLabel.text = "\(seconds)"
            countdownLabel.isHidden = false
        case .scanning:
            shutterButton.shutterButtonState = .scanning
            countdownLabel.isHidden = true
        }
    }

    private func startCountdown(completion: @escaping () -> Void) {
        countdownTimer?.invalidate()
        var remaining = countdownStartCount
        state = .countdown(remaining)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: countdownPerSecondDuration, repeats: true) { [weak self] timer in
            guard let self else { return }
            hapticEngine.countdownCountedDown()
            remaining -= 1
            if remaining <= 0 {
                timer.invalidate()
                self.countdownTimer = nil
                self.state = .default
                completion()
            } else {
                self.state = .countdown(remaining)
            }
        }
    }

    private func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        state = .default
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

    private func emitGuidance(_ message: String) {
        promptLabel.text = message
        onRealtimeGuidance?(message)
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
        stopAutoFinishTimers()
        guard autoFinishSeconds > 0 else { return }
        autoFinishRemaining = autoFinishSeconds
        autoFinishLabel.isHidden = false
        updateAutoFinishLabel()
        autoFinishTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(autoFinishSeconds), repeats: false) { [weak self] _ in
            self?.finishScanNow()
        }
        autoFinishCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            autoFinishRemaining = max(0, autoFinishRemaining - 1)
            updateAutoFinishLabel()
            if autoFinishRemaining <= 0 {
                autoFinishCountdownTimer?.invalidate()
                autoFinishCountdownTimer = nil
            }
        }
    }

    private func stopAutoFinishTimers() {
        autoFinishTimer?.invalidate()
        autoFinishTimer = nil
        autoFinishCountdownTimer?.invalidate()
        autoFinishCountdownTimer = nil
        autoFinishLabel.isHidden = true
    }

    private func updateAutoFinishLabel() {
        autoFinishLabel.text = String(format: L("scanning.autofinish"), autoFinishRemaining)
    }

    @objc private func focusOnTap(_ gesture: UITapGestureRecognizer) {
        guard state != .scanning else { return }
        let location = gesture.location(in: metalContainerView)
        cameraManager.focusOnTap(at: location)
    }

    @objc private func thermalStateChanged(_ notification: Notification) {
        guard let processInfo = notification.object as? ProcessInfo else { return }
        if processInfo.thermalState == .serious || processInfo.thermalState == .critical {
            handleCriticalThermalState()
        }
    }

    private func handleCriticalThermalState() {
        if state == .scanning {
            stopScanning(reason: .finished)
        }

        let alert = UIAlertController(
            title: L("scanning.thermal.title"),
            message: L("scanning.thermal.message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("common.ok"), style: .default, handler: { [weak self] _ in
            self?.dismiss(animated: true)
        }))

        guard presentedViewController == nil else { return }
        present(alert, animated: true)
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

    private func handleReconstructionError(_ error: Error) {
        Log.scan.error("Reconstruction API error: \(error.localizedDescription, privacy: .public)")
        stopScanning(reason: .canceled)
    }

#if DEBUG
    func debug_setStateScanning() {
        state = .scanning
    }

    func debug_stopScanning(reason: ScanningTerminationReason) {
        stopScanning(reason: reason)
    }

    func debug_handleReconstructionError(_ error: Error) {
        handleReconstructionError(error)
    }

    func debug_triggerViewWillDisappear() {
        viewWillDisappear(false)
    }

    func debug_handleCriticalThermalState() {
        handleCriticalThermalState()
    }
#endif
}
