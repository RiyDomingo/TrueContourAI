# Scan Engine Guide

This document explains how scanning works in TrueContourAI and what to review when changing scan behavior.

## Executive Summary
TrueContourAI scan runtime is built on StandardCyborg components and most closely resembles the historical `TrueDepthFusion` flow:
- Camera stream from `CameraManager`
- Reconstruction through `SCReconstructionManager`
- Texturing via `SCMeshTexturing`
- Final handoff into `PreviewCoordinator`, `PreviewViewController`, and `PreviewStore`

## Main Runtime Classes
- [TrueContourAI/Features/Scan/AppScanningViewController.swift](../TrueContourAI/Features/Scan/AppScanningViewController.swift)
- [TrueContourAI/Features/Scan/ScanStore.swift](../TrueContourAI/Features/Scan/ScanStore.swift)
- [TrueContourAI/Features/Scan/ScanCaptureService.swift](../TrueContourAI/Features/Scan/ScanCaptureService.swift)
- [TrueContourAI/Features/Scan/ScanRuntimeEngine.swift](../TrueContourAI/Features/Scan/ScanRuntimeEngine.swift)
- [TrueContourAI/Features/Scan/ScanSessionController.swift](../TrueContourAI/Features/Scan/ScanSessionController.swift)
- [TrueContourAI/Features/Scan/ScanCoordinator.swift](../TrueContourAI/Features/Scan/ScanCoordinator.swift)
- [TrueContourAI/Features/Scan/ScanAssembler.swift](../TrueContourAI/Features/Scan/ScanAssembler.swift)
- [TrueContourAI/Features/Preview/PreviewCoordinator.swift](../TrueContourAI/Features/Preview/PreviewCoordinator.swift)
- [TrueContourAI/Features/Preview/PreviewViewController.swift](../TrueContourAI/Features/Preview/PreviewViewController.swift)
- [TrueContourAI/Core/Services/ScanRepository.swift](../TrueContourAI/Core/Services/ScanRepository.swift)
- [TrueContourAI/Core/Services/ScanExporterService.swift](../TrueContourAI/Core/Services/ScanExporterService.swift)

## Lifecycle
1. `ScanCoordinator.startScanFlow(...)`
- Checks runtime capability and simulator/device constraints.
- Requests a fully assembled scan feature from `ScanAssembler` and presents `AppScanningViewController`.

2. `AppScanningViewController` binds scan state and forwards scan intents
- Renders live preview.
- Forwards start, finish, dismiss, and focus events into `ScanStore`.
- Applies `ScanStore` state/effects to the scan HUD and accessibility surface.
- Hot-path rule: camera callbacks must not create `UIImage` / `CIImage` / `CIContext`, run ML, or do heavy scoring/allocation work. Any preserved-frame design must use bounded retention and defer conversion until after scanning.

3. `ScanCaptureService` owns the TrueDepth capture session
- Starts/stops `CameraManager`.
- Delivers synchronized color + depth frames.
- Handles focus requests and camera lifecycle.

4. `ScanRuntimeEngine` owns reconstruction/runtime work
- Consumes frame payloads from `ScanCaptureService`.
- Drives reconstruction, metrics, thermal warnings, and preview payload creation.

5. `ScanSessionController`
- `ScanSessionController` owns countdown and auto-finish timer mechanics.
- Runtime activation/deactivation now routes through `ScanStore` + `ScanRuntimeEngine`; there is no separate runtime policy owner in the active scan flow.

## Hot Path Constraints
- Allowed in camera / reconstruction callbacks:
  - lightweight scalar bookkeeping
  - preview rendering
  - reconstruction accumulation
  - bounded guidance / progress state updates
- Not allowed in camera / reconstruction callbacks:
  - image conversion
  - Core ML
  - verbose per-frame logging
  - repeated expensive string formatting
  - unbounded array growth or repeated heavy allocation
- Any new capture-time feature must prove it does not materially increase callback cost on a physical TrueDepth iPhone.

## Scan Stability Checklist
- No per-frame or per-motion logs in active scanning.
- UI updates are throttled; critical transitions remain immediate.
- No image / ML / heavy diagnostics work runs in the synchronized camera callback.
- Validate depth resolution and texture-save interval on the connected TrueDepth iPhone before and after changes.
- Compare tracking stability, preview output, and export behavior against the pre-change device baseline.

6. Reconstruction callbacks
- Uses `SCReconstructionManagerDelegate` callbacks for tracking state.
- Saves color buffers periodically for mesh texturing.

7. Finish/cancel behavior
- `ScanStore` owns the UI-facing finish/cancel state transitions.
- Cancel path resets reconstruction and returns delegate cancel callback.
- Manual finish path finalizes reconstruction, builds point cloud, and returns delegate scan callback.
- Auto-finish uses the configured scan duration when enabled.
- Both finish paths should be validated on a physical TrueDepth device.

8. Preview and export
- `PreviewCoordinator` routes presentation only.
- `PreviewViewController` hosts preview UI and forwards intents into `PreviewStore`.
- `PreviewExportUseCase` performs save prechecks and export execution.
- Quality gate can block export if thresholds fail.
- Save flow calls `ScanExporterService.exportScanFolder(...)`.
- Existing-scan reopen flows load summaries/artifacts through `ScanRepository`.
- Exported artifact set depends on settings:
  - `Export GLTF` controls `scene.gltf`
  - `Export OBJ` controls `head_mesh.obj`
  - metadata/thumbnail outputs remain part of the saved scan folder flow

## Important Seams Added for Testability
`AppScanningViewController` and the scan runtime now use protocol seams around high-risk dependencies:
- `ReconstructionManaging`
- `CameraManaging`
- `ScanningHapticFeedbackProviding`

These seams allow deterministic unit tests of cancel/finish/error lifecycle without live hardware runtime coupling.

## Ear Verification Note
Ear verification recovery work, coordinate contracts, and device-debug workflow are documented in:

- [docs/EAR_LANDMARKING_RECOVERY.md](./EAR_LANDMARKING_RECOVERY.md)

## Quality Gate Behavior
Quality is evaluated from point cloud properties:
- valid points
- valid/raw ratio
- physical bounds sanity
- quality score threshold

If gate is enabled and quality is insufficient, export is blocked and guidance is shown.

Relevant file:
- [TrueContourAI/Features/Scan/ScanQuality.swift](../TrueContourAI/Features/Scan/ScanQuality.swift)

## Export Orchestration
Preview export flow does prechecks and state transitions before calling export:
- `blockedByQualityGate`
- `meshNotReady`
- `ready`

On success, it updates last scan folder and notifies observers.
On failure, it restores preview UI state.
Quality-gate blocking should be reviewed both for logic and for end-user recovery messaging.

Policy coverage note:
- runtime override matrices, GLTF/OBJ policy, and preview save prechecks are now primarily covered in unit tests
- physical-device smoke should stay focused on true capture/preview/save/reopen workflows rather than diagnostics-only artifact assertions

## Why It Resembles TrueDepthFusion
Compared to `StandardCyborgExample`, this app has richer orchestration around the same underlying scan primitives:
- explicit scan lifecycle transitions
- manual finish and auto-finish handling
- quality gating and remediation messaging
- export orchestration and metadata summaries

That makes it operationally much closer to `TrueDepthFusion` style architecture.

## Hardware Testing Rule
Any change to scan capture/reconstruction/finalize paths must be validated on a physical TrueDepth iPhone.
This includes:
- manual finish
- cancel during active scan
- save/export after preview
- quality-gate blocked export
- artifact verification against export settings
