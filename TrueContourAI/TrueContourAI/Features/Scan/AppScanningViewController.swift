import AVFoundation
import CoreMotion
import MediaPlayer
import Metal
import QuartzCore
import StandardCyborgFusion
import StandardCyborgUI
import UIKit

protocol ReconstructionManaging: AnyObject {
    var delegate: SCReconstructionManagerDelegate? { get set }
    var includesColorBuffersInMetadata: Bool { get set }
    var latestCameraCalibrationData: AVCameraCalibrationData? { get }
    var latestCameraCalibrationFrameWidth: Int { get }
    var latestCameraCalibrationFrameHeight: Int { get }

    func reset()
    func finalize(_ completion: @escaping () -> Void)
    func buildPointCloud() -> SCPointCloud
    func buildPointCloudSnapshot() -> SCPointCloud?
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
    typealias DiagnosticsSnapshot = CameraDiagnosticsSnapshot

    var delegate: CameraManagerDelegate? { get set }
    var isSessionRunning: Bool { get }
    var diagnosticsSnapshot: CameraDiagnosticsSnapshot { get }

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

struct CameraDiagnosticsSnapshot {
    var deliveredSynchronizedPairCount = 0
    var droppedSynchronizedPairCount = 0
    var droppedDepthDataCount = 0
    var droppedVideoDataCount = 0
    var missingSynchronizedDataCount = 0
}

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

    var latestCameraCalibrationData: AVCameraCalibrationData? { manager.latestCameraCalibrationData }
    var latestCameraCalibrationFrameWidth: Int { manager.latestCameraCalibrationFrameWidth }
    var latestCameraCalibrationFrameHeight: Int { manager.latestCameraCalibrationFrameHeight }

    func reset() { manager.reset() }
    func finalize(_ completion: @escaping () -> Void) { manager.finalize(completion) }
    func buildPointCloud() -> SCPointCloud { manager.buildPointCloud() }
    func buildPointCloudSnapshot() -> SCPointCloud? { manager.buildPointCloudSnapshot() }

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

    var delegate: CameraManagerDelegate? {
        get { manager.delegate }
        set { manager.delegate = newValue }
    }

    var isSessionRunning: Bool { manager.isSessionRunning }
    var diagnosticsSnapshot: CameraDiagnosticsSnapshot {
        let stats = manager.statisticsSnapshot
        return CameraDiagnosticsSnapshot(
            deliveredSynchronizedPairCount: stats.deliveredSynchronizedPairCount,
            droppedSynchronizedPairCount: stats.droppedSynchronizedPairCount,
            droppedDepthDataCount: stats.droppedDepthDataCount,
            droppedVideoDataCount: stats.droppedVideoDataCount,
            missingSynchronizedDataCount: stats.missingSynchronizedDataCount
        )
    }

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

struct ScanMetalContext {
    let device: MTLDevice
    let algorithmCommandQueue: MTLCommandQueue
    let visualizationCommandQueue: MTLCommandQueue
}

private final class UnavailableScanRuntimeEngine: ScanRuntimeEngining {
    var onEvent: ((ScanRuntimeEvent) -> Void)?
    var onRenderFrame: ((ScanRenderFrame) -> Void)?

    var diagnosticsSnapshot: ScanRuntimeDiagnosticsSnapshot {
        ScanRuntimeDiagnosticsSnapshot(
            succeededCount: 0,
            lostTrackingCount: 0,
            droppedFrameCount: 0
        )
    }

    func activate() {}
    func deactivate() {}
    func beginCapture(autoFinishSeconds: Int) {}
    func processFrame(_ frame: ScanFramePayload, isScanning: Bool) {}
    func finishCapture() {}
    func cancelCapture() {}
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

final class AppScanningViewController: UIViewController {
    private struct Layout {
        static let topStatusInset: CGFloat = 10
        static let sheetBottomInset: CGFloat = 10
    }

    private struct ScanSheetProfile {
        let collapsed: CGFloat
        let half: CGFloat
        let full: CGFloat
    }

    weak var delegate: AppScanningViewControllerDelegate?

