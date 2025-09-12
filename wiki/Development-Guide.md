# Development Guide

This guide covers advanced development topics for StandardCyborgCocoa, including best practices, performance optimization, and extending the framework.

## Development Environment Setup

### Prerequisites

- **Xcode 15.0+** with Swift 6.0 support
- **iOS 16.0+** or **macOS 12.0+** deployment targets
- **Physical device** with TrueDepth camera for testing
- **Git LFS** for handling large binary files (ML models)

### Project Setup

1. **Clone with LFS support**:
   ```bash
   git lfs clone https://github.com/StandardCyborg/StandardCyborgCocoa.git
   ```

2. **Open the workspace**:
   ```bash
   open StandardCyborgSDK.xcodeproj
   ```

3. **Select appropriate scheme**:
   - `TrueDepthFusion` - Full-featured demo app
   - `StandardCyborgExample` - Simple integration example
   - `VisualTesterMac` - macOS testing app

## Building from Source

### Swift Package Manager Dependencies

The project uses SPM for C++ dependencies. To rebuild dependencies:

```bash
# Clean SPM cache if needed
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf .build

# Update packages
xcodebuild -resolvePackageDependencies
```

### Build Configuration

**Debug Configuration:**
```swift
// Reconstruction manager with debug settings
let manager = SCReconstructionManager(device: device, 
                                    commandQueue: commandQueue, 
                                    maxThreadCount: 1) // Single thread for debugging
```

**Release Configuration:**
```swift
// Optimized settings for production
let maxThreads: Int32 = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2
let manager = SCReconstructionManager(device: device, 
                                    commandQueue: commandQueue, 
                                    maxThreadCount: maxThreads)
```

## Advanced Topics

### Custom Metal Shaders

You can extend the rendering pipeline with custom Metal shaders:

```metal
// CustomDepthShader.metal
#include <metal_stdlib>
using namespace metal;

vertex VertexOut vertex_custom_depth(VertexIn in [[stage_in]],
                                     constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * float4(in.position, 1.0);
    out.color = in.color;
    return out;
}

fragment float4 fragment_custom_depth(VertexOut in [[stage_in]]) {
    // Custom depth visualization logic
    return float4(in.color.rgb, 1.0);
}
```

**Integration:**
```swift
class CustomScanningRenderer: DefaultScanningViewRenderer {
    private var customPipelineState: MTLRenderPipelineState?
    
    override init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        super.init(device: device, commandQueue: commandQueue)
        setupCustomPipeline()
    }
    
    private func setupCustomPipeline() {
        guard let library = device.makeDefaultLibrary() else { return }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_custom_depth")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_custom_depth")
        
        customPipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
}
```

### Extending Point Cloud Processing

Create custom point cloud processors:

``swift
extension SCPointCloud {
    func customFilter(threshold: Float) -> SCPointCloud {
        // Implement custom filtering logic
        let filteredCloud = SCPointCloud()
        
        // Access raw data and apply custom processing
        let positions = self.getPositions()
        let colors = self.getColors()
        
        // Apply filtering logic here...
        
        return filteredCloud
    }
    
    func detectFeatures() -> [FeaturePoint] {
        // Custom feature detection algorithm
        var features: [FeaturePoint] = []
        
        // Implementation using scsdk geometry operations
        
        return features
    }
}
```

### Custom ML Model Integration

Integrate your own Core ML models:

```swift
class CustomLandmarkingModel: NSObject {
    private let model: MLModel
    
    init() throws {
        // Load your custom model
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        self.model = try MLModel(contentsOf: Bundle.main.url(forResource: "CustomModel", 
                                                            withExtension: "mlmodel")!)
    }
    
    func detectCustomLandmarks(in pixelBuffer: CVPixelBuffer) throws -> [CustomLandmark] {
        let input = try MLDictionaryFeatureProvider(dictionary: ["input": MLFeatureValue(pixelBuffer: pixelBuffer)])
        let output = try model.prediction(from: input)
        
        // Parse output and return landmarks
        return parseModelOutput(output)
    }
}
```

## Performance Optimization

### Memory Management

**Pool pixel buffers to reduce allocations:**
```swift
class PixelBufferPool {
    private let pool: CVPixelBufferPool
    
    init(width: Int, height: Int, format: OSType) {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: format,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]
        
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
        self.pool = pool!
    }
    
    func getPixelBuffer() -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        return pixelBuffer
    }
}
```

**Optimize Metal resource usage:**
```swift
class OptimizedRenderer {
    private let commandQueue: MTLCommandQueue
    private let vertexBufferPool: [MTLBuffer]
    
