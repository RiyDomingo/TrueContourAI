# TrueContourAI Architecture

This document explains how TrueContourAI is organized and how scan data moves through the system.

## Architectural Style
- Programmatic UIKit app.
- Root app composition through `AppCoordinator` and `AppEnvironment`.
- Coordinator-assisted flow for scan start, home actions, and preview presentation.
- Service-oriented persistence/export layer with internal repository/export helper split inside `ScanService`.
- Explicit scan lifecycle state via `ScanFlowState`.
- Transitional architecture: controllers are thinner than before, but Preview and Scan still carry active refactor debt.

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
- `HomeToastPresenter`: environment-aware toast timing and presentation.

### Scan
- `ScanCoordinator`: validates device capability, configures scan VC.
- `AppScanningViewController`: runtime scan engine adapter over StandardCyborg SDK; now owns the manual-finish control surface and no longer relies on synchronous main-thread state reads from camera callbacks.
- `ScanFlowState`: current phase (`idle/scanning/preview/saving`) plus truthful session timing metrics.
- `ScanQualityValidator`: quality scoring and export gate advice.
- `LocalMeasurementGenerationService`: heuristic-only measurement summary generation.

### Preview
- `PreviewViewModel`: preview-session state for metrics, quality report, measurement summary, mesh, and ear-verification artifacts.
- `ScanPreviewCoordinator`: route/orchestration layer for post-scan preview, meshing state, save/export, and preview-session lifecycle guards. This is still the heaviest coordinator in the app and remains transitional.
- `ScanPreviewCoordinator.ExportResultEvent`: structured success/failure export UI event output.
- `SaveExportViewStateController`: meshing/save button/status/toast UI state control.
- `ScanSummaryBuilder`: summary metadata for persisted scans.

### Settings
- `SettingsViewController`: settings UI and storage/delete actions, with section construction delegated to an internal builder.
  - Sections: `General`, `Export`, `Advanced`, `Storage`.
  - `Export` now treats GLTF as required for any saved scan the app can reopen in-app.
  - `Advanced` exposes only quality-gate controls that are actually honored by the app.
- `SettingsStore`: persisted app preferences.

### Core
- `ScanService`: stable public facade over scan storage/repository and export-writing helpers.
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
  - View controllers still own UIKit composition, but active flows are being pushed toward explicit feature-state ownership.
  - Coordinators own route orchestration and some remaining flow policy.
  - Services own IO/export/serialization, with `ScanService` now internally split between storage/repository and export-writing concerns.
- Testability:
  - Protocol seams around scan engine components.
  - Deterministic environment wiring is centralized through `AppEnvironment`.
  - Release validation still depends on real build and simulator/device coverage.

## Known Architectural Debt
- `ScanPreviewCoordinator` is still too large and should be split further into preview-session and export workflow collaborators.
- `AppScanningViewController` still owns substantial runtime orchestration and HUD behavior in one class.
- `ScanService` is cleaner internally but still exposes a broad facade.
- Some tests still rely on hardware/runtime-sensitive flows and remain slower or less deterministic than ideal.

## Closest Reference Implementation
The scan engine architecture in TrueContourAI is closer to the old `TrueDepthFusion` pattern than `StandardCyborgExample`, because it uses:
- `CameraManager` + `SCReconstructionManager`
- per-frame accumulate/reconstruction callbacks
- `SCMeshTexturing` and finalize-based handoff

See [docs/SCAN_ENGINE.md](./docs/SCAN_ENGINE.md).
