# TrueContourAI App

This simple app demonstrates how to integrate our SDK for 3D scanning and meshing.

<p float="left">
  <img src="https://user-images.githubusercontent.com/891664/83936489-139a9280-a779-11ea-9f4c-6bbf916aa878.PNG" width="200">
  <img src="https://user-images.githubusercontent.com/891664/83936490-16958300-a779-11ea-9b13-ee27739abeb1.PNG" width="200">
  <img src="https://user-images.githubusercontent.com/891664/83936491-18f7dd00-a779-11ea-9412-71794abb4f50.PNG" width="200">
</p>

## Getting Started
This repo uses Swift Package Manager for dependencies (StandardCyborgFusion and StandardCyborgUI). You'll need Xcode and Git installed, plus a device with a TrueDepth/FaceID camera.


```
# clone the repo
git clone git@github.com:StandardCyborg/StandardCyborgCocoa.git
cd StandardCyborgCocoa/TrueContourAI

# open the project
open TrueContourAI.xcodeproj

# Xcode will resolve SwiftPM packages on first open.
# Build and run on your device. Running on the simulator won't work.
```

## Dependencies
- SwiftPM local packages: `StandardCyborgFusion`, `StandardCyborgUI`
- SwiftPM remote package: `ZipArchive` (declared by `StandardCyborgFusion`)

## App Flow
- Home: start a head scan, open recent scans, or share the scans folder.
- Scan: follow on-screen prompts to capture a full head scan.
- Preview: rotate the model, verify ear landmarks, and save the scan.
- Settings: export options, scan duration, and storage management.

## Architecture
- See `ARCHITECTURE.md` for component responsibilities and flow overview.

## Tests
- Open `TrueContourAI.xcodeproj`
- Select scheme `TrueContourAITests`
- Run tests with `⌘U`
