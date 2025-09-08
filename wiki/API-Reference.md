# API Reference

This document provides detailed API documentation for StandardCyborgCocoa's key classes and methods.

## StandardCyborgFusion Framework

### Core Classes

#### SCReconstructionManager

The main class for managing 3D reconstruction operations.

```swift
class SCReconstructionManager: NSObject
```

**Initialization**
```swift
init(device: MTLDevice, 
     commandQueue: MTLCommandQueue, 
     maxThreadCount: Int32)
```
- `device`: Metal device for GPU operations
- `commandQueue`: Metal command queue for processing
- `maxThreadCount`: Maximum number of threads for reconstruction

**Key Properties**
```swift
var delegate: SCReconstructionManagerDelegate? { get set }
var includesColorBuffersInMetadata: Bool { get set }
var latestCameraCalibrationData: AVCameraCalibrationData? { get }
var latestCameraCalibrationFrameWidth: Int { get }
var latestCameraCalibrationFrameHeight: Int { get }
var flipsInputHorizontally: Bool { get set }
```

**Core Methods**
```swift
// Start reconstruction process
func accumulate(depthBuffer: CVPixelBuffer, 
               colorBuffer: CVPixelBuffer, 
               calibrationData: AVCameraCalibrationData)

// Add device motion data
func accumulateDeviceMotion(_ motion: CMDeviceMotion)

// Build current point cloud
func buildPointCloud() -> SCPointCloud

// Finalize reconstruction
func finalize(completion: @escaping () -> Void)

// Reset reconstruction state
func reset()

// Process single frame (preview mode)
func reconstructSingleDepthBuffer(_ depthBuffer: CVPixelBuffer,
                                colorBuffer: CVPixelBuffer,
                                with calibrationData: AVCameraCalibrationData,
                                smoothingPoints: Bool) -> SCPointCloud
```

#### SCReconstructionManagerDelegate

Protocol for receiving reconstruction updates.

```swift
protocol SCReconstructionManagerDelegate: AnyObject {
    func reconstructionManager(_ manager: SCReconstructionManager,
                              didProcessWith metadata: SCAssimilatedFrameMetadata,
                              statistics: SCReconstructionManagerStatistics)
    
    func reconstructionManager(_ manager: SCReconstructionManager,
                              didEncounterAPIError error: Error)
}
```

#### SCPointCloud

Represents a 3D point cloud with positions, normals, and colors.

```swift
class SCPointCloud: NSObject
```

**Key Properties**
```swift
var pointCount: Int { get }
var hasNormals: Bool { get }
var hasColors: Bool { get }
```

**Methods**
```swift
// File I/O
func write(to url: URL) throws
static func read(from url: URL) throws -> SCPointCloud

// SceneKit integration
func buildNode() -> SCNNode

// Geometry operations
func transform(by matrix: simd_float4x4)
func boundingBox() -> (min: simd_float3, max: simd_float3)

// Metal integration
func buildVertexBuffer(device: MTLDevice) -> MTLBuffer?
func buildColorBuffer(device: MTLDevice) -> MTLBuffer?
```

#### SCMesh

Represents a 3D mesh with vertices, faces, and optional texture coordinates.

```swift
class SCMesh: NSObject
```

**Key Properties**
```swift
var vertexCount: Int { get }
var faceCount: Int { get }
var hasTexture: Bool { get }
var hasColors: Bool { get }
```

**Methods**
```swift
// File I/O
func write(to url: URL, format: SCMeshFileFormat) throws
static func read(from url: URL) throws -> SCMesh

// Mesh operations
func decimate(targetFaceCount: Int)
func smooth(iterations: Int)
func calculateNormals()

// SceneKit integration  
func buildNode() -> SCNNode
```

#### SCMeshTexturing

Handles mesh texturing and UV mapping.

```swift
class SCMeshTexturing: NSObject
```

**Properties**
```swift
var cameraCalibrationData: AVCameraCalibrationData? { get set }
var cameraCalibrationFrameWidth: Int { get set }
var cameraCalibrationFrameHeight: Int { get set }
```

**Methods**
```swift
func reset()
func saveColorBufferForReconstruction(_ colorBuffer: CVPixelBuffer,
                                     withViewMatrix viewMatrix: simd_float4x4,
                                     projectionMatrix: simd_float4x4)
func applyTexture(to mesh: SCMesh)
```

#### SCScene

Scene graph management for 3D content.

```swift
class SCScene: NSObject
```

**Methods**
```swift
func addPointCloud(_ pointCloud: SCPointCloud, withKey key: String)
func addMesh(_ mesh: SCMesh, withKey key: String)
func removeObject(withKey key: String)
func buildSceneKitScene() -> SCNScene
```

### Machine Learning Classes

#### SCEarLandmarking

Ear feature detection using Core ML.

```swift
class SCEarLandmarking: NSObject
```

**Methods**
```swift
func detectLandmarks(in pixelBuffer: CVPixelBuffer) -> [SCLandmark2D]
```

#### SCFootTracking

Foot detection and tracking.

```swift
class SCFootTracking: NSObject
```

**Methods**
```swift
func detectFoot(in pixelBuffer: CVPixelBuffer) -> CGRect?
func trackFoot(in pixelBuffer: CVPixelBuffer, 
              previousBoundingBox: CGRect) -> CGRect?
```

### Data Types

#### SCAssimilatedFrameMetadata

Contains metadata about processed frames.

```swift
struct SCAssimilatedFrameMetadata {
    let result: SCAssimilatedFrameResult
    let viewMatrix: simd_float4x4
    let projectionMatrix: simd_float4x4
    let colorBuffer: Unmanaged<CVPixelBuffer>?
    let timestamp: CMTime
}
```

