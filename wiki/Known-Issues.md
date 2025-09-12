# Known Issues

This page tracks known limitations and issues in StandardCyborgCocoa.

## Current Known Issues

### Critical Issues

#### Memory Pressure on Older Devices
**Affected Versions:** All versions  
**Devices:** iPhone X, iPad Pro (2018)  
**Status:** Open  

**Description:**  
Extended scanning sessions (>2 minutes) on devices with 3GB RAM or less may experience memory pressure leading to app termination.

**Workarounds:**
- Limit continuous scanning to 60-90 seconds
- Implement memory monitoring and automatic scan termination
- Reduce depth resolution to 320x240 on affected devices

```swift
// Recommended mitigation
let maxScanDuration: TimeInterval = UIDevice.current.userInterfaceIdiom == .pad ? 120 : 60
```

#### Thermal Throttling on iPhone Models
**Affected Versions:** All versions  
**Devices:** iPhone X, XS, 11, 12 (non-Pro models)  
**Status:** Open  

**Description:**  
iPhone models with smaller thermal mass reach critical thermal state faster during intensive scanning, causing automatic termination.

**Workarounds:**
- Reduce maximum thread count to 1 on non-Pro iPhones
- Implement thermal state monitoring with progressive performance reduction
- Add forced cooling breaks every 30 seconds

### Performance Issues

#### Frame Drop During Color Buffer Processing
**Affected Versions:** All versions  
**Devices:** All  
**Status:** Under Investigation  

**Description:**  
Occasional frame drops when processing color buffers for texture mapping, particularly with high-resolution color streams.

**Impact:** Reduced reconstruction quality and potential tracking failures  
**Workarounds:**
- Reduce color resolution to 1920x1440
- Skip color buffer processing every 5th frame
- Use separate command queue for texture operations

#### Metal Command Buffer Timeout
**Affected Versions:** All versions  
**Devices:** Primarily iPad Pro models  
**Status:** Open  

**Description:**  
Long-running Metal operations occasionally timeout, causing reconstruction to halt.

**Symptoms:**
- Console message: "Metal command buffer timeout"
- Reconstruction stops progressing
- UI remains responsive

**Workarounds:**
```swift
// Reduce Metal operation complexity
let conservativeSettings = SCReconstructionManagerParameters()
conservativeSettings.maxPointsPerSurfel = 1000 // Default: 2000
```

### Compatibility Issues

#### iOS 17 Camera Session Interruptions
**Affected Versions:** All versions  
**iOS Versions:** iOS 17.0-17.2  
**Status:** Fixed in iOS 17.3  

**Description:**  
iOS 17.0-17.2 introduced camera session interruption issues affecting TrueDepth camera stability.

**Workarounds:**
- Update to iOS 17.3 or later
- Implement robust camera session recovery
- Add automatic session restart on interruption

#### Xcode 15 Swift Package Manager Issues
**Affected Versions:** All versions  
**Xcode Versions:** Xcode 15.0-15.1  
**Status:** Fixed in Xcode 15.2  

**Description:**  
SPM dependency resolution fails intermittently with C++ packages in Xcode 15.0-15.1.

**Workarounds:**
- Update to Xcode 15.2 or later
- Use manual dependency management if needed
- Clear SPM cache frequently during development

#### ZipArchive Dependency Integration Issues
**Affected Versions:** All versions  
**Status:** Workaround Available  

**Description:**  
The ZipArchive dependency may not be properly recognized by Xcode in some development environments, showing as "README" instead of "Package" in the Package Dependencies panel. This can cause import errors in Objective-C++ files that use ZipArchive functionality.

**Note:** ZipArchive is now a required dependency for StandardCyborgFusion. Applications that do not properly integrate ZipArchive will fail to build or run correctly.

**Symptoms:**
- 'SSZipArchive/SSZipArchive.h' file not found errors
- ZipArchive showing as "README" in Xcode Package Dependencies
- Build failures in files that use ZipArchive functionality

**Workarounds:**
1. **Update Package.swift configuration:**
   ```swift
   // In Package.swift, ensure ZipArchive is properly configured:
   .package(name: "ZipArchive", url: "https://github.com/ZipArchive/ZipArchive.git", from: "2.4.0")
   ```

2. **Use direct imports in source files:**
   ```objc
   // In Objective-C++ files, use direct import:
   #import <SSZipArchive/SSZipArchive.h>
   
   // Use ZipArchive functionality directly
   [SSZipArchive createZipFileAtPath:objZipPath withContentsOfDirectory:zipDirectory];
   ```

3. **Reset package caches:**
   - File → Packages → Reset Package Caches
   - Product → Clean Build Folder
   - Restart Xcode

### File I/O Issues

#### Large PLY File Export Timeout
**Affected Versions:** All versions  
**Point Counts:** >500K points  
**Status:** Open  

**Description:**  
Exporting very large point clouds (>500K points) to PLY format may timeout or fail due to memory constraints.

**Workarounds:**
- Implement streaming PLY export
- Reduce point cloud density before export
- Export in smaller chunks

