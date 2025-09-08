# StandardCyborgCocoa Wiki

Welcome to the StandardCyborgCocoa documentation! This wiki provides comprehensive documentation for the real-time 3D scanning SDK for iOS.

![StandardCyborgCocoa Logo](https://user-images.githubusercontent.com/6288076/51778445-84766880-20b6-11e9-8f46-b63c0a016d8b.png)

## What is StandardCyborgCocoa?

StandardCyborgCocoa is an open-source iOS SDK that enables real-time 3D scanning using the TrueDepth camera found on modern iOS devices. Originally developed by Standard Cyborg for 3D-printed prosthetics, this framework provides powerful 3D reconstruction capabilities for iOS applications.

## Key Features

- **Real-time 3D Reconstruction** - Live scanning using TrueDepth camera data
- **Machine Learning Integration** - Built-in ML models for foot and ear detection/landmarking
- **Multiple Export Formats** - Support for PLY, OBJ, USDZ file formats
- **Metal-Accelerated Processing** - GPU-optimized rendering and computation
- **Swift Package Manager** - Modern dependency management
- **Cross-platform Support** - iOS 16+ and macOS 12+

## Quick Links

### Getting Started
- [Installation Guide](Getting-Started#installation)
- [Basic Usage](Getting-Started#basic-usage)
- [Sample Projects](Getting-Started#sample-projects)

### Documentation
- [Architecture Overview](Architecture)
- [API Reference](API-Reference)
- [Development Guide](Development-Guide)

### Support
- [Troubleshooting](Troubleshooting)
- [FAQ](FAQ)
- [Known Issues](Known-Issues)

## Project Structure

The repository contains several key components:

| Component | Description |
|-----------|-------------|
| **StandardCyborgFusion** | Core 3D reconstruction framework |
| **StandardCyborgUI** | UI components for scanning interfaces |
| **scsdk** | Pure C++ core algorithms and data structures |
| **TrueDepthFusion** | Full-featured demo application |
| **StandardCyborgExample** | Simple integration example |
| **VisualTesterMac** | macOS development and testing tool |

## Hardware Requirements

- **iOS Device**: iPhone X or later, iPad Pro (2018) or later
- **Camera**: TrueDepth camera system required
- **OS**: iOS 16.0+ or macOS 12.0+

## License

StandardCyborgCocoa is released under the MIT License. See the [LICENSE](../LICENSE) file for details.

## Community

This project is now community-maintained following Standard Cyborg's closure. Contributions, bug reports, and feature requests are welcome through GitHub issues and pull requests.

---

*Last updated: January 2025*