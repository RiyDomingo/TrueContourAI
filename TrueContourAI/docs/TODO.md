# TrueContourAI TODO

This file tracks remaining implementation, validation, and hygiene tasks.

## Now
- [x] Restore enough local disk space to get clean `xcodebuild` results again, then record fresh build status for:
  - `TrueContourAI`
  - `TrueContourAITests`
  - `TrueContourAIUITests`
- [ ] Validate main scan flow end-to-end on device: start scan -> preview -> export -> reopen scan.
- [x] Verify quality-gate blocked export flow and recovery messaging on device.
- [ ] Validate export settings matrix on device:
  - [x] GLTF on / OBJ on
  - [x] GLTF on / OBJ off
  - [x] `GLTF off / OBJ on` is prevented (`SettingsViewController` guard + device-smoke launch-arg hardening keeps GLTF enabled)
  - [x] `GLTF off / OBJ off` is prevented in Settings and from preview-save precheck
- [ ] Re-run the full `TrueContourAIUITests` suite on the connected iPhone and capture a final pass/fail summary after the decimate-ratio fix landed.

## Next
- [ ] Confirm no accidental staged legacy/archive content before next commit.
- [ ] Periodically clean local generated artifacts before commits (`.xcresult`, package `.build/`, DerivedData outputs).

## Documentation
- [x] Keep `README.md` aligned with latest run/build/test commands.
- [x] Update `docs/SCAN_ENGINE.md` whenever scan lifecycle behavior changes.
- [x] Update `docs/REVIEW_CHECKLIST.md` when review policy changes.
- [x] Add a short release checklist doc.

## Architecture / Code Quality
- [ ] Reduce view-controller orchestration when touching Home/Scan/Preview flows; prefer pushing UI state and side effects behind focused helpers/controllers.
- [ ] Keep protocol seams for high-risk dependencies when modifying those areas:
  - scan runtime
  - export orchestration
  - settings side effects
- [ ] Add tests for any new branch introduced in scan/preview/settings code as part of the same change.
- [ ] Run `StandardCyborgFusion` tests only when fusion/package code changes, scan-quality behavior regresses, or that dependency is updated; do not block UI-only releases on that suite.
- [x] Keep unit and UI test schemes separated cleanly.

## Repository Hygiene
- [x] Keep legacy material in `LegacyArchive/` only.
- [x] Avoid duplicate file variants (for example `* 2.swift`, `* 2.md`).
- [x] Add `.gitignore` entries for macOS/Xcode clutter.
- [ ] Remove committed/generated clutter that still exists outside the active app subrepo when repository-wide cleanup is performed.

## Optional Improvements
- [x] Add CI workflow for build + unit tests + UI test compile checks.
- [ ] Add coverage reporting for `TrueContourAI/Features/Scan` and `TrueContourAI/Features/Preview`.
- [x] Add changelog process for major scan-engine behavior changes.

## Backlog: Fusion Runtime TODOs
- [ ] `StandardCyborgFusion/Sources/StandardCyborgFusion/Public/SCReconstructionManager.mm`
  - threading/queuing behavior
- [ ] `StandardCyborgFusion/Sources/StandardCyborgFusion/Public/SCMeshTexturing.mm`
  - cancel projection mid-operation
- [ ] `StandardCyborgFusion/Sources/StandardCyborgFusion/Public/SCMesh+FileIO.mm`
  - reduce/avoid disk temp usage for textures

## Log
- [x] 2026-02-28: Mac disk-space blocker cleared; generic iOS `xcodebuild build` checks now succeed for `TrueContourAI`, `TrueContourAITests`, and `TrueContourAIUITests`.
- [x] 2026-02-28: Earlier simulator build failure was caused by local `No space left on device` while creating `StandardCyborgFusion.o.lipo`, not by a source-level compile error.
- [x] 2026-02-28: Verified Xcode destination includes connected physical TrueDepth iPhone (`Riy's iPhone`).
- [x] 2026-02-28: Device smoke test `TrueContourAIDeviceSmokeTests.testDeviceSmokeStartScanFinishShowsPreview()` passed on physical iPhone via `xcodebuild test`.
- [x] 2026-02-28: Device smoke evidence captured from UI logs for:
  - `testDeviceSmokeStartScanCancelReturnsHome()` passed
  - `testDeviceSmokeSaveReportsExportArtifactPresence()` passed
