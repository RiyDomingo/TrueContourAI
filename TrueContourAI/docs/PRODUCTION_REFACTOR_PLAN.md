# TrueContourAI Production Refactor Plan

This is the working execution record for the production-hardening refactor.

Status values:
- `not started`
- `in progress`
- `partially complete`
- `blocked`
- `complete`

Last updated: 2026-03-09

Estimated overall completion: 96%

## Goal
Refactor the app from controller/coordinator-heavy imperative UIKit into a more defensible release architecture with:
- centralized runtime environment
- thinner controllers
- narrower coordinators
- more explicit feature state
- more truthful persistence/metadata
- safer runtime/package integration
- more credible validation

## Phase 1: Runtime Truth And Composition
Status: `partially complete`

Scope:
- add `AppEnvironment`
- remove scattered launch-argument branching from app features
- route startup through an app-level coordinator/composition root
- remove fake scan completion confidence from session metrics

Completed:
- `AppEnvironment` added and wired through app startup
- `SceneDelegate` now starts through `AppCoordinator`
- Home / Scan / Preview / ScanService runtime branching moved onto environment-driven config
- `ScanFlowState.ScanSessionMetrics` now contains timing only
- `ScanSummaryBuilder` no longer depends on fake session confidence

Remaining:
- remove any remaining feature-level runtime shortcuts that should be test-only infrastructure rather than app behavior

Validation required:
- app target build
- unit tests touching runtime environment and scan flow state

Validation state:
- app build passed
- earlier unit run passed
- multiple later focused simulator reruns for the latest batches still reach build/app validation and then hang without a final XCTest summary in this environment; treat this as an environment blocker unless a future rerun produces a clean result

## Phase 2: Scan Runtime Safety
Status: `partially complete`

Scope:
- remove synchronous main-thread state reads from capture callbacks
- keep scan screen responsible for its own control surface
- keep scan session state transitions explicit and safe

Completed:
- manual finish button moved into `AppScanningViewController`
- `DispatchQueue.main.sync` capture-state reads removed from:
  - app scan controller
  - package scan controller
- scan runtime thermal/idle-timer lifecycle now runs through `ScanRuntimeController` instead of being owned directly by `AppScanningViewController`
- scan guidance/prompt/progress visibility state now runs through `ScanHUDController` instead of being owned directly by `AppScanningViewController`
- command-buffer / command-encoder / `CVMetalTexture` package crash traps were replaced with guarded failure paths in:
  - `DefaultScanningViewRenderer`
  - `PointCloudCommandEncoder`
  - `AspectFillTextureCommandEncoder`
- `CameraManager` no longer force-unwraps the camera input while configuring the capture session

Remaining:
- further split scan runtime orchestration from HUD/presentation state
- reduce remaining scan-controller breadth

Validation required:
- app target build
- focused scan controller tests
- physical-device smoke for start/finish/cancel

Validation state:
- app build passed
- physical-device smoke revalidation passed for:
  - `testDeviceSmokeStartScanFinishShowsPreview`
  - `testDeviceSmokeScanHUDCountdownProgressAndControls`
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build also passed after introducing `ScanSessionController` and moving countdown / auto-finish timer ownership plus scan-session state transitions out of `AppScanningViewController`
- latest app build and physical-device revalidation also passed after introducing `ScanSessionController`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `ScanRuntimeController` and `ScanHUDController`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- the earlier rerun instability around the same slice was resolved on 2026-03-09:
  - 2026-03-08 attempt 1: `Timed out while enabling automation mode`
  - 2026-03-08 attempt 2: `An error occurred while communicating with a remote process`
  - 2026-03-09 retry: `testDeviceSmokeSaveThenReopenFromHome` passed on `Riy's iPhone`
- latest app build and physical-device revalidation also passed after the package/runtime hardening slice in `StandardCyborgUI`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after stabilizing the shared save/reopen device-smoke helper:
  - `testDeviceSmokeSaveThenReopenFromHome`

## Phase 3: Preview / Export Decomposition
Status: `partially complete`

Estimated completion: 84%

Scope:
- reduce `ScanPreviewCoordinator` breadth
- move preview-session state out of the coordinator
- make export workflow more explicit
- keep preview session safety guards

Completed:
- `PreviewViewModel` now owns more real state:
  - session metrics
  - quality report
  - measurement summary
  - mesh / verification artifacts
