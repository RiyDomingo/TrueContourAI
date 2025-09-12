//
//  CameraCaptureService.swift
//  CyborgRugby
//
//  Dedicated camera capture and frame processing service
//

import UIKit
import AVFoundation
import Vision
import OSLog

@MainActor
protocol CameraCaptureServiceDelegate: AnyObject {
    func cameraService(_ service: CameraCaptureService, didCaptureFrame pixelBuffer: CVPixelBuffer, with pose: HeadScanningPose)
    func cameraService(_ service: CameraCaptureService, didFailWithError error: Error)
    func cameraServiceDidStartCapture(_ service: CameraCaptureService)
    func cameraServiceDidStopCapture(_ service: CameraCaptureService)
}

@MainActor
class CameraCaptureService: NSObject {
    
    // MARK: - Properties
    
    weak var delegate: CameraCaptureServiceDelegate?
    
    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentDevice: AVCaptureDevice?
    private let videoQueue = DispatchQueue(label: "CyborgRugby.camera", qos: .userInitiated)
    
    private var isCapturing = false
    private var currentPose: HeadScanningPose = .frontFacing
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    deinit {
        // Cannot access MainActor properties from deinit in Swift 6
        // Capture session will be automatically cleaned up by ARC
    }
    
    // MARK: - Public Methods
    
    func startCapture() {
        guard !isCapturing else { return }
        
        Task { @MainActor in
            self.captureSession.startRunning()
            self.isCapturing = true
            self.delegate?.cameraServiceDidStartCapture(self)
            AppLog.camera.info("Camera capture started")
        }
    }
    
    func stopCapture() {
        guard isCapturing else { return }
        
        Task { @MainActor in
            self.captureSession.stopRunning()
            self.isCapturing = false
            self.delegate?.cameraServiceDidStopCapture(self)
            AppLog.camera.info("Camera capture stopped")
        }
    }
    
    func updateCurrentPose(_ pose: HeadScanningPose) {
        currentPose = pose
    }
    
    var isCaptureRunning: Bool {
        return captureSession.isRunning
    }
    
    // MARK: - Private Methods
    
    private func setupCaptureSession() {
        captureSession.sessionPreset = .vga640x480
        
        // Configure TrueDepth camera
        guard let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) else {
            AppLog.camera.error("TrueDepth camera not available")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                currentDevice = device
            }
            
            // Configure video output
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
                self.videoOutput = videoOutput
            }
            
            // Configure device settings
            try device.lockForConfiguration()
            
            // Set frame rate for optimal scanning
            if !device.activeFormat.videoSupportedFrameRateRanges.isEmpty {
                device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 30) // 30 FPS
                device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 30)
            }
            
            // Enable auto-focus if available
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // Enable auto-exposure if available
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
            
            AppLog.camera.info("Camera session configured successfully")
            
        } catch {
            AppLog.camera.error("Failed to setup camera: \(error.localizedDescription)")
            Task { @MainActor in
                self.delegate?.cameraService(self, didFailWithError: error)
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Mirror the front-facing camera output
        connection.isVideoMirrored = true
        
        Task { @MainActor in
            self.delegate?.cameraService(self, didCaptureFrame: pixelBuffer, with: self.currentPose)
        }
    }
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        AppLog.camera.debug("Dropped camera frame")
    }
}