```swift
extension SCPointCloud {
    func exportInChunks(to baseURL: URL, chunkSize: Int = 100000) {
        let totalPoints = pointCount
        let chunkCount = (totalPoints + chunkSize - 1) / chunkSize
        
        for chunk in 0..<chunkCount {
            let startIndex = chunk * chunkSize
            let endIndex = min(startIndex + chunkSize, totalPoints)
            
            let chunkCloud = extractSubset(startIndex: startIndex, endIndex: endIndex)
            let chunkURL = baseURL.appendingPathComponent("chunk_\\(chunk).ply")
            
            try? chunkCloud.write(to: chunkURL)
        }
    }
}
```

### Machine Learning Issues

#### Core ML Model Loading Failures on macOS
**Affected Versions:** All versions  
**Platform:** macOS Catalyst builds  
**Status:** Open  

**Description:**  
Built-in ML models fail to load in macOS Catalyst applications due to model compilation differences.

**Impact:** Ear and foot tracking features unavailable on macOS  
**Workarounds:**
- Disable ML features for macOS builds
- Use alternative detection algorithms
- Compile separate macOS-specific models

#### Landmark Detection Accuracy Variations
**Affected Versions:** All versions  
**Lighting Conditions:** Low light, harsh shadows  
**Status:** Open  

**Description:**  
Ear and foot landmark detection accuracy decreases significantly in poor lighting conditions.

**Workarounds:**
- Implement lighting quality assessment
- Provide user feedback for optimal lighting
- Fall back to manual landmark placement

### UI/UX Issues

#### ShutterButton Animation Lag
**Affected Versions:** All versions  
**Devices:** iPhone X, iPad Pro (2018)  
**Status:** Open  

**Description:**  
ShutterButton press animations may lag during active scanning due to high CPU/GPU usage.

**Workarounds:**
- Use simpler button animations during scanning
- Implement animation priority queuing
- Reduce animation frame rate

#### Metal Layer Resize Issues
**Affected Versions:** All versions  
**Scenarios:** Device rotation, multitasking  
**Status:** Under Investigation  

**Description:**  
CAMetalLayer doesn't properly resize when returning from background or rotating device.

**Workarounds:**
```swift
override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    // Force Metal layer resize
    CATransaction.begin()
    CATransaction.disableActions()
    metalLayer.frame = containerView.bounds
    metalLayer.drawableSize = CGSize(
        width: metalLayer.frame.width * metalLayer.contentsScale,
        height: metalLayer.frame.height * metalLayer.contentsScale
    )
    CATransaction.commit()
}
```

## Planned Fixes

### Next Release (Target: Q2 2025)
- [ ] Memory pressure improvements for iPhone models
- [ ] Enhanced thermal management
- [ ] Streaming PLY export for large files
- [ ] Metal command buffer timeout fixes
- [ ] macOS Catalyst ML model support
- [x] Improved ZipArchive integration (completed)

### Future Releases
- [ ] Advanced noise reduction algorithms
- [ ] Improved lighting condition handling
- [ ] Background processing capabilities
- [ ] Enhanced UI responsiveness
- [ ] Custom shader pipeline support

## Reporting New Issues

When reporting new issues, please include:

### Environment Information
```swift
// Include this debug information
print("Device: \\(UIDevice.current.model)")
print("iOS: \\(UIDevice.current.systemVersion)")
print("Memory: \\(getAvailableMemory()) MB")
print("Thermal: \\(ProcessInfo.processInfo.thermalState)")
print("Framework version: \\(getFrameworkVersion())")
```

### Reproduction Steps
1. Specific steps to reproduce the issue
2. Expected behavior vs actual behavior
3. Frequency of occurrence (always, sometimes, rarely)
4. Specific devices/iOS versions affected

### Sample Data
- Console logs showing errors
- Crash reports if applicable
- Sample point clouds or mesh files if relevant
- Screenshots or videos of the issue

### Issue Categories
Please tag issues with appropriate labels:
- `bug` - Functionality not working as expected
- `performance` - Performance-related issues
- `documentation` - Documentation problems
- `enhancement` - Feature requests
- `question` - Usage questions

## Workaround Status

| Issue | Workaround Available | Severity | Priority |
|-------|---------------------|----------|----------|
| Memory pressure | ✅ Partial | High | High |
| Thermal throttling | ✅ Yes | High | High |
| Frame drops | ✅ Partial | Medium | Medium |
| Metal timeouts | ✅ Partial | Medium | Medium |
| iOS 17 interruptions | ✅ Yes | High | Fixed |
| Xcode 15 SPM | ✅ Yes | Medium | Fixed |
| ZipArchive integration | ✅ Yes | High | High |
| PLY export timeout | ✅ Yes | Low | Medium |
| ML model failures | ✅ Yes | Medium | Low |
| Landmark accuracy | ✅ Partial | Low | Low |
| Animation lag | ✅ Yes | Low | Low |

## Version Compatibility Matrix

| StandardCyborgCocoa | iOS Support | Xcode | Known Issues |
|-------------------|-------------|--------|--------------|
| Current | 16.0+ | 15.2+ | Memory pressure, thermal throttling |
| Previous | 15.0+ | 14.0+ | iOS 17 interruptions, Xcode 15 SPM |

---

*This page is updated regularly. Check back for the latest known issue status and workarounds.*