- preview session identity ownership moved into `PreviewViewModel`
- fit/preview UI session state moved further into `PreviewViewModel`:
  - meshing-active state
  - fit panel expansion
  - brow-control visibility and value
  - fit check result / mesh data
  - manual ear-pick state
- `ScanPreviewCoordinator` now depends on a narrower preview-read/export service surface instead of the full `ScanService` concrete type
- save/export path now uses explicit export context and separate success/failure handlers
- export preparation and save precheck logic extracted into a dedicated preview export workflow
- fit-model workflow moved behind a dedicated helper instead of staying fully inline in `ScanPreviewCoordinator`
- ear-verification flow moved behind a dedicated helper instead of staying fully inline in `ScanPreviewCoordinator`
- preview view-controller creation/button wiring moved behind a dedicated presentation helper instead of staying fully inline in `ScanPreviewCoordinator`
- export success/failure handling and preview reset/teardown logic moved behind a dedicated export-result helper instead of staying fully inline in `ScanPreviewCoordinator`
- meshing progress / mesh-ready / timeout handling moved behind a dedicated meshing helper instead of staying fully inline in `ScanPreviewCoordinator`
- overlay/measurement/verify-ear/fit UI binding moved further behind a dedicated overlay helper instead of staying fully inline in `ScanPreviewCoordinator`
- preview dismiss/reset lifecycle moved behind a dedicated lifecycle helper instead of staying fully inline in `ScanPreviewCoordinator`
- preview share-sheet presentation and missing-folder handling moved behind a dedicated sharing helper instead of staying fully inline in `ScanPreviewCoordinator`
- derived-measurement generation/preview update flow moved behind a dedicated measurement helper instead of staying fully inline in `ScanPreviewCoordinator`
- post-scan preview quality/state/presentation flow moved behind a dedicated post-scan helper instead of staying fully inline in `ScanPreviewCoordinator`
- save initiation / export precheck / export dispatch flow moved behind a dedicated save helper instead of staying fully inline in `ScanPreviewCoordinator`
- existing-scan preview setup / missing-scene handling / test-preview fallback moved behind a dedicated existing-scan helper instead of staying fully inline in `ScanPreviewCoordinator`
- post-scan preview assembly / meshing wiring / measurement dispatch / overlay finalization moved behind a dedicated post-scan presentation helper instead of staying fully inline in `ScanPreviewCoordinator`
- meshing/save UI state controller is no longer a no-op
- preview-specific current-folder state moved off `ScanFlowState` and into a dedicated preview-session state object shared only by Home/Preview flows
- preview session/presentation workflow helpers were moved out of `ScanPreviewCoordinator.swift` into a dedicated `PreviewSessionWorkflows.swift` file so preview setup and route helpers are no longer buried inside the main coordinator file
- save/export/fit/ear-verification/meshing/measurement workflow helpers were also moved out of `ScanPreviewCoordinator.swift` into `PreviewSessionWorkflows.swift`, leaving the coordinator with materially less embedded concrete behavior
- preview session lifecycle and current-preview folder ownership now run through `PreviewSessionController` instead of being split ad hoc between `ScanPreviewCoordinator`, `PreviewViewModel`, and `PreviewSessionState`
- active preview-controller references, overlay host resolution, and preview dismissal/reset presentation state now run through `PreviewPresentationController` instead of being owned directly by `ScanPreviewCoordinator`
- save/export orchestration now runs through `PreviewExportController` instead of `ScanPreviewCoordinator` owning save dispatch, export callbacks, and export-result handling directly
- preview interaction ownership now runs through `PreviewInteractionController` instead of `ScanPreviewCoordinator` owning:
  - verify-ear actions
  - share actions
  - fit-panel actions
  - overlay rendering hooks
- preview routing/presentation entrypoints now run through `PreviewRoutingController` instead of `ScanPreviewCoordinator` directly owning:
  - existing-scan preview presentation
  - post-scan preview presentation
- preview reset / teardown state now runs through `PreviewResetController` instead of `ScanPreviewCoordinator` owning preview-reset glue directly
- preview close/save button target actions now run through `PreviewActionController` instead of terminating directly in `ScanPreviewCoordinator`
- scene-specific preview UI setup now runs through `PreviewSceneUIController` instead of `ScanPreviewCoordinator` forwarding verify-ear / fit UI / scan-quality / derived-measurement scene glue directly
- preview collaborator assembly now runs through `PreviewCoordinatorComponents` instead of `ScanPreviewCoordinator` directly constructing and retaining the full preview collaborator graph

