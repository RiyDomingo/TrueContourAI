//
//  ReconstructionService.swift
//  CyborgRugby
//
//  Manages 3D reconstruction and point cloud processing
//

import Foundation
import StandardCyborgFusion
import Metal
import AVFoundation
import OSLog

@MainActor
protocol ReconstructionServiceDelegate: AnyObject {
    func reconstructionService(_ service: ReconstructionService, didProcessFrame metadata: SCAssimilatedFrameMetadata, statistics: SCReconstructionManagerStatistics)
    func reconstructionService(_ service: ReconstructionService, didCompleteReconstruction pointCloud: SCPointCloud?, mesh: SCMesh?)
    func reconstructionService(_ service: ReconstructionService, didFailWithError error: Error)
    func reconstructionService(_ service: ReconstructionService, didUpdateProgress progress: Float)
}

@MainActor
class ReconstructionService: NSObject {
    
    // MARK: - Properties
    
    weak var delegate: ReconstructionServiceDelegate?
    
    private let metalDevice: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var reconstructionManager: SCReconstructionManager?
    
    private(set) var isRecording = false
    private(set) var currentProgress: Float = 0.0
    
    // Configuration
    private let maxThreadCount: Int32
    
    // MARK: - Initialization
    
    init(metalDevice: MTLDevice, commandQueue: MTLCommandQueue? = nil) {
        self.metalDevice = metalDevice
        self.commandQueue = commandQueue ?? metalDevice.makeCommandQueue()!
        self.maxThreadCount = Int32(ProcessInfo.processInfo.activeProcessorCount)
        
        super.init()
        setupReconstructionManager()
    }
    
    deinit {
        // Clean up reconstruction manager
        reconstructionManager?.delegate = nil
        reconstructionManager = nil
    }
    
    // MARK: - Public Methods
    
    func startRecording() {
        guard !isRecording else {
            AppLog.scan.warning("Attempted to start recording while already recording")
            return
        }
        
        guard reconstructionManager != nil else {
            AppLog.scan.error("No reconstruction manager available")
            return
        }
        
        isRecording = true
        currentProgress = 0.0
        
        AppLog.scan.info("Started 3D reconstruction recording")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
        AppLog.scan.info("Stopped 3D reconstruction recording")
    }
    
    func resetReconstruction() {
        stopRecording()
        setupReconstructionManager()
        AppLog.scan.info("Reset reconstruction manager")
    }
    
    func finalizeReconstruction() {
        guard let manager = reconstructionManager else {
            let error = ReconstructionError.noReconstructionManager
            delegate?.reconstructionService(self, didFailWithError: error)
            return
        }
        
        stopRecording()
        
        // Finalize reconstruction asynchronously
        Task { [weak self] in
            guard let self = self else { return }
            
            // Use async approach for finalization
            await withCheckedContinuation { continuation in
                manager.finalize {
                    continuation.resume()
                }
            }
            
            // Build point cloud after finalization
            let pointCloud = manager.buildPointCloud()
            
            await MainActor.run {
                self.delegate?.reconstructionService(self, didCompleteReconstruction: pointCloud, mesh: nil)
            }
        }
    }
    
    func processDepthFrame(_ depthData: AVDepthData, colorBuffer: CVPixelBuffer? = nil) {
        guard isRecording, let manager = reconstructionManager else { return }
        
        // Extract depth buffer and calibration data from AVDepthData
        let depthBuffer = depthData.depthDataMap
        let calibrationData = depthData.cameraCalibrationData
        
        // Accumulate the depth and color data into the reconstruction manager
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            // Process frame using StandardCyborgFusion API
            guard let calibrationData = calibrationData else { return }
            manager.accumulate(depthBuffer: depthBuffer, 
                             colorBuffer: colorBuffer ?? depthBuffer, 
                             calibrationData: calibrationData)
            
            await MainActor.run {
                // Update progress based on frame processing
                self.currentProgress = min(self.currentProgress + 0.01, 1.0)
                self.delegate?.reconstructionService(self, didUpdateProgress: self.currentProgress)
            }
        }
    }
    
    func getReconstructionStats() -> ReconstructionStats {
        return ReconstructionStats(
            framesProcessed: Int(currentProgress * 1000), // Approximation
            currentProgress: currentProgress,
            isRecording: isRecording,
            estimatedPointCount: Int(currentProgress * 50000) // Approximation
        )
    }
    
    // MARK: - Private Methods
    
    private func setupReconstructionManager() {
        reconstructionManager = SCReconstructionManager(
            device: metalDevice,
            commandQueue: commandQueue,
            maxThreadCount: self.maxThreadCount
        )
        
        reconstructionManager?.delegate = self
        AppLog.scan.info("Initialized reconstruction manager with \(self.maxThreadCount) threads")
    }
}

// MARK: - SCReconstructionManagerDelegate

extension ReconstructionService: SCReconstructionManagerDelegate {
    
    nonisolated func reconstructionManager(_ manager: SCReconstructionManager, didProcessWith metadata: SCAssimilatedFrameMetadata, statistics: SCReconstructionManagerStatistics) {
        Task { @MainActor in
            // Forward metadata and statistics to delegate
            self.delegate?.reconstructionService(self, didProcessFrame: metadata, statistics: statistics)
            
            // Update progress based on statistics
            let progress = Float(statistics.succeededCount) / max(Float(statistics.succeededCount + statistics.lostTrackingCount), 1.0)
            self.currentProgress = min(progress, 1.0)
            self.delegate?.reconstructionService(self, didUpdateProgress: self.currentProgress)
        }
    }
    
    nonisolated func reconstructionManager(_ manager: SCReconstructionManager, didEncounterAPIError error: Error) {
        Task { @MainActor in
            self.delegate?.reconstructionService(self, didFailWithError: error)
        }
    }
}

// MARK: - Supporting Types

struct ReconstructionStats {
    let framesProcessed: Int
    let currentProgress: Float
    let isRecording: Bool
    let estimatedPointCount: Int
    
    var progressDescription: String {
        return String(format: "%.1f%% complete", currentProgress * 100)
    }
}

enum ReconstructionError: LocalizedError {
    case noReconstructionManager
    case reconstructionFailed(String)
    case invalidDepthData
    
    var errorDescription: String? {
        switch self {
        case .noReconstructionManager:
            return "Reconstruction manager not available"
        case .reconstructionFailed(let message):
            return "Reconstruction failed: \(message)"
        case .invalidDepthData:
            return "Invalid depth data provided"
        }
    }
}