    private(set) var autoFinishSeconds: Int
    private(set) var requiresManualFinish: Bool
    private(set) var developerModeEnabled: Bool
    private(set) var maxDepthResolution: Int
    private(set) var generatesTexturedMeshes: Bool
    private(set) var texturedMeshColorBufferSaveInterval: Int
    private(set) var processingConfig: SettingsStore.ProcessingConfig

    private let metalContainerView = UIView()
    private let metalLayer = CAMetalLayer()
    private let countdownLabel = UILabel()
    private let dismissButton = UIButton(type: .system)
    private let manualFinishButton = UIButton(type: .system)
    private let shutterButton = ShutterButton()
    private let bottomSheet = BottomSheetController()
    private let sheetStack = UIStackView()
    private let shutterContainer = UIView()
    private let thermalWarningLabel = UILabel()

    private let promptLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 3
        label.textAlignment = .center
        label.font = DesignSystem.Typography.bodyEmphasis()
        label.textColor = DesignSystem.Colors.textPrimary
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
        label.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
        label.textColor = .white
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
        label.isHidden = true
        label.accessibilityIdentifier = "scanProgressLabel"
        return label
    }()

    private let developerDiagnosticsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = DesignSystem.Colors.textSecondary
        label.font = DesignSystem.Typography.caption()
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 3
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
        label.isHidden = true
        return label
    }()

    private let metalContext: ScanMetalContext?
    private lazy var scanningViewRenderer: ScanningViewRenderer? = {
        guard let metalContext else { return nil }
        return DefaultScanningViewRenderer(
            device: metalContext.device,
            commandQueue: metalContext.visualizationCommandQueue
        )
    }()

    private let runtimeEngine: ScanRuntimeEngining
    private lazy var metalInitializationFailure: ScanFailureViewData? = {
        guard metalContext == nil else { return nil }
        return ScanFailureViewData(
            title: L("scan.start.unavailable.title"),
            message: L("scan.start.cameraUnavailable.message"),
            allowsRetry: false
        )
    }()
    private let store: ScanStore
    private let orientationSource: ScanInterfaceOrientationSource

    private var didRouteCancel = false
    private var didRouteCompletion = false
    private var volumeView: MPVolumeView?
    private var isObservingVolumeButtons = false
    private var currentInterfaceOrientation: UIInterfaceOrientation = .portrait

    init(
        store: ScanStore,
        runtimeEngine: ScanRuntimeEngining,
        autoFinishSeconds: Int,
        requiresManualFinish: Bool,
        developerModeEnabled: Bool,
        maxDepthResolution: Int,
        generatesTexturedMeshes: Bool,
        texturedMeshColorBufferSaveInterval: Int,
        processingConfig: SettingsStore.ProcessingConfig,
        orientationSource: ScanInterfaceOrientationSource,
        metalContext: ScanMetalContext?
    ) {
        self.store = store
        self.runtimeEngine = runtimeEngine
        self.autoFinishSeconds = autoFinishSeconds
        self.requiresManualFinish = requiresManualFinish
        self.developerModeEnabled = developerModeEnabled
        self.maxDepthResolution = maxDepthResolution
        self.generatesTexturedMeshes = generatesTexturedMeshes
        self.texturedMeshColorBufferSaveInterval = texturedMeshColorBufferSaveInterval
        self.processingConfig = processingConfig
        self.orientationSource = orientationSource
        self.metalContext = metalContext
        super.init(nibName: nil, bundle: nil)
    }