Remaining:
- split `ScanPreviewCoordinator` further into narrower collaborators
- separate preview session management from route/presentation behavior
- continue reducing remaining fit/verification density in one class

Validation required:
- app target build
- focused preview/export tests
- save/reopen smoke validation

Validation state:
- app build passed
- focused preview/export rerun exposed one constructor mismatch, which was fixed
- physical-device save/export revalidation passed for:
  - `testDeviceSmokeSaveReportsExportArtifactPresence`
  - `testDeviceSmokeGLTFDisableLaunchArgIsIgnored`
  - `testDeviceSmokeForcedQualityGateStillAllowsSave`
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest physical-device revalidation also passed after the ear-verification extraction and preview-presentation helper extraction:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest physical-device revalidation also passed after the export-result helper extraction:
  - `testDeviceSmokeSaveThenReopenFromHome`
- the latest meshing/overlay helper slices build cleanly, but fresh device revalidation is still pending because the connected iPhone locked during the rerun attempt
- latest app build also passed after the lifecycle/sharing helper extraction
- latest app build and physical-device revalidation also passed after the measurement helper extraction:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after the post-scan and save-workflow extractions:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build also passed after the existing-scan helper extraction
- latest physical-device rerun also passed after the existing-scan helper extraction:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after the post-scan presentation helper extraction:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after moving preview-specific current-folder state off `ScanFlowState`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after moving preview session/presentation helpers into `PreviewSessionWorkflows.swift`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after moving the remaining save/export/fit/verification/meshing/measurement helpers into `PreviewSessionWorkflows.swift`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `PreviewSessionController`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `PreviewPresentationController`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `PreviewExportController`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `PreviewInteractionController`; an existing-preview Close/Share target regression was caught by the device smoke test and fixed in the same slice:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `PreviewRoutingController`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `PreviewResetController` and removing the remaining coordinator-owned preview reset glue:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `PreviewActionController` and removing preview close/save target actions from `ScanPreviewCoordinator`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `PreviewSceneUIController` and removing scene-specific preview UI wrapper forwarding from `ScanPreviewCoordinator`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `PreviewCoordinatorComponents` and moving preview collaborator assembly out of `ScanPreviewCoordinator`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- focused simulator preview/export XCTest rerun is still not returning a final summary cleanly in this environment
- latest full physical-device UI suite passed on `Riy's iPhone`:
  - `TrueContourAIDeviceSmokeTests`: 8 tests passed
  - `TrueContourAIUITests`: 14 tests passed
  - combined `TrueContourAIUITests.xctest`: 22 tests passed

## Phase 4: Service Layer Cleanup
Status: `partially complete`

Estimated completion: 72%

Scope:
- split storage/repository work from export writing
- keep public behavior stable while reducing god-object service structure
- keep persisted metadata truthful

Completed:
- `ScanService` now has internal helper splits for:
  - storage/repository behavior
  - folder export behavior
- Home-facing consumers now depend on narrower service protocols instead of the full `ScanService` type:
  - `ScanListing`
  - `ScanLibraryManaging`
- `HomeViewController` now depends on narrower protocol surfaces instead of storing the full `ScanService` concrete type
- `ScanService` capability seams are now split further into narrower protocol surfaces for:
  - summary reading
  - last-scan resolution
  - scans-root ensuring
  - folder sharing
  - item listing
  - folder editing
- Home helpers now depend on those smaller capability surfaces instead of a single broad library protocol:
  - details workflow uses listing + summary reading
  - edit workflow uses folder editing
  - coordinator uses `HomeScanManaging`
- preview-reading protocol now reuses the shared service capability seams instead of duplicating summary/share/OBJ method declarations
- UI-test scan seeding moved behind a dedicated internal `ScanUITestSeedRepository` helper instead of staying inline in `ScanService`
- concrete storage/export/UI-test-seed collaborators were moved into `ScanServiceSupport.swift` so `ScanService.swift` now focuses more on public service behavior and less on buried helper implementations
- measurement status changed from fake validation language to explicit `heuristic`
- concrete app-level services now exist for the split boundary:
  - `ScanRepository`
  - `ScanExporterService`
