# TrueContourAI Architecture Refactor Checklist

This checklist records the current architecture convergence state after the refactor. It is not a promise of stricter purity than the checked-in code actually provides.

## Final Outcome

- [x] UIKit controllers primarily render, bind, and forward intents; remaining platform/UI wiring is kept local to the screen boundary
- [x] One primary state owner exists per feature:
  - `HomeViewModel`
  - `ScanStore`
  - `PreviewStore`
  - `SettingsStore`
- [x] Scan and Preview coordinators are route-only in the main flow; Home keeps narrow presentation helpers for details/library actions
- [x] Use cases/services own side effects
- [x] `ScanRepository` is the production scan persistence owner
- [x] `ScanExporterService` is the production export owner
- [x] GLTF remains required for reopenable scans
- [x] Persistent UI lives in `State`
- [x] One-shot UI lives in `Effect`
- [x] UI-test/device-smoke runtime shaping is applied ephemerally through `AppRuntimeSettings`, not by mutating persisted `SettingsStore`

## Phase Completion Record

### Phase 1: Boundary Hardening
- [x] `ScanFolderValidator` added
- [x] Invalid scan folders excluded from repository-backed listings and last-scan resolution
- [x] `deleteAllScans` moved off the main thread
- [x] Shared scan/preview runtime force unwraps removed from active-path code
- [x] Fake preview presenter fallbacks removed
- [x] `ScanService` frozen to compatibility-only before retirement

Validation:
- [x] Incomplete scan folders no longer appear on Home
- [x] Delete-all no longer blocks the main thread

### Phase 2: Scan Extraction
- [x] `ScanCaptureService` owns capture/session lifecycle
- [x] `ScanRuntimeEngine` owns reconstruction/runtime lifecycle
- [x] `ScanStore` owns scan UI state and scan effects
- [x] `AppScanningViewController` reduced to render/bind/intent forwarding
- [x] `ScanCoordinator` limited to entry gating, presentation, and routing

Validation:
- [x] Capture session lifecycle is not controller-owned
- [x] Reconstruction lifecycle is not controller-owned
- [x] All UI-facing scan state comes from `ScanStore`

### Phase 3: Preview Extraction
- [x] `PreviewSceneAdapter` added
- [x] `PreviewExportUseCase` added
- [x] Save precheck/export execution moved out of workflow/coordinator-owned product logic
- [x] `PreviewStore` owns preview state/effects
- [x] `PreviewFitUseCase` and `PreviewEarVerificationUseCase` added
- [x] `PreviewCoordinator` reduced to routing/presentation ownership
- [x] Live preview scene reads isolated behind `PreviewSceneAdapter`

Validation:
- [x] `PreviewStore` is the state owner
- [x] `PreviewCoordinator` is route-only in the active flow
- [x] Export no longer depends on live preview VC state outside `PreviewSceneAdapter`

### Phase 4: Home and Settings Assembly Cleanup
- [x] `HomeAssembler` added
- [x] `SettingsAssembler` added
- [x] Home graph construction removed from `HomeViewController`
- [x] `SettingsStorageUseCase` owns async storage usage and delete-all work
- [x] Home and Settings controllers are binder/intent-forward surfaces

Validation:
- [x] No large feature graph is built inside `HomeViewController`
- [x] Settings destructive/storage work is outside the controller

### Phase 5: Debt Removal And Final Cleanup
- [x] Remaining production `ScanService` usages removed
- [x] Preview naming aligned to `PreviewCoordinator`, `PreviewViewController`, and `PreviewStore`
- [x] Preview support file ownership narrowed; UI-only presentation/overlay helpers extracted
- [x] Test names aligned to repository/exporter and preview coordinator ownership
- [x] Architecture/development/readme docs updated to the steady-state model
- [x] Active docs/checklists updated again to match the current helper-layer reality and test-architecture split

Validation:
- [x] One production owner exists per responsibility
- [x] No retired preview/scan compatibility layer remains in the documented main flow; remaining helper controllers are UI/session support only
- [x] Docs describe the current architecture rather than the migration target

## Final Acceptance

- [x] App build passes on the connected TrueDepth device
- [x] Focused renamed unit/device-backed suites pass
- [x] Architecture docs match implemented structure, including the remaining UI/session helper layers
- [x] No active production/doc/test references remain to retired preview or repository/exporter naming
- [x] Export-policy/runtime-override coverage is primarily unit-tested; physical-device smoke remains reserved for true hardware/UI risk
- [x] The representative `save -> return home -> reopen` device-smoke path is stable again on the current connected-device validation path

## Ongoing Release Rule

- [x] Physical TrueDepth device smoke remains a permanent release gate for scan/runtime/export changes

## Intentional Exceptions And Remaining Acceptable Debt

- [x] `HomeCoordinator` still owns narrow Home-side presentation helpers for details/library actions; Home is not as strictly route-only as Scan/Preview.
- [x] Preview still keeps narrow UI/session helpers (`PreviewPresentationController`, `PreviewPresentationWorkflow`, `PreviewOverlayWorkflow`, `PreviewOverlayUIController`, `PreviewSessionWorkflows`) but `PreviewStore` remains the single preview feature owner.
- [x] Scan still keeps `ScanSessionController` and `ScanRuntimeController` as timer/platform helpers under `ScanStore` / `ScanRuntimeEngine`, and `AppScanningViewController` still retains the UIKit/Metal/platform wiring that belongs at the screen edge rather than in the store.
- [x] The save/reopen hardware smoke path is passing again, but it remains a release-facing validation point and should continue to be rerun after scan/preview/export changes.
