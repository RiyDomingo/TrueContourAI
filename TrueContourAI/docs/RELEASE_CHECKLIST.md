# Release Checklist

Use this checklist before a serious handoff, TestFlight build, or tagged release.

## Build
- [x] `TrueContourAI` builds cleanly.
- [x] `TrueContourAITests` builds cleanly.
- [x] `TrueContourAIUITests` builds cleanly.
- [x] Any local environment blocker affecting build/test validity is recorded in `docs/TODO.md` with date and current status.

## Tests
- [x] Run `TrueContourAITests` and record pass/fail summary.
- [x] Run `TrueContourAIUITests` and record pass/fail summary.
- [ ] Re-run focused/unit validation after any package-rendering hardening or runtime-environment refactor that changes scan/preview bootstrap behavior.
- [ ] Run `StandardCyborgFusion` tests if fusion/package code changed, scan-quality behavior changed unexpectedly, or a dependency update touched that package.
- [ ] Do not treat `StandardCyborgFusion` tests as a mandatory gate for UI-only or app-orchestration-only releases.
- [x] Classify any failure as product bug, test bug, device/environment issue, or hardware-gated skip.
- [x] Keep the connected iPhone unlocked during physical-device test runs.
- [x] Remaining known failures in `docs/TODO.md` are either fixed or explicitly accepted before release.

## Physical TrueDepth Validation
- [x] Start scan -> finish -> preview
- [x] Start scan -> cancel -> return home
- [x] Save/export succeeds from preview
- [ ] Reopen saved scan from Home
- [x] Manual finish path is stable
- [x] Quality-gate blocked export flow is validated
- [ ] Device smoke rerun after UI-test harness changes that remove synthetic preview shortcuts
- [x] Evidence for each validated device flow is recorded in `docs/TODO.md`.

## Export Artifact Verification
- [x] `GLTF on / OBJ on`
- [x] `GLTF on / OBJ off`
- [x] Verify the app prevents `GLTF off / OBJ on` because GLTF is required for reopenable saved scans.
- [x] Verify the app prevents `GLTF off / OBJ off`.
- [x] Saved artifact set matches active settings
- [x] Evidence for the active export matrix is recorded in `docs/TODO.md`.

Note: as of March 5, 2026, OBJ-only is no longer treated as a valid saved-scan export mode. Export-matrix evidence is tracked in `docs/TODO.md`.

## Documentation
- [ ] `README.md` reflects current commands and hardware rules
- [ ] `DEVELOPMENT.md` reflects current workflow
- [ ] `docs/SCAN_ENGINE.md` reflects current lifecycle
- [x] `docs/TODO.md` has dated evidence entries
- [ ] `CHANGELOG.md` records notable behavior and validation-relevant changes

## Repository Hygiene
- [ ] No duplicate file variants left in active scope
- [ ] Legacy content remains under `LegacyArchive/`
- [ ] `.gitignore` covers normal local clutter
- [ ] No generated artifacts are being committed unintentionally
