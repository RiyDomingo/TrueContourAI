# TrueContourAI Review Checklist

Use this checklist for code reviews, release readiness checks, and handoffs.

## 1) Scope and Intent
- Confirm the PR/task goal is clearly stated.
- Confirm changed files match the stated goal.
- Confirm no unrelated legacy code was pulled into active app paths.

## 2) Build Integrity
Run and confirm:
```bash
xcodebuild build -project TrueContourAI.xcodeproj -scheme TrueContourAI -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project TrueContourAI.xcodeproj -scheme TrueContourAITests -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project TrueContourAI.xcodeproj -scheme TrueContourAIUITests -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

- No build errors.
- Warnings are reviewed and understood.

## 3) Test Coverage and Wiring
- New tests are added for new logic.
- New test files are wired into target sources if required.
- Existing test suites still compile.
- UI tests use deterministic launch arguments and seeded data.
- Unit and UI test schemes are kept separate unless there is an explicit reason to combine them.

## 4) Scan Engine Safety (High Priority)
For any scan-related changes, verify:
- `ScanCoordinator` capability checks remain correct.
- `AppScanningViewController` cancel/finish/error paths still terminate correctly.
- Quality gate behavior remains intentional.
- Export prechecks restore UI state on failure paths.

If scan runtime behavior changed:
- Plan/execute smoke verification on physical TrueDepth iPhone.
- Do not treat simulator-only verification as complete for scan engine changes.
- Device smoke UI tests (`TrueContourAIDeviceSmokeTests`) must be run on hardware; skip/fail in simulator is expected.
- Confirm exported artifact presence matches active export settings (`scene.gltf`, `head_mesh.obj`).

## 5) Architecture and Boundaries
- View controllers are not overloaded with orchestration logic.
- Coordinators/services own flow and IO behavior.
- Protocol seams are used where deterministic tests are needed.
- No dependency path breakage for `StandardCyborgFusion`, `StandardCyborgUI`, `scsdk`, `CppDependencies`.

## 6) File System Hygiene
- Active app code stays in active folders.
- Legacy content remains in `LegacyArchive/`.
- No accidental generated artifacts committed (`build/`, temporary outputs, etc.).
- No duplicate file variants (for example, `* 2.swift`, `* 2.md`) unless explicitly intentional.

## 7) User-Facing Behavior
- Localizable strings are used for new UI text.
- No hardcoded user-facing UI strings in feature code.
- Settings and alerts are clear and actionable.
- Error messages avoid leaking sensitive path details.
- Accessibility identifiers remain stable for UI tests.
- Settings keeps the intended information architecture:
  - General, Export, Advanced, Storage.
- New or changed scan/export messages must be validated in context on device, not only by string review.

## 8) Documentation Updates
If behavior/structure changed, update:
- `README.md`
- `ARCHITECTURE.md`
- `DEVELOPMENT.md`
- `docs/SCAN_ENGINE.md` or `docs/REPO_LAYOUT.md` as applicable

## 9) Reviewer Output Template
Use this simple summary format:

1. **What changed:**
- ...

2. **Risk level:**
- Low / Medium / High

3. **What was validated:**
- Build: pass/fail
- Tests: pass/fail
- Device smoke (if scan engine touched): done/not done

4. **Open issues or follow-ups:**
- ...
