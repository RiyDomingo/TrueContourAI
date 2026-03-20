# Changelog

All notable TrueContourAI behavior changes should be recorded in this file.

This project follows a simple keep-a-changelog style:
- add dated entries for scan lifecycle, export behavior, settings UX, test infrastructure, and repo hygiene changes
- prefer concise, reviewer-oriented notes over narrative history
- record validation notes when a change required physical TrueDepth device confirmation

## Unreleased

### Added
- Release-readiness documentation (`docs/RELEASE_CHECKLIST.md`)
- CI workflow for build and test-target build validation (`.github/workflows/ios-build.yml`)
- Steady-state feature assemblers:
  - `HomeAssembler`
  - `ScanAssembler`
  - `PreviewAssembler`
  - `SettingsAssembler`
- Preview steady-state collaborators:
  - `PreviewCoordinator`
  - `PreviewViewController`
  - `PreviewStore`
  - `PreviewFeatureModels`
  - `PreviewSceneAdapter`
  - `PreviewExportUseCase`
  - `PreviewFitUseCase`
  - `PreviewEarVerificationUseCase`
- Scan steady-state collaborators:
  - `ScanFeatureModels`
  - `ScanCaptureService`
  - `ScanRuntimeEngine`
  - `ScanStore`
  - `ScanSessionController`
  - `ScanRuntimeController`
- Persistence/export collaborators:
  - `ScanRepository`
  - `ScanExporterService`
  - `ScanTestSeedService`
- Home/Settings support collaborators:
  - `HomeRecentScansController`
  - `HomeFeedbackController`
  - `HomeScanSessionController`
  - `HomeScanFlowController`
  - `SettingsFeedbackController`
  - `SettingsStorageUseCase`

### Changed
- Phase 1 boundary hardening now filters incomplete scan folders out of repository-backed listings and last-scan resolution, moves settings delete-all work off the main thread, and freezes `ScanService` as a compatibility adapter over repository/export services.
- Phase 2 scan extraction now routes TrueDepth capture through `ScanCaptureService`, runtime/reconstruction through `ScanRuntimeEngine`, and all scan HUD/state/effects through `ScanStore`, leaving `AppScanningViewController` as a rendering/binding surface.
- Phase 3 preview extraction now routes preview phase/state/effects through `PreviewStore`, save/export precheck/execution through `PreviewExportUseCase`, fit logic through `PreviewFitUseCase`, and ear verification through `PreviewEarVerificationUseCase`, with live scene reads isolated behind `PreviewSceneAdapter`.
- Phase 4 Home/Settings assembly cleanup now routes Home and Settings feature graph construction through `HomeAssembler` and `SettingsAssembler`, removes large collaborator assembly from `HomeViewController`, and moves async settings storage/delete work behind `SettingsStorageUseCase`.
- Phase 5 debt removal now deletes the concrete `ScanService`, moves shared scan protocols onto the repository/exporter path, adds root-owned `ScanAssembler` and `PreviewAssembler`, and removes obsolete preview transition helpers that duplicated the store/use-case architecture.
- Final cleanup now aligns project/test/doc naming to `PreviewCoordinator`, `PreviewViewController`, `PreviewStore`, `ScanRepositoryExporterTests`, `PreviewStoreTests`, and `SettingsStorageUseCaseTests`.
- Separated `TrueContourAITests` from `TrueContourAIUITests` in the shared unit-test scheme
- Updated repo documentation to reflect physical-device TrueDepth validation requirements
- Preview/save/reopen flow no longer depends on a single oversized coordinator for most workflow state.
- Scan/session/HUD lifecycle is no longer centered entirely inside `AppScanningViewController`.
- Normal app composition now builds repository/export services directly instead of centering everything on the legacy `ScanService` facade.
- Scan domain models now live outside `ScanService` so the scan domain is no longer nested under a compatibility sidecar type.
- Test infrastructure now prefers real repository/export services and records stronger physical-device evidence for the main save/reopen flow.
- Ear verification recovery now documents and enforces separate coordinate contracts for detector bbox rendering vs landmark point rendering, and persists device-debug artifacts under `Documents/Scans/EarDebug`.
- `Verify Ear` now lives in the normal preview summary UI instead of the developer-only section.
- Ear verification now prefers a preserved capture-faithful scan frame over preview snapshot fallback, while keeping the full-scene overlay for UI context and the crop overlay for QA.
- Scan-time ear verification image selection now scores capture frames for side-profile strength and tracking quality, preferring the best candidate over the simple latest-frame policy and recording the winning frame metadata in debug output.
- UI-test scan seeding now includes a deterministic `ear_view.png`, and autonomous preview/device-smoke tests can trigger `Verify Ear` without a fresh manual scan.
- UI-test/device-smoke runtime shaping now goes through `AppRuntimeSettings` instead of mutating persisted `SettingsStore`.
- Preview state ownership is further consolidated around `PreviewStore`; remaining preview workflows are now thin UI/session plumbing rather than alternate product-state owners.
- PreviewStore internals are now grouped by session/render/fit/verification concern to reduce mutable sprawl without changing external ownership.
- Test architecture now favors unit coverage for runtime overrides, export-policy matrices, and preview save prechecks; physical-device smoke remains focused on true UI/hardware workflows instead of diagnostics-label artifact assertions.

