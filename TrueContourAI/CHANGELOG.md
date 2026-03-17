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
- Ear verification recovery now documents and enforces separate coordinate contracts for detector bbox rendering vs landmark point rendering, and persists device-debug artifacts under `Documents/Scans/EarDebug`.
- `Verify Ear` now lives in the normal preview summary UI instead of the developer-only section.
- Ear verification now prefers a preserved capture-faithful scan frame over preview snapshot fallback, while keeping the full-scene overlay for UI context and the crop overlay for QA.
- Scan-time ear verification image selection now scores capture frames for side-profile strength and tracking quality, preferring the best candidate over the simple latest-frame policy and recording the winning frame metadata in debug output.
- UI-test scan seeding now includes a deterministic `ear_view.png`, and autonomous preview/device-smoke tests can trigger `Verify Ear` without a fresh manual scan.

### Fixed
- Stabilized settings UI-test helpers to wait for an always-visible settings control instead of a non-visible storage-row anchor
- Removed synchronous capture-state reads from scan callbacks.
- Hardened package/runtime setup so several Metal/camera failure paths degrade instead of crashing immediately.
- Full `TrueContourAIUITests` rerun on `Riy's iPhone` passed after tightening the device-smoke save/reopen helper.
- Fixed a double Y-flip in ear landmark overlay rendering that was placing accepted landmark points above the ear even when crop generation and model output were valid.

### Validation
- `TrueContourAIUITests` full physical-device rerun on `Riy's iPhone`: 22 tests passed, 0 failed on 2026-03-09
- Focused repeated physical-device smoke for `testDeviceSmokeSaveThenReopenFromHome` stayed green across the preview/service/runtime refactor slices on 2026-03-09
- Ear landmark recovery and overlay fixes: build-verified on 2026-03-14; physical-device confirmation of final anatomical placement still pending on the latest build