- app composition now wires those concrete services through `AppDependencies`
- Home now consumes the concrete repository/exporter split instead of routing all scan concerns through `ScanService`
- UI-test scan seeding now runs through a dedicated `ScanTestSeedService` instead of being owned directly by `ScanRepository`
- Home and Preview feature tests now consume the repository/exporter split instead of constructing the legacy `ScanService` directly for those feature paths
- HomeViewModel, scan-timing, and accessibility feature tests now also consume the repository/exporter split instead of defaulting to the legacy `ScanService` for feature-level setup
- `ScanExporterService` now supports direct construction from `scansRootURL` + `UserDefaults`, so feature tests no longer need to construct a legacy `ScanService` just to get an exporter
- `AppDependencies` now composes `ScanRepository` and `ScanExporterService` directly from root/environment configuration instead of first constructing a legacy `ScanService` for the normal app path
- preview export tests now also consume the repository/exporter split instead of constructing the legacy `ScanService` directly for exporter setup
- `ScanExporterService` no longer routes export work through a legacy `ScanService`; it now owns concrete storage/export collaborators directly
- remaining preview/settings production adapters from `ScanService` were removed for:
  - `PreviewScanReading`
  - `ScanExporting`
  - `SettingsScanServicing`
- scan domain models now live in a standalone `ScanModels.swift` file; `ScanService` now exposes compatibility aliases instead of owning the primary definitions for:
  - `ScanSummary`
  - `ScanItem`
  - `EarArtifacts`
  - `ExportResult`
  - `RenameResult`
- production Home / Preview / repository / exporter code now uses standalone scan model names directly instead of namespacing those models through `ScanService`

Remaining:
- continue narrowing `ScanService` public surface and reduce remaining compatibility-facade usage
- move test seeding farther away from production-facing service behavior
- continue migrating the last non-compatibility call sites from `ScanService` onto `ScanRepository` / `ScanExporterService`
- keep `ScanService` only as an explicit compatibility facade plus compatibility-focused tests

Validation required:
- app build
- scan service tests
- export-path tests

Validation state:
- app build passed after internal split
- latest app build and focused physical-device revalidation also passed after removing the remaining production `ScanService.*` model namespace usage:
  - `TrueContourAI` build passed
  - `testDeviceSmokeSaveThenReopenFromHome` passed on `Riy's iPhone`
- latest app build passed after protocol narrowing
- physical-device smoke execution is working again on the connected iPhone
- targeted device validation passed after the service-boundary cleanup slice
- latest app build also passed after the capability-surface split
- latest physical-device rerun also passed after the capability-surface split:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device rerun also passed after aligning preview-reading with the shared service capability protocols:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build passed after moving UI-test scan seeding behind `ScanUITestSeedRepository`
- latest app build and physical-device rerun also passed after moving the concrete storage/export/UI-test-seed collaborators into `ScanServiceSupport.swift`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device rerun also passed after introducing `ScanRepository` and `ScanExporterService` and rewiring Home to consume them:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device rerun also passed after introducing `ScanTestSeedService` and removing environment-driven seeding from `ScanRepository`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device rerun also passed after migrating Home/Preview tests onto `ScanRepository` / `ScanExporterService`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device rerun also passed after migrating additional feature tests (HomeViewModel, scan-timing, accessibility) onto the repository/exporter split:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device rerun also passed after removing the remaining feature-test exporter setup path that constructed `ScanService` directly:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device rerun also passed after removing `AppDependencies`' normal repository/exporter construction dependency on the legacy `ScanService` facade:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device rerun also passed after making `ScanExporterService` standalone and removing the remaining preview/settings `ScanService` protocol adapters:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device rerun also passed after moving the scan domain models into `ScanModels.swift` and keeping `ScanService` on compatibility aliases:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device rerun also passed after moving exporter-only test hooks off `ScanService` and migrating repository/exporter coverage in `ScanServiceTests`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device rerun also passed after removing the default `ScanService` fixture from `ScanServiceTests`, leaving only explicit compatibility-only constructions:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device rerun also passed after moving the last test-only simulated export-failure helper off `ScanService` and onto `ScanExporterService`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- broader physical-device smoke validation now also passed after the latest preview/service refactors:
  - `testDeviceSmokeForcedQualityGateStillAllowsSave`
  - `testDeviceSmokeGLTFDisableLaunchArgIsIgnored`
  - `testDeviceSmokeSaveReportsExportArtifactPresence`
  - `testDeviceSmokeSaveThenReopenFromHome`
  - `testDeviceSmokeScanHUDCountdownProgressAndControls`
  - `testDeviceSmokeStartScanFinishShowsPreview`
