//
//  CameraManager.swift
//  CyborgRugby
//
//  Simple camera manager for TrueDepth camera access
//

import Foundation
import AVFoundation
import Vision

// MARK: - CameraManagerDelegate

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer)
    func cameraManager(_ manager: CameraManager, didFailWithError error: Error)
    // New: synchronized TrueDepth outputs for reconstruction
    func cameraManager(_ manager: CameraManager,
                       didOutput colorBuffer: CVPixelBuffer,
                       depthBuffer: CVPixelBuffer,
                       calibrationData: AVCameraCalibrationData)
}

class CameraManager: NSObject {
    weak var delegate: CameraManagerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var captureDevice: AVCaptureDevice?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var depthOutput: AVCaptureDepthDataOutput?
    private var synchronizer: AVCaptureDataOutputSynchronizer?
    private let sessionQueue = DispatchQueue(label: "CameraManager.sessionQueue")
    
    var isRunning: Bool {
        return captureSession?.isRunning ?? false
    }
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        guard let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) else {
            print("❌ TrueDepth camera not available")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            let session = AVCaptureSession()
            session.beginConfiguration()
            if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            let depthOutput = AVCaptureDepthDataOutput()
            depthOutput.isFilteringEnabled = true
            depthOutput.alwaysDiscardsLateDepthData = true
            
            if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
            if session.canAddOutput(depthOutput) { session.addOutput(depthOutput) }
            
            // Ensure connections are from the TrueDepth camera
            if let videoConnection = videoOutput.connection(with: .video),
               videoConnection.isCameraIntrinsicMatrixDeliverySupported {
                videoConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
            
            // Try to select a format that supports depth
            try device.lockForConfiguration()
            if let depthFormat = device.activeFormat.supportedDepthDataFormats.last {
                device.activeDepthDataFormat = depthFormat
            }
            device.unlockForConfiguration()
            
            // Synchronize depth and video
            let synchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoOutput, depthOutput])
            synchronizer.setDelegate(self, queue: sessionQueue)
            
            session.commitConfiguration()
            
            captureSession = session
            captureDevice = device
            self.videoOutput = videoOutput
            self.depthOutput = depthOutput
            self.synchronizer = synchronizer
            
        } catch {
            print("❌ Camera setup failed: \(error)")
            delegate?.cameraManager(self, didFailWithError: error)
        }
    }
    
    func startCapture() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopCapture() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
}

// MARK: - AVCaptureDataOutputSynchronizerDelegate
extension CameraManager: AVCaptureDataOutputSynchronizerDelegate {
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer,
                                didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        guard
            let videoOutput = self.videoOutput,
            let depthOutput = self.depthOutput,
            let syncedVideo = synchronizedDataCollection.synchronizedData(for: videoOutput) as? AVCaptureSynchronizedSampleBufferData,
            let syncedDepth = synchronizedDataCollection.synchronizedData(for: depthOutput) as? AVCaptureSynchronizedDepthData,
            !syncedVideo.sampleBufferWasDropped,
            !syncedDepth.depthDataWasDropped,
            let colorBuffer = CMSampleBufferGetImageBuffer(syncedVideo.sampleBuffer)
        else { return }
        
        let depthData = syncedDepth.depthData
        let depthBuffer = depthData.depthDataMap
        if let calibration = depthData.cameraCalibrationData {
            // Emit combined data for reconstruction
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.cameraManager(self,
                                             didOutput: colorBuffer,
                                             depthBuffer: depthBuffer,
                                             calibrationData: calibration)
                // Also emit color-only for existing consumers (pose validator)
                self.delegate?.cameraManager(self, didOutput: colorBuffer)
            }
        }
    }
}

// MARK: - Backward compatibility (video-only delegate)
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // No-op when using synchronizer; keep to satisfy protocol if ever used standalone
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.cameraManager(self, didOutput: pixelBuffer)
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("⚠️ Camera frame dropped")
    }
}
