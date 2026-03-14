# Ear Landmarking Recovery

This document records the current ear verification architecture, the recovery work completed so far, and the remaining risks.

## Current Architecture

Ear verification is an on-device preview feature:

1. `PreviewSessionWorkflows` triggers verification from the preview UI.
2. `EarLandmarksService` runs the two-stage ML pipeline.
3. `SCEarTracking` produces the ear bounding box.
4. `SCEarLandmarking` predicts 5 landmark points inside a 300x300 ear crop.
5. The result is rendered as an overlay and exported as ear artifacts when available.

Relevant files:

- [TrueContourAI/Features/Scan/EarLandmarksService.swift](../TrueContourAI/Features/Scan/EarLandmarksService.swift)
- [TrueContourAI/Features/Preview/PreviewOverlayUIController.swift](../TrueContourAI/Features/Preview/PreviewOverlayUIController.swift)
- [StandardCyborgFusion/Sources/StandardCyborgFusion/EarLandmarking/EarLandmarkingAnalysis.m](../StandardCyborgFusion/Sources/StandardCyborgFusion/EarLandmarking/EarLandmarkingAnalysis.m)
- [STANDARD_CYBORG_EAR_ML_REFERENCE.md](./STANDARD_CYBORG_EAR_ML_REFERENCE.md)

## Coordinate Contracts

These contracts must not drift:

1. `earBoundingBox`
- Detector-native normalized coordinates
- Bottom-left origin
- Used for green bbox rendering

2. `landmarks`
- App-normalized coordinates after remapping from the crop
- Top-left origin
- Used for point rendering and persisted `ear_landmarks.json`

3. Overlay rendering
- Bounding boxes must be rendered from detector/native coordinates
- Landmarks must be rendered from top-left normalized coordinates exactly once
- Landmarks must not receive an additional Y flip during drawing

## Recovery Work Completed

### 2026-03-13: Landmark path recovery

Changes:

1. Kept bbox detection on `SCEarTracking`
2. Matched legacy landmark crop expansion to `0.15`
3. Restored legacy-style crop-and-scale behavior at `300x300`
4. Switched landmark inference to `VNCoreMLRequest`
5. Centralized crop-to-image remapping
6. Added bbox-only fallback on landmark failure
7. Added debug artifacts and validation logging

Why:

- Bounding box MVP was working
- Landmark points were failing due to likely software-contract drift

Validation status:

- Build-verified
- Physical-device validation showed the crop and raw model output were plausible
- Overlay placement was still wrong

### 2026-03-14: Verify Ear UI access fix

Changes:

1. Moved `Verify Ear` from the developer-only preview section into the normal summary section
2. Added a regression test to ensure the button remains visible with developer mode disabled

Why:

- The feature was unreachable in normal preview UI

Validation status:

- Build-verified
- Requires device confirmation in the updated build

### 2026-03-14: Overlay coordinate fix

Changes:

1. Split bbox and landmark overlay mapping into separate paths
2. Kept bbox rendering on bottom-left detector coordinates
3. Removed the second Y flip from landmark rendering
4. Added `overlayLayout(...)` to make render math testable
5. Extended `ear-landmark-debug.json` with rendered overlay coordinates

Why:

- Debug artifacts showed valid crop, valid raw outputs, and accepted mapped landmarks
- The rendered points were appearing above the ear, indicating a render-space bug rather than an inference failure

Validation status:

- Build-verified
- Unit coverage added for overlay mapping
- Physical-device validation still required after the latest build

## Debug Artifacts

In debug builds, ear verification writes artifacts to:

`Documents/Scans/EarDebug`

Files:

1. `ear-landmark-input.png`
2. `ear-landmark-overlay.png`
3. `ear-landmark-crop-overlay.png`
4. `ear-landmark-debug.json`

`ear-landmark-debug.json` currently captures:

1. detector bbox
2. display bbox
3. landmark crop rect
4. raw landmark preview
5. mapped landmarks
6. rendered landmarks
7. rendered bbox
8. overlay flip settings
9. validation failure, if any

## Exported Ear Artifacts

Ear verification now persists two different visual artifacts:

1. `thumbnail_ear_overlay.png`
- Full-scene preview overlay
- Useful for context and confirming where the ear was found in the overall preview

2. `ear_crop_overlay.png`
- Cropped side-ear QA overlay derived from the exact model-input crop
- This is the primary artifact for judging ear shape and landmark placement

3. `ear_view.png`
- Full preview snapshot used for verification

For anatomical landmark review, prefer `ear_crop_overlay.png` over the full-scene overlay.

## Current Evidence

From the latest device debug run:

1. bbox detection is working
2. crop generation is working
3. model execution is working
4. landmark output is non-empty and plausible
5. the previous overlay bug was a second Y flip on top-left landmark coordinates

This means the main remaining technical risk is not bbox detection or model loading.

## Open Risk

The landmark model still runs on a preview-rendered scene snapshot rather than a camera-faithful source image.

That input currently appears:

1. aliased
2. lower-detail
3. mesh-textured
4. composited over a synthetic background

This may be acceptable for bbox detection but still too degraded for reliable anatomical landmark placement.

## Capture-Faithful Verification Source

Ear verification now prefers a preserved camera color frame captured during active scanning.

Source precedence:

1. best scored preserved scan capture frame
2. latest preserved capture frame fallback
3. preview snapshot fallback

The current scan-time frame scorer is deterministic and heuristic-based:

1. reject lost/failed tracking frames
2. reject very early scan frames before reconstruction has stabilized
3. prefer stronger side-profile view matrices over frontal frames
4. boost stable capture states and penalize warning states
5. break score ties by preferring the newer frame

Artifacts now have distinct roles:

1. `ear_view.png`
- Actual image used for ear verification
- This should be the preserved camera frame when available

2. `thumbnail_ear_overlay.png`
- Full-scene context overlay shown in preview flows
- Still useful for scene-level context, not primary anatomical QA

3. `ear_crop_overlay.png`
- Primary anatomical QA artifact
- Derived from the actual model-input crop

4. `ear-landmark-debug.json`
- Records:
  - verification source type
  - whether preview fallback was used
  - verification image dimensions
  - selected frame index
  - selected frame score breakdown
  - crop/debug/render metadata

If anatomical placement is still weak after the capture-faithful source migration, the next issue is likely model quality or model-domain mismatch rather than overlay math.

## Validation Checklist

Any future ear-landmarking change should be validated on a physical TrueDepth iPhone.

Minimum checklist:

1. `Verify Ear` is visible in normal preview UI
2. green bbox still appears
3. 5 landmark points render on a known-good scan
4. points land on the ear, not above it
5. `ear_landmarks.json` is non-empty only when landmarks succeed
6. `Documents/Scans/EarDebug/ear-landmark-debug.json` is written in debug builds

## Default Decisions In Force

1. Keep bbox MVP behavior stable
2. Prefer bbox-only fallback over bad landmark output
3. Treat coordinate-contract drift as a higher-probability failure than model failure
4. Do not retrain or replace the model until rendering and source-image contract issues are ruled out