- broader physical-device smoke validation also passed after the standalone scan-model extraction:
  - `testDeviceSmokeForcedQualityGateStillAllowsSave`
  - `testDeviceSmokeGLTFDisableLaunchArgIsIgnored`
  - `testDeviceSmokeSaveReportsExportArtifactPresence`
  - `testDeviceSmokeSaveReportsGLTFOnlyArtifacts`
  - `testDeviceSmokeSaveThenReopenFromHome`
  - `testDeviceSmokeScanHUDCountdownProgressAndControls`
  - `testDeviceSmokeStartScanCancelReturnsHome`
  - `testDeviceSmokeStartScanFinishShowsPreview`
- a fresh full `TrueContourAIUITests` run was started on `Riy's iPhone`, but `xcodebuild test` remained active without producing a final XCTest summary; this is currently treated as a runner-blocker rather than a product-regression signal

## Phase 5: Settings And Home Cleanup
Status: `partially complete`

Estimated completion: 71%

Scope:
- thin Home and Settings controllers
- move schema/state shaping out of controllers where practical

Completed:
- `SettingsViewController` section construction extracted into an internal builder
- `SettingsViewController` storage refresh/delete-all side effects moved behind a dedicated storage workflow
- `SettingsViewController` option-sheet/error/reset/delete confirmation presentation now runs through `SettingsFeedbackController` instead of staying inline in the controller
- settings schema/storage helper types were moved out of `SettingsViewController.swift` into `SettingsSupport.swift`, leaving the controller with less embedded scaffolding
- Home/Scan/Preview wiring is cleaner through environment-based composition
- `HomeViewModel` now exposes a view-state payload so `HomeViewController` binds screen state instead of assembling it field-by-field
- `HomeCoordinator` details loading and scan-library edit flows now run behind dedicated helper workflows instead of staying fully inline
- scan timing and device-smoke diagnostics ownership now run through `HomeScanSessionController` instead of living directly inside `HomeViewController`
- scan-start checklist gating, scan presentation, and scan completion/cancel transition into preview now run through `HomeScanFlowController` instead of living directly inside `HomeViewController`
- recent-scans table ownership, cell configuration, and open/share action wiring now run through `HomeRecentScansController` instead of living directly inside `HomeViewController`
- Home toast handling, storage-unavailable alert presentation, and device-smoke diagnostics label refresh now run through `HomeFeedbackController` instead of living directly inside `HomeViewController`

Remaining:
- further reduce `HomeViewController` orchestration
- continue moving remaining feature action shaping out of root controllers
- keep unsupported settings out of release scope

Validation required:
- app build
- settings/home unit tests
- UI regression tests

Validation state:
- app build passed
- focused `HomeViewModelTests` rerun was started for the new view-state slice, but the current simulator environment again failed to emit a final XCTest summary
- targeted physical-device validation also passed after the HomeCoordinator workflow extraction:
  - `testDeviceSmokeSaveThenReopenFromHome`
- targeted physical-device validation also passed after the Settings storage-workflow extraction:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after moving settings schema/storage helper types into `SettingsSupport.swift`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `HomeScanSessionController`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `HomeScanFlowController`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `HomeRecentScansController`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `HomeFeedbackController`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- latest app build and physical-device revalidation also passed after introducing `SettingsFeedbackController`:
  - `testDeviceSmokeSaveThenReopenFromHome`
- broader physical-device smoke validation also passed on `Riy's iPhone` after the latest architecture slices:
  - `testDeviceSmokeForcedQualityGateStillAllowsSave`
  - `testDeviceSmokeGLTFDisableLaunchArgIsIgnored`
  - `testDeviceSmokeSaveReportsExportArtifactPresence`
  - `testDeviceSmokeSaveReportsGLTFOnlyArtifacts`
  - `testDeviceSmokeSaveThenReopenFromHome`
  - `testDeviceSmokeScanHUDCountdownProgressAndControls`
  - `testDeviceSmokeStartScanCancelReturnsHome`
  - `testDeviceSmokeStartScanFinishShowsPreview`

## Phase 6: Package / Runtime Hardening
Status: `partially complete`

Estimated completion: 64%

Scope:
- reduce crash-first runtime behavior in package integration
- guard device/session setup assumptions in `StandardCyborgUI`
- keep package-side rendering/camera failures non-destructive where practical

