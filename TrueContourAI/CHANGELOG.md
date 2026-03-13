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
- Preview runtime collaborators:
  - `PreviewSessionController`
  - `PreviewPresentationController`
  - `PreviewRoutingController`
  - `PreviewInteractionController`
  - `PreviewExportController`
  - `PreviewResetController`
  - `PreviewActionController`
  - `PreviewSceneUIController`
  - `PreviewCoordinatorComponents`
- Scan runtime collaborators:
  - `ScanSessionController`
  - `ScanRuntimeController`
  - `ScanHUDController`
- Scan storage/export collaborators:
  - `ScanRepository`
  - `ScanExporterService`
  - `ScanTestSeedService`
- Home/Settings support collaborators:
  - `HomeScanSessionController`
  - `HomeScanFlowController`
  - `HomeRecentScansController`
  - `HomeFeedbackController`
  - `SettingsFeedbackController`

### Changed
- Separated `TrueContourAITests` from `TrueContourAIUITests` in the shared unit-test scheme
- Updated repo documentation to reflect physical-device TrueDepth validation requirements
- Preview/save/reopen flow no longer depends on a single oversized coordinator for most workflow state.
- Scan/session/HUD lifecycle is no longer centered entirely inside `AppScanningViewController`.
- Normal app composition now builds repository/export services directly instead of centering everything on the legacy `ScanService` facade.
- Scan domain models now live outside `ScanService` so the scan domain is no longer nested under a compatibility sidecar type.
- Test infrastructure now prefers real repository/export services and records stronger physical-device evidence for the main save/reopen flow.

### Fixed
- Stabilized settings UI-test helpers to wait for an always-visible settings control instead of a non-visible storage-row anchor
- Removed synchronous capture-state reads from scan callbacks.
- Hardened package/runtime setup so several Metal/camera failure paths degrade instead of crashing immediately.
- Full `TrueContourAIUITests` rerun on `Riy's iPhone` passed after tightening the device-smoke save/reopen helper.

### Validation
- `TrueContourAIUITests` full physical-device rerun on `Riy's iPhone`: 22 tests passed, 0 failed on 2026-03-09
- Focused repeated physical-device smoke for `testDeviceSmokeSaveThenReopenFromHome` stayed green across the preview/service/runtime refactor slices on 2026-03-09
