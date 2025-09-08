# Troubleshooting Guide

This guide helps you resolve common issues when working with StandardCyborgCocoa.

## Quick Diagnostics Checklist

Before diving into specific issues, verify these basic requirements:

- [ ] **Hardware**: Device has TrueDepth camera (iPhone X+, iPad Pro 2018+)
- [ ] **Simulator**: Running on physical device (not simulator)
- [ ] **Permissions**: Camera access granted in iOS Settings
- [ ] **Dependencies**: All Swift packages resolved successfully
- [ ] **Build Target**: iOS 16.0+ deployment target
- [ ] **Xcode**: Version 15.0+ with Swift 6.0 support

## Common Issues

### Installation Problems

#### Issue: Swift Package Manager fails to resolve dependencies

**Symptoms:**
- Build errors about missing packages
- "Package resolution failed" messages
- Missing framework imports

**Solutions:**

1. **Clean SPM cache:**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   rm -rf .build
   ```

2. **Reset package dependencies:**
   - File → Packages → Reset Package Caches
   - File → Packages → Resolve Package Versions

3. **Check network connectivity:**
   ```bash
   # Test GitHub access
   git ls-remote https://github.com/ZipArchive/ZipArchive.git
   ```

4. **Manual dependency resolution:**
   ```bash
   xcodebuild -resolvePackageDependencies -project StandardCyborgSDK.xcodeproj
   ```

#### Issue: Git LFS files not downloading

**Symptoms:**
- ML model files are small pointer files
- Build errors about missing `.mlmodel` files
- Runtime crashes when loading models

**Solutions:**

1. **Install Git LFS:**
   ```bash
   brew install git-lfs
   git lfs install
   ```

2. **Pull LFS files:**
   ```bash
   git lfs pull
   ```

3. **Verify LFS files:**
   ```bash
   # Check file sizes - should be several MB each
   ls -la StandardCyborgFusion/Sources/StandardCyborgFusion/Models/
   ```

### Runtime Issues

#### Issue: "Hardware not supported" error

**Symptoms:**
- App crashes on launch
- Error: `SCError.hardwareNotSupported`
- Cannot create `SCReconstructionManager`

**Solutions:**

1. **Verify TrueDepth camera:**
   ```swift
   import AVFoundation
   
   func checkTrueDepthSupport() -> Bool {
       let discoverySession = AVCaptureDevice.DiscoverySession(
           deviceTypes: [.builtInTrueDepthCamera],
           mediaType: .video,
           position: .front
       )
       return !discoverySession.devices.isEmpty
   }
   ```

2. **Check device model programmatically:**
   ```swift
   var systemInfo = utsname()
   uname(&systemInfo)
   let modelCode = withUnsafePointer(to: &systemInfo.machine) {
       $0.withMemoryRebound(to: CChar.self, capacity: 1) {
           ptr in String.init(validatingUTF8: ptr)
       }
   }
   print("Device model: \(modelCode ?? "Unknown")")
   ```

3. **Supported devices list:**
   - iPhone X, XS, XS Max, XR, 11, 11 Pro, 11 Pro Max, 12 series, 13 series, 14 series, 15 series
   - iPad Pro 11" (1st, 2nd, 3rd, 4th gen), iPad Pro 12.9" (3rd, 4th, 5th, 6th gen)

#### Issue: Camera permission denied

**Symptoms:**
- Black camera preview
- Permission alert not appearing
- Error: `SCError.cameraAccessDenied`

**Solutions:**

1. **Add Info.plist entries:**
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>This app uses the camera for 3D scanning</string>
   ```

2. **Request permissions programmatically:**
   ```swift
   import AVFoundation
   
   func requestCameraPermission() {
       AVCaptureDevice.requestAccess(for: .video) { granted in
           DispatchQueue.main.async {
               if granted {
                   self.setupCamera()
               } else {
                   self.showPermissionDeniedAlert()
               }
           }
       }
   }
   ```

3. **Check current permission status:**
   ```swift
   let status = AVCaptureDevice.authorizationStatus(for: .video)
   switch status {
   case .authorized:
       // Permission granted
   case .denied, .restricted:
       // Permission denied - guide user to Settings
   case .notDetermined:
       // Request permission
   @unknown default:
       break
   }
   ```

#### Issue: Metal device creation fails

**Symptoms:**
- `MTLCreateSystemDefaultDevice()` returns `nil`
- Metal-related crashes
- Black rendering output

