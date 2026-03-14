# StandardCyborg Ear ML Reference

This note captures the public StandardCyborg sources that define the ear ML contract used by this app.

It is not a replacement for our app-level recovery notes. Its purpose is narrower:

1. identify the upstream/public source of truth
2. record what those sources actually say
3. map those findings to the current `TrueContourAI` implementation

## Public Source Links

Public GitHub repositories:

1. [StandardCyborgCocoa](https://github.com/StandardCyborg/StandardCyborgCocoa)
2. [StandardCyborgSDK](https://github.com/StandardCyborg/StandardCyborgSDK)

Relevant upstream source files:

1. [EarLandmarkingAnalysis.h](https://github.com/StandardCyborg/StandardCyborgSDK/blob/main/StandardCyborgFusion/Sources/StandardCyborgFusion/EarLandmarking/EarLandmarkingAnalysis.h)
2. [EarLandmarkingAnalysis.m](https://github.com/StandardCyborg/StandardCyborgSDK/blob/main/StandardCyborgFusion/Sources/StandardCyborgFusion/EarLandmarking/EarLandmarkingAnalysis.m)
3. [SCEarTracking.h](https://github.com/StandardCyborg/StandardCyborgSDK/blob/main/StandardCyborgFusion/Sources/include/StandardCyborgFusion/SCEarTracking.h)
4. [SCEarTracking.m](https://github.com/StandardCyborg/StandardCyborgSDK/blob/main/StandardCyborgFusion/Sources/StandardCyborgFusion/Public/SCEarTracking.m)
5. [SCEarLandmarking.h](https://github.com/StandardCyborg/StandardCyborgSDK/blob/main/StandardCyborgFusion/Sources/include/StandardCyborgFusion/SCEarLandmarking.h)
6. [SCEarTrackingModel.h](https://github.com/StandardCyborg/StandardCyborgSDK/blob/main/StandardCyborgFusion/Sources/include/StandardCyborgFusion/SCEarTrackingModel.h)

Local mirror in this repo:

1. [EarLandmarkingAnalysis.h](../StandardCyborgFusion/Sources/StandardCyborgFusion/EarLandmarking/EarLandmarkingAnalysis.h)
2. [EarLandmarkingAnalysis.m](../StandardCyborgFusion/Sources/StandardCyborgFusion/EarLandmarking/EarLandmarkingAnalysis.m)
3. [SCEarTracking.h](../StandardCyborgFusion/Sources/include/StandardCyborgFusion/SCEarTracking.h)
4. [SCEarTracking.m](../StandardCyborgFusion/Sources/StandardCyborgFusion/Public/SCEarTracking.m)
5. [SCEarLandmarking.h](../StandardCyborgFusion/Sources/include/StandardCyborgFusion/SCEarLandmarking.h)
6. [SCEarTrackingModel.h](../StandardCyborgFusion/Sources/include/StandardCyborgFusion/SCEarTrackingModel.h)

## What StandardCyborg Publicly Confirms

The public repositories confirm that `StandardCyborgFusion` includes:

1. ear bounding-box detection
2. ear landmark prediction
3. model-generated Objective-C/Core ML interfaces for both models

The public README material is high-level. The practical contract lives in the source code, especially `EarLandmarkingAnalysis.*`.

## Upstream Ear Landmarking Contract

From `EarLandmarkingAnalysis.h` and `EarLandmarkingAnalysis.m`, the upstream implementation expects:

1. input image in portrait orientation
2. ear bounding box normalized to `[0, 1]`
3. ear bounding box origin at bottom-left
4. bounding box expansion factor of `0.15`
5. crop resized to `300x300`
6. inference performed via `VNCoreMLRequest`
7. output remapped back into full-image coordinates after flipping the expanded bbox into top-left space

This is the most important upstream contract for our recovery work.

## Upstream Ear Tracking Contract

From `SCEarTracking.h`, `SCEarTracking.m`, and `SCEarTrackingModel.h`, the tracker:

1. runs on-device using the bundled ear tracking model
2. outputs a normalized ear bbox
3. is the intended first stage before landmarking

In practice, the app should treat tracker output as detector-native coordinates until explicitly converted.

## Model Interface Notes

From the generated model headers:

1. `SCEarLandmarking`
- input is a `300x300` BGRA image buffer
- output is `normed_coordinates_yx`

2. `SCEarTrackingModel`
- input is a `300x300` BGRA image buffer
- output includes confidence and coordinates arrays

The upstream implementation code reads the landmark output as paired values and then applies remapping in `EarLandmarkingAnalysis.m`.

## What This Means For TrueContourAI

These public upstream sources support the decisions already taken in this app:

1. restore legacy crop expansion to `0.15`
2. preserve the clamped crop-and-scale behavior
3. use `VNCoreMLRequest` for landmark inference
4. keep bbox and landmark coordinate handling separate
5. treat `EarLandmarkingAnalysis.m` as the source of truth for the original landmarking contract

## What The Public Sources Do Not Provide

The public StandardCyborg repositories do **not** provide:

1. a full app-level narrative for ear verification UX
2. a detailed explanation of the product workflow around preview/export
3. guidance about using preview-rendered images versus camera-faithful images
4. performance/quality guarantees for the models on our current app inputs

Those questions must still be answered from:

1. our app code
2. our device validation artifacts
3. our recovery notes

## Related Internal Notes

For current app behavior and recovery status, see:

1. [EAR_LANDMARKING_RECOVERY.md](./EAR_LANDMARKING_RECOVERY.md)
2. [SCAN_ENGINE.md](./SCAN_ENGINE.md)
