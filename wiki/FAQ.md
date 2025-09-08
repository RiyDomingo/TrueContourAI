# Frequently Asked Questions

This page answers common questions about StandardCyborgCocoa.

## General Questions

### What is StandardCyborgCocoa?

StandardCyborgCocoa is an open-source iOS SDK for real-time 3D scanning using the TrueDepth camera system. It was originally developed by Standard Cyborg for creating 3D-printed prosthetics and is now community-maintained under the MIT license.

### What happened to Standard Cyborg the company?

Standard Cyborg was a company that developed 3D-printed prosthetics and this 3D scanning software. The company no longer exists, but before closing, they open-sourced this framework under the MIT license for the community to maintain and develop.

### Is this project still maintained?

Yes, the project is now community-maintained. All feature development, maintenance, and support is provided by open source contributors and maintainers.

## Hardware and Compatibility

### Which devices support StandardCyborgCocoa?

The SDK requires a TrueDepth camera system, found on:

**iPhones:**
- iPhone X and later (X, XS, XS Max, XR, 11 series, 12 series, 13 series, 14 series, 15 series)

**iPads:**
- iPad Pro 11-inch (all generations)
- iPad Pro 12.9-inch (3rd generation and later)

### Can I use this on older devices?

No, StandardCyborgCocoa specifically requires the TrueDepth camera hardware, which is only available on devices listed above. Regular cameras cannot provide the depth information needed for 3D reconstruction.

### Will this work in the iOS Simulator?

No, the iOS Simulator cannot simulate TrueDepth camera hardware. You must use a physical device for development and testing.

### What about Android support?

StandardCyborgCocoa is designed specifically for iOS and the TrueDepth camera system. There is no Android version, as Android devices use different depth sensing technologies.

## Technical Questions

### What file formats can I export to?

StandardCyborgCocoa supports several 3D file formats:

- **PLY** - Point clouds and meshes with custom metadata
- **OBJ** - Mesh geometry (widely supported)
- **USDZ** - Apple's AR format for iOS/macOS
- **JSON** - Metadata and scene graph information

### How accurate are the 3D scans?

Accuracy depends on several factors:
- **Distance**: Best results at 20-50cm from subject
- **Lighting**: Good, even lighting improves quality
- **Subject**: Textured surfaces scan better than smooth/reflective ones
- **Movement**: Slow, steady scanning produces better results

Typical accuracy is 1-3mm for objects scanned under good conditions.

### Can I customize the ML models?

Yes, you can integrate your own Core ML models. The framework includes built-in models for:
- Ear feature detection and landmarking
- Foot detection and tracking

You can replace these with custom models or add new detection capabilities.

### How much storage do scans require?

Storage requirements vary by scan quality and duration:
- **Point cloud (PLY)**: 1-10MB typical
- **Textured mesh (OBJ + texture)**: 5-50MB typical
- **USDZ with textures**: 10-100MB typical

The exact size depends on point count, texture resolution, and compression settings.

## Development Questions

### What's the minimum iOS version?

StandardCyborgCocoa requires iOS 16.0 or later. This ensures compatibility with the latest Swift features and Metal performance improvements.

### Can I use this with SwiftUI?

Yes, you can integrate StandardCyborgCocoa with SwiftUI. The framework provides UIKit components that can be wrapped using `UIViewRepresentable`:

```swift
struct ScanningView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ScanningViewController {
        return ScanningViewController()
    }
    
    func updateUIViewController(_ uiViewController: ScanningViewController, context: Context) {
        // Update as needed
    }
}
```

### Do I need to understand Metal programming?

Basic usage doesn't require Metal knowledge - the framework handles GPU operations automatically. However, understanding Metal is helpful for:
- Custom rendering effects
- Performance optimization
- Advanced visualization features

### How do I handle memory pressure?

