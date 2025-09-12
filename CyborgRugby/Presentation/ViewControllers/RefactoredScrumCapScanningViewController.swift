//
//  RefactoredScrumCapScanningViewController.swift
//  CyborgRugby
//
//  Refactored scanning controller using extracted services for better architecture
//

import UIKit
import OSLog
import StandardCyborgFusion
import SceneKit
import AVFoundation
import Metal

@MainActor
class RefactoredScrumCapScanningViewController: UIViewController {
    
    // MARK: - Delegate
    weak var delegate: ScrumCapScanningViewControllerDelegate?
    
    // MARK: - Services
    private let cameraService = CameraCaptureService()
    private let poseDetectionService: PoseDetectionService
    private let uiStateManager = ScanningUIStateManager()
    private let multiAngleScanManager: RefactoredMultiAngleScanManager
    private let rugbyEarAnalyzer = RugbyEarProtectionCalculator()
    private let voiceCoach = VoiceCoach()
    private let achievementManager = AchievementManager.shared
    
    // MARK: - UI Components
    private var metalContainerView: UIView!
    private var sceneView: SCNView!
    private var poseInstructionLabel: UILabel!
    private var statusHintLabel: UILabel!
    private var poseProgressStack: UIStackView!
    private var poseProgressLabel: UILabel!
    private var scanningButton: UIButton!
    private var skipPoseButton: UIButton!
    private var timerLabel: UILabel!
    private var achievementBannerView: UIView!
    
    // MARK: - Properties
    private let metalDevice = MTLCreateSystemDefaultDevice()!
    private var scanningViewRenderer: ScanningViewRenderer!
    private var reconstructionManager: SCReconstructionManager?
    private let metalLayer = CAMetalLayer()
    
    // MARK: - Initialization
    
    init() {
        self.poseDetectionService = PoseDetectionService()
        // Initialize Metal device for scanning services
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.multiAngleScanManager = RefactoredMultiAngleScanManager(metalDevice: metalDevice)
        super.init(nibName: nil, bundle: nil)
        setupServiceDelegates()
    }
    
    required init?(coder: NSCoder) {
        self.poseDetectionService = PoseDetectionService()
        // Initialize Metal device for scanning services
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.multiAngleScanManager = RefactoredMultiAngleScanManager(metalDevice: metalDevice)
        super.init(coder: coder)
        setupServiceDelegates()
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMetalComponents()
        setupReconstruction()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        requestCameraPermissionAndStart()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopAllServices()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateMetalLayerFrame()
        updateSceneViewFrame()
    }
    
    // MARK: - Setup Methods
    
    private func setupServiceDelegates() {
        cameraService.delegate = self
        poseDetectionService.delegate = self
        uiStateManager.delegate = self
        multiAngleScanManager.delegate = self
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        createUIComponents()
        layoutUIComponents()
        bindUIToState()
    }
    
    private func setupMetalComponents() {
        // Setup metal layer
        metalLayer.device = metalDevice
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.isOpaque = true
        metalLayer.contentsScale = UIScreen.main.scale
        metalContainerView.layer.addSublayer(metalLayer)
        
        // Setup scanning renderer
        scanningViewRenderer = ScanningViewRenderer(
            device: metalDevice,
            commandQueue: metalDevice.makeCommandQueue()!
        )
        
        // Setup scene view
        setupSceneView()
    }
    
    private func setupReconstruction() {
        reconstructionManager = SCReconstructionManager(
            device: metalDevice,
            commandQueue: metalDevice.makeCommandQueue()!,
            maxThreadCount: Int32(ProcessInfo.processInfo.activeProcessorCount)
        )
        // Delegate will be set by the service architecture
    }
    
    // MARK: - UI Creation and Layout
    
    private func createUIComponents() {
        metalContainerView = UIView()
        metalContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metalContainerView)
        
        poseInstructionLabel = createLabel(font: .systemFont(ofSize: 20, weight: .bold))
        statusHintLabel = createLabel(font: .systemFont(ofSize: 16, weight: .medium), color: .systemYellow)
        timerLabel = createLabel(font: .monospacedDigitSystemFont(ofSize: 16, weight: .medium))
        poseProgressLabel = createLabel(font: .systemFont(ofSize: 16, weight: .medium))
        
        statusHintLabel.isHidden = true
        timerLabel.isHidden = true
        
        poseProgressStack = UIStackView()
        poseProgressStack.axis = .horizontal
        poseProgressStack.alignment = .center
        poseProgressStack.distribution = .equalCentering
        poseProgressStack.spacing = 8
        poseProgressStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(poseProgressStack)
        
        scanningButton = createPrimaryButton(title: "Start Scanning", imageName: "camera.viewfinder")
        skipPoseButton = createSecondaryButton(title: "Skip Pose", imageName: "forward.fill")
        