    convenience init(
        reconstructionManagerFactory: @escaping (MTLDevice, MTLCommandQueue, Int32) -> ReconstructionManaging = {
            SCReconstructionManagerAdapter(device: $0, commandQueue: $1, maxThreadCount: $2)
        },
        cameraManager: CameraManaging = CameraManagerAdapter(),
        hapticEngine: ScanningHapticFeedbackProviding = ScanningHapticFeedbackEngine.shared,
        autoFinishSeconds: Int = 0,
        requiresManualFinish: Bool = false,
        developerModeEnabled: Bool = false,
        maxDepthResolution: Int = 320,
        generatesTexturedMeshes: Bool = true,
        texturedMeshColorBufferSaveInterval: Int = 8,
        processingConfig: SettingsStore.ProcessingConfig = SettingsStore().processingConfig,
        backgroundWorkRunner: @escaping (@escaping () -> Void) -> Void = { work in
            DispatchQueue.global(qos: .userInitiated).async(execute: work)
        }
    ) {
        let captureConfiguration = ScanCaptureConfiguration(
            maxDepthResolution: maxDepthResolution,
            textureSaveInterval: texturedMeshColorBufferSaveInterval,
            developerModeEnabled: developerModeEnabled
        )
        let runtimeConfiguration = ScanRuntimeConfiguration(
            processingConfig: processingConfig,
            texturedMeshEnabled: generatesTexturedMeshes,
            textureSaveInterval: texturedMeshColorBufferSaveInterval
        )
        let orientationSource = ScanInterfaceOrientationSource()
        let captureService = ScanCaptureService(
            cameraManager: cameraManager,
            configuration: captureConfiguration,
            orientationProvider: { orientationSource.current }
        )
        let metalContext = Self.makeMetalContextForAssembly()
        let runtimeEngine: ScanRuntimeEngining
        if let metalContext {
            runtimeEngine = ScanRuntimeEngine(
                reconstructionManager: reconstructionManagerFactory(
                    metalContext.device,
                    metalContext.algorithmCommandQueue,
                    2
                ),
                configuration: runtimeConfiguration,
                developerModeEnabled: developerModeEnabled,
                requiresManualFinish: requiresManualFinish,
                backgroundWorkRunner: backgroundWorkRunner
            )
        } else {
            runtimeEngine = UnavailableScanRuntimeEngine()
        }
        let store = ScanStore(
            captureService: captureService,
            runtimeEngine: runtimeEngine,
            autoFinishSeconds: autoFinishSeconds,
            requiresManualFinish: requiresManualFinish,
            developerModeEnabled: developerModeEnabled,
            hapticEngine: hapticEngine
        )
        self.init(
            store: store,
            runtimeEngine: runtimeEngine,
            autoFinishSeconds: autoFinishSeconds,
            requiresManualFinish: requiresManualFinish,
            developerModeEnabled: developerModeEnabled,
            maxDepthResolution: maxDepthResolution,
            generatesTexturedMeshes: generatesTexturedMeshes,
            texturedMeshColorBufferSaveInterval: texturedMeshColorBufferSaveInterval,
            processingConfig: processingConfig,
            orientationSource: orientationSource,
            metalContext: metalContext
        )
    }