### Fixed
- Removed remaining scan/preview runtime force-unwrap crash paths in `StandardCyborgUI` for Metal/session/SceneKit/resource setup, replacing them with guarded fallbacks.
- Removed fake preview presenter fallbacks from preview coordinator composition.
- Removed the concrete legacy `ScanService` type from the active codebase.
- Removed the active `PreviewCoordinatorComponents` composition wrapper and obsolete preview controller layer (`PreviewRoutingController`, `PreviewInteractionController`, `PreviewExportController`, `PreviewActionController`, `PreviewResetController`, `PreviewSceneUIController`).
- Removed `ScanHUDController`; scan HUD state now comes from `ScanStore`.
- Stabilized settings UI-test helpers to wait for an always-visible settings control instead of a non-visible storage-row anchor
- Removed synchronous capture-state reads from scan callbacks.
- Hardened package/runtime setup so several Metal/camera failure paths degrade instead of crashing immediately.
- Fixed a double Y-flip in ear landmark overlay rendering that was placing accepted landmark points above the ear even when crop generation and model output were valid.

### Validation
- `TrueContourAIUITests` full physical-device rerun on `Riy's iPhone`: 22 tests passed, 0 failed on 2026-03-09
- Focused repeated physical-device smoke for `testDeviceSmokeSaveThenReopenFromHome` stayed green across the preview/service/runtime refactor slices on 2026-03-09
- Ear landmark recovery and overlay fixes: build-verified on 2026-03-14; physical-device confirmation of final anatomical placement still pending on the latest build
- Phase 2 scan feature extraction: connected-device build succeeded and focused `ScanCoordinatorTests`, `AppScanningViewControllerTests`, and `ScanStoreTests` passed on `Riy's iPhone` on 2026-03-19
- Phase 3 preview extraction: connected-device build succeeded and focused preview coordinator/export tests and `ScanFlowStateTests` passed on `Riy's iPhone` on 2026-03-19
- Phase 4 Home/Settings assembly cleanup: connected-device build succeeded and focused `HomeViewModelTests`, `HomeCoordinatorTests`, `SettingsViewControllerTests`, `ScanTimingTests`, and `AccessibilitySmokeTests` passed on `Riy's iPhone` on 2026-03-19
- Phase 5 debt removal: connected-device build succeeded and focused repository/export, preview coordinator/export, `ScanFlowStateTests`, `HomeViewModelTests`, `HomeCoordinatorTests`, `SettingsViewControllerTests`, `ScanTimingTests`, and `AccessibilitySmokeTests` passed on `Riy's iPhone` on 2026-03-19
- Final refactor cleanup: connected-device build succeeded and focused `ScanRepositoryExporterTests`, `ScanStoreTests`, `PreviewStoreTests`, `PreviewCoordinatorTests`, `PreviewCoordinatorExportTests`, `SettingsStorageUseCaseTests`, and `SettingsViewControllerTests` passed on `Riy's iPhone` on 2026-03-20
- Runtime override cleanup: connected-device build succeeded and focused `AppRuntimeSettingsTests`, `SettingsStorageUseCaseTests`, `SettingsViewControllerTests`, `ScanCoordinatorTests`, `ScanStoreTests`, `PreviewCoordinatorExportTests`, and `PreviewStoreTests` passed on `Riy's iPhone` on 2026-03-20
- Preview ownership consolidation: connected-device build succeeded and focused `PreviewStoreTests`, `PreviewCoordinatorTests`, and `PreviewCoordinatorExportTests` passed on `Riy's iPhone` on 2026-03-20
- PreviewStore internal refinement: connected-device build succeeded and focused `PreviewStoreTests`, `PreviewCoordinatorTests`, and `PreviewCoordinatorExportTests` passed on `Riy's iPhone` on 2026-03-20
- Test-architecture cleanup: connected-device UI test target build succeeded, and focused `AppRuntimeSettingsTests`, `PreviewCoordinatorExportTests`, `ScanRepositoryExporterTests`, and `SettingsViewControllerTests` passed on `Riy's iPhone` on 2026-03-20; one representative save/reopen device-smoke rerun still failed and remains an active end-to-end stability check
