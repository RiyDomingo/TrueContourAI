# TrueContourAI Production Refactor Plan

This is the working execution record for the production-hardening refactor.

Status values:
- `not started`
- `in progress`
- `partially complete`
- `blocked`
- `complete`

Last updated: 2026-03-08

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
- later focused rerun for latest batches still needs a final clean recorded summary

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

## Phase 3: Preview / Export Decomposition
Status: `partially complete`

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
- focused simulator preview/export XCTest rerun is still not returning a final summary cleanly in this environment

## Phase 4: Service Layer Cleanup
Status: `partially complete`

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
- preview export tests now also consume the repository/exporter split instead of constructing the legacy `ScanService` directly for exporter setup

Remaining:
- continue narrowing `ScanService` public surface and reduce remaining compatibility-facade usage
- move test seeding farther away from production-facing service behavior
- continue migrating feature call sites from `ScanService` onto `ScanRepository` / `ScanExporterService`

Validation required:
- app build
- scan service tests
- export-path tests

Validation state:
- app build passed after internal split
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
- broader physical-device smoke validation now also passed after the latest preview/service refactors:
  - `testDeviceSmokeForcedQualityGateStillAllowsSave`
  - `testDeviceSmokeGLTFDisableLaunchArgIsIgnored`
  - `testDeviceSmokeSaveReportsExportArtifactPresence`
  - `testDeviceSmokeSaveThenReopenFromHome`
  - `testDeviceSmokeScanHUDCountdownProgressAndControls`
  - `testDeviceSmokeStartScanFinishShowsPreview`
- a fresh full `TrueContourAIUITests` run was started on `Riy's iPhone`, but `xcodebuild test` remained active without producing a final XCTest summary; this is currently treated as a runner-blocker rather than a product-regression signal

## Phase 5: Settings And Home Cleanup
Status: `partially complete`

Scope:
- thin Home and Settings controllers
- move schema/state shaping out of controllers where practical

Completed:
- `SettingsViewController` section construction extracted into an internal builder
- `SettingsViewController` storage refresh/delete-all side effects moved behind a dedicated storage workflow
- settings schema/storage helper types were moved out of `SettingsViewController.swift` into `SettingsSupport.swift`, leaving the controller with less embedded scaffolding
- Home/Scan/Preview wiring is cleaner through environment-based composition
- `HomeViewModel` now exposes a view-state payload so `HomeViewController` binds screen state instead of assembling it field-by-field
- `HomeCoordinator` details loading and scan-library edit flows now run behind dedicated helper workflows instead of staying fully inline
- scan timing and device-smoke diagnostics ownership now run through `HomeScanSessionController` instead of living directly inside `HomeViewController`
- scan-start checklist gating, scan presentation, and scan completion/cancel transition into preview now run through `HomeScanFlowController` instead of living directly inside `HomeViewController`
- recent-scans table ownership, cell configuration, and open/share action wiring now run through `HomeRecentScansController` instead of living directly inside `HomeViewController`

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

## Phase 6: Package / Runtime Hardening
Status: `partially complete`

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
- final changed-area XCTest summary for the latest refactor batch is still not recorded cleanly in this environment
- package/runtime latest-batch device revalidation is still incomplete

## Current Overall Status
- runtime/composition cleanup: materially improved
- preview/export architecture: improved but not finished
- service split: improved but not finished
- package hardening: improved but not finished
- test credibility: improved, with fresh targeted iPhone evidence for scan, save, and reopen flows

## Completion Estimate
Overall estimated completion: `58%`

Phase estimates:
- Phase 1: Runtime Truth And Composition: `85%`
- Phase 2: Scan Runtime Safety: `65%`
- Phase 3: Preview / Export Decomposition: `60%`
- Phase 4: Service Layer Cleanup: `50%`
- Phase 5: Settings And Home Cleanup: `62%`
- Phase 6: Package / Runtime Hardening: `55%`
- Phase 7: Test Architecture Cleanup: `55%`
- Phase 8: Documentation And Release Truth: `70%`

Notes:
- these percentages are engineering estimates, not checklist math
- the largest remaining structural debt is still preview/export ownership and the still-broad public `ScanService` facade
- current progress is real, but the plan is not close enough to call finished

## Fastest Path To 80%
The shortest route from the current estimated `58%` to `80%+` is:

1. Finish the real preview/export split.
   - Make `ScanPreviewCoordinator` a true route coordinator.
   - Push remaining orchestration into concrete preview session/export owners.
   - Expected gain: `+8%` to `+10%`

2. Split `ScanService` into real concrete services.
   - Introduce first-class `ScanRepository`, `ScanExporter`, and test-seed/debug-only support.
   - Rewire Home/Preview/Settings off the broad service facade.
   - Expected gain: `+6%` to `+8%`

3. Do one more strong Home controller thinning pass.
   - Move remaining top-level action routing out of `HomeViewController`.
   - Leave the root controller primarily as binder/lifecycle host.
   - Expected gain: `+3%` to `+4%`

4. Capture broader real-device validation.
   - Re-run wider device flows, not just the focused reopen smoke.
   - Use the connected TrueDepth iPhone as the release-signoff signal.
   - Expected gain: `+5%` to `+7%`

Best order:
1. finish preview/export decomposition
2. finish service split
3. finish final Home thinning pass
4. rerun broader device validation

Not the fastest path:
- doc-only cleanup
- small helper extractions
- minor protocol renames
- simulator-only stabilization
- cosmetic controller refactors that do not move ownership

## Release Readiness
Current verdict: `not ready`

Why:
- latest batch does not yet have a final clean focused test summary recorded
- latest package/runtime changes have not yet been re-validated on physical TrueDepth flow
- preview/service architecture still has known transitional debt
