# TODO Triage

This document explains how to treat TODO/FIXME/XXX markers found in the repository.

## Summary
Not all TODOs are equal. Most markers currently found in this repo are in third-party dependencies and should not block application development.

## Categories

## 1) Actionable Now (first-party, high impact)
These are in actively used scan-runtime code paths and may affect reliability/performance.

Current known items:
- `StandardCyborgFusion/Sources/StandardCyborgFusion/Public/SCReconstructionManager.mm`
  - TODO: threading/queuing behavior
- `StandardCyborgFusion/Sources/StandardCyborgFusion/Public/SCMeshTexturing.mm`
  - TODO: cancel projection mid-operation
- `StandardCyborgFusion/Sources/StandardCyborgFusion/Public/SCMesh+FileIO.mm`
  - TODO: reduce/avoid disk temp usage for textures

Policy:
- Evaluate and schedule these when touching scan engine/export internals.
- Add targeted tests if behavior changes.

## 2) Defer (first-party but low current ROI)
These include TODOs in bundled library internals under `StandardCyborgFusion/libigl/...`.

Policy:
- Do not modify unless you are already changing that exact area.
- Treat as technical debt backlog, not immediate blockers.

## 3) Third-Party Ignore by Default
These include markers in:
- `scsdk/...`
- `CppDependencies/...`

Policy:
- Do not open work items for these by default.
- Only act if a specific bug/performance issue is traced there.

## Triage Decision Rule
When you find a TODO/FIXME/XXX, decide in this order:
1. Is it in active app runtime paths? (`TrueContourAI/`, core `StandardCyborgFusion` public runtime files)
2. Is it tied to current planned work?
3. Does it have user-visible impact or stability risk?

If all are yes -> move into `docs/TODO.md` under `Now` or `Next`.
Otherwise -> leave in place and document under deferred/ignore policy.

## Release Readiness Guidance
Do not block release purely due to third-party TODO counts.
Block only on unresolved issues that affect:
- correctness,
- crash risk,
- scan/export success rate,
- data loss/security.

## Optional Future Improvement
Add an automated TODO report script that outputs counts by category:
- app first-party
- fusion core
- bundled library internals
- third-party dependencies

