# TrueContourAI Development Guide

This guide is for day-to-day development, code review prep, and reliable local testing.

## Prerequisites
- Xcode (current team-supported version).
- macOS with command line tools installed.
- Physical iPhone with TrueDepth camera for real scan testing.

## Open and Build
1. Open [TrueContourAI.xcodeproj](./TrueContourAI.xcodeproj).
2. Allow SwiftPM to resolve dependencies.
3. Build app scheme `TrueContourAI`.

CLI build example:
```bash
xcodebuild build -project TrueContourAI.xcodeproj -scheme TrueContourAI -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

## Test Strategy
### Unit tests
- Scheme: `TrueContourAITests`
- Covers scan quality, coordinators, view models, settings behavior, export prechecks.

```bash
xcodebuild build -project TrueContourAI.xcodeproj -scheme TrueContourAITests -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project TrueContourAI.xcodeproj -scheme TrueContourAITests -destination 'id=<DEVICE_ID>'
```

### UI tests
- Scheme: `TrueContourAIUITests`
- Uses launch arguments and seeded data to keep tests deterministic.

```bash
xcodebuild build -project TrueContourAI.xcodeproj -scheme TrueContourAIUITests -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project TrueContourAI.xcodeproj -scheme TrueContourAIUITests -destination 'id=<DEVICE_ID>'
```

- Keep the test device unlocked for the full run. Xcode destination preflight will block launch if the phone locks.
- Record environment blockers separately from product failures in `docs/TODO.md`:
  - device locked
  - signing/provisioning issue
  - host cache/DerivedData issue
- Prefer physical-device UI evidence over simulator evidence for:
  - scan start/finish/cancel
  - preview save/export
  - save -> return home -> reopen
  - quality-gate blocked export

### Hardware smoke tests
- Run selected tests on connected iPhone when touching scan engine paths.
- Simulator cannot validate TrueDepth scanning pipeline behavior.
- Record device evidence in `docs/TODO.md` after each smoke run.
- Preferred smoke coverage:
  - start scan -> finish -> preview
  - start scan -> cancel -> return home
  - save/export produces expected artifacts
  - quality-gate block path
  - manual finish path

## Required Review Checks Before Merge
- App scheme builds clean.
- Unit test scheme builds clean.
- UI test scheme builds clean.
- Unit and UI tests are run, not only built, when behavior has changed materially.
- No accidental dependency path breakage.
- No legacy folder reintroduction into active app target.
- If scan/preview bootstrap changes, rerun focused smoke on the connected iPhone before treating the slice as complete.

## Coding Expectations
- Keep UI programmatic.
- Keep user-facing text localized in `Localizable.strings`.
- Do not add hardcoded user-facing strings in view/controller files.
- Use services/coordinators instead of pushing orchestration into view controllers.
- Prefer protocol seams for high-risk runtime dependencies.
- Prefer concrete feature collaborators over adding more helper methods inside the same oversized coordinator/controller file.

## Current Architecture Direction
- `HomeViewController` should mainly bind and forward intents.
- `AppScanningViewController` should mainly bind scan UI and camera callbacks, not own all runtime state directly.
- `ScanPreviewCoordinator` is now composition-focused; new preview behavior should land in preview collaborators first, not back in the coordinator.
- New scan persistence/export work should target `ScanRepository` / `ScanExporterService`, not expand the legacy `ScanService` compatibility facade.

## Logging and Diagnostics
- Use existing structured `Log.*` channels.
- Avoid `print(...)` for operational events.
- Keep privacy-sensitive paths/data logged as private.

## Common Pitfalls
- Running scan behavior on simulator and assuming parity.
- Treating build success as equivalent to a completed test pass.
- Mixing unit and UI test bundles into the same scheme test action.
- Editing package folder structure without checking SwiftPM local references.
- Adding files to disk without wiring them to target sources.
- Mixing legacy app code into active TrueContourAI paths.

## Safe Cleanup Policy
- Move obsolete folders into `LegacyArchive/` first.
- Verify build/test schemes still succeed.
- Delete archived content only after team confirmation.

## Related Docs
- [README.md](./README.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [docs/SCAN_ENGINE.md](./docs/SCAN_ENGINE.md)
- [docs/REPO_LAYOUT.md](./docs/REPO_LAYOUT.md)
- [docs/REVIEW_CHECKLIST.md](./docs/REVIEW_CHECKLIST.md)
- [docs/TODO.md](./docs/TODO.md)
- [CHANGELOG.md](./CHANGELOG.md)
- [docs/TODO_TRIAGE.md](./docs/TODO_TRIAGE.md)
- [docs/DEPENDENCY_UPGRADE_PLAN.md](./docs/DEPENDENCY_UPGRADE_PLAN.md)