#### SCAssimilatedFrameResult

Enumeration of frame processing results.

```swift
enum SCAssimilatedFrameResult: Int {
    case succeeded
    case failed
    case poorTracking
}
```

#### SCReconstructionManagerStatistics

Statistics about the reconstruction process.

```swift
struct SCReconstructionManagerStatistics {
    let succeededCount: Int
    let failedCount: Int
    let poorTrackingCount: Int
    let totalFrameCount: Int
}
```

#### SCLandmark2D / SCLandmark3D

2D and 3D landmark representations.

```swift
struct SCLandmark2D {
    let position: CGPoint
    let confidence: Float
}

struct SCLandmark3D {
    let position: simd_float3
    let confidence: Float
}
```

## StandardCyborgUI Framework

### Rendering Classes

#### DefaultScanningViewRenderer

Metal-based renderer for live scanning preview.

```swift
class DefaultScanningViewRenderer: NSObject
```

**Methods**
```swift
init(device: MTLDevice, commandQueue: MTLCommandQueue)

func draw(colorBuffer: CVPixelBuffer,
         depthBuffer: CVPixelBuffer,
         pointCloud: SCPointCloud,
         depthCameraCalibrationData: AVCameraCalibrationData,
         viewMatrix: simd_float4x4,
         into layer: CAMetalLayer,
         flipsInputHorizontally: Bool)
```

#### ShutterButton

Customizable camera shutter button.

```swift
class ShutterButton: UIButton
```

**Properties**
```swift
@IBInspectable var ringColor: UIColor { get set }
@IBInspectable var innerColor: UIColor { get set }
@IBInspectable var isRecording: Bool { get set }
```

### Utility Classes

#### AspectFillTextureCommandEncoder

Metal command encoder for texture rendering.

```swift
class AspectFillTextureCommandEncoder: NSObject
```

**Methods**
```swift
func encode(to commandBuffer: MTLCommandBuffer,
           sourceTexture: MTLTexture,
           destinationTexture: MTLTexture,
           aspectFillSourceInDestination: Bool)
```

## scsdk Core Library

### C++ Classes (Swift Bridged)

#### Geometry

Core geometry operations.

```cpp
class Geometry {
public:
    Geometry(const std::vector<Vec3>& positions,
             const std::vector<Vec3>& normals = {},
             const std::vector<Vec3>& colors = {},
             const std::vector<Face3>& faces = {});
    
    // Spatial queries
    int getClosestVertexIndex(const Vec3& queryPosition) const;
    std::vector<int> getNClosestVertexIndices(const Vec3& queryPosition, int n) const;
    std::vector<int> getVertexIndicesInRadius(const Vec3& queryPosition, float radius) const;
    
    // Ray tracing
    RayTraceResult rayTrace(Vec3 rayOrigin, Vec3 rayDirection, 
                           float rayMin = 0.001f, float rayMax = 1e30f) const;
    
    // Transformations
    void transform(const Mat3x4& mat);
    
    // Data access
    const std::vector<Vec3>& getPositions() const;
    const std::vector<Vec3>& getNormals() const;
    const std::vector<Vec3>& getColors() const;
    const std::vector<Face3>& getFaces() const;
    
    // Properties
    int vertexCount() const;
    int faceCount() const;
    bool hasNormals() const;
    bool hasColors() const;
    bool hasFaces() const;
};
```

#### SceneGraph

Scene graph management.

```cpp
class SceneGraph {
public:
    void addNode(const std::string& key, std::shared_ptr<GeometryNode> node);
    void removeNode(const std::string& key);
    std::shared_ptr<GeometryNode> getNode(const std::string& key) const;
    
    void transform(const Mat3x4& transform);
    BoundingBox3 computeBoundingBox() const;
};
```

## File I/O Constants

### Supported File Formats

```swift
enum SCMeshFileFormat: Int {
    case PLY = 0
    case OBJ = 1
    case USDZ = 2
}

enum SCPointCloudFileFormat: Int {
    case PLY = 0
    case JSON = 1
}
```

### PLY Format Metadata

The framework uses custom PLY metadata:

```
comment StandardCyborgFusionVersion 1.2.0
comment StandardCyborgFusionMetadata { "color_space": "sRGB" }
```

## Error Types

### Common Error Cases

```swift
enum SCError: Error {
    case hardwareNotSupported
    case cameraAccessDenied
    case reconstructionFailed
    case fileIOError(String)
    case metalResourceError
    case thermalThrottling
}
```

## Usage Examples

### Basic Point Cloud Processing
```swift
// Create reconstruction manager
let device = MTLCreateSystemDefaultDevice()!
let commandQueue = device.makeCommandQueue()!
let manager = SCReconstructionManager(device: device, 
                                    commandQueue: commandQueue, 
                                    maxThreadCount: 2)

// Process frames
manager.accumulate(depthBuffer: depthBuffer, 
                  colorBuffer: colorBuffer, 
                  calibrationData: calibrationData)

// Get result
let pointCloud = manager.buildPointCloud()

// Export to file
try pointCloud.write(to: outputURL)
```

### SceneKit Integration
```swift
// Convert point cloud to SceneKit node
let pointCloudNode = pointCloud.buildNode()
scene.rootNode.addChildNode(pointCloudNode)

// Apply transforms
pointCloud.transform(by: transformMatrix)
```

---

*This API reference covers the most commonly used classes and methods. For complete documentation, refer to the header files in the framework bundles.*