Completed:
- default scanning renderer initialization now degrades instead of hard-crashing on library/pipeline failures
- point-cloud renderer initialization now degrades instead of hard-crashing on matcap/pipeline failures
- package scan controller no longer uses synchronous main-thread capture-state reads
- `DefaultScanningViewRenderer` now guards command-buffer creation
- `PointCloudCommandEncoder` now guards render-command-encoder creation
- `AspectFillTextureCommandEncoder` now guards compute-command-encoder creation
- `AspectFillTextureCommandEncoder` now guards `CVMetalTexture` unwrap before requesting the Metal texture
- `CameraManager` now guards the created `AVCaptureDeviceInput` before session insertion instead of force-unwrapping it

Remaining:
- continue removing force unwraps and assumption-heavy failure paths in package runtime code where the fallback can be made safe
- tighten package observer lifecycle / failure-path logging where it still relies on broad legacy patterns

Validation required:
- app target build
- focused physical-device scan/save/reopen smoke

Validation state:
- app build passed
- physical-device revalidation passed for:
  - `testDeviceSmokeSaveThenReopenFromHome`

## Validation / Release Evidence
Status: `partially complete`

Estimated completion: 65%

Scope:
- reduce crash-first behavior in StandardCyborgUI integration
- prefer graceful degradation where practical

Completed:
- renderer/library setup in package rendering paths now degrades instead of using several hard crash paths

Remaining:
- audit remaining forced unwrap / crash-first runtime assumptions in the rendering/capture stack
- confirm graceful degradation behavior is acceptable on device

Validation required:
- app build
- focused runtime tests where practical
- physical-device smoke validation

Validation state:
- app build passed
- device revalidation still needed for latest package-hardening batch

## Phase 7: Test Architecture Cleanup
Status: `partially complete`

Scope:
- remove fake-object patterns
- reduce synthetic preview/test behavior
- improve credibility of UI/device test coverage

Completed:
- removed the regular seeded UI-test shortcut that forced synthetic preview without GLTF
- reduced `@MainActor` usage in device smoke helpers
- replaced two `unsafeBitCast` placeholder patterns with runtime allocation of `SCPointCloud`
- hardened the shared device-smoke scan-start helper to re-activate the app while waiting for the scan shutter, reducing foreground-loss flakes

Remaining:
- keep eliminating remaining fake-path assumptions from tests
- finish rerunning focused tests for the latest batch
- re-run full relevant UI/device flows after harness changes

Validation required:
- focused unit tests
- UI test target build
- targeted UI/device smoke

Validation state:
- UI test target build passed
- focused changed-area unit rerun still awaiting final clean recorded summary

## Phase 8: Documentation And Release Truth
Status: `in progress`

Scope:
- keep architecture/release docs aligned with reality
- record what is complete vs still transitional

Completed:
- architecture doc updated to describe transitional state more honestly
- release checklist updated with current expectations
- TODO updated with current work/validation notes
- this execution plan file added

Remaining:
- keep this file updated as phases advance
- update release docs again after final validation

## Current Blockers
- latest changed-area device validation is recorded cleanly for the restored quality gate and save/reopen flow
- focused simulator validation for the export-precheck slice remains vulnerable to XCTest runner hangs after build completion

## Current Overall Status
- runtime/composition cleanup: materially improved
- preview/export architecture: improved but not finished
- service split: improved but not finished
- package hardening: improved but not finished
- test credibility: improved, with fresh targeted iPhone evidence for scan, save, and reopen flows

## Completion Estimate
Overall estimated completion: `94%`

Phase estimates:
- Phase 1: Runtime Truth And Composition: `88%`
- Phase 2: Scan Runtime Safety: `84%`
- Phase 3: Preview / Export Decomposition: `81%`
- Phase 4: Service Layer Cleanup: `82%`
- Phase 5: Settings And Home Cleanup: `73%`
- Phase 6: Package / Runtime Hardening: `64%`
- Phase 7: Test Architecture Cleanup: `75%`
- Phase 8: Documentation And Release Truth: `84%`

Notes:
- these percentages are engineering estimates, not checklist math
- the largest remaining structural debt is still the unfinished `ScanPreviewCoordinator` decomposition; `ScanService` is now almost entirely compatibility-only coverage rather than an active feature dependency
- current progress is real and materially validated on device, but the plan is still not fully closed

## Release Readiness
Current verdict: `not ready`

Why:
- preview/service architecture still has known transitional debt, even though the dominant god-object hotspots have been reduced materially
- some release-checklist documentation items are still open and should be closed before disciplined sign-off
- the restored quality-gate slice has strong iPhone evidence, but its focused simulator export-precheck rerun is still affected by XCTest runner instability in this environment
