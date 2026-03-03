//
//  ScrumCapScanningViewController.swift
//  CyborgRugby
//

import UIKit
import AVFoundation
import StandardCyborgFusion

protocol ScrumCapScanningViewControllerDelegate: AnyObject {
    func scrumCapScanningViewController(_ vc: ScrumCapScanningViewController, didCompleteScan result: CompleteScanResult)
    func scrumCapScanningViewControllerDidCancel(_ vc: ScrumCapScanningViewController)
}

final class ScrumCapScanningViewController: UIViewController {
    
    weak var delegate: ScrumCapScanningViewControllerDelegate?
    
    // Core
    private let cameraManager = CameraManager()
    private let reconstructionService: ReconstructionService
    
    // UI
    private let previewView = UIView()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    
    private let cancelButton = UIButton(type: .system)
    private let finishButton = UIButton(type: .system)
    
    // State
    private var isScanning = false
    private var scanStartTime: CFTimeInterval = 0
    private let targetScanDuration: CFTimeInterval = 10.0 // tweak as needed
    
    // MARK: - Init
    
    init?() {
        guard let recon = ReconstructionService() else { return nil }
        self.reconstructionService = recon
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    // MARK: - VC
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        cameraManager.delegate = self
        reconstructionService.delegate = self
        
        buildUI()
        wirePreview()
        
        statusLabel.text = "Ready"
        progressView.progress = 0
        
        // Start immediately (or you can require a tap)
        startContinuousScan()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewView.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraManager.stopSession()
    }
    
    // MARK: - UI
    
    private func buildUI() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        statusLabel.numberOfLines = 2
        view.addSubview(statusLabel)
        
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        view.addSubview(cancelButton)
        
        finishButton.translatesAutoresizingMaskIntoConstraints = false
        finishButton.setTitle("Finish", for: .normal)
        finishButton.addTarget(self, action: #selector(didTapFinish), for: .touchUpInside)
        view.addSubview(finishButton)
        
        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.leftAnchor.constraint(equalTo: view.leftAnchor),
            previewView.rightAnchor.constraint(equalTo: view.rightAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            statusLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
            statusLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),
            
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            progressView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
            progressView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),
            
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            cancelButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
            
            finishButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            finishButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),
        ])
    }
    
    private func wirePreview() {
        let layer = cameraManager.makePreviewLayer(videoGravity: .resizeAspectFill)
        previewView.layer.insertSublayer(layer, at: 0)
        self.previewLayer = layer
    }
    
    // MARK: - Scan Control
    
    private func startContinuousScan() {
        isScanning = true
        scanStartTime = CACurrentMediaTime()
        
        statusLabel.text = "Scanning… move slowly around the head."
        progressView.progress = 0
        
        reconstructionService.startNewSession()
        cameraManager.startSession()
    }
    
    private func updateProgress() {
        guard isScanning else { return }
        let elapsed = CACurrentMediaTime() - scanStartTime
        let progress = min(max(Float(elapsed / targetScanDuration), 0), 1)
        progressView.setProgress(progress, animated: true)
        
        if elapsed >= targetScanDuration {
            finishScan()
        }
    }
    
    private func finishScan() {
        guard isScanning else { return }
        isScanning = false
        
        statusLabel.text = "Finalizing…"
        cameraManager.stopSession()
        reconstructionService.finalize()
    }
    
    private func fail(_ message: String) {
        isScanning = false
        cameraManager.stopSession()
        reconstructionService.reset()
        
        statusLabel.text = "Error: \(message)"
        
        // Optional: auto-dismiss after showing message
    }
    
    // MARK: - Actions
    
    @objc private func didTapCancel() {
        isScanning = false
        cameraManager.stopSession()
        reconstructionService.reset()
        delegate?.scrumCapScanningViewControllerDidCancel(self)
    }
    
    @objc private func didTapFinish() {
        finishScan()
    }
}

// MARK: - CameraManagerDelegate

extension ScrumCapScanningViewController: CameraManagerDelegate {
    func cameraManager(
        _ manager: CameraManager,
        didOutputColorBuffer colorBuffer: CVPixelBuffer,
        depthBuffer: CVPixelBuffer,
        calibrationData: AVCameraCalibrationData,
        timestamp: CMTime
    ) {
        guard isScanning else { return }
        
        reconstructionService.processFrame(depthBuffer: depthBuffer, colorBuffer: colorBuffer, calibrationData: calibrationData)
        updateProgress()
    }
    
    func cameraManager(_ manager: CameraManager, didFail error: Error) {
        fail(error.localizedDescription)
    }
}

// MARK: - ReconstructionServiceDelegate

extension ScrumCapScanningViewController: ReconstructionServiceDelegate {
    func reconstructionService(_ service: ReconstructionService, didUpdatePointCount pointCount: Int) {
        // If you later expose a real count, you can show it here.
    }
    
    func reconstructionService(_ service: ReconstructionService, didFinish pointCloud: SCPointCloud) {
        statusLabel.text = "Processing results…"
        
        // Build a CompleteScanResult compatible with existing app model
        var scans: [HeadScanningPose: ScanResult] = [:]
        
        // Only one pose is actually captured in the new flow:
        let capturedPose: HeadScanningPose = .frontFacing
        
        scans[capturedPose] = ScanResult(
            pose: capturedPose,
            status: .completed,
            pointCloud: pointCloud,
            quality: 0.85,
            timestamp: Date()
        )
        
        // Mark the rest as skipped (no point cloud)
        for pose in HeadScanningPose.allCases where pose != capturedPose {
            scans[pose] = ScanResult(
                pose: pose,
                status: .skipped,
                pointCloud: nil,
                quality: nil,
                timestamp: Date()
            )
        }
        
        // Derive measurements using existing placeholder service (won’t crash)
        let measurementService = MeasurementGenerationService()
        let measurements = measurementService.generateMeasurements(from: scans)
        
        // Compute overall quality using only completed scans with quality
        let completedQualities = scans.values.compactMap { $0.status == .completed ? $0.quality : nil }
        let overallQuality: Double = completedQualities.isEmpty ? 0.0 : (completedQualities.reduce(0, +) / Double(completedQualities.count))
        
        let result = CompleteScanResult(
            individualScans: scans,
            overallQuality: overallQuality,
            measurements: measurements,
            timestamp: Date()
        )
        
        delegate?.scrumCapScanningViewController(self, didCompleteScan: result)
    }
    
    func reconstructionService(_ service: ReconstructionService, didFail error: Error) {
        fail(error.localizedDescription)
    }
}
