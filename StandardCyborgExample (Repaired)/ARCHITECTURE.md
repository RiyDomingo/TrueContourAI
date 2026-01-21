# TrueContourAI Architecture

This document provides a high-level overview of how the app is organized and how core flows move through the system.

## Goals
- Keep UI controllers thin and focused on view rendering.
- Centralize navigation and flow logic in coordinators.
- Make scan state explicit and testable.

## Key Components
- `ViewController`: Home screen UI and user intent events.
- `HomeCoordinator`: Navigation for settings, scan list actions, and how-to sheet.
- `ScanCoordinator`: Starts scan flow, configures scanning VC, adds Finish button.
- `ScanPreviewCoordinator`: Presents preview, handles Verify Ear, saving/export, toasts.
- `ScanFlowState`: Shared state for scan phase, preview artifacts, current folder.
- `HomeViewModel`: Observable scan list and empty state for the home screen.
- `ScanService`: File IO, export, and scan folder management.

## Data Flow (Home -> Scan -> Preview -> Save)

```
Home UI (ViewController)
  |
  | user taps Start Scan
  v
ScanCoordinator.startScanFlow
  |
  | scanning completes
  v
ScanPreviewCoordinator.presentPreviewAfterScan
  |
  | user taps Save
  v
ScanService.exportScanFolder (background)
  |
  | success -> toast + refresh scans
  v
HomeViewModel.refresh -> UI update
```

## State Ownership
- `ScanFlowState.phase` is the source of truth for scan lifecycle:
  - `.idle` -> `.scanning` -> `.preview` -> `.saving` -> `.idle`
- `HomeViewModel` owns the scan list and derived flags (`isEmpty`, `canViewLast`).

## Testing Strategy
- Unit tests cover:
  - `ScanService` listing, rename, delete, last-scan behavior.
  - `ScanFlowState` phase transitions.
  - Coordinator error flows and export handling.
- UI tests exist for core home actions and the how-to flow; expand as flows stabilize.

## Notes
- Keep long-running work off the main thread (exports, ML detection).
- Localize user-facing strings via `Localizable.strings`.