    init(device: MTLDevice) {
        self.commandQueue = device.makeCommandQueue()!
        
        // Pre-allocate buffers
        self.vertexBufferPool = (0..<3).map { _ in
            device.makeBuffer(length: 1024 * 1024, options: .storageModeShared)!
        }
    }
}
```

### Threading Optimization

**Custom dispatch queues for different operations:**
```swift
class OptimizedReconstructionManager {
    private let frameProcessingQueue = DispatchQueue(label: "frame-processing", 
                                                   qos: .userInitiated)
    private let pointCloudQueue = DispatchQueue(label: "point-cloud-generation", 
                                              qos: .utility)
    private let fileIOQueue = DispatchQueue(label: "file-io", 
                                          qos: .background)
    
    func processFrame(_ frame: DepthFrame) {
        frameProcessingQueue.async {
            // Heavy frame processing
            let processedFrame = self.processDepthFrame(frame)
            
            self.pointCloudQueue.async {
                // Point cloud generation
                self.generatePointCloud(from: processedFrame)
            }
        }
    }
}
```

### Thermal Management

**Monitor and respond to thermal state:**
```swift
class ThermalAwareScanner: NSObject {
    private var isThrottled = false
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func thermalStateChanged() {
        switch ProcessInfo.processInfo.thermalState {
        case .critical:
            // Stop scanning immediately
            stopScanning()
            showThermalWarning()
        case .serious:
            // Reduce frame rate and thread count
            throttlePerformance()
        case .fair, .nominal:
            // Resume normal operation
            resumeNormalPerformance()
        @unknown default:
            break
        }
    }
    
    private func throttlePerformance() {
        isThrottled = true
        reconstructionManager.maxThreadCount = 1
        // Reduce frame processing rate
    }
}
```

## Testing Strategies

### Unit Testing

**Test point cloud operations:**
```swift
class PointCloudTests: XCTestCase {
    func testPointCloudCreation() {
        let positions = [SIMD3<Float>(0, 0, 0), SIMD3<Float>(1, 1, 1)]
        let colors = [SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 1, 0)]
        
        let pointCloud = SCPointCloud(positions: positions, colors: colors)
        
        XCTAssertEqual(pointCloud.pointCount, 2)
        XCTAssertTrue(pointCloud.hasColors)
    }
    
    func testBoundingBoxCalculation() {
        let positions = [
            SIMD3<Float>(-1, -1, -1),
            SIMD3<Float>(1, 1, 1)
        ]
        let pointCloud = SCPointCloud(positions: positions)
        
        let boundingBox = pointCloud.boundingBox()
        XCTAssertEqual(boundingBox.min, SIMD3<Float>(-1, -1, -1))
        XCTAssertEqual(boundingBox.max, SIMD3<Float>(1, 1, 1))
    }
}
```

### Integration Testing

**Test reconstruction pipeline:**
```swift
class ReconstructionIntegrationTests: XCTestCase {
    var reconstructionManager: SCReconstructionManager!
    
    override func setUp() {
        super.setUp()
        let device = MTLCreateSystemDefaultDevice()!
        let commandQueue = device.makeCommandQueue()!
        reconstructionManager = SCReconstructionManager(device: device, 
                                                       commandQueue: commandQueue, 
                                                       maxThreadCount: 1)
    }
    
