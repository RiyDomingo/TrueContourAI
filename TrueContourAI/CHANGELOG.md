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

### Changed
- Separated `TrueContourAITests` from `TrueContourAIUITests` in the shared unit-test scheme
- Updated repo documentation to reflect physical-device TrueDepth validation requirements

### Fixed
- Stabilized settings UI-test helpers to wait for an always-visible settings control instead of a non-visible storage-row anchor
