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

public class DefaultScanningViewRenderer: ScanningViewRenderer {
    
    private let _commandQueue: MTLCommandQueue
    private let _drawTextureCommandEncoder: AspectFillTextureCommandEncoder?
    private let _pointCloudRenderer: PointCloudCommandEncoder?
    
    public var flipsInputHorizontally: Bool = false
    
    required public init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        _commandQueue = commandQueue

        do {
            let library = try device.makeDefaultLibrary(bundle: Bundle.scuiResourcesBundle)
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
            guard let drawable = metalLayer.nextDrawable() else { return }
            guard let commandBuffer = _commandQueue.makeCommandBuffer() else {
                NSLog("DefaultScanningViewRenderer could not create command buffer")
                return
            }
            commandBuffer.label = "ScanningViewRenderer.commandBuffer"
            let outputTexture = drawable.texture
            
            if let colorBuffer = colorBuffer {
                _drawTextureCommandEncoder?.encodeCommands(onto: commandBuffer,
                                                           colorBuffer: colorBuffer,
                                                           outputTexture: outputTexture)
            }
            
            if let pointCloud = pointCloud {
                _pointCloudRenderer?.encodeCommands(onto: commandBuffer,
                                                    pointCloud: pointCloud,
                                                    depthCameraCalibrationData: depthCameraCalibrationData,
                                                    viewMatrix: viewMatrix,
                                                    pointSize: 16,
                                                    flipsInputHorizontally: flipsInputHorizontally,
                                                    outputTexture: outputTexture)
            }
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
            commandBuffer.waitUntilScheduled()
        }
    }
}
