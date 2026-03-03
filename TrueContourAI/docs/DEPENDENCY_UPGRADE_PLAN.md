# Dependency Upgrade Plan (TrueContourAI)

This plan updates vendored dependencies safely, with small steps and explicit rollback points.

Date baseline: February 27, 2026.

## Goals
- Reduce security/stability risk from stale dependencies.
- Keep scan, preview, and export behavior stable.
- Avoid large-batch upgrades that are hard to debug.

## Current Local Baseline (Observed)
- `CppDependencies/json`: `nlohmann/json` 3.11.3
- `CppDependencies/Eigen`: Eigen 3.4.0
- `CppDependencies/tinygltf`: older snapshot (local README shows up to v2.4.0)
- `StandardCyborgFusion/libigl`: legacy snapshot (older than current upstream)

## Upgrade Policy
1. Upgrade one dependency at a time.
2. Build + targeted tests after each dependency upgrade.
3. Commit each dependency step separately.
4. If regressions appear, revert only the current step and continue later.

## Validation Gates Per Step
Run all three gates before moving to the next dependency:

1. App build:
```bash
xcodebuild build -project TrueContourAI.xcodeproj -scheme TrueContourAI -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

2. Unit tests build:
```bash
xcodebuild build -project TrueContourAI.xcodeproj -scheme TrueContourAITests -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

3. On-device smoke pass (TrueDepth iPhone):
- Start scan
- Complete scan capture
- Generate preview mesh
- Export/share scan

## Execution Order

## Phase 1 (Low Risk): `nlohmann/json` 3.11.3 -> 3.12.x
Why first:
- Header-only and generally low integration risk.

Watch for:
- Compiler warnings/errors from stricter templates.
- Behavior changes in JSON parse/serialize edge cases.

Done when:
- All validation gates pass.

## Phase 2 (Low/Medium Risk): Eigen 3.4.0 -> 3.4.1
Why now:
- Patch-level update before considering major jump.

Watch for:
- Numeric behavior shifts in geometry ops.
- Any compile breaks in `StandardCyborgFusion`.

Done when:
- All validation gates pass.

## Phase 3 (Medium Risk): tinygltf (current snapshot -> latest stable 2.x)
Why separate:
- Can affect mesh/asset export and metadata handling.

Watch for:
- GLTF/GLB export compatibility.
- Texture/image write paths.
- Changes around extension parsing.

Extra checks:
- Compare output files from before/after upgrade for schema compatibility.

Done when:
- All validation gates pass and exports open correctly in at least one external viewer.

## Phase 4 (High Risk): libigl (legacy snapshot -> pinned newer release)
Why last:
- Geometry kernels are core to mesh behavior; this can break runtime and numerics.

Watch for:
- API drift and renamed headers/functions.
- Topology/mesh cleanup behavior changes.
- Performance regressions in preview/export.

Extra checks:
- Run representative scans (good, average, noisy) and compare quality outcomes.

Done when:
- All validation gates pass and no user-visible quality regression is found.

## Phase 5 (Optional, Deferred): Major upgrades (e.g., Eigen 5.x)
Only start this phase after prior phases are stable in production-like testing.

## Rollback Criteria
Rollback the current phase if any of the below occurs:
- Build break in app or test targets.
- Scan pipeline crash or hang.
- Export failures increase.
- Mesh quality regresses materially on same test scans.

Rollback method:
- Revert only the dependency update commit for that phase.
- Keep prior successful phases.

## Ownership and Tracking
- Track each phase in `docs/TODO.md` as separate items.
- Record final upgraded versions and date in `README.md` once complete.
- Keep this plan updated when priorities or constraints change.
