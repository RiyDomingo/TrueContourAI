# TrueContourAI Architecture

This document explains how TrueContourAI is organized and how scan data moves through the system.

## Architectural Style
- Programmatic UIKit app.
- Coordinator-assisted flow for scan start, home actions, and preview presentation.
- Service-oriented persistence/export layer with scan lifecycle state shared through `ScanFlowState`.
- Explicit scan lifecycle state via `ScanFlowState`.

## Top-Level Modules
- [TrueContourAI/App](./TrueContourAI/App): app lifecycle and dependency wiring.
- [TrueContourAI/Core](./TrueContourAI/Core): cross-cutting services/utilities.
- [TrueContourAI/Features](./TrueContourAI/Features): Home, Scan, Preview, Settings.
- [TrueContourAITests](./TrueContourAITests): unit/integration-oriented tests.
- [TrueContourAIUITests](./TrueContourAIUITests): deterministic UI regression tests.

## Feature Ownership
### Home
- `HomeViewController`: home UI and wiring.
- `HomeViewModel`: recent scans, filter/sort state, and display models.
- `HomeCoordinator`: routes to scan start, settings, preview entry points.

### Scan
- `ScanCoordinator`: validates device capability, configures scan VC.
- `AppScanningViewController`: runtime scan engine adapter over StandardCyborg SDK.
- `ScanFlowState`: current phase (`idle/scanning/preview/saving`).
- `ScanQualityValidator`: quality scoring and export gate advice.

### Preview
- `ScanPreviewCoordinator`: post-scan orchestration, meshing state, save/export, and preview-session lifecycle guards.
- `ScanPreviewCoordinator.ExportResultEvent`: structured success/failure export UI event output.
- `SaveExportViewStateController`: save button/spinner/toast UI state control.
- `ScanSummaryBuilder`: summary metadata for persisted scans.

### Settings
- `SettingsViewController`: settings UI and storage/delete actions.
  - Sections: `General`, `Export`, `Advanced`, `Storage`.
  - `Export` now treats GLTF as required for any saved scan the app can reopen in-app.
  - `Advanced` exposes only quality-gate controls that are actually honored by the app.
- `SettingsStore`: persisted app preferences.

### Core
- `ScanService`: scan folder lifecycle, export artifacts, share items.
- Utilities: localization, design system, view helpers.

## Runtime Flow
1. User taps Start Scan on Home.
2. `ScanCoordinator.startScanFlow(...)` creates/configures `AppScanningViewController`.
3. Scan VC captures and reconstructs frames.
4. Scan VC returns point cloud + mesh texturing via delegate.
5. `ScanPreviewCoordinator.presentPreviewAfterScan(...)` shows preview.
6. User saves export.
7. `ScanService.exportScanFolder(...)` writes artifacts and metadata.
8. Home refreshes recent scans.

## Scan State Model
`ScanFlowState.phase` is the single shared status for scan lifecycle transitions.

Expected progression:
- `idle` -> `scanning` -> `preview` -> `saving` -> `idle`

Failure transitions:
- `scanning` -> `failed` or cancel to `idle`
- `saving` failure returns to `preview`

## Why This Design
- Separation of concerns:
  - View controllers still own most UIKit composition.
  - Coordinators own route orchestration and some flow policy.
  - Services own IO/export/serialization.
- Testability:
  - Protocol seams around scan engine components.
  - Deterministic test hooks around quality gating and export paths remain, but release validation still depends on real build and simulator/device coverage.

## Closest Reference Implementation
The scan engine architecture in TrueContourAI is closer to the old `TrueDepthFusion` pattern than `StandardCyborgExample`, because it uses:
- `CameraManager` + `SCReconstructionManager`
- per-frame accumulate/reconstruction callbacks
- `SCMeshTexturing` and finalize-based handoff

See [docs/SCAN_ENGINE.md](./docs/SCAN_ENGINE.md).
