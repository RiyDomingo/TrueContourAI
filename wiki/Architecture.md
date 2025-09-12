# Architecture Overview

This document provides a comprehensive overview of StandardCyborgCocoa's architecture, including its modular design, data flow, and key components.

## High-Level Architecture

StandardCyborgCocoa follows a layered architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ TrueDepthFusion │  │ StandardCyborg  │  │ VisualTester │ │
│  │     (iOS)       │  │   Example       │  │    (macOS)   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                      UI Layer                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              StandardCyborgUI                           │ │
│  │  • DefaultScanningViewRenderer                          │ │
│  │  • ShutterButton                                        │ │
│  │  • AspectFillTextureCommandEncoder                      │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                    Fusion Layer                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │            StandardCyborgFusion                         │ │
│  │  • SCReconstructionManager                              │ │
│  │  • SCPointCloud / SCMesh                                │ │
│  │  • Machine Learning Models                              │ │
│  │  • File I/O (PLY, OBJ, USDZ)                           │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                     Core Layer                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    scsdk                                │ │
│  │  • Core Algorithms (C++)                                │ │
│  │  • Data Structures (Geometry, Scene Graph)              │ │
│  │  • Mathematical Utilities                               │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                Dependencies Layer                           │
│  Eigen • nanoflann • happly • json • PoissonRecon         │ │
│  SparseICP • tinygltf • stb • libigl • ZipArchive          │ │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. StandardCyborgFusion (Fusion Layer)

The primary framework providing 3D reconstruction capabilities.

**Key Classes:**
- `SCReconstructionManager` - Main reconstruction engine
- `SCPointCloud` - Point cloud data structure and operations
- `SCMesh` - Mesh data structure and operations
- `SCScene` - Scene graph management
- ML Models for detection and landmarking

**Responsibilities:**
- Real-time 3D reconstruction
- Camera data processing
- Point cloud generation
- Mesh creation and texturing
- File format I/O

### 2. StandardCyborgUI (UI Layer)

Optional framework providing ready-to-use UI components for scanning.

**Key Components:**
- `DefaultScanningViewRenderer` - Metal-based rendering for live preview
- `ShutterButton` - Camera control UI component
- `AspectFillTextureCommandEncoder` - Texture rendering utilities

**Responsibilities:**
- Live scanning visualization
- User interface components
- Metal rendering pipeline

### 3. scsdk (Core Layer)

Pure C++ core library containing fundamental algorithms and data structures.

**Key Modules:**
- `sc3d::Geometry` - Core geometry operations
- `scene_graph::SceneGraph` - Scene management
- `io` - File I/O utilities
- `math` - Mathematical operations
- `util` - Utility functions

**Responsibilities:**
- Core 3D algorithms
- Data structure implementations
- Cross-platform mathematical operations
- Low-level file operations

## Data Flow Architecture

### Scanning Pipeline

```
TrueDepth Camera
       ↓
┌─────────────────┐
│ CameraManager   │ ← AVFoundation
└─────────────────┘
       ↓
┌─────────────────┐
│ Raw Frame Data  │
│ • Color Buffer  │
│ • Depth Buffer  │ 
│ • Calibration   │
└─────────────────┘
       ↓
┌─────────────────┐
│ Reconstruction  │
│ Manager         │ ← Metal Processing
└─────────────────┘
       ↓
┌─────────────────┐
│ Point Cloud     │ ← scsdk algorithms
│ Generation      │
└─────────────────┘
       ↓
┌─────────────────┐
│ Visualization   │ ← StandardCyborgUI
│ & Export        │
└─────────────────┘
```

### Metal Processing Pipeline

```
Depth Buffer → Metal Shaders → Surfel Processing → Point Cloud
     ↓              ↓               ↓                   ↓
Color Buffer → Texture Mapping → Color Assignment → Textured Mesh
```

## Framework Dependencies

### Swift Package Dependencies

| Package | Purpose | License | Optional |
|---------|---------|---------|----------|
| **Eigen** | Linear algebra operations | MPL2 | ❌ No |
| **nanoflann** | K-d tree for nearest neighbor | BSD | ❌ No |
| **happly** | PLY file I/O | MIT | ❌ No |
| **json** (nlohmann) | JSON parsing | MIT | ❌ No |
| **PoissonRecon** | Surface reconstruction | BSD | ❌ No |
| **SparseICP** | Iterative Closest Point | BSD | ❌ No |
| **tinygltf** | glTF file support | MIT | ❌ No |
| **ZipArchive** | Archive handling | MIT | ❌ No |
| **libigl** | Geometry processing | MPL2 | ❌ No |

### System Frameworks

| Framework | Usage |
|-----------|-------|
| **Metal** | GPU computation and rendering |
| **AVFoundation** | Camera capture and calibration |
| **SceneKit** | 3D scene rendering |
| **CoreMotion** | Device motion tracking |
| **UIKit/AppKit** | User interface |

## Threading Model

### Multi-threaded Architecture

```
Main Thread (UI)
├── Camera Capture Queue
├── Metal Command Queues
│   ├── Algorithm Queue (Heavy computation)
│   └── Visualization Queue (Rendering)
└── Reconstruction Thread Pool
    ├── Frame Processing
    ├── Point Cloud Generation
    └── Mesh Construction
```

**Thread Configuration:**
- **iPad**: Up to 4 reconstruction threads
- **iPhone**: Up to 2 reconstruction threads
- Separate queues for algorithms vs visualization to maintain UI responsiveness

## Memory Management

### Resource Lifecycle

1. **Initialization Phase**
   - Metal device and command queue setup
   - Reconstruction manager allocation
   - ML model loading

2. **Scanning Phase**
   - Frame-by-frame processing
   - Incremental point cloud building
   - Automatic memory pressure handling

3. **Finalization Phase**
   - Final reconstruction
   - Resource cleanup
   - Export preparation

### Thermal Management

The architecture includes thermal state monitoring:
- Automatic scanning termination on overheating
- Performance scaling based on device thermal state
- Memory pressure adaptation

## File Format Support

### Input Formats
- **Raw TrueDepth Data** - Native iOS camera format
- **Recorded Sessions** - For testing and development

### Output Formats
- **PLY** - Point clouds with custom metadata
- **OBJ** - Mesh geometry (requires ZipArchive for zipped exports)
- **USDZ** - AR-compatible format
- **JSON** - Metadata and scene graphs

## Machine Learning Integration

### Built-in Models
- **SCEarLandmarking.mlmodel** - Ear feature detection
- **SCEarTrackingModel.mlmodel** - Ear tracking
- **SCFootTrackingModel.mlmodel** - Foot tracking

### ML Pipeline
```
TrueDepth Frame → ML Model → Feature Detection → Tracking → 3D Reconstruction
```

## Error Handling Strategy

### Hierarchical Error Management
1. **Hardware Level** - Camera and sensor failures
2. **Processing Level** - Algorithm and computation errors  
3. **Application Level** - User interface and file I/O errors

### Recovery Mechanisms
- Automatic retry for transient failures
- Graceful degradation for processing errors
- User notification for hardware issues

## Performance Considerations

### Optimization Strategies
- **Metal GPU acceleration** for intensive computations
- **Multi-threading** for parallel processing
- **Memory pooling** for frequent allocations
- **Thermal monitoring** for sustained performance

### Benchmarking Points
- Frame processing latency
- Point cloud generation rate
- Memory usage patterns
- Thermal performance curves

---

*For implementation details of specific components, see the [API Reference](API-Reference) documentation.*