        scanningButton.addTarget(self, action: #selector(scanningButtonTapped), for: .touchUpInside)
        skipPoseButton.addTarget(self, action: #selector(skipPoseButtonTapped), for: .touchUpInside)
        
        achievementBannerView = createAchievementBanner()
        
        [poseInstructionLabel, statusHintLabel, timerLabel, poseProgressLabel, scanningButton, skipPoseButton, achievementBannerView].forEach {
            view.addSubview($0)
        }
    }
    
    private func layoutUIComponents() {
        NSLayoutConstraint.activate([
            // Metal container fills screen
            metalContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            metalContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            metalContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Pose instruction at top
            poseInstructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            poseInstructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            poseInstructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Status hint below instruction
            statusHintLabel.topAnchor.constraint(equalTo: poseInstructionLabel.bottomAnchor, constant: 10),
            statusHintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusHintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Timer below status
            timerLabel.topAnchor.constraint(equalTo: statusHintLabel.bottomAnchor, constant: 8),
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Progress stack below timer
            poseProgressStack.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 12),
            poseProgressStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Progress label below stack
            poseProgressLabel.topAnchor.constraint(equalTo: poseProgressStack.bottomAnchor, constant: 8),
            poseProgressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Scanning button at bottom
            scanningButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanningButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            // Skip button above scanning button
            skipPoseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            skipPoseButton.bottomAnchor.constraint(equalTo: scanningButton.topAnchor, constant: -12),
            
            // Achievement banner at top
            achievementBannerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            achievementBannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            achievementBannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            achievementBannerView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    // MARK: - Helper Methods
    
    private func createLabel(font: UIFont, color: UIColor = .white) -> UILabel {
        let label = UILabel()
        label.textColor = color
        label.font = font
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func createPrimaryButton(title: String, imageName: String) -> UIButton {
        let button = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = title
            config.image = UIImage(systemName: imageName)
            config.imagePadding = 8
            config.cornerStyle = .large
            button.configuration = config
        } else {
            button.setTitle(title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = .systemBlue
            button.layer.cornerRadius = 16
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func createSecondaryButton(title: String, imageName: String) -> UIButton {
        let button = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.title = title
            config.image = UIImage(systemName: imageName)
            config.imagePadding = 8
            config.cornerStyle = .large
            button.configuration = config
        } else {
            button.setTitle(title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = .systemOrange
            button.layer.cornerRadius = 12
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }
    
    private func createAchievementBanner() -> UIView {
        let banner = UIView()
        banner.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        banner.layer.cornerRadius = 12
        banner.layer.masksToBounds = true
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.isHidden = true
        return banner
    }
    
    private func setupSceneView() {
        sceneView = SCNView()
        sceneView.backgroundColor = UIColor.clear
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.isHidden = true
        view.insertSubview(sceneView, aboveSubview: metalContainerView)
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Add basic lighting
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor.white
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)
    }
    
    // MARK: - Service Management
    
    private func requestCameraPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startServices()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.startServices()
                    } else {
                        self?.showCameraPermissionAlert()
                    }
                }
            }
        default:
            showCameraPermissionAlert()
        }
    }
    
    private func startServices() {
        cameraService.startCapture()
        poseDetectionService.startMotionTracking()
        AppLog.ui.info("Started scanning services")
    }
    
    private func stopAllServices() {
        cameraService.stopCapture()
        poseDetectionService.stopMotionTracking()
        uiStateManager.stopScanning()
        voiceCoach.stopSpeaking()
        AppLog.ui.info("Stopped all scanning services")
    }
    
    private func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "This app needs camera access for 3D scanning. Please enable it in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - UI State Binding
    
    private func bindUIToState() {
        // This would typically use Combine or similar binding mechanism
        // For now, we'll update UI in delegate methods
    }
    
    private func updateMetalLayerFrame() {
        CATransaction.begin()
        CATransaction.disableActions()
        metalLayer.frame = metalContainerView.bounds
        metalLayer.drawableSize = CGSize(
            width: metalLayer.frame.width * metalLayer.contentsScale,
            height: metalLayer.frame.height * metalLayer.contentsScale
        )
        CATransaction.commit()
    }
    
    private func updateSceneViewFrame() {
        sceneView?.frame = metalContainerView.bounds
    }
    
    // MARK: - Actions
    
    @objc private func scanningButtonTapped() {
        if uiStateManager.currentState == .idle {
            uiStateManager.startScanning()
        } else {
            uiStateManager.stopScanning()
        }
    }
    
    @objc private func skipPoseButtonTapped() {
        // Skip current pose and move to next
        let nextPose = getNextPose()
        uiStateManager.updateCurrentPose(nextPose)
        cameraService.updateCurrentPose(nextPose)
        poseDetectionService.updateCurrentPose(nextPose)
    }
    
    @objc private func showProfile() {
        // Show profile screen
    }
    
    private func getNextPose() -> HeadScanningPose {
        let allPoses = HeadScanningPose.allCases
        let currentIndex = allPoses.firstIndex(of: uiStateManager.currentPose) ?? 0
        let nextIndex = (currentIndex + 1) % allPoses.count
        return allPoses[nextIndex]
    }
}

// MARK: - Service Delegates

extension RefactoredScrumCapScanningViewController: CameraCaptureServiceDelegate {
    