    func testFullReconstructionPipeline() {
        let expectation = XCTestExpectation(description: "Reconstruction completes")
        
        // Load test data
        let testFrames = loadTestFrames()
        
        // Process frames
        for frame in testFrames {
            reconstructionManager.accumulate(depthBuffer: frame.depthBuffer,
                                           colorBuffer: frame.colorBuffer,
                                           calibrationData: frame.calibration)
        }
        
        // Finalize
        reconstructionManager.finalize {
            let pointCloud = self.reconstructionManager.buildPointCloud()
            XCTAssertGreaterThan(pointCloud.pointCount, 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
}
```

### Performance Testing

**Benchmark critical operations:**
```swift
class PerformanceTests: XCTestCase {
    func testReconstructionPerformance() {
        measure {
            let device = MTLCreateSystemDefaultDevice()!
            let commandQueue = device.makeCommandQueue()!
            let manager = SCReconstructionManager(device: device, 
                                                commandQueue: commandQueue, 
                                                maxThreadCount: 2)
            
            // Process batch of frames
            for _ in 0..<100 {
                let testFrame = createTestFrame()
                manager.accumulate(depthBuffer: testFrame.depth,
                                 colorBuffer: testFrame.color,
                                 calibrationData: testFrame.calibration)
            }
            
            let pointCloud = manager.buildPointCloud()
            _ = pointCloud.pointCount // Force evaluation
        }
    }
}
```

## Debugging Techniques

### Visual Debugging

**Debug point cloud visualization:**
```swift
extension SCPointCloud {
    func saveDebugVisualization(to url: URL) {
        let scene = SCNScene()
        let node = self.buildNode()
        
        // Add coordinate axes for reference
        let axesNode = createCoordinateAxes()
        scene.rootNode.addChildNode(axesNode)
        scene.rootNode.addChildNode(node)
        
        // Export for viewing
        scene.write(to: url, options: nil, delegate: nil) { _, _ in }
    }
    
    private func createCoordinateAxes() -> SCNNode {
        let axesNode = SCNNode()
        
        // X-axis (red)
        let xAxis = SCNBox(width: 0.1, height: 0.01, length: 0.01, chamferRadius: 0)
        xAxis.firstMaterial?.diffuse.contents = UIColor.red
        let xNode = SCNNode(geometry: xAxis)
        xNode.position = SCNVector3(0.05, 0, 0)
        
        // Similar for Y and Z axes...
        axesNode.addChildNode(xNode)
        
        return axesNode
    }
}
```

### Logging and Metrics

**Comprehensive logging system:**
```swift
class ReconstructionLogger {
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    static func log(_ message: String, level: LogLevel = .info) {
        let timestamp = DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level.rawValue)] \(message)")
    }
    
    static func logPerformanceMetric(_ metric: String, value: Double) {
        log("METRIC: \(metric) = \(value)")
    }
}

// Usage
ReconstructionLogger.log("Starting reconstruction", level: .info)
ReconstructionLogger.logPerformanceMetric("frame_processing_time_ms", value: processingTime * 1000)
```

## Contributing Guidelines

### Code Style

- **Swift**: Follow Swift API Design Guidelines
- **C++**: Use Google C++ Style Guide
- **Naming**: Use descriptive names, avoid abbreviations
- **Documentation**: Add doc comments for public APIs

### Testing Requirements

- Unit tests for new functionality
- Integration tests for major features
- Performance tests for critical paths
- All tests must pass on CI

### Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Implement changes with tests
4. Update documentation
5. Submit pull request with detailed description

## Advanced Use Cases

### Custom File Formats

**Implement custom export formats:**
```swift
extension SCPointCloud {
    func exportToCustomFormat(url: URL) throws {
        let positions = getPositions()
        let colors = getColors()
        
        var output = "CUSTOM_FORMAT_V1\n"
        output += "VERTEX_COUNT \(pointCount)\n"
        
        for i in 0..<pointCount {
            let pos = positions[i]
            let col = colors[i]
            output += "\(pos.x) \(pos.y) \(pos.z) \(col.x) \(col.y) \(col.z)\n"
        }
        
        try output.write(to: url, atomically: true, encoding: .utf8)
    }
}
```

### Real-time Streaming

**Stream point clouds over network:**
```swift
class PointCloudStreamer {
    private let websocket: URLSessionWebSocketTask
    
    func streamPointCloud(_ pointCloud: SCPointCloud) {
        let compressedData = compressPointCloud(pointCloud)
        let message = URLSessionWebSocketTask.Message.data(compressedData)
        
        websocket.send(message) { error in
            if let error = error {
                print("Streaming error: \(error)")
            }
        }
    }
    
    private func compressPointCloud(_ pointCloud: SCPointCloud) -> Data {
        // Implement compression algorithm
        // Could use quantization, octree encoding, etc.
        return Data()
    }
}
```

### Handling Dependencies

StandardCyborgCocoa requires several dependencies to function properly. All dependencies are managed through Swift Package Manager and are required for the framework to work correctly.

For Objective-C++ files that use dependencies, direct imports should be used:

``objc
// Objective-C++ files - Direct import since ZipArchive is required
#import <SSZipArchive/SSZipArchive.h>

// Use the dependency directly
[SSZipArchive createZipFileAtPath:objZipPath withContentsOfDirectory:zipDirectory];
```

For Swift files, direct imports should be used:

```swift
// Swift files - Direct import since ZipArchive is required
import SSZipArchive

func createZipFile() {
    // Use ZipArchive functionality directly
}
```

This approach ensures that:
1. All required dependencies are available at compile time
2. The code fails fast if dependencies are missing
3. Developers get clear error messages when dependencies are not properly configured

## Framework Dependencies

### Managing Required Dependencies

StandardCyborgCocoa includes several required dependencies that must be available in all environments:

| Dependency | Purpose | Required |
|------------|---------|----------|
| **ZipArchive** | Archive handling for OBJ exports | ❌ Yes |
| **Eigen** | Linear algebra operations | ❌ Yes |
| **nanoflann** | K-d tree for nearest neighbor | ❌ Yes |
| **happly** | PLY file I/O | ❌ Yes |
| **json** (nlohmann) | JSON parsing | ❌ Yes |

When adding new dependencies:
1. Ensure they are required for core functionality
2. Add them directly to Package.swift
3. Import them directly in source files
4. Document the dependency in the wiki

---

*For more specific implementation details, refer to the example projects in the repository and the [API Reference](API-Reference).*