- [x] 2026-02-28: `TrueContourAITests.xcscheme` corrected to stop including `TrueContourAIUITests` as a testable.
- [x] 2026-02-28: `TrueContourAITests` rerun on physical iPhone after scheme cleanup completed with `** TEST SUCCEEDED **`.
- [x] 2026-02-28: Full `TrueContourAIUITests` run on physical iPhone exposed five settings-screen failures caused by the test helper waiting for a non-visible storage-row anchor instead of an always-visible control.
- [x] 2026-02-28: Settings UI-test helper updated to stabilize against `settings.showPreScanChecklist` rather than `settings.storageUsageRow`.
- [x] 2026-02-28: Fresh full `TrueContourAIUITests` rerun completed on the unlocked device.
- [x] 2026-02-28: Full `TrueContourAIUITests` status after helper fix:
  - 17 tests executed
  - 15 passed
  - 2 failed
  - remaining failures are limited to decimate-ratio option selection in settings UI tests
- [x] 2026-02-28: The two decimate-ratio settings UI tests were fixed on physical iPhone hardware:
  - `testSettingsDecimateRatioOptionCanBeChanged`
  - `testSettingsResetRestoresProcessingDefaults`
- [x] 2026-03-03: Rollout hardening landed in app code:
  - incomplete export folders are cleaned up on fatal export failure
  - export folder names now include fractional seconds to avoid same-second collisions
  - at least one export format must remain enabled
  - scan startup now handles denied/not-determined camera access before presenting scan UI
- [x] 2026-03-03: New app-level regression coverage added for:
  - no-export-formats save precheck
  - preventing disable of the last export format in Settings
  - camera-denied / first-launch camera permission flow in `ScanCoordinator`
- [x] 2026-03-03: Added new physical-device smoke coverage for:
  - quality-gate blocked save path
  - GLTF-only export artifact diagnostics
  - OBJ-only export artifact diagnostics
- [x] 2026-03-03: Targeted physical-device export smoke rerun clarified that earlier GLTF-only / OBJ-only failures were quality-gate test noise, not export failures.
- [x] 2026-03-03: Targeted physical-device export matrix evidence now exists for:
  - `testDeviceSmokeSaveReportsExportArtifactPresence`
  - `testDeviceSmokeSaveReportsGLTFOnlyArtifacts`
  - `testDeviceSmokeSaveReportsOBJOnlyArtifacts`
- [x] 2026-03-03: Device-smoke harness now disables the quality gate for export-artifact tests unless the test explicitly forces a quality-gate block.
- [x] 2026-03-03: Device-smoke diagnostics now include `folder=...` again after save success so hardware export assertions can validate the saved folder name consistently.
- [x] 2026-03-03: Explicit physical-device quality-gate evidence captured:
  - `testDeviceSmokeQualityGateBlockShowsAlert` passed on `Riy's iPhone`
- [x] 2026-03-03: Full `TrueContourAIUITests` run on `Riy's iPhone` completed with one remaining failure:
  - 20 tests executed
  - 19 passed
  - 1 failed
  - remaining failure was `testStartScanUnavailableShowsAlert`
