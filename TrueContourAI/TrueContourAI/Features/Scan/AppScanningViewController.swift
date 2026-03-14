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
        didCompleteScan payload: ScanPreviewInput
    )
    func appScanningViewController(
        _ controller: AppScanningViewController,
        didScan pointCloud: SCPointCloud,
        meshTexturing: SCMeshTexturing
    )
}

final class AppScanningViewController: UIViewController, CameraManagerDelegate, SCReconstructionManagerDelegate {
    typealias ScanningTerminationReason = AppScanningTerminationReason
    private typealias State = AppScanningSessionState

    private struct EarVerificationPendingFrame {
        let image: UIImage
        let frameIndex: Int
        let timestamp: CFAbsoluteTime
    }

    private struct EarVerificationFrameCandidate {
        let image: UIImage
        let frameIndex: Int
        let timestamp: CFAbsoluteTime
        let scoreBreakdown: EarVerificationFrameScoreBreakdown
    }

    private struct EarVerificationFrameScoreBreakdown: Equatable {
        let totalScore: Float
        let profileScore: Float
        let trackingScore: Float
        let guidanceScore: Float
        let timingScore: Float
    }

    private enum Layout {
        static let topStatusInset: CGFloat = 10
        static let instructionToProgressSpacing: CGFloat = 8
        static let statusToFocusHintSpacing: CGFloat = 6
        static let sheetBottomInset: CGFloat = 10
        static let sheetCollapsedHeight: CGFloat = 170
        static let sheetHalfHeight: CGFloat = 260
        static let sheetFullHeight: CGFloat = 360
    }

    private struct ScanSheetProfile {
        let collapsed: CGFloat
        let half: CGFloat
        let full: CGFloat
    }

    weak var delegate: AppScanningViewControllerDelegate?
    var onRealtimeGuidance: ((String) -> Void)?
    var autoFinishSeconds: Int = 0
    var requiresManualFinish: Bool = false
    var developerModeEnabled = false
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

    private let metalContainerView = UIView()
    private let metalLayer = CAMetalLayer()
    private let countdownLabel = UILabel()
    private let dismissButton = UIButton(type: .system)
    private let manualFinishButton = UIButton(type: .system)
    private let shutterButton = ShutterButton()
    private let bottomSheet = BottomSheetController()
    private let sheetStack = UIStackView()
    private let shutterContainer = UIView()