    func cameraService(_ service: CameraCaptureService, didCaptureFrame pixelBuffer: CVPixelBuffer, with pose: HeadScanningPose) {
        // Process frame through pose detection
        poseDetectionService.processFrame(pixelBuffer)
        
        // Update visualization
        scanningViewRenderer?.updateFrame(pixelBuffer)
    }
    
    func cameraService(_ service: CameraCaptureService, didFailWithError error: Error) {
        AppLog.camera.error("Camera service error: \(error.localizedDescription)")
        // Handle camera error
    }
    
    func cameraServiceDidStartCapture(_ service: CameraCaptureService) {
        AppLog.camera.info("Camera capture started successfully")
    }
    
    func cameraServiceDidStopCapture(_ service: CameraCaptureService) {
        AppLog.camera.info("Camera capture stopped")
    }
}

extension RefactoredScrumCapScanningViewController: PoseDetectionServiceDelegate {
    
    func poseDetectionService(_ service: PoseDetectionService, didValidatePose pose: HeadScanningPose, isValid: Bool, confidence: Float) {
        uiStateManager.updatePoseValidation(isValid: isValid, confidence: confidence)
    }
    
    func poseDetectionService(_ service: PoseDetectionService, didUpdateStability isStable: Bool) {
        uiStateManager.updateStability(isStable: isStable)
    }
    
    func poseDetectionService(_ service: PoseDetectionService, didDetectPerfectPose pose: HeadScanningPose) {
        uiStateManager.showPerfectPoseFeedback()
        // Trigger haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

extension RefactoredScrumCapScanningViewController: ScanningUIStateManagerDelegate {
    
    func stateManager(_ manager: ScanningUIStateManager, didUpdateUI state: ScanningUIState) {
        updateUIForState(state)
    }
    
    func stateManager(_ manager: ScanningUIStateManager, shouldShowAchievement achievement: String) {
        showAchievement(achievement)
    }
    
    private func updateUIForState(_ state: ScanningUIState) {
        poseInstructionLabel.text = state.instruction
        statusHintLabel.text = state.statusHint
        statusHintLabel.isHidden = state.statusHint == nil
        
        let showProgress = state.showProgressIndicators
        timerLabel.isHidden = !showProgress
        poseProgressStack.isHidden = !showProgress
        poseProgressLabel.isHidden = !showProgress
        
        // Update button states
        switch state {
        case .idle:
            scanningButton.setTitle("Start Scanning", for: .normal)
            skipPoseButton.isHidden = true
        case .scanning, .waitingForValidPose, .validPose, .capturingPose:
            scanningButton.setTitle("Stop Scanning", for: .normal)
            skipPoseButton.isHidden = false
        case .completed:
            scanningButton.setTitle("Complete", for: .normal)
            skipPoseButton.isHidden = true
        case .error:
            scanningButton.setTitle("Retry", for: .normal)
            skipPoseButton.isHidden = true
        }
    }
    
    private func showAchievement(_ achievement: String) {
        // Show achievement banner animation
        achievementBannerView.isHidden = false
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
            self.achievementBannerView.alpha = 1.0
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0, options: [.curveEaseIn]) {
                self.achievementBannerView.alpha = 0.0
            } completion: { _ in
                self.achievementBannerView.isHidden = true
            }
        }
    }
}

extension RefactoredScrumCapScanningViewController: RefactoredMultiAngleScanManagerDelegate {
    
    func scanManager(_ manager: RefactoredMultiAngleScanManager, didStartPose pose: HeadScanningPose) {
        AppLog.scan.info("Started pose: \(pose.displayName)")
    }
    
    func scanManager(_ manager: RefactoredMultiAngleScanManager, didCompletePose pose: HeadScanningPose, withResult result: ScanResult) {
        uiStateManager.completePose(pose)
        AppLog.scan.info("Completed pose: \(pose.displayName)")
    }
    
    func scanManager(_ manager: RefactoredMultiAngleScanManager, didFailPose pose: HeadScanningPose, withError error: Error) {
        AppLog.scan.error("Failed pose: \(pose.displayName) - \(String(describing: error))")
    }
    
    func scanManager(_ manager: RefactoredMultiAngleScanManager, didUpdateProgress progress: Float) {
        // Update progress UI if needed
    }
    
    func scanManager(_ manager: RefactoredMultiAngleScanManager, didFinishAllScans finalResult: CompleteScanResult) {
        delegate?.scrumCapScanning(self, didComplete: finalResult)
    }
    
    func scanManager(_ manager: RefactoredMultiAngleScanManager, poseValidationUpdate result: PoseValidationResult, for pose: HeadScanningPose) {
        // Handle pose validation updates if needed
    }
}

// Note: SCReconstructionManagerDelegate conformance is now handled by ReconstructionService
// The refactored architecture uses service delegation instead of direct protocol conformance