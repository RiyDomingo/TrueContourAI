//
//  ReconstructionService.swift
//  CyborgRugby
//

import Foundation
import Metal
import AVFoundation
import StandardCyborgFusion

protocol ReconstructionServiceDelegate: AnyObject {
    func reconstructionService(_ service: ReconstructionService, didUpdatePointCount pointCount: Int)
    func reconstructionService(_ service: ReconstructionService, didFinish pointCloud: SCPointCloud)
    func reconstructionService(_ service: ReconstructionService, didFail error: Error)
}

final class ReconstructionService {
    
    weak var delegate: ReconstructionServiceDelegate?
    
    private let queue = DispatchQueue(label: "com.standardcyborg.cyborgrugby.reconstruction", qos: .userInitiated)
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    private var manager: SCReconstructionManager?
    private var hasReceivedAnyFrame = false
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.commandQueue = commandQueue
    }
    
    func startNewSession(maxThreadCount: Int = 2) {
        queue.async { [weak self] in
            guard let self else { return }
            self.hasReceivedAnyFrame = false
            self.manager = SCReconstructionManager(device: self.device, commandQueue: self.commandQueue, maxThreadCount: Int32(maxThreadCount))
        }
    }
    
    func processFrame(depthBuffer: CVPixelBuffer, colorBuffer: CVPixelBuffer, calibrationData: AVCameraCalibrationData) {
        queue.async { [weak self] in
            guard let self else { return }
            guard let manager = self.manager else { return }
            
            self.hasReceivedAnyFrame = true
            manager.accumulate(depthBuffer: depthBuffer, colorBuffer: colorBuffer, calibrationData: calibrationData)
            
            // If you have a fast way to query count, report it; otherwise keep it simple.
            // StandardCyborgFusion doesn't always expose a cheap "current point count" mid-stream.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.reconstructionService(self, didUpdatePointCount: 0)
            }
        }
    }
    
    func finalize() {
        queue.async { [weak self] in
            guard let self else { return }
            guard let manager = self.manager else { return }
            
            guard self.hasReceivedAnyFrame else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.delegate?.reconstructionService(
                        self,
                        didFail: NSError(domain: "ReconstructionService", code: 10, userInfo: [NSLocalizedDescriptionKey: "No frames were captured."])
                    )
                }
                return
            }
            
            let pointCloud = manager.buildPointCloud()
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.reconstructionService(self, didFinish: pointCloud)
            }
        }
    }
    
    func reset() {
        queue.async { [weak self] in
            guard let self else { return }
            self.manager = nil
            self.hasReceivedAnyFrame = false
        }
    }
}
