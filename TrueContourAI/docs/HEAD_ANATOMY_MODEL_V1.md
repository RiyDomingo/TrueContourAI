# Head Anatomy Model V1

This document defines a practical v1 contract for integrating a head-anatomy landmark model into TrueContourAI.

## Scope

V1 predicts 3D anatomical landmarks from a finalized scan mesh/point cloud and returns confidence metadata.
Downstream measurements remain deterministic and are computed from landmarks.

## Landmark Set (v1)

Required landmarks:

1. `glabella`
2. `nasion`
3. `vertex`
4. `opisthocranion`
5. `euryon_left`
6. `euryon_right`
7. `tragion_left`
8. `tragion_right`
9. `inion`

Optional landmarks:

1. `sellion`
2. `frontotemporale_left`
3. `frontotemporale_right`
4. `menton`

## File Artifacts

When anatomy inference runs successfully, the app can persist:

1. `head_anatomy_landmarks.json`
2. `head_anatomy_overlay.png` (optional visual QA)
3. `head_anatomy_debug.json` (optional, debug builds only)

## JSON Schema (proposed)

`head_anatomy_landmarks.json`

```json
{
  "schema_version": 1,
  "model_name": "HeadAnatomyV1",
  "model_version": "1.0.0",
  "created_at": "2026-03-06T12:34:56.000Z",
  "coordinate_frame": "pca_aligned_mesh_local",
  "units": "mm",
  "scan_reference": {
    "folder_name": "Scan-2026-03-06T12-30-00Z",
    "source_artifact": "head_mesh.obj"
  },
  "overall_confidence": 0.87,
  "landmarks": [
    {
      "name": "glabella",
      "position_mm": { "x": 2.1, "y": 132.4, "z": -7.2 },
      "confidence": 0.92,
      "is_estimated": false
    },
    {
      "name": "tragion_left",
      "position_mm": { "x": -71.6, "y": 88.9, "z": 10.8 },
      "confidence": 0.83,
      "is_estimated": false
    }
  ],
  "warnings": [
    "Right temporal region had low coverage."
  ]
}
```

## Inference Contract

Input assumptions:

1. Mesh in meters, converted to millimeters internally for output.
2. Stable local frame via PCA alignment before inference.
3. Optional point cloud features can be provided for future model versions.

Output expectations:

1. Landmark positions in millimeters.
2. Confidence per landmark.
3. Overall confidence in `[0, 1]`.
4. Non-fatal warnings for low-quality regions.

## Quality Gates

Suggested minimum shipping thresholds:

1. Mean landmark error <= 4.0 mm (validation set)
2. P95 landmark error <= 8.0 mm
3. Symmetry error (`tragion_left` vs `tragion_right`) <= 6.0 mm median
4. Derived measurement drift <= 1.5% median vs reference

## Privacy and Labeling Notes

1. Model updates require labeled training data outside the app runtime.
2. Current app exports are inference outputs, not ground-truth labels.
3. Keep training dataset collection opt-in and explicitly consented.
