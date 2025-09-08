# Getting Started with StandardCyborgCocoa

This guide will help you integrate StandardCyborgCocoa into your iOS project and perform your first 3D scan.

## Prerequisites

### Hardware Requirements
- iOS device with TrueDepth camera:
  - iPhone X or later
  - iPad Pro (2018) or later
- **Note**: The SDK will not work in the iOS Simulator

### Software Requirements
- Xcode 15.0 or later
- iOS 16.0+ deployment target
- Swift 6.0 support

## Installation

StandardCyborgCocoa uses Swift Package Manager for dependency management.

### Method 1: Swift Package Manager (Recommended)

1. In Xcode, go to **File → Add Package Dependencies**
2. Enter the repository URL:
   ```
   https://github.com/StandardCyborg/StandardCyborgCocoa.git
   ```
3. Select the packages you need:
   - **StandardCyborgFusion** (Required) - Core 3D reconstruction
   - **StandardCyborgUI** (Optional) - Pre-built UI components

### Method 2: Local Development

1. Clone the repository:
   ```bash
   git clone https://github.com/StandardCyborg/StandardCyborgCocoa.git
   ```

2. Add local package dependencies in Xcode:
   - **File → Add Package Dependencies**
   - Choose **Add Local...**
   - Select the `StandardCyborgFusion` and/or `StandardCyborgUI` directories

## Basic Integration

### 1. Import the Framework

```swift
import StandardCyborgFusion
import StandardCyborgUI // Optional, for UI components
```

### 2. Request Camera Permissions

Add camera usage description to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app uses the camera for 3D scanning</string>
```

### 3. Basic Scanning Implementation

Here's a minimal example of setting up 3D scanning:

```swift
import UIKit
import StandardCyborgFusion
import AVFoundation
import Metal

class ScanningViewController: UIViewController {
    
    // MARK: - Properties
    private let metalDevice = MTLCreateSystemDefaultDevice()!
    private lazy var commandQueue = metalDevice.makeCommandQueue()!
    private lazy var reconstructionManager = SCReconstructionManager(
        device: metalDevice,
        commandQueue: commandQueue,
        maxThreadCount: 2
    )
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScanning()
    }
    
    private func setupScanning() {
        // Configure reconstruction manager
        reconstructionManager.delegate = self
        reconstructionManager.includesColorBuffersInMetadata = true
    }
    
    // Start scanning
    private func startScanning() {
        // Implementation depends on your camera setup
        // See TrueDepthFusion example for complete implementation
    }
}

// MARK: - SCReconstructionManagerDelegate
extension ScanningViewController: SCReconstructionManagerDelegate {
    
    func reconstructionManager(_ manager: SCReconstructionManager,
                              didProcessWith metadata: SCAssimilatedFrameMetadata,
                              statistics: SCReconstructionManagerStatistics) {
        // Handle reconstruction progress
        print("Frames processed: \\(statistics.succeededCount)")
    }
    
    func reconstructionManager(_ manager: SCReconstructionManager, 
                              didEncounterAPIError error: Error) {
        print("Reconstruction error: \\(error)")
    }
}
```

## Sample Projects

The repository includes several example projects to help you get started:

### 1. StandardCyborgExample (Simple)
**Location**: `StandardCyborgExample (Repaired)/`

A minimal example showing basic integration:
```bash
# Open the example project
cd "StandardCyborgExample (Repaired)"
open StandardCyborgExample.xcodeproj
```

**Key Features**:
- Basic scanning setup
- Simple UI implementation
- Point cloud visualization

### 2. TrueDepthFusion (Advanced)
**Location**: `TrueDepthFusion/`

A comprehensive scanning application with advanced features:
```bash
# Run the full-featured app
cd TrueDepthFusion
# Open StandardCyborgSDK.xcodeproj and select TrueDepthFusion target
```

**Key Features**:
- Full camera management
- Real-time visualization
- Scan saving/loading
- Thermal monitoring
- Audio feedback
- Settings configuration

## Key Classes Overview

### Core Classes

| Class | Purpose |
|-------|---------|
| `SCReconstructionManager` | Main reconstruction engine |
| `SCPointCloud` | Point cloud data structure |
| `SCMesh` | Mesh data structure |
| `CameraManager` | TrueDepth camera handling |

### UI Components (StandardCyborgUI)

| Component | Purpose |
|-----------|---------|
| `DefaultScanningViewRenderer` | Renders scanning preview |
| `ShutterButton` | Camera shutter button UI |
| `AspectFillTextureCommandEncoder` | Texture rendering |

## Basic Workflow

1. **Initialize Metal resources**
   ```swift
   let device = MTLCreateSystemDefaultDevice()!
   let commandQueue = device.makeCommandQueue()!
   ```

2. **Create reconstruction manager**
   ```swift
   let reconstructionManager = SCReconstructionManager(
       device: device,
       commandQueue: commandQueue,
       maxThreadCount: 2
   )
   ```

3. **Setup camera and start session**
   ```swift
   let cameraManager = CameraManager()
   cameraManager.delegate = self
   cameraManager.configureCaptureSession()
   cameraManager.startSession()
   ```

4. **Process frames during scanning**
   ```swift
   func cameraDidOutput(colorBuffer: CVPixelBuffer, 
                       depthBuffer: CVPixelBuffer,
                       calibrationData: AVCameraCalibrationData) {
       reconstructionManager.accumulate(
           depthBuffer: depthBuffer,
           colorBuffer: colorBuffer,
           calibrationData: calibrationData
       )
   }
   ```

5. **Generate final result**
   ```swift
   reconstructionManager.finalize { [weak self] in
       let pointCloud = self?.reconstructionManager.buildPointCloud()
       // Use the point cloud...
   }
   ```

## Next Steps

- Explore the [Architecture](Architecture) documentation to understand the framework structure
- Review the [API Reference](API-Reference) for detailed class documentation
- Check out the [Development Guide](Development-Guide) for advanced topics
- See [Troubleshooting](Troubleshooting) if you encounter issues

## Common First Steps Checklist

- [ ] Hardware: Confirmed device has TrueDepth camera
- [ ] Permissions: Added camera usage description to Info.plist
- [ ] Dependencies: Successfully added StandardCyborgFusion via SPM
- [ ] Build: Project builds without errors
- [ ] Test: Ran on physical device (not simulator)

---

*Need help? Check the [Troubleshooting](Troubleshooting) guide or review the sample projects.*