**Solutions:**

1. **Check Metal support:**
   ```swift
   guard let device = MTLCreateSystemDefaultDevice() else {
       print("Metal is not supported on this device")
       return
   }
   print("Metal device: \(device.name)")
   ```

2. **Alternative device selection:**
   ```swift
   let devices = MTLCopyAllDevices()
   for device in devices {
       print("Available Metal device: \(device.name)")
   }
   ```

3. **Verify on supported hardware only**

### Performance Issues

#### Issue: App overheating/thermal throttling

**Symptoms:**
- Device becomes very hot
- Automatic scanning termination
- Performance degradation over time
- Thermal state warnings

**Solutions:**

1. **Implement thermal monitoring:**
   ```swift
   NotificationCenter.default.addObserver(
       forName: ProcessInfo.thermalStateDidChangeNotification,
       object: nil,
       queue: .main
   ) { _ in
       switch ProcessInfo.processInfo.thermalState {
       case .critical:
           self.stopScanning()
           self.showThermalWarning()
       case .serious:
           self.reducePerformance()
       default:
           self.resumeNormalPerformance()
       }
   }
   ```

2. **Reduce processing load:**
   ```swift
   // Reduce thread count
   let conservativeThreadCount: Int32 = 1
   
   // Lower resolution depth processing
   cameraManager.configureCaptureSession(
       maxColorResolution: 1920,
       maxDepthResolution: 320, // Instead of 640
       maxFramerate: 24        // Instead of 30
   )
   ```

3. **Add cooling breaks:**
   ```swift
   // Automatic scanning duration limits
   let maxScanDuration: TimeInterval = 30
   ```

#### Issue: Memory pressure/crashes

**Symptoms:**
- App receives memory warnings
- Crashes with memory-related errors
- Performance degradation over time

**Solutions:**

1. **Monitor memory usage:**
   ```swift
   func logMemoryUsage() {
       var info = mach_task_basic_info()
       var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
       
       let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
           $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
               task_info(mach_task_self_,
                        task_flavor_t(MACH_TASK_BASIC_INFO),
                        $0,
                        &count)
           }
       }
       
       if kerr == KERN_SUCCESS {
           let memoryUsage = Double(info.resident_size) / 1024.0 / 1024.0
           print("Memory usage: \(memoryUsage) MB")
       }
   }
   ```

2. **Implement memory cleanup:**
   ```swift
   override func didReceiveMemoryWarning() {
       super.didReceiveMemoryWarning()
       
       // Stop scanning immediately
       stopScanning()
       
       // Clear caches
       reconstructionManager.reset()
       
       // Release temporary resources
       pointCloudCache.removeAll()
   }
   ```

3. **Optimize resource usage:**
   ```swift
   // Use autoreleasepool for batch operations
   autoreleasepool {
       for frame in frames {
           processFrame(frame)
       }
   }
   ```

### Scanning Quality Issues

#### Issue: Poor reconstruction quality

**Symptoms:**
- Noisy point clouds
- Missing geometry
- Incorrect colors
- Tracking failures

**Solutions:**

1. **Improve scanning conditions:**
   - **Lighting**: Ensure good, even lighting
   - **Distance**: Maintain 20-50cm from subject
   - **Movement**: Move slowly and steadily
   - **Coverage**: Scan from multiple angles

2. **Adjust reconstruction parameters:**
   ```swift
   reconstructionManager.includesColorBuffersInMetadata = true
   
   // Use higher quality depth processing
   let useFullResolution = true
   cameraManager.configureCaptureSession(
       maxDepthResolution: useFullResolution ? 640 : 320
   )
   ```

3. **Check tracking quality:**
   ```swift
   func reconstructionManager(_ manager: SCReconstructionManager,
                             didProcessWith metadata: SCAssimilatedFrameMetadata,
                             statistics: SCReconstructionManagerStatistics) {
       switch metadata.result {
       case .succeeded:
           // Good tracking
       case .poorTracking:
           print("Poor tracking - slow down movement")
       case .failed:
           print("Tracking failed - restart scanning")
       @unknown default:
           break
       }
   }
   ```

#### Issue: Scanning freezes or becomes unresponsive

**Symptoms:**
- UI becomes unresponsive
- Camera preview freezes
- No reconstruction progress

**Solutions:**

1. **Check thread configuration:**
   ```swift
   // Ensure proper queue separation
   let algorithmQueue = device.makeCommandQueue()!
   algorithmQueue.label = "algorithm"
   
   let visualizationQueue = device.makeCommandQueue()!
   visualizationQueue.label = "visualization"
   ```

2. **Monitor frame processing:**
   ```swift
   private var lastFrameTime = CACurrentMediaTime()
   
   func cameraDidOutput(...) {
       let currentTime = CACurrentMediaTime()
       let deltaTime = currentTime - lastFrameTime
       lastFrameTime = currentTime
       
       if deltaTime > 0.1 { // More than 100ms
           print("Frame processing too slow: \(deltaTime)s")
       }
   }
   ```

3. **Add timeout handling:**
   ```swift
   let timeout: TimeInterval = 5.0
   DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
       if self.isProcessingFrame {
           print("Frame processing timeout")
           self.resetReconstruction()
       }
   }
   ```

## Error Codes Reference

### Standard Cyborg Error Codes

| Error Code | Description | Solution |
|------------|-------------|----------|
| `hardwareNotSupported` | Device lacks TrueDepth camera | Use supported device |
| `cameraAccessDenied` | Camera permission not granted | Check permissions |
| `reconstructionFailed` | Internal reconstruction error | Restart scanning |
| `fileIOError` | File read/write failed | Check file permissions |
| `metalResourceError` | GPU resource allocation failed | Reduce memory usage |
| `thermalThrottling` | Device overheating | Allow cooling time |

### AVFoundation Error Codes

| Error | Description | Solution |
|-------|-------------|----------|
| `configurationFailed` | Camera setup failed | Check hardware support |
| `notAuthorized` | Missing camera permission | Request permission |
| `sessionRuntimeError` | Camera session error | Restart session |

## Debugging Tools

### Logging Configuration

Enable verbose logging for debugging:

```swift
// Add to AppDelegate
func application(_ application: UIApplication, 
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    #if DEBUG
    // Enable Metal debugging
    setenv("MTL_DEBUG_LAYER", "1", 1)
    setenv("MTL_DEBUG_LAYER_VALIDATE_UNRETAINED_RESOURCES", "4", 1)
    
    // Enable AVFoundation logging
    setenv("AVF_DEBUG", "1", 1)
    #endif
    
    return true
}
```

### Performance Profiling

Use Instruments to profile performance:

1. **Product → Profile** in Xcode
2. Select **Time Profiler** for CPU usage
3. Select **Metal System Trace** for GPU analysis
4. Select **Allocations** for memory analysis

### Crash Analysis

For crash analysis:

1. **Enable crash reporting:**
   ```swift
   // Add crash handler
   NSSetUncaughtExceptionHandler { exception in
       print("Uncaught exception: \(exception)")
   }
   ```

2. **Analyze crash logs:**
   - Xcode → Window → Devices and Simulators
   - Select device → View Device Logs

## Getting Help

### Community Resources

- **GitHub Issues**: Report bugs and request features
- **Discussions**: Ask questions and share experiences
- **Stack Overflow**: Tag questions with `standardcyborg`

### Reporting Bugs

When reporting issues, include:

1. **Device information:**
   ```swift
   print("Device: \(UIDevice.current.model)")
   print("iOS version: \(UIDevice.current.systemVersion)")
   print("App version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "Unknown")")
   ```

2. **Reproduction steps**
3. **Expected vs actual behavior**
4. **Console logs and crash reports**
5. **Sample code if applicable**

### Debug Information Collection

Create a debug report:

```swift
func collectDebugInfo() -> String {
    var info = "=== DEBUG INFO ===\n"
    
    // Device info
    info += "Device: \(UIDevice.current.model)\n"
    info += "iOS: \(UIDevice.current.systemVersion)\n"
    
    // Hardware capabilities
    info += "TrueDepth: \(checkTrueDepthSupport())\n"
    info += "Metal: \(MTLCreateSystemDefaultDevice()?.name ?? "Not available")\n"
    
    // Memory info
    let memInfo = getMemoryInfo()
    info += "Memory: \(memInfo.used)MB used / \(memInfo.total)MB total\n"
    
    // Thermal state
    info += "Thermal: \(ProcessInfo.processInfo.thermalState.rawValue)\n"
    
    return info
}
```

---

*Can't find a solution? Check the [GitHub Issues](https://github.com/StandardCyborg/StandardCyborgCocoa/issues) or create a new issue with detailed information about your problem.*