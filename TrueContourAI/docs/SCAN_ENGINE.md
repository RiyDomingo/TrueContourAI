# Scan Engine Guide

This document explains how scanning works in TrueContourAI and what to review when changing scan behavior.

## Executive Summary
TrueContourAI scan runtime is built on StandardCyborg components and most closely resembles the historical `TrueDepthFusion` flow:
- Camera stream from `CameraManager`
- Reconstruction through `SCReconstructionManager`
- Texturing via `SCMeshTexturing`
- Final handoff into preview/export coordinator

## Main Runtime Classes
- [TrueContourAI/Features/Scan/AppScanningViewController.swift](../TrueContourAI/Features/Scan/AppScanningViewController.swift)
- [TrueContourAI/Features/Scan/ScanSessionController.swift](../TrueContourAI/Features/Scan/ScanSessionController.swift)
- [TrueContourAI/Features/Scan/ScanRuntimeController.swift](../TrueContourAI/Features/Scan/ScanRuntimeController.swift)
- [TrueContourAI/Features/Scan/ScanHUDController.swift](../TrueContourAI/Features/Scan/ScanHUDController.swift)
- [TrueContourAI/Features/Scan/ScanCoordinator.swift](../TrueContourAI/Features/Scan/ScanCoordinator.swift)
- [TrueContourAI/Features/Preview/ScanPreviewCoordinator.swift](../TrueContourAI/Features/Preview/ScanPreviewCoordinator.swift)
- [TrueContourAI/Core/Services/ScanRepository.swift](../TrueContourAI/Core/Services/ScanRepository.swift)
- [TrueContourAI/Core/Services/ScanExporterService.swift](../TrueContourAI/Core/Services/ScanExporterService.swift)

## Lifecycle
1. `ScanCoordinator.startScanFlow(...)`
- Checks runtime capability and simulator/device constraints.
- Creates and configures `AppScanningViewController`.

2. `AppScanningViewController` starts camera session
- Receives synchronized color + depth frames.
- Renders live preview.
- Accumulates frames into reconstruction manager while scanning.
- Delegates countdown/auto-finish/session timing to `ScanSessionController`.
- Delegates thermal + idle-timer lifecycle to `ScanRuntimeController`.
- Delegates guidance/prompt/progress/HUD visibility state to `ScanHUDController`.
- Hot-path rule: camera callbacks must not create `UIImage` / `CIImage` / `CIContext`, run ML, or do heavy scoring/allocation work. Any preserved-frame design must use bounded retention and defer conversion until after scanning.

3. Reconstruction callbacks
- Uses `SCReconstructionManagerDelegate` callbacks for tracking state.
- Saves color buffers periodically for mesh texturing.

4. Finish/cancel behavior
- Cancel path resets reconstruction and returns delegate cancel callback.
- Manual finish path finalizes reconstruction, builds point cloud, and returns delegate scan callback.
- Auto-finish uses the configured scan duration when enabled.
- Both finish paths should be validated on a physical TrueDepth device.

5. Preview and export
- `ScanPreviewCoordinator` now acts primarily as a preview composition/entrypoint object.
- Preview session, routing, export, reset, interaction, and scene UI are split into dedicated preview collaborators.
- Quality gate can block export if thresholds fail.
- Save flow calls `ScanExporterService.exportScanFolder(...)`.
- Existing-scan reopen flows load summaries/artifacts through `ScanRepository`.
- Exported artifact set depends on settings:
  - `Export GLTF` controls `scene.gltf`
  - `Export OBJ` controls `head_mesh.obj`
  - metadata/thumbnail outputs remain part of the saved scan folder flow

## Important Seams Added for Testability
`AppScanningViewController` now has protocol seams around high-risk dependencies:
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