    private let promptLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 3
        label.textAlignment = .center
        label.font = DesignSystem.Typography.bodyEmphasis()
        label.textColor = DesignSystem.Colors.textPrimary
        label.backgroundColor = .clear
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("scanning.prompt.initial")
        label.accessibilityIdentifier = "scanGuidanceLabel"
        return label
    }()

    private let guidanceStatusChip: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = DesignSystem.Typography.caption()
        label.adjustsFontForContentSizeCategory = true
        label.text = L("scanning.guidance.status.caution")
        label.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
        label.textColor = UIColor.white
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.isHidden = true
        label.accessibilityIdentifier = "scanGuidanceStatusChip"
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
        label.alpha = 1
        return label
    }()

    private let progressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = DesignSystem.Typography.caption()
        label.textColor = DesignSystem.Colors.textPrimary
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
        label.text = L("scanning.progress.capturing")
        label.isHidden = true
        label.accessibilityIdentifier = "scanProgressLabel"
        return label
    }()

    private let captureProgressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.28)
        progressView.progressTintColor = DesignSystem.Colors.actionPrimary
        progressView.progress = 0
        progressView.isHidden = true
        progressView.accessibilityIdentifier = "scanCaptureProgressView"
        return progressView
    }()

    private let developerDiagnosticsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = DesignSystem.Colors.textSecondary
        label.font = DesignSystem.Typography.caption()
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 2
        label.textAlignment = .left
        label.isHidden = true
        label.accessibilityIdentifier = "scanDeveloperDiagnosticsLabel"
        return label
    }()

    private var latestEarVerificationImage: UIImage?
    private var latestEarVerificationImageFrameIndex: Int?
    private var pendingEarVerificationFrame: EarVerificationPendingFrame?
    private var bestEarVerificationFrameCandidate: EarVerificationFrameCandidate?
    private var capturedCameraFrameIndex = 0

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
    private lazy var sessionController = makeSessionController()
    private lazy var runtimeController = makeRuntimeController()
    private let hudController = ScanHUDController()
    private let motionManager = CMMotionManager()
    private let scanStateLock = NSLock()
    private var activeScanningState = false

    private var latestViewMatrix = matrix_identity_float4x4
    private var assimilatedFrameIndex = 0
    private var consecutiveFailedCount = 0
    private var promptTimer: Timer?
    private var currentHUDState: AppScanHUDState = .idlePrompts {
        didSet { updateHUDVisibility() }
    }

    private var volumeView: MPVolumeView?
    private var isObservingVolumeButtons = false

    private let minSucceededFramesForCompletion = 50
    private let maxReconstructionThreadCount: Int32 = 2
    private let unstableMotionThreshold = 0.16
    private let goodTrackingFrameInterval = 40
    private let minimumEarVerificationAssimilatedFrameIndex = 8

    private func scanSheetProfile() -> ScanSheetProfile {
        Self.scanSheetProfile(forHeight: view.bounds.height, isPad: traitCollection.userInterfaceIdiom == .pad)
    }

    private static func scanSheetProfile(forHeight h: CGFloat, isPad: Bool) -> ScanSheetProfile {
        if isPad || h >= 900 {
            return ScanSheetProfile(collapsed: 180, half: 250, full: 320)
        }
        if h <= 700 {
            return ScanSheetProfile(collapsed: 168, half: 236, full: 300)
        }
        return ScanSheetProfile(collapsed: Layout.sheetCollapsedHeight, half: Layout.sheetHalfHeight, full: Layout.sheetFullHeight)
    }

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
        view.addSubview(guidanceStatusChip)
        view.addSubview(dismissButton)
        view.addSubview(manualFinishButton)
        bottomSheet.install(in: view, bottomInset: Layout.sheetBottomInset)
        sheetStack.translatesAutoresizingMaskIntoConstraints = false
        sheetStack.axis = .vertical
        sheetStack.spacing = DesignSystem.Spacing.s
        sheetStack.alignment = .fill
        bottomSheet.contentView.addSubview(sheetStack)
        sheetStack.addArrangedSubview(promptLabel)
        sheetStack.addArrangedSubview(progressLabel)
        sheetStack.addArrangedSubview(autoFinishLabel)
        sheetStack.addArrangedSubview(developerDiagnosticsLabel)
        shutterContainer.translatesAutoresizingMaskIntoConstraints = false
        shutterContainer.addSubview(shutterButton)
        sheetStack.addArrangedSubview(shutterContainer)

        bottomSheet.setSnapHeights(
            collapsed: scanSheetProfile().collapsed,
            half: scanSheetProfile().half,
            full: developerModeEnabled ? scanSheetProfile().full : scanSheetProfile().half
        )
        bottomSheet.setSnapPoint(.collapsed, animated: false)

        NSLayoutConstraint.activate([
            metalContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            metalContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            metalContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            guidanceStatusChip.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guidanceStatusChip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Layout.topStatusInset),
            guidanceStatusChip.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
            guidanceStatusChip.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            guidanceStatusChip.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),

            sheetStack.topAnchor.constraint(equalTo: bottomSheet.contentView.topAnchor),
            sheetStack.leadingAnchor.constraint(equalTo: bottomSheet.contentView.leadingAnchor),
            sheetStack.trailingAnchor.constraint(equalTo: bottomSheet.contentView.trailingAnchor),
            sheetStack.bottomAnchor.constraint(equalTo: bottomSheet.contentView.bottomAnchor),
            shutterContainer.heightAnchor.constraint(equalToConstant: 92),
            shutterButton.centerXAnchor.constraint(equalTo: shutterContainer.centerXAnchor),
            shutterButton.centerYAnchor.constraint(equalTo: shutterContainer.centerYAnchor)
        ])
        promptLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        progressLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        autoFinishLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        countdownLabel.textColor = .white
        countdownLabel.font = DesignSystem.Typography.title()
        countdownLabel.textAlignment = .center
        countdownLabel.isHidden = true
        countdownLabel.accessibilityIdentifier = "scanCountdownLabel"
        NSLayoutConstraint.activate([
            countdownLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            countdownLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        dismissButton.setTitle(L("common.close"), for: .normal)
        DesignSystem.applyButton(dismissButton, title: L("common.close"), style: .secondary, size: .regular)
        dismissButton.accessibilityIdentifier = "scanDismissButton"
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dismissButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            dismissButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        ])

        manualFinishButton.isHidden = true
        manualFinishButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            manualFinishButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            manualFinishButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        ])

        shutterButton.addTarget(self, action: #selector(shutterTapped(_:)), for: .touchUpInside)
        shutterButton.accessibilityIdentifier = "scanShutterButton"
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.widthAnchor.constraint(equalToConstant: 84).isActive = true
        shutterButton.heightAnchor.constraint(equalTo: shutterButton.widthAnchor).isActive = true

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

    }

    private func makeSessionController() -> ScanSessionController {
        let controller = ScanSessionController(hapticEngine: hapticEngine)
        controller.autoFinishSeconds = autoFinishSeconds
        controller.onStateChange = { [weak self] state in
            guard let self else { return }
            setActiveScanningState(state == .scanning)
            updateUI()
        }
        controller.onAutoFinishRemainingChange = { [weak self] _ in
            guard let self else { return }
            if self.state == .scanning {
                self.updateCaptureProgress()
                self.updateAutoFinishLabel()
            }
        }
        controller.onAutoFinishTriggered = { [weak self] in
            self?.finishScanNow()
        }
        return controller
    }

    private func makeRuntimeController() -> ScanRuntimeController {
        let controller = ScanRuntimeController()
        controller.onCriticalThermalState = { [weak self] in
            self?.handleCriticalThermalState()
        }
        return controller
    }

    private var state: State {
        sessionController.state
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        runtimeController.activate()
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
        sessionController.invalidate()
        runtimeController.deactivate()
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
        let profile = scanSheetProfile()
        let maxFull = max(profile.half, min(profile.full, view.bounds.height * 0.42))
        bottomSheet.setSnapHeights(
            collapsed: profile.collapsed,
            half: profile.half,
            full: developerModeEnabled ? maxFull : profile.half
        )
    }

    @objc private func dismissTapped() {
        stopScanning(reason: .canceled)
        dismiss(animated: true)
    }

    func configureManualFinishButton(title: String, target: Any?, action: Selector) {
        DesignSystem.applyButton(manualFinishButton, title: title, style: .primary, size: .regular)
        manualFinishButton.accessibilityIdentifier = "finishScanNowButton"
        manualFinishButton.accessibilityLabel = title
        manualFinishButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        manualFinishButton.removeTarget(nil, action: nil, for: .allEvents)
        manualFinishButton.addTarget(target, action: action, for: .touchUpInside)
        manualFinishButton.isEnabled = true
        DesignSystem.updateButtonEnabled(manualFinishButton, style: .primary)
        updateManualFinishButtonVisibility()
    }

    @objc func shutterTapped(_ sender: UIButton?) {
        guard presentedViewController == nil, cameraManager.isSessionRunning else { return }

        switch state {
        case .default:
            sessionController.startCountdown { [weak self] in
                self?.startScanning()
            }
        case .countdown:
            sessionController.cancelCountdown()
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
        sessionController.autoFinishSeconds = autoFinishSeconds
        sessionController.beginScanning()
        assimilatedFrameIndex = 0
        consecutiveFailedCount = 0
        latestEarVerificationImage = nil
        latestEarVerificationImageFrameIndex = nil
        pendingEarVerificationFrame = nil
        bestEarVerificationFrameCandidate = nil
        capturedCameraFrameIndex = 0
        meshTexturing.reset()
        captureProgressView.progress = 0
        hudController.resetForNewCapture()
        stopPromptLoop()
        applyGuidanceUpdate(hudController.initialActiveScanGuidance())
        emitGuidance(.start, force: true)
        updateCaptureProgress()
    }

    private func stopScanning(reason: ScanningTerminationReason) {
        guard sessionController.stopScanning(reason: reason) else { return }
        latestViewMatrix = matrix_identity_float4x4
        meshTexturing.reset()
        hudController.resetAfterCapture()
        currentHUDState = hudController.currentHUDState
        startPromptLoop()

        switch reason {
        case .canceled:
            clearEarVerificationFrameState()
            reconstructionManager.reset()
            delegate?.appScanningViewControllerDidCancel(self)
        case .finished:
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
                let selectedEarVerificationImage = self.bestEarVerificationFrameCandidate?.image ?? self.latestEarVerificationImage
                let selectedSelectionMetadata = self.makeEarVerificationSelectionMetadata()
                let payload = ScanPreviewInput(
                    pointCloud: pointCloud,
                    meshTexturing: self.meshTexturing,
                    earVerificationImage: selectedEarVerificationImage,
                    earVerificationSelectionMetadata: selectedSelectionMetadata
                )
                self.clearEarVerificationFrameState()
                self.delegate?.appScanningViewController(self, didCompleteScan: payload)
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
                self.emitGuidance(.moveSlower)
            }
        }
    }

    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }

    private func setActiveScanningState(_ isActive: Bool) {
        scanStateLock.lock()
        activeScanningState = isActive
        scanStateLock.unlock()
        runtimeController.updateScanningState(isScanning: isActive)
    }

    private func isActiveScanningState() -> Bool {
        scanStateLock.lock()
        let isActive = activeScanningState
        scanStateLock.unlock()
        return isActive
    }

    // MARK: - CameraManagerDelegate

    func cameraDidOutput(colorBuffer: CVPixelBuffer, depthBuffer: CVPixelBuffer, depthCalibrationData: AVCameraCalibrationData) {
        let isScanning = isActiveScanningState()
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
            captureEarVerificationImage(from: colorBuffer)
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
        scorePendingEarVerificationFrame(with: metadata)

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
            updateCaptureProgress()
            consecutiveFailedCount = 0
            if metadata.result == .poorTracking {
                emitGuidance(.poorTracking)
            } else if assimilatedFrameIndex % goodTrackingFrameInterval == 0 {
                emitGuidance(.goodTracking)
            }
        case .failed:
            if requiresManualFinish {
                break
            }
            consecutiveFailedCount += 1
            emitGuidance(.trackingLost, force: true)
            let belowMinFrames = statistics.succeededCount < minSucceededFramesForCompletion
            let exceededFailureTolerance = consecutiveFailedCount >= 5
            if belowMinFrames && exceededFailureTolerance {
                stopScanning(reason: .canceled)
            } else if !belowMinFrames {
                stopScanning(reason: .finished)
            }
        case .lostTracking:
            emitGuidance(.trackingLost, force: true)
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
        hudController.updateForSessionState(state)
        switch state {
        case .default:
            shutterButton.shutterButtonState = .default
            countdownLabel.isHidden = true
            currentHUDState = hudController.currentHUDState
        case .countdown(let seconds):
            shutterButton.shutterButtonState = .countdown
            countdownLabel.text = "\(seconds)"
            countdownLabel.isHidden = false
            currentHUDState = hudController.currentHUDState
        case .scanning:
            shutterButton.shutterButtonState = .scanning
            countdownLabel.isHidden = true
            currentHUDState = hudController.currentHUDState
        }
        updateManualFinishButtonVisibility()
    }

    private func updateManualFinishButtonVisibility() {
        let shouldShow = requiresManualFinish && state == .scanning
        manualFinishButton.isHidden = !shouldShow
        manualFinishButton.alpha = shouldShow ? 1.0 : 0.0
        manualFinishButton.isEnabled = shouldShow
        DesignSystem.updateButtonEnabled(manualFinishButton, style: .primary)
        if shouldShow {
            view.bringSubviewToFront(manualFinishButton)
        }
    }

    private func startPromptLoop() {
        stopPromptLoop()
        promptLabel.text = hudController.resetIdlePrompts()
        currentHUDState = hudController.currentHUDState
    }

    private func stopPromptLoop() {
        promptTimer?.invalidate()
        promptTimer = nil
    }

    @discardableResult
    private func emitGuidance(_ state: AppScanGuidanceState, force: Bool = false) -> Bool {
        guard let update = hudController.emitGuidance(state, force: force) else { return false }
        applyGuidanceUpdate(update)
        onRealtimeGuidance?(update.message)
        return true
    }

    private func applyGuidanceUpdate(_ update: AppScanGuidanceUpdate) {
        promptLabel.text = update.message
        guidanceStatusChip.text = "  \(update.status.title)  "
        guidanceStatusChip.backgroundColor = update.status.backgroundColor
        guidanceStatusChip.textColor = update.status.textColor
        guidanceStatusChip.accessibilityLabel = update.accessibilityLabel
        currentHUDState = update.hudState
    }

    private func updateCaptureProgress() {
        guard state == .scanning else { return }
        let update = hudController.progressUpdate(
            autoFinishSeconds: autoFinishSeconds,
            autoFinishRemaining: sessionController.autoFinishRemaining,
            assimilatedFrameIndex: assimilatedFrameIndex,
            minSucceededFramesForCompletion: minSucceededFramesForCompletion
        )
        progressLabel.text = update.text
        developerDiagnosticsLabel.text = update.diagnostics
    }

    private func updateHUDVisibility() {
        let visibility = hudController.visibility(for: currentHUDState, autoFinishSeconds: autoFinishSeconds)
        promptLabel.isHidden = visibility.promptHidden
        progressLabel.isHidden = visibility.progressHidden
        captureProgressView.isHidden = visibility.progressBarHidden
        guidanceStatusChip.isHidden = visibility.statusHidden
        autoFinishLabel.isHidden = visibility.autoFinishHidden
        focusHintLabel.isHidden = visibility.focusHintHidden
        developerDiagnosticsLabel.isHidden = !(developerModeEnabled && bottomSheet.currentSnapPoint == .full && state == .scanning)
        switch currentHUDState {
        case .idlePrompts:
            bottomSheet.setSnapPoint(.collapsed, animated: true)
        case .countdown:
            bottomSheet.setSnapPoint(.collapsed, animated: true)
        case .capturing, .warning, .critical:
            bottomSheet.setSnapPoint(.half, animated: true)
        }
    }

    @discardableResult
    private func applyNextIdlePromptIfNeeded() -> Bool {
        guard let prompt = hudController.nextIdlePromptIfNeeded(for: state) else { return false }
        promptLabel.text = prompt
        return true
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

    private func updateAutoFinishLabel() {
        autoFinishLabel.isHidden = autoFinishSeconds <= 0 || state != .scanning
        autoFinishLabel.text = String(format: L("scanning.autofinish"), sessionController.autoFinishRemaining)
    }

    private func clearEarVerificationFrameState() {
        latestEarVerificationImage = nil
        latestEarVerificationImageFrameIndex = nil
        pendingEarVerificationFrame = nil
        bestEarVerificationFrameCandidate = nil
        capturedCameraFrameIndex = 0
    }

    private func makeEarVerificationSelectionMetadata() -> EarVerificationSelectionMetadata? {
        if let bestCandidate = bestEarVerificationFrameCandidate {
            return EarVerificationSelectionMetadata(
                source: .bestCaptureFrame,
                frameIndex: bestCandidate.frameIndex,
                totalScore: Double(bestCandidate.scoreBreakdown.totalScore),
                profileScore: Double(bestCandidate.scoreBreakdown.profileScore),
                trackingScore: Double(bestCandidate.scoreBreakdown.trackingScore),
                guidanceScore: Double(bestCandidate.scoreBreakdown.guidanceScore),
                timingScore: Double(bestCandidate.scoreBreakdown.timingScore)
            )
        }

        if let latestFrameIndex = latestEarVerificationImageFrameIndex, latestEarVerificationImage != nil {
            return EarVerificationSelectionMetadata(
                source: .latestCaptureFallback,
                frameIndex: latestFrameIndex,
                totalScore: nil,
                profileScore: nil,
                trackingScore: nil,
                guidanceScore: nil,
                timingScore: nil
            )
        }

        return nil
    }

    private func scorePendingEarVerificationFrame(with metadata: SCAssimilatedFrameMetadata) {
        guard let pendingFrame = pendingEarVerificationFrame else { return }
        pendingEarVerificationFrame = nil

        guard let scoreBreakdown = Self.makeEarVerificationFrameScore(
            metadataResult: metadata.result,
            guidanceState: currentHUDState,
            assimilatedFrameIndex: assimilatedFrameIndex,
            minimumAssimilatedFrameIndex: minimumEarVerificationAssimilatedFrameIndex,
            viewMatrix: metadata.viewMatrix
        ) else {
            return
        }

        let candidate = EarVerificationFrameCandidate(
            image: pendingFrame.image,
            frameIndex: pendingFrame.frameIndex,
            timestamp: pendingFrame.timestamp,
            scoreBreakdown: scoreBreakdown
        )

        if let bestCandidate = bestEarVerificationFrameCandidate {
            if Self.shouldReplaceEarVerificationCandidate(current: bestCandidate, with: candidate) {
                bestEarVerificationFrameCandidate = candidate
            }
        } else {
            bestEarVerificationFrameCandidate = candidate
        }
    }

    private static func makeEarVerificationFrameScore(
        metadataResult: SCAssimilatedFrameResult,
        guidanceState: AppScanHUDState,
        assimilatedFrameIndex: Int,
        minimumAssimilatedFrameIndex: Int,
        viewMatrix: simd_float4x4
    ) -> EarVerificationFrameScoreBreakdown? {
        guard assimilatedFrameIndex >= minimumAssimilatedFrameIndex else { return nil }

        let trackingScore: Float
        switch metadataResult {
        case .succeeded:
            trackingScore = 1.0
        case .poorTracking:
            trackingScore = 0.35
        case .lostTracking, .failed:
            return nil
        @unknown default:
            return nil
        }

        let guidanceScore: Float
        switch guidanceState {
        case .capturing:
            guidanceScore = 0.3
        case .warning:
            guidanceScore = -0.2
        case .critical:
            return nil
        case .idlePrompts, .countdown:
            guidanceScore = 0
        }

        let normalizedProgress = min(max(Float(assimilatedFrameIndex - minimumAssimilatedFrameIndex) / 40.0, 0), 1)
        let timingScore = normalizedProgress * 0.2
        let profileScore = Self.earVerificationProfileScore(from: viewMatrix)
        let totalScore = profileScore + trackingScore + guidanceScore + timingScore

        return EarVerificationFrameScoreBreakdown(
            totalScore: totalScore,
            profileScore: profileScore,
            trackingScore: trackingScore,
            guidanceScore: guidanceScore,
            timingScore: timingScore
        )
    }

    private static func earVerificationProfileScore(from viewMatrix: simd_float4x4) -> Float {
        let horizontalMagnitude = sqrt((viewMatrix.columns.0.x * viewMatrix.columns.0.x) + (viewMatrix.columns.1.x * viewMatrix.columns.1.x))
        let yaw = abs(atan2(viewMatrix.columns.2.x, horizontalMagnitude))
        let normalizedYaw = min(max(yaw / (.pi / 2), 0), 1)
        return normalizedYaw * 1.2
    }

    private static func shouldReplaceEarVerificationCandidate(
        current: EarVerificationFrameCandidate,
        with candidate: EarVerificationFrameCandidate
    ) -> Bool {
        if candidate.scoreBreakdown.totalScore > current.scoreBreakdown.totalScore + 0.0001 {
            return true
        }

        if abs(candidate.scoreBreakdown.totalScore - current.scoreBreakdown.totalScore) <= 0.0001 {
            return candidate.frameIndex > current.frameIndex
        }

        return false
    }

    private func captureEarVerificationImage(from colorBuffer: CVPixelBuffer) {
        if currentHUDState == .critical { return }
        guard let image = Self.uiImage(from: colorBuffer) else { return }
        latestEarVerificationImage = image
        capturedCameraFrameIndex += 1
        latestEarVerificationImageFrameIndex = capturedCameraFrameIndex
        pendingEarVerificationFrame = EarVerificationPendingFrame(
            image: image,
            frameIndex: capturedCameraFrameIndex,
            timestamp: CFAbsoluteTimeGetCurrent()
        )
    }

    @objc private func focusOnTap(_ gesture: UITapGestureRecognizer) {
        guard state != .scanning else { return }
        let location = gesture.location(in: metalContainerView)
        cameraManager.focusOnTap(at: location)
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

    private static func uiImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return normalizedUIImage(UIImage(cgImage: cgImage))
    }

    private static func normalizedUIImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
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

    private func handleReconstructionError(_ error: Error) {
        Log.scan.error("Reconstruction API error: \(error.localizedDescription, privacy: .public)")
        stopScanning(reason: .canceled)
    }

#if DEBUG
    static func debug_scanSheetProfile(height: CGFloat, isPad: Bool) -> (collapsed: CGFloat, half: CGFloat, full: CGFloat) {
        let p = scanSheetProfile(forHeight: height, isPad: isPad)
        return (p.collapsed, p.half, p.full)
    }

    func debug_setStateScanning() {
        sessionController.debug_setStateScanning()
    }

    func debug_setStateDefault() {
        sessionController.debug_setStateDefault()
    }

    @discardableResult
    func debug_emitGuidance(named name: String, force: Bool = false) -> Bool {
        switch name {
        case "start":
            return emitGuidance(.start, force: force)
        case "moveSlower":
            return emitGuidance(.moveSlower, force: force)
        case "poorTracking":
            return emitGuidance(.poorTracking, force: force)
        case "goodTracking":
            return emitGuidance(.goodTracking, force: force)
        case "trackingLost":
            return emitGuidance(.trackingLost, force: force)
        default:
            return false
        }
    }

    @discardableResult
    func debug_applyNextIdlePromptStep() -> Bool {
        applyNextIdlePromptIfNeeded()
    }

    func debug_guidanceText() -> String? {
        promptLabel.text
    }

    func debug_statusChipText() -> String? {
        guidanceStatusChip.text?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func debug_statusChipHidden() -> Bool {
        guidanceStatusChip.isHidden
    }

    func debug_progressLabelText() -> String? {
        progressLabel.text
    }

    func debug_progressHidden() -> Bool {
        progressLabel.isHidden || captureProgressView.isHidden
    }

    func debug_countdownHidden() -> Bool {
        countdownLabel.isHidden
    }

    func debug_setAutoFinishForProgress(seconds: Int, remaining: Int) {
        autoFinishSeconds = seconds
        sessionController.debug_setAutoFinish(seconds: seconds, remaining: remaining)
    }

    func debug_setAssimilatedFramesForProgress(_ frames: Int) {
        assimilatedFrameIndex = frames
    }

    func debug_updateCaptureProgress() {
        updateCaptureProgress()
    }

    func debug_setStateCountdown(seconds: Int) {
        sessionController.debug_setStateCountdown(seconds: seconds)
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

    static func debug_makeEarVerificationFrameScore(
        metadataResult: SCAssimilatedFrameResult,
        guidanceState: AppScanHUDState,
        assimilatedFrameIndex: Int,
        minimumAssimilatedFrameIndex: Int,
        viewMatrix: simd_float4x4
    ) -> (total: Float, profile: Float, tracking: Float, guidance: Float, timing: Float)? {
        guard let score = makeEarVerificationFrameScore(
            metadataResult: metadataResult,
            guidanceState: guidanceState,
            assimilatedFrameIndex: assimilatedFrameIndex,
            minimumAssimilatedFrameIndex: minimumAssimilatedFrameIndex,
            viewMatrix: viewMatrix
        ) else { return nil }

        return (
            total: score.totalScore,
            profile: score.profileScore,
            tracking: score.trackingScore,
            guidance: score.guidanceScore,
            timing: score.timingScore
        )
    }

    static func debug_shouldReplaceEarVerificationCandidate(
        currentScore: Float,
        currentFrameIndex: Int,
        candidateScore: Float,
        candidateFrameIndex: Int
    ) -> Bool {
        let current = EarVerificationFrameCandidate(
            image: UIImage(),
            frameIndex: currentFrameIndex,
            timestamp: 0,
            scoreBreakdown: .init(
                totalScore: currentScore,
                profileScore: 0,
                trackingScore: 0,
                guidanceScore: 0,
                timingScore: 0
            )
        )
        let candidate = EarVerificationFrameCandidate(
            image: UIImage(),
            frameIndex: candidateFrameIndex,
            timestamp: 0,
            scoreBreakdown: .init(
                totalScore: candidateScore,
                profileScore: 0,
                trackingScore: 0,
                guidanceScore: 0,
                timingScore: 0
            )
        )
        return shouldReplaceEarVerificationCandidate(current: current, with: candidate)
    }
#endif
}
