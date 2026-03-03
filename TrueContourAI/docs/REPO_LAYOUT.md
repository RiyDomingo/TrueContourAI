# Repository Layout

This document tells reviewers what is active, what is dependency support, and what is legacy.

## Active App Scope (edit frequently)
- [TrueContourAI](../TrueContourAI)
- [TrueContourAI.xcodeproj](../TrueContourAI.xcodeproj)
- [TrueContourAITests](../TrueContourAITests)
- [TrueContourAIUITests](../TrueContourAIUITests)

## Active Dependency Scope (edit with care)
- [StandardCyborgFusion](../StandardCyborgFusion)
- [StandardCyborgUI](../StandardCyborgUI)
- [scsdk](../scsdk)
- [CppDependencies](../CppDependencies)

These are referenced by local Swift package paths. Moving/renaming breaks dependency resolution.

## Legacy/Archived Scope (do not use for new work)
- [LegacyArchive](../LegacyArchive)

Current archived items include:
- `TrueDepthFusion`
- `StandardCyborgSDK.xcodeproj`
- `StandardCyborgAlgorithmsTestbed`
- historical duplicate `README 2.md`
- generated `build` artifacts

## Rule of Thumb
- If a file/folder is not referenced by `TrueContourAI.xcodeproj` targets or local package references, it should stay archived.
- Do not copy code from legacy folders into active app without explicit review.

## Quick Validation After Any Reorganization
1. Build app scheme `TrueContourAI`.
2. Build `TrueContourAITests`.
3. Build `TrueContourAIUITests`.
4. Open project in Xcode and confirm no broken file references.

## Suggested Folder Policy Going Forward
- Keep root focused on active project and dependencies.
- Keep all retired projects in `LegacyArchive/`.
- Periodically remove generated artifacts (`DerivedData`, local `build` outputs).
- Keep docs current when moving folders.