- [x] 2026-03-03: `testStartScanUnavailableShowsAlert` was fixed to handle the pre-scan checklist path and then passed in a targeted physical-device rerun.
- [x] 2026-03-03: `testDeviceSmokeStartScanFinishShowsPreview` later failed in a full hardware suite rerun because the scan shutter did not become ready within the original short timeout, then passed in a targeted physical-device rerun after the test was hardened to wait for a hittable shutter button.
- [ ] 2026-03-03: A second post-fix full `TrueContourAIUITests` rerun was started on `Riy's iPhone`, but the live `xcodebuild test-without-building` session remained unresolved long past the earlier full-run duration and did not finalize a readable `.xcresult` bundle before this note.
- [ ] 2026-03-03: Focused simulator `xcodebuild test` rerun for the new unit tests did not complete due to simulator/runtime startup issues; test targets still compile cleanly.
- [x] 2026-03-04: Recovery validation on the standalone app repo succeeded:
  - `TrueContourAI` builds cleanly
  - `TrueContourAITests` builds cleanly
  - `TrueContourAIUITests` builds cleanly
- [x] 2026-03-04: Full `TrueContourAITests` simulator run completed with `** TEST SUCCEEDED **` after hardening fixes:
  - `SettingsViewControllerTests.testRefreshStorageUsageTransitionsFromCalculatingToResolvedText` now passes in focused and full reruns
  - `ScanCoordinatorTests.testStartScanFlowAppliesConfigurationToScanningViewController` was made deterministic by pinning camera authorization to `.authorized`
- [x] 2026-03-04: Production-hardening milestones landed through active-flow structural cleanup:
  - GLTF is now required for saved scans the app can reopen in-app
  - fake last-scan metadata was removed from Home
  - saved summary confidence no longer uses the old hard-coded `0.85`
  - unsupported advanced processing controls were removed from Settings
  - scan runtime safety was tightened around readiness, queue access, and thermal shutdown
  - preview async callbacks are now guarded by preview-session identity
  - package integration was hardened in low-risk areas (`CameraManager`, bundle lookup, meshing error fallback, preview scene fallback)
  - `ViewController` was renamed to `HomeViewController`
- [x] 2026-03-04: Fresh simulator UI evidence was captured for the updated settings flow:
  - `TrueContourAIUITests.testSettingsShowsAdvancedSection()` passed on `iPhone 17 Pro` simulator
  - `xcodebuild test` completed with `** TEST SUCCEEDED **` and produced:
    - `~/Library/Developer/Xcode/DerivedData/TrueContourAI-emphtlquybacfifpqnuczgkofhot/Logs/Test/Test-TrueContourAIUITests-2026.03.04_20-31-42-+0200.xcresult`
- [x] 2026-03-05: Fresh full `TrueContourAITests` simulator rerun passed after widening the flaky async timeout in `SettingsViewControllerTests`:
  - `xcodebuild test -scheme TrueContourAITests` completed with `** TEST SUCCEEDED **`
  - `SettingsViewControllerTests.testRefreshStorageUsageTransitionsFromCalculatingToResolvedText` passed in the full suite
- [x] 2026-03-05: Physical TrueDepth smoke evidence refreshed on `Riy’s iPhone`:
  - `testDeviceSmokeStartScanFinishShowsPreview` passed
  - `testDeviceSmokeStartScanCancelReturnsHome` passed
  - `testDeviceSmokeQualityGateBlockShowsAlert` passed
  - `testDeviceSmokeSaveReportsGLTFOnlyArtifacts` passed
  - `testDeviceSmokeGLTFDisableLaunchArgIsIgnored` passed
  - `testDeviceSmokeSaveReportsExportArtifactPresence` initially failed due a brittle home/diagnostics assertion, then passed after switching to the shared `saveAndReturnDiagnostics` helper
- [ ] 2026-03-05: Full simulator `TrueContourAIUITests` runs remain unstable in this environment:
  - long-running `xcodebuild test` sessions can terminate with CoreSimulator state failures (e.g., Mach `ipc/mig server died`, `Invalid device state`) before emitting final XCTest summaries
  - device smoke evidence above is treated as the primary release signal for TrueDepth-critical flows
- [ ] 2026-03-05: `swift test --package-path StandardCyborgFusion` fails in this environment while linking package tests with:
  - `ld: framework 'UIKit' not found`
  - this is tracked as an environment/toolchain limitation for SwiftPM package-test execution rather than an app-target runtime regression
