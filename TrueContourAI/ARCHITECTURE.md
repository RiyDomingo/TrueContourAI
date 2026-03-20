# TrueContourAI Architecture

This document explains how TrueContourAI is organized and how scan data moves through the system.

## Architectural Style
- Programmatic UIKit app.
- Root app composition through `AppCoordinator`, `AppDependencies`, and stateless feature assemblers.
- Coordinator-assisted flow for scan start, home actions, and preview presentation.
- Service-oriented persistence/export layer with one production owner per responsibility.
- Explicit feature state via `HomeViewModel`, `ScanStore`, `PreviewStore`, and `SettingsStore`.
- Controllers bind/render/forward intents only; stores, coordinators, services, and use cases own the rest.

## Top-Level Modules
- [TrueContourAI/App](./TrueContourAI/App): app lifecycle and dependency wiring.
- [TrueContourAI/Core](./TrueContourAI/Core): cross-cutting services/utilities.
- [TrueContourAI/Features](./TrueContourAI/Features): Home, Scan, Preview, Settings.
- [TrueContourAITests](./TrueContourAITests): unit/integration-oriented tests.
- [TrueContourAIUITests](./TrueContourAIUITests): deterministic UI regression tests.

## Feature Ownership
### Home
- `HomeAssembler`: stateless factory for Home feature composition.
- `HomeViewController`: home UI, binding, and intent forwarding only.
- `HomeViewModel`: Home state owner with `state`, `onStateChange`, `onEffect`, and `send(_:)`.
- `HomeCoordinator`: owns Home-side navigation and presentation helpers for scan start, settings, preview entry, scan details, rename/delete flows, and storage-unavailable alerts.
- `HomeToastPresenter`: environment-aware toast timing and presentation.

### Scan
- `ScanAssembler`: stateless factory for scan feature composition.
- `ScanCoordinator`: validates simulator/device/camera gating, presents scan VC, and routes cancel/complete handoff.
- `ScanStore`: primary owner of scan UI state and one-shot scan effects.
- `ScanCaptureService`: owns `CameraManager` session lifecycle, frame delivery, and focus requests.
- `ScanRuntimeEngine`: owns reconstruction/runtime lifecycle, motion/thermal handling, preview payload finalization, and scan render-frame generation.
- `AppScanningViewController`: renders Metal/UIKit surfaces, binds `ScanStore`, and forwards user intents only.
- `ScanFlowState`: current phase (`idle/scanning/preview/saving`) plus truthful session timing metrics.
- `ScanQualityValidator`: quality scoring and export gate advice.
- `LocalMeasurementGenerationService`: heuristic-only measurement summary generation.

### Preview
- `PreviewAssembler`: stateless factory for preview feature composition.
- `PreviewStore`: primary owner of preview phase/state, derived view data, and one-shot preview effects.
- `PreviewCoordinator`: presentation/routing entry point only. Preview save/export product logic no longer lives in the coordinator.
- `PreviewViewController`: preview-screen boundary that hosts `ScenePreviewViewController` presentation as an implementation detail.
- `PreviewExportUseCase`: save precheck, export request construction, export execution, and saved-result mapping.
- `PreviewFitUseCase`: fit-check domain logic and summary creation.
- `PreviewEarVerificationUseCase`: ear-verification execution and result mapping.
- `PreviewSceneAdapter`: only layer that reads live `ScenePreviewViewController` scene/snapshot state for export/verification snapshot extraction.
- `PreviewExportResultEvent`: structured success/failure export UI event output.
- `SaveExportViewStateController`: meshing/save button/status/toast UI state control.
- `ScanSummaryBuilder`: summary metadata for persisted scans.
- UI-only preview helpers still in use:
  - `PreviewPresentationController`
  - `PreviewPresentationWorkflow`
  - `PreviewOverlayWorkflow`
  - `PreviewOverlayUIController`
  - `PreviewSessionController`
  - `PreviewSessionWorkflows`
  - `PreviewAlertPresenter`
  - `PreviewButtonConfigurator`
  - `MeshingTimeoutController`

### Settings
- `SettingsAssembler`: stateless factory for Settings feature composition.
- `SettingsViewController`: settings UI, binding, and intent forwarding, with section construction delegated to an internal builder.
  - Sections: `General`, `Export`, `Advanced`, `Storage`.
  - `Export` now treats GLTF as required for any saved scan the app can reopen in-app.
  - `Advanced` exposes only quality-gate controls that are actually honored by the app.
- `SettingsStore`: persisted-preference owner and Settings state/effect owner with `state`, `onStateChange`, `onEffect`, and `send(_:)`.
- `SettingsStorageUseCase`: async storage usage calculation and async delete-all scans.

### Core
- `ScanRepository`: production owner of scan listing, validity filtering, asset resolution, last-scan resolution, and rename/delete/delete-all.
- `ScanExporterService`: production owner of export folder writing and artifact cleanup.
- `ScanFolderValidator`: frozen validity rule owner. A reopenable scan must contain `scene.gltf`; invalid folders are excluded from Home recents and last-scan resolution.
- Utilities: localization, design system, view helpers.

## Runtime Flow
1. User taps Start Scan on Home.
2. `ScanCoordinator.startScanFlow(...)` requests the scan feature from `ScanAssembler` and presents `AppScanningViewController`.
3. `ScanCaptureService` starts the TrueDepth session and streams frames into `ScanRuntimeEngine`.
4. `ScanStore` owns countdown/capturing/finishing state and emits effects.
5. `AppScanningViewController` renders state and forwards completion/cancel routing through its delegate.
6. `PreviewCoordinator.presentPreviewAfterScan(...)` presents preview routing only.
7. `PreviewStore` owns preview state while `PreviewExportUseCase`, `PreviewFitUseCase`, and `PreviewEarVerificationUseCase` perform side effects/work.
8. `ScanExporterService.exportScanFolder(...)` writes artifacts and metadata.
9. `PreviewStore` emits a route effect and Home refreshes recent scans.

## Scan State Model
`ScanStore.state` is the source of truth for active scan UI, while `ScanFlowState.phase` tracks cross-feature scan session progress.

Expected progression:
- `idle` -> `scanning` -> `preview` -> `saving` -> `idle`

Failure transitions:
- `scanning` -> `failed` or cancel to `idle`
- `saving` failure returns to `preview`

## Why This Design
- Separation of concerns:
  - View controllers render, bind, and forward intents instead of constructing large feature graphs.
  - Coordinators own route orchestration and entry gating only.
  - Assemblers own feature graph construction for Home, Scan, Preview, and Settings.
  - Services and use cases own IO/export/runtime/verification work.
- Testability:
  - Protocol seams around scan engine components.
  - Deterministic environment wiring is centralized through `AppEnvironment`.
  - Release validation still depends on real build and simulator/device coverage.

## Known Constraints
- Some tests still rely on hardware/runtime-sensitive flows and remain slower or less deterministic than ideal.
- Device smoke on physical TrueDepth hardware remains a release gate.

## Closest Reference Implementation
The scan engine architecture in TrueContourAI is closer to the old `TrueDepthFusion` pattern than `StandardCyborgExample`, because it uses:
- `CameraManager` + `SCReconstructionManager`
- per-frame accumulate/reconstruction callbacks
- `SCMeshTexturing` and finalize-based handoff

See [docs/SCAN_ENGINE.md](./docs/SCAN_ENGINE.md).