    @available(*, unavailable, message: "Programmatic-only. Use init(reconstructionManagerFactory:cameraManager:hapticEngine:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindStore()
        configureUI()
        store.onStateChange?(store.state)
        if let metalInitializationFailure {
            apply(state: .failed(metalInitializationFailure))
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshCurrentInterfaceOrientation()
        installVolumeShutterIfNeeded()
        guard metalInitializationFailure == nil else {
            handle(
                effect: .alert(
                    title: L("scan.start.unavailable.title"),
                    message: L("scan.start.cameraUnavailable.message"),
                    identifier: "metalUnavailable"
                )
            )
            return
        }
        store.send(.viewDidAppear)
        store.send(.startSession)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removeVolumeShutterObserver()
        if !didRouteCancel && !didRouteCompletion {
            store.send(.dismissTapped)
        }
        runtimeEngine.deactivate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refreshCurrentInterfaceOrientation()
        CATransaction.begin()
        CATransaction.disableActions()
        metalLayer.frame = metalContainerView.bounds
        let scale = view.window?.windowScene?.screen.scale ?? traitCollection.displayScale
        metalLayer.drawableSize = CGSize(width: metalLayer.frame.width * scale, height: metalLayer.frame.height * scale)
        CATransaction.commit()
        updateSheetLayout()
    }

    @objc private func dismissTapped() {
        store.send(.dismissTapped)
    }

    @objc func shutterTapped(_ sender: UIButton?) {
        store.send(.startSession)
    }

    @objc func finishScanNow() {
        store.send(.finishTapped)
    }

    func configureManualFinishButton(title: String, target: Any?, action: Selector) {
        DesignSystem.applyButton(manualFinishButton, title: title, style: .primary, size: .regular)
        manualFinishButton.accessibilityIdentifier = "finishScanNowButton"
        manualFinishButton.accessibilityLabel = title
    }

    private func bindStore() {
        store.onStateChange = { [weak self] state in
            self?.apply(state: state)
        }
        store.onEffect = { [weak self] effect in
            self?.handle(effect: effect)
        }
        runtimeEngine.onRenderFrame = { [weak self] renderFrame in
            guard let self else { return }
            guard let scanningViewRenderer = self.scanningViewRenderer else { return }
            scanningViewRenderer.draw(
                colorBuffer: renderFrame.colorBuffer,
                pointCloud: renderFrame.pointCloud,
                depthCameraCalibrationData: renderFrame.calibrationData,
                viewMatrix: renderFrame.viewMatrix,
                into: self.metalLayer
            )
        }
    }

    private func configureUI() {
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
        bottomSheet.contentView.addSubview(sheetStack)
        sheetStack.addArrangedSubview(promptLabel)
        sheetStack.addArrangedSubview(progressLabel)
        sheetStack.addArrangedSubview(autoFinishLabel)
        sheetStack.addArrangedSubview(focusHintLabel)
        sheetStack.addArrangedSubview(thermalWarningLabel)
        sheetStack.addArrangedSubview(developerDiagnosticsLabel)
        shutterContainer.translatesAutoresizingMaskIntoConstraints = false
        shutterContainer.addSubview(shutterButton)
        sheetStack.addArrangedSubview(shutterContainer)

        NSLayoutConstraint.activate([
            metalContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            metalContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            metalContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            guidanceStatusChip.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guidanceStatusChip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Layout.topStatusInset),

            sheetStack.topAnchor.constraint(equalTo: bottomSheet.contentView.topAnchor),
            sheetStack.leadingAnchor.constraint(equalTo: bottomSheet.contentView.leadingAnchor),
            sheetStack.trailingAnchor.constraint(equalTo: bottomSheet.contentView.trailingAnchor),
            sheetStack.bottomAnchor.constraint(equalTo: bottomSheet.contentView.bottomAnchor),
            shutterContainer.heightAnchor.constraint(equalToConstant: 92),
            shutterButton.centerXAnchor.constraint(equalTo: shutterContainer.centerXAnchor),
            shutterButton.centerYAnchor.constraint(equalTo: shutterContainer.centerYAnchor),

            countdownLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            countdownLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            dismissButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            dismissButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            manualFinishButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            manualFinishButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        ])

        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        countdownLabel.textColor = .white
        countdownLabel.font = DesignSystem.Typography.title()
        countdownLabel.textAlignment = .center
        countdownLabel.isHidden = true
        countdownLabel.accessibilityIdentifier = "scanCountdownLabel"

        DesignSystem.applyButton(dismissButton, title: L("common.close"), style: .secondary, size: .regular)
        dismissButton.accessibilityIdentifier = "scanDismissButton"
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false

        DesignSystem.applyButton(manualFinishButton, title: L("common.finish"), style: .primary, size: .regular)
        manualFinishButton.isHidden = true
        manualFinishButton.accessibilityIdentifier = "finishScanNowButton"
        manualFinishButton.addTarget(self, action: #selector(finishScanNow), for: .touchUpInside)
        manualFinishButton.translatesAutoresizingMaskIntoConstraints = false

        shutterButton.addTarget(self, action: #selector(shutterTapped(_:)), for: .touchUpInside)
        shutterButton.accessibilityIdentifier = "scanShutterButton"
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.isEnabled = false
        shutterButton.widthAnchor.constraint(equalToConstant: 84).isActive = true
        shutterButton.heightAnchor.constraint(equalTo: shutterButton.widthAnchor).isActive = true

        thermalWarningLabel.translatesAutoresizingMaskIntoConstraints = false
        thermalWarningLabel.font = DesignSystem.Typography.caption()
        thermalWarningLabel.textColor = .systemOrange
        thermalWarningLabel.numberOfLines = 2
        thermalWarningLabel.text = L("scanning.thermal.message")
        thermalWarningLabel.isHidden = true

        metalLayer.isOpaque = true
        metalLayer.device = metalContext?.device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalContainerView.layer.addSublayer(metalLayer)
        metalContainerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focusOnTap(_:))))
        updateSheetLayout()
    }

    private func updateSheetLayout() {
        let profile = Self.scanSheetProfile(forHeight: view.bounds.height, isPad: traitCollection.userInterfaceIdiom == .pad)
        let maxFull = max(profile.half, min(profile.full, view.bounds.height * 0.42))
        bottomSheet.setSnapHeights(
            collapsed: profile.collapsed,
            half: profile.half,
            full: developerModeEnabled ? maxFull : profile.half
        )
        bottomSheet.setSnapPoint(.collapsed, animated: false)
    }

    private func apply(state: ScanState) {
        switch state {
        case .idle:
            shutterButton.isEnabled = false
            break
        case .requestingPermission:
            shutterButton.isEnabled = false
            dismissButton.isEnabled = false
        case let .ready(viewData):
            shutterButton.shutterButtonState = .default
            shutterButton.isEnabled = true
            countdownLabel.isHidden = true
            promptLabel.text = viewData.promptText
            focusHintLabel.text = viewData.focusHintText
            focusHintLabel.isHidden = viewData.focusHintText == nil
            guidanceStatusChip.isHidden = true
            progressLabel.isHidden = true
            autoFinishLabel.isHidden = true
            thermalWarningLabel.isHidden = true
            developerDiagnosticsLabel.text = viewData.developerDiagnosticsText
            developerDiagnosticsLabel.isHidden = viewData.developerDiagnosticsText == nil
            manualFinishButton.isHidden = !viewData.finishButtonVisible
            manualFinishButton.isEnabled = viewData.finishButtonEnabled
            dismissButton.isEnabled = viewData.dismissButtonEnabled
        case let .countdown(viewData):
            shutterButton.shutterButtonState = .countdown
            shutterButton.isEnabled = true
            countdownLabel.text = viewData.countdownText
            countdownLabel.isHidden = false
            promptLabel.text = nil
            guidanceStatusChip.isHidden = true
            progressLabel.isHidden = true
            autoFinishLabel.isHidden = true
            focusHintLabel.isHidden = true
            thermalWarningLabel.isHidden = true
            developerDiagnosticsLabel.isHidden = true
            manualFinishButton.isHidden = true
            dismissButton.isEnabled = viewData.dismissButtonEnabled
        case let .capturing(viewData):
            applyCapturing(viewData, shutterState: .scanning)
        case let .finishing(viewData):
            applyCapturing(viewData, shutterState: .scanning)
            dismissButton.isEnabled = false
            manualFinishButton.isEnabled = false
            shutterButton.isEnabled = false
        case .unavailable(let viewData):
            shutterButton.isEnabled = false
            promptLabel.text = viewData.message
        case .failed(let failure):
            shutterButton.isEnabled = true
            promptLabel.text = failure.message
            guidanceStatusChip.isHidden = true
            countdownLabel.isHidden = true
            progressLabel.isHidden = true
            autoFinishLabel.isHidden = true
            focusHintLabel.isHidden = true
            thermalWarningLabel.isHidden = true
            developerDiagnosticsLabel.isHidden = true
            manualFinishButton.isHidden = true
            dismissButton.isEnabled = true
        case let .completed(payload):
            guard !didRouteCompletion else { return }
            didRouteCompletion = true
            delegate?.appScanningViewController(self, didCompleteScan: payload)
            delegate?.appScanningViewController(self, didScan: payload.pointCloud, meshTexturing: payload.meshTexturing)
        }
    }

    private func applyCapturing(_ viewData: ScanCapturingViewData, shutterState: ShutterButtonState) {
        shutterButton.shutterButtonState = shutterState
        shutterButton.isEnabled = false
        countdownLabel.isHidden = true
        promptLabel.text = viewData.promptText
        if let chipText = viewData.guidanceChipText {
            guidanceStatusChip.text = "  \(chipText)  "
            guidanceStatusChip.backgroundColor = guidanceBackgroundColor(for: viewData.guidanceChipStyle)
            guidanceStatusChip.isHidden = false
        } else {
            guidanceStatusChip.isHidden = true
        }
        progressLabel.text = viewData.progressText
        progressLabel.isHidden = viewData.progressText == nil
        autoFinishLabel.text = autoFinishSeconds > 0 ? String(format: L("scanning.autofinish"), max(0, autoFinishSeconds - (Int(round((viewData.progressFraction ?? 0) * Float(autoFinishSeconds)))))) : nil
        autoFinishLabel.isHidden = autoFinishSeconds <= 0
        focusHintLabel.text = viewData.focusHintText
        focusHintLabel.isHidden = viewData.focusHintText == nil
        thermalWarningLabel.isHidden = !viewData.thermalWarningVisible
        developerDiagnosticsLabel.text = viewData.developerDiagnosticsText
        developerDiagnosticsLabel.isHidden = viewData.developerDiagnosticsText == nil
        manualFinishButton.isHidden = !viewData.finishButtonVisible
        manualFinishButton.isEnabled = viewData.finishButtonEnabled
        dismissButton.isEnabled = viewData.dismissButtonEnabled
        bottomSheet.setSnapPoint(viewData.thermalWarningVisible || developerModeEnabled ? .half : .collapsed, animated: false)
    }

    private func handle(effect: ScanEffect) {
        switch effect {
        case let .alert(title, message, identifier):
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("common.ok"), style: .default, handler: { [weak self] _ in
                guard let self else { return }
                if identifier == "cameraDenied" || identifier == "cameraUnavailable" || identifier == "thermalShutdown" {
                    self.dismiss(animated: true)
                }
            }))
            if presentedViewController == nil {
                present(alert, animated: true)
            }
        case .dismiss:
            guard !didRouteCancel && !didRouteCompletion else { return }
            didRouteCancel = true
            delegate?.appScanningViewControllerDidCancel(self)
        case .hapticPrimary:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    static func makeMetalContextForAssembly() -> ScanMetalContext? {
        guard let device = MTLCreateSystemDefaultDevice(),
              let algorithmCommandQueue = device.makeCommandQueue(),
              let visualizationCommandQueue = device.makeCommandQueue() else {
            return nil
        }
        return ScanMetalContext(
            device: device,
            algorithmCommandQueue: algorithmCommandQueue,
            visualizationCommandQueue: visualizationCommandQueue
        )
    }

    static func makeUnavailableRuntimeEngineForAssembly() -> ScanRuntimeEngining {
        UnavailableScanRuntimeEngine()
    }

    private func refreshCurrentInterfaceOrientation() {
        guard Thread.isMainThread else { return }
        currentInterfaceOrientation = view.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait
        orientationSource.current = currentInterfaceOrientation
    }

    private func guidanceBackgroundColor(for style: GuidanceChipStyle) -> UIColor {
        switch style {
        case .neutral:
            return UIColor.systemGray.withAlphaComponent(0.85)
        case .caution:
            return UIColor.systemOrange.withAlphaComponent(0.9)
        case .warning:
            return UIColor.systemRed.withAlphaComponent(0.9)
        case .good:
            return UIColor.systemGreen.withAlphaComponent(0.86)
        }
    }

    @objc private func focusOnTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: metalContainerView)
        store.send(.focusRequested(location))
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

    private static func scanSheetProfile(forHeight h: CGFloat, isPad: Bool) -> ScanSheetProfile {
        if isPad || h >= 900 {
            return ScanSheetProfile(collapsed: 180, half: 250, full: 320)
        }
        if h <= 700 {
            return ScanSheetProfile(collapsed: 168, half: 236, full: 300)
        }
        return ScanSheetProfile(collapsed: 170, half: 260, full: 360)
    }

#if DEBUG
    static func debug_scanSheetProfile(height: CGFloat, isPad: Bool) -> (collapsed: CGFloat, half: CGFloat, full: CGFloat) {
        let profile = scanSheetProfile(forHeight: height, isPad: isPad)
        return (profile.collapsed, profile.half, profile.full)
    }

    func debug_scanState() -> ScanState {
        store.state
    }
#endif
}
