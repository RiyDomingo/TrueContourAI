//
//  DefaultScanningViewRenderer.swift
//  StandardCyborgUI
//
//  Copyright © 2019 Standard Cyborg. All rights reserved.
//

import AVFoundation
import Foundation
import Metal
import StandardCyborgFusion

protocol ScanningCommandBuffering: AnyObject {
    var label: String? { get set }
    func present(_ drawable: CAMetalDrawable)
    func commit()
    func addScheduledHandler(_ handler: @escaping (MTLCommandBuffer) -> Void)
    func addCompletedHandler(_ handler: @escaping (MTLCommandBuffer) -> Void)
}

protocol ScanningCommandQueueing: AnyObject {
    func makeCommandBuffer() -> ScanningCommandBuffering?
}

private final class MetalScanningCommandBuffer: ScanningCommandBuffering {
    private let base: MTLCommandBuffer
    
    init(base: MTLCommandBuffer) {
        self.base = base
    }
    
    var label: String? {
        get { base.label }
        set { base.label = newValue }
    }
    
    func present(_ drawable: CAMetalDrawable) {
        base.present(drawable)
    }
    
    func commit() {
        base.commit()
    }
    
    func addScheduledHandler(_ handler: @escaping (MTLCommandBuffer) -> Void) {
        base.addScheduledHandler(handler)
    }
    
    func addCompletedHandler(_ handler: @escaping (MTLCommandBuffer) -> Void) {
        base.addCompletedHandler(handler)
    }
    
    var metalCommandBuffer: MTLCommandBuffer { base }
}

private final class MetalScanningCommandQueue: ScanningCommandQueueing {
    private let base: MTLCommandQueue
    
    init(base: MTLCommandQueue) {
        self.base = base
    }
    
    func makeCommandBuffer() -> ScanningCommandBuffering? {
        guard let commandBuffer = base.makeCommandBuffer() else { return nil }
        return MetalScanningCommandBuffer(base: commandBuffer)
    }
}

public class DefaultScanningViewRenderer: ScanningViewRenderer {
    
    private let _commandQueue: ScanningCommandQueueing
    private let _drawTextureCommandEncoder: AspectFillTextureCommandEncoder?
    private let _pointCloudRenderer: PointCloudCommandEncoder?
    private let _inFlightLock = NSLock()
    private var _hasInFlightFrame = false
    
    public var flipsInputHorizontally: Bool = false
    
    required public convenience init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.init(device: device, commandQueue: MetalScanningCommandQueue(base: commandQueue), makeLibrary: {
            try device.makeDefaultLibrary(bundle: Bundle.scuiResourcesBundle)
        })
    }
    
    init(device: MTLDevice,
         commandQueue: ScanningCommandQueueing,
         makeLibrary: () throws -> MTLLibrary)
    {
        _commandQueue = commandQueue

        do {
            let library = try makeLibrary()
            _drawTextureCommandEncoder = AspectFillTextureCommandEncoder(device: device, library: library)
            _pointCloudRenderer = PointCloudCommandEncoder(device: device, library: library)
        } catch {
            _drawTextureCommandEncoder = nil
            _pointCloudRenderer = nil
            NSLog("DefaultScanningViewRenderer initialization failed: %@", error.localizedDescription)
        }
    }
    
    public func draw(colorBuffer: CVPixelBuffer?,
                     pointCloud: SCPointCloud?,
                     depthCameraCalibrationData: AVCameraCalibrationData,
                     viewMatrix: matrix_float4x4,
                     into metalLayer: CAMetalLayer)
    {
        autoreleasepool {
            guard _beginFrameIfPossible() else { return }
            guard let drawable = metalLayer.nextDrawable() else {
                _finishFrame()
                return
            }
            guard let commandBuffer = _commandQueue.makeCommandBuffer() else {
                _finishFrame()
                NSLog("DefaultScanningViewRenderer could not create command buffer")
                return
            }
            
            commandBuffer.label = "ScanningViewRenderer.commandBuffer"
            let outputTexture = drawable.texture
            
            if let colorBuffer = colorBuffer,
               let metalCommandBuffer = (commandBuffer as? MetalScanningCommandBuffer)?.metalCommandBuffer
            {
                _drawTextureCommandEncoder?.encodeCommands(onto: metalCommandBuffer,
                                                           colorBuffer: colorBuffer,
                                                           outputTexture: outputTexture)
            }
            
            if let pointCloud = pointCloud,
               let metalCommandBuffer = (commandBuffer as? MetalScanningCommandBuffer)?.metalCommandBuffer
            {
                _pointCloudRenderer?.encodeCommands(onto: metalCommandBuffer,
                                                    pointCloud: pointCloud,
                                                    depthCameraCalibrationData: depthCameraCalibrationData,
                                                    viewMatrix: viewMatrix,
                                                    pointSize: 16,
                                                    flipsInputHorizontally: flipsInputHorizontally,
                                                    outputTexture: outputTexture)
            }
            
            commandBuffer.addScheduledHandler { [weak self] _ in
                self?._finishFrame()
            }
            commandBuffer.addCompletedHandler { [weak self] _ in
                self?._finishFrame()
            }
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    private func _beginFrameIfPossible() -> Bool
    {
        _inFlightLock.lock()
        defer { _inFlightLock.unlock() }
        
        if _hasInFlightFrame {
            return false
        }
        
        _hasInFlightFrame = true
        return true
    }
    
    private func _finishFrame()
    {
        _inFlightLock.lock()
        _hasInFlightFrame = false
        _inFlightLock.unlock()
    }
}
