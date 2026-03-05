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

    enum ScanningTerminationReason {
        case canceled
        case finished
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

    private enum State: Equatable {
        case `default`
        case countdown(Int)
        case scanning
    }

    private enum HUDState: Equatable {
        case idlePrompts
        case countdown
        case capturing
        case warning
        case critical
    }

    private struct HUDVisibility {
        let promptHidden: Bool
        let progressHidden: Bool
        let progressBarHidden: Bool
        let statusHidden: Bool
        let autoFinishHidden: Bool
        let focusHintHidden: Bool
    }

    private enum GuidanceState {
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

    private enum GuidanceStatus {
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
            UIColor.white
        }
    }

    private let metalContainerView = UIView()
    private let metalLayer = CAMetalLayer()
    private let countdownLabel = UILabel()
    private let dismissButton = UIButton(type: .system)
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
    private var lastGuidanceState: GuidanceState?
    private var lastGuidanceAt: Date = .distantPast
    private var pendingGuidanceState: GuidanceState?
    private var pendingGuidanceSince: Date = .distantPast
    private var currentHUDState: HUDState = .idlePrompts {
        didSet { updateHUDVisibility() }
    }

    private var volumeView: MPVolumeView?
    private var isObservingVolumeButtons = false

    private let countdownStartCount = 3
    private let countdownPerSecondDuration: TimeInterval = 0.75
    private let minSucceededFramesForCompletion = 50
    private let maxReconstructionThreadCount: Int32 = 2
    private let unstableMotionThreshold = 0.16
    private let guidanceCooldown: TimeInterval = 2.0
    private let warningGuidanceHoldWindow: TimeInterval = 0.6
    private let recoveryGuidanceHoldWindow: TimeInterval = 0.8
    private let goodTrackingFrameInterval = 40
    private let goodTrackingMinimumRepeatInterval: TimeInterval = 4.0

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
        autoFinishRemaining = max(0, autoFinishSeconds)
        captureProgressView.progress = 0
        lastGuidanceState = nil
        lastGuidanceAt = .distantPast
        pendingGuidanceState = nil
        pendingGuidanceSince = .distantPast
        stopPromptLoop()
        currentHUDState = .capturing
        emitGuidance(.start, force: true)
        startAutoFinishTimerIfNeeded()
        updateCaptureProgress()
    }

    private func stopScanning(reason: ScanningTerminationReason) {
        guard state == .scanning else { return }
        state = .default
        latestViewMatrix = matrix_identity_float4x4
        meshTexturing.reset()
        stopAutoFinishTimers()
        lastGuidanceState = nil
        lastGuidanceAt = .distantPast
        pendingGuidanceState = nil
        pendingGuidanceSince = .distantPast
        currentHUDState = .idlePrompts
        startPromptLoop()

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
                self.emitGuidance(.moveSlower)
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
        switch state {
        case .default:
            shutterButton.shutterButtonState = .default
            countdownLabel.isHidden = true
            currentHUDState = .idlePrompts
        case .countdown(let seconds):
            shutterButton.shutterButtonState = .countdown
            countdownLabel.text = "\(seconds)"
            countdownLabel.isHidden = false
            currentHUDState = .countdown
        case .scanning:
            shutterButton.shutterButtonState = .scanning
            countdownLabel.isHidden = true
            if currentHUDState == .idlePrompts || currentHUDState == .countdown {
                currentHUDState = .capturing
            }
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
        stopPromptLoop()
        promptStep = 0
        promptLabel.text = L("scanning.prompt.initial")
    }

    private func stopPromptLoop() {
        promptTimer?.invalidate()
        promptTimer = nil
    }

    @discardableResult
    private func emitGuidance(_ state: GuidanceState, force: Bool = false) -> Bool {
        if state == .trackingLost {
            return applyGuidance(state, now: Date())
        }
        let now = Date()
        if !force, let last = lastGuidanceState {
            let elapsed = now.timeIntervalSince(lastGuidanceAt)
            let isPriorityUpgrade = state.priority > last.priority
            if state == .goodTracking && elapsed < goodTrackingMinimumRepeatInterval {
                return false
            }
            if shouldHoldGuidanceTransition(from: last, to: state, now: now) {
                return false
            }
            if !isPriorityUpgrade && elapsed < guidanceCooldown {
                return false
            }
            if state == last && elapsed < (guidanceCooldown * 1.5) {
                return false
            }
        }
        return applyGuidance(state, now: now)
    }

    @discardableResult
    private func applyGuidance(_ state: GuidanceState, now: Date) -> Bool {
        pendingGuidanceState = nil
        let message = state.message
        promptLabel.text = message
        applyGuidanceStatus(for: state, message: message)
        onRealtimeGuidance?(message)
        lastGuidanceState = state
        lastGuidanceAt = now
        return true
    }

    private func updateCaptureProgress() {
        guard state == .scanning else { return }
        if autoFinishSeconds > 0 {
            let elapsed = max(0, autoFinishSeconds - autoFinishRemaining)
            let progress = min(max(Float(elapsed) / Float(autoFinishSeconds), 0), 1)
            progressLabel.text = String(format: L("scanning.progress.timeFormat"), elapsed, autoFinishSeconds)
            developerDiagnosticsLabel.text = String(format: "Frames: %d · Progress: %d%%", assimilatedFrameIndex, Int(round(progress * 100)))
        } else {
            let progress = min(max(Float(assimilatedFrameIndex) / Float(minSucceededFramesForCompletion), 0), 1)
            progressLabel.text = L("scanning.progress.capturing")
            developerDiagnosticsLabel.text = String(format: "Frames: %d · Progress: %d%%", assimilatedFrameIndex, Int(round(progress * 100)))
        }
    }

    private func shouldHoldGuidanceTransition(from previous: GuidanceState, to next: GuidanceState, now: Date) -> Bool {
        if next == previous { return false }
        let isUpgrade = next.priority > previous.priority
        let holdWindow = isUpgrade ? warningGuidanceHoldWindow : recoveryGuidanceHoldWindow
        if pendingGuidanceState != next {
            pendingGuidanceState = next
            pendingGuidanceSince = now
            return true
        }
        return now.timeIntervalSince(pendingGuidanceSince) < holdWindow
    }

    private func applyGuidanceStatus(for guidance: GuidanceState, message: String) {
        let status: GuidanceStatus
        switch guidance {
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
        guidanceStatusChip.text = "  \(status.title)  "
        guidanceStatusChip.backgroundColor = status.backgroundColor
        guidanceStatusChip.textColor = status.textColor
        guidanceStatusChip.accessibilityLabel = String(
            format: L("scanning.guidance.status.accessibility"),
            status.title,
            message
        )
    }

    private func updateHUDVisibility() {
        let visibility = hudVisibility(for: currentHUDState)
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

    private func hudVisibility(for state: HUDState) -> HUDVisibility {
        // Visibility matrix (single source of truth):
        // idlePrompts => prompt + focus hint only
        // countdown   => countdown only
        // capturing/* => prompt + status + progress text (+ auto-finish when enabled)
        switch state {
        case .idlePrompts:
            return HUDVisibility(
                promptHidden: false,
                progressHidden: true,
                progressBarHidden: true,
                statusHidden: true,
                autoFinishHidden: true,
                focusHintHidden: false
            )
        case .countdown:
            return HUDVisibility(
                promptHidden: true,
                progressHidden: true,
                progressBarHidden: true,
                statusHidden: true,
                autoFinishHidden: true,
                focusHintHidden: true
            )
        case .capturing, .warning, .critical:
            return HUDVisibility(
                promptHidden: false,
                progressHidden: false,
                progressBarHidden: true,
                statusHidden: false,
                autoFinishHidden: autoFinishSeconds <= 0,
                focusHintHidden: true
            )
        }
    }

    @discardableResult
    private func applyNextIdlePromptIfNeeded() -> Bool {
        guard state == .default else { return false }
        let prompts = [
            L("scanning.prompt.1"),
            L("scanning.prompt.2"),
            L("scanning.prompt.3"),
            L("scanning.prompt.4"),
            L("scanning.prompt.5"),
            L("scanning.prompt.6")
        ]
        promptLabel.text = prompts[promptStep % prompts.count]
        promptStep += 1
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
            updateCaptureProgress()
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
        if state == .scanning {
            updateCaptureProgress()
        }
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
    static func debug_scanSheetProfile(height: CGFloat, isPad: Bool) -> (collapsed: CGFloat, half: CGFloat, full: CGFloat) {
        let p = scanSheetProfile(forHeight: height, isPad: isPad)
        return (p.collapsed, p.half, p.full)
    }

    func debug_setStateScanning() {
        state = .scanning
    }

    func debug_setStateDefault() {
        state = .default
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
        autoFinishRemaining = remaining
    }

    func debug_setAssimilatedFramesForProgress(_ frames: Int) {
        assimilatedFrameIndex = frames
    }

    func debug_updateCaptureProgress() {
        updateCaptureProgress()
    }

    func debug_setStateCountdown(seconds: Int) {
        state = .countdown(seconds)
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