The framework includes built-in memory management, but you should:
- Monitor device thermal state
- Implement `didReceiveMemoryWarning` handling
- Limit scan duration on constrained devices
- Use appropriate thread counts (2 for iPhone, 4 for iPad)

## Performance and Optimization

### Why is my app getting hot during scanning?

3D reconstruction is computationally intensive. The framework includes thermal monitoring, but you should:
- Limit continuous scanning duration
- Reduce thread count when thermal state is elevated
- Use lower resolution depth processing if needed
- Provide user feedback about thermal state

### How can I improve scanning performance?

Several optimization strategies:
- Use appropriate thread counts for device type
- Reduce depth resolution for less powerful devices
- Implement frame rate throttling under thermal pressure
- Pool buffers to reduce memory allocations
- Use Metal performance shaders where possible

### What causes reconstruction to fail?

Common causes of reconstruction failure:
- **Poor lighting** - Infrared projector needs adequate conditions
- **Fast movement** - Camera tracking can't keep up
- **Reflective surfaces** - Depth sensor struggles with mirrors/glass
- **Insufficient texture** - Plain surfaces lack visual features
- **Distance** - Too close (<15cm) or too far (>1m)

## Licensing and Usage

### What license is StandardCyborgCocoa under?

The project is licensed under the MIT License, which allows both commercial and non-commercial use with attribution.

### Can I use this in commercial applications?

Yes, the MIT license permits commercial use. You just need to include the license notice in your application.

### Do I need to contribute changes back?

No, the MIT license doesn't require you to contribute changes back, though contributions are welcome and help the community.

### Are there any patent concerns?

The open-source release includes the necessary rights for the algorithms and techniques used. However, you should consult with legal counsel for specific patent questions related to your use case.

## File Format Questions

### What's the PLY format metadata?

StandardCyborgCocoa adds custom metadata to PLY files:
```
comment StandardCyborgFusionVersion 1.2.0
comment StandardCyborgFusionMetadata { "color_space": "sRGB" }
```

This helps identify files created by the framework and preserves color space information.

### Can I import existing 3D models?

The framework is primarily designed for creating 3D scans, but you can import PLY and OBJ files using the file I/O APIs for processing and visualization.

### How do I handle large scan files?

For large scans:
- Use streaming or progressive loading
- Implement level-of-detail systems
- Consider mesh decimation for display
- Use compression for storage/transmission

## Integration Questions

### Can I integrate with ARKit?

Yes, StandardCyborgCocoa works well with ARKit. You can:
- Use ARKit for world tracking and StandardCyborgCocoa for detailed scanning
- Export USDZ files that work with AR Quick Look
- Combine tracked camera poses with scan data

### How do I integrate with SceneKit?

The framework provides direct SceneKit integration:
```swift
let pointCloud = reconstructionManager.buildPointCloud()
let sceneNode = pointCloud.buildNode()
sceneView.scene?.rootNode.addChildNode(sceneNode)
```

### Can I use this with other 3D libraries?

Yes, you can export data and use it with:
- Open3D (via PLY files)
- PCL (Point Cloud Library)
- MeshLab
- Blender
- Unity/Unreal Engine

## Troubleshooting

### My scans look noisy - how do I fix this?

Noisy scans usually result from:
- Poor lighting conditions - improve lighting
- Fast movement - scan more slowly
- Wrong distance - maintain 20-50cm from subject
- Low quality settings - use higher resolution if device supports it

### The camera preview is black - what's wrong?

Black camera preview typically indicates:
- Missing camera permissions - check Info.plist and iOS Settings
- Device doesn't have TrueDepth camera
- Camera being used by another app
- Hardware failure

### Scanning freezes or crashes - how do I debug?

For freezing/crashing issues:
- Check device memory and thermal state
- Reduce thread count and resolution
- Enable Metal debugging layers
- Check console logs for specific errors
- Test on different device models

---

*Don't see your question answered? Check the [Troubleshooting](Troubleshooting) guide or create an issue on GitHub.*