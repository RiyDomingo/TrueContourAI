# Release Checklist

Use this checklist before a serious handoff, TestFlight build, or tagged release.

## Build
- [ ] `TrueContourAI` builds cleanly.
- [ ] `TrueContourAITests` builds cleanly.
- [ ] `TrueContourAIUITests` builds cleanly.
- [ ] Any local environment blocker affecting build/test validity is recorded in `docs/TODO.md` with date and current status.

## Tests
- [ ] Run `TrueContourAITests` and record pass/fail summary.
- [ ] Run `TrueContourAIUITests` and record pass/fail summary.
- [ ] Run `StandardCyborgFusion` tests if fusion/package code changed, scan-quality behavior changed unexpectedly, or a dependency update touched that package.
- [ ] Do not treat `StandardCyborgFusion` tests as a mandatory gate for UI-only or app-orchestration-only releases.
- [ ] Classify any failure as product bug, test bug, device/environment issue, or hardware-gated skip.
- [ ] Keep the connected iPhone unlocked during physical-device test runs.
- [ ] Remaining known failures in `docs/TODO.md` are either fixed or explicitly accepted before release.

## Physical TrueDepth Validation
- [ ] Start scan -> finish -> preview
- [ ] Start scan -> cancel -> return home
- [ ] Save/export succeeds from preview
- [ ] Reopen saved scan from Home
- [ ] Manual finish path is stable
- [ ] Quality-gate blocked export flow is validated
- [ ] Evidence for each validated device flow is recorded in `docs/TODO.md`.

## Export Artifact Verification
- [ ] `GLTF on / OBJ on`
- [ ] `GLTF on / OBJ off`
- [ ] `GLTF off / OBJ on`
- [ ] Verify the app prevents `GLTF off / OBJ off` because at least one export format must remain enabled.
- [ ] Saved artifact set matches active settings
- [ ] Evidence for the active export matrix is recorded in `docs/TODO.md`.

Note: as of March 3, 2026, `docs/TODO.md` contains targeted iPhone evidence for the three valid export combinations. Keep this checklist unchecked until that evidence is rolled into the final release-signoff pass.

## Documentation
- [ ] `README.md` reflects current commands and hardware rules
- [ ] `DEVELOPMENT.md` reflects current workflow
- [ ] `docs/SCAN_ENGINE.md` reflects current lifecycle
- [ ] `docs/TODO.md` has dated evidence entries
- [ ] `CHANGELOG.md` records notable behavior and validation-relevant changes

## Repository Hygiene
- [ ] No duplicate file variants left in active scope
- [ ] Legacy content remains under `LegacyArchive/`
- [ ] `.gitignore` covers normal local clutter
- [ ] No generated artifacts are being committed unintentionally
