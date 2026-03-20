# TrueContourAI

TrueContourAI is an iOS app for TrueDepth-based 3D head scanning, preview, and export.

The app captures depth + color frames on-device, reconstructs a point cloud, generates a textured mesh, and exports scan artifacts (GLTF/OBJ + metadata) to a local scans folder.

## Who This Is For
- Developers maintaining or extending the app.
- Reviewers who need to understand architecture and scanning behavior quickly.
- Non-specialists who need a clear starting point for build/run/test.

## What This App Does
- Starts a guided head scan using a front-facing TrueDepth camera.
- Builds a point cloud and preview mesh.
- Evaluates scan quality and can block export when quality is too low.
- Supports optional ear verification and derived measurements.
- Saves scan results locally and exposes sharing/export flows.

## Hardware Requirements
- iPhone with TrueDepth camera (Face ID class device).
- iOS device required for real scan behavior.
- Simulator is useful for UI/basic flows, but not real TrueDepth capture.

## Quick Start
1. Open [TrueContourAI.xcodeproj](./TrueContourAI.xcodeproj) in Xcode.
2. Let Swift Package Manager resolve local package dependencies.
3. Select scheme `TrueContourAI`.
4. For real scanning, run on a connected TrueDepth iPhone.

## Build and Test Commands
App build:
```bash
xcodebuild build -project TrueContourAI.xcodeproj -scheme TrueContourAI -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

Unit test build:
```bash
xcodebuild build -project TrueContourAI.xcodeproj -scheme TrueContourAITests -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

UI test build:
```bash
xcodebuild build -project TrueContourAI.xcodeproj -scheme TrueContourAIUITests -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

Physical-device test runs:
```bash
xcodebuild test -project TrueContourAI.xcodeproj -scheme TrueContourAITests -destination 'id=<DEVICE_ID>'
xcodebuild test -project TrueContourAI.xcodeproj -scheme TrueContourAIUITests -destination 'id=<DEVICE_ID>'
```

Focused physical-device smoke:
```bash
xcodebuild test -project TrueContourAI.xcodeproj -scheme TrueContourAIUITests -destination 'id=<DEVICE_ID>' -only-testing:TrueContourAIUITests/TrueContourAIDeviceSmokeTests/testDeviceSmokeSaveThenReopenFromHome
```

Keep the connected iPhone unlocked during `xcodebuild test` runs. Xcode will block UI-test launch at destination preflight if the device locks mid-run.

## Saved Scan Artifacts
Depending on export settings, a saved scan folder may contain:
- `scene.gltf`
- `head_mesh.obj`
- `scan_summary.json`
- `thumbnail.png`
- `ear_view.png`
- `ear_landmarks.json`
- `thumbnail_ear_overlay.png`

Physical-device validation should confirm the artifact set matches the active export toggles.

## Project Entry Points
- App target source: [TrueContourAI](./TrueContourAI)
- Unit tests: [TrueContourAITests](./TrueContourAITests)
- UI tests: [TrueContourAIUITests](./TrueContourAIUITests)
- Xcode project: [TrueContourAI.xcodeproj](./TrueContourAI.xcodeproj)

## Core Flows
1. Home
- Start scan
- Open recent scan
- Open settings

2. Scan
- Configure scan parameters
- Capture depth + color frames
- Reconstruct point cloud

3. Preview
- Meshing + quality feedback
- Verify ear (if available)
- Save/export

4. Persist
- Write scan folder artifacts
- Update last scan
- Refresh home list

## Current Runtime Shape
- App startup routes through `AppCoordinator` and `AppEnvironment`.
- App-scoped runtime/test overrides are applied through `AppRuntimeSettings`; persisted preferences remain owned by `SettingsStore`.
- Home flow is driven by `HomeViewModel` state/effects and assembled through `HomeAssembler`.
- Scan flow centers on `ScanAssembler`, `ScanCoordinator`, `ScanStore`, `ScanCaptureService`, `ScanRuntimeEngine`, and `AppScanningViewController`.
- Preview flow centers on `PreviewAssembler`, `PreviewCoordinator`, `PreviewViewController`, `PreviewStore`, `PreviewExportUseCase`, `PreviewFitUseCase`, `PreviewEarVerificationUseCase`, and `PreviewSceneAdapter`.
- Settings flow centers on `SettingsAssembler`, `SettingsStore`, and `SettingsStorageUseCase`.
- Preview still uses a few UI/session helpers for presentation, overlays, and existing-scan loading/session plumbing:
  - `PreviewPresentationController`
  - `PreviewPresentationWorkflow`
  - `PreviewOverlayWorkflow`
  - `PreviewOverlayUIController`
  - `PreviewSessionWorkflows`
- Scan still uses two narrow internal helpers under the store/runtime boundary:
  - `ScanSessionController`
  - `ScanRuntimeController`
- Scan storage/export behavior is owned directly by:
  - `ScanRepository`
  - `ScanExporterService`
  - `ScanTestSeedService` for UI-test seeding

## Current Intentional Exceptions
- `HomeCoordinator` still owns narrow Home-side presentation helpers for scan details/library actions; it is not as strictly route-only as Scan/Preview.
- Preview still keeps UI/session helper layers for hosting, overlays, meshing callbacks, and existing-scan loading/session plumbing, but `PreviewStore` remains the single preview feature owner.
- Scan still keeps `ScanSessionController` and `ScanRuntimeController` as helper layers for timer/platform plumbing, and `AppScanningViewController` still owns the UIKit/Metal/platform wiring that cannot reasonably move lower.

## Key Dependencies
- Local Swift packages:
  - `StandardCyborgFusion`
  - `StandardCyborgUI`
  - `scsdk`
  - `CppDependencies/*` packages (Eigen, PoissonRecon, etc.)
- Package references are defined in [TrueContourAI.xcodeproj/project.pbxproj](./TrueContourAI.xcodeproj/project.pbxproj).

## Documentation Map
- [ARCHITECTURE.md](./ARCHITECTURE.md): app structure and responsibilities.
- [DEVELOPMENT.md](./DEVELOPMENT.md): build/test/developer workflow.
- [docs/SCAN_ENGINE.md](./docs/SCAN_ENGINE.md): scanning pipeline details.
- [docs/REPO_LAYOUT.md](./docs/REPO_LAYOUT.md): active vs legacy folders.
- [docs/REVIEW_CHECKLIST.md](./docs/REVIEW_CHECKLIST.md): step-by-step reviewer checklist.
- [docs/TODO.md](./docs/TODO.md): current execution tracker.
- [CHANGELOG.md](./CHANGELOG.md): notable behavior and validation-relevant changes.
- [docs/TODO_TRIAGE.md](./docs/TODO_TRIAGE.md): how to classify TODO/FIXME items.
- [docs/DEPENDENCY_UPGRADE_PLAN.md](./docs/DEPENDENCY_UPGRADE_PLAN.md): staged dependency update strategy and safety gates.

## Current Important Constraint
- Real scan testing must be performed on physical hardware with TrueDepth.
- Simulator is not accepted as scan-runtime validation for capture/finalize/export behavior.
- The strongest current release evidence is still physical-device UI/device-smoke coverage on `Riy's iPhone`, with export-policy and runtime-override matrices now primarily covered in unit tests instead of diagnostics-heavy smoke assertions.
- The representative `save -> return home -> reopen` smoke path is passing again, but it should remain part of the release-facing rerun set after scan/preview/export changes.
