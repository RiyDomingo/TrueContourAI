import UIKit
import StandardCyborgUI

enum PreviewExportResultEvent: Equatable {
    case success(folderName: String, formatSummary: String, earServiceUnavailable: Bool)
    case failure(message: String)
}

final class PreviewExportController {
    private let scanFlowState: ScanFlowState
    private let scanExporter: ScanExporting
    private let onToast: ((String) -> Void)?
    private let onExportResult: ((PreviewExportResultEvent) -> Void)?
    private let onScansChanged: (() -> Void)?

    private lazy var exportWorkflow = PreviewExportWorkflow(settingsStore: settingsStore)
    private lazy var saveWorkflow = PreviewSaveWorkflow(
        previewViewModel: previewViewModel,
        scanFlowState: scanFlowState,
        saveExportViewState: saveExportViewState,
        alertPresenter: alertPresenter,
        scanExporter: scanExporter
    )
    private lazy var exportResultWorkflow = PreviewExportResultWorkflow(
        previewViewModel: previewViewModel,
        saveExportViewState: saveExportViewState,
        alertPresenter: alertPresenter,
        scanFlowState: scanFlowState,
        scanExporter: scanExporter,
        environment: environment,
        onToast: onToast,
        onExportResult: onExportResult,
        onScansChanged: onScansChanged,
        previewSessionController: previewSessionController,
        presentationController: presentationController,
        resetController: resetController,
        exportFormatSummary: { [weak self] in
            self?.exportFormatSummary() ?? L("scan.preview.exportFormat.none")
        }
    )

    private let previewViewModel: PreviewViewModel
    private let settingsStore: SettingsStore
    private let saveExportViewState: SaveExportUIStateAdapting
    private let alertPresenter: PreviewAlertPresenter
    private let environment: AppEnvironment
    private let previewSessionController: PreviewSessionController
    private let presentationController: PreviewPresentationController
    private let resetController: PreviewResetController

    init(
        previewViewModel: PreviewViewModel,
        settingsStore: SettingsStore,
        scanFlowState: ScanFlowState,
        saveExportViewState: SaveExportUIStateAdapting,
        alertPresenter: PreviewAlertPresenter,
        scanExporter: ScanExporting,
        environment: AppEnvironment,
        onToast: ((String) -> Void)?,
        onExportResult: ((PreviewExportResultEvent) -> Void)?,
        onScansChanged: (() -> Void)?,
        previewSessionController: PreviewSessionController,
        presentationController: PreviewPresentationController,
        resetController: PreviewResetController
    ) {
        self.previewViewModel = previewViewModel
        self.settingsStore = settingsStore
        self.scanFlowState = scanFlowState
        self.saveExportViewState = saveExportViewState
        self.alertPresenter = alertPresenter
        self.scanExporter = scanExporter
        self.environment = environment
        self.onToast = onToast
        self.onExportResult = onExportResult
        self.onScansChanged = onScansChanged
        self.previewSessionController = previewSessionController
        self.presentationController = presentationController
        self.resetController = resetController
    }

    func performSave(previewVC: ScenePreviewViewController, previewSessionID: UUID, earServiceUnavailable: Bool) {
        saveWorkflow.performSave(
            previewVC: previewVC,
            previewSessionID: previewSessionID,
            exportWorkflow: exportWorkflow,
            earServiceUnavailable: earServiceUnavailable,
            isCurrentPreviewSession: { [weak self] sessionID in
                self?.previewSessionController.isCurrentSession(sessionID) ?? false
            },
            onFailure: { [weak self] message in
                guard let self else { return }
                self.exportResultWorkflow.handleFailure(message: message, previewVC: previewVC)
            },
            onSuccess: { [weak self] folderURL, exportContext in
                guard let self else { return }
                self.exportResultWorkflow.handleSuccess(
                    folderURL: folderURL,
                    previewSessionID: previewSessionID,
                    exportContext: exportContext
                )
            }
        )
    }

    func handleInvocationFailure(reason: String) {
        guard let presentingVC = presentationController.currentPreviewedViewController
            ?? presentationController.resolvedScenePreviewViewController else {
            Log.export.error("Save invocation failed without preview presenter: \(reason, privacy: .public)")
            return
        }

        saveExportViewState.markSaveFailed()
        presentingVC.present(
            alertPresenter.makeAlert(
                title: L("scan.preview.exportFailed.title"),
                message: String(format: L("scan.preview.exportFailed.message"), reason),
                identifier: "exportInvocationAlert"
            ),
            animated: true
        )
        scanFlowState.setPhase(.preview)
        previewViewModel.setPhase(.preview)
        saveExportViewState.setButtonsEnabled(true)
        saveExportViewState.setMeshingStatusText(L("scan.preview.readyToSave"))
        saveExportViewState.setMeshingSpinnerActive(false)
        saveExportViewState.hideSavingToast()
        onExportResult?(.failure(message: reason))
        Log.export.error("Save invocation failed: \(reason, privacy: .public)")
    }

    func exportFormatSummary() -> String {
        exportWorkflow.exportFormatSummary()
    }

    #if DEBUG
    func debugHandleExportResult(_ result: ScanExportResult, isEarServiceUnavailable: Bool) {
        switch result {
        case .failure(let message):
            onExportResult?(.failure(message: message))
            scanFlowState.setPhase(.preview)
        case .success(let folderURL):
            scanExporter.setLastScanFolder(folderURL)
            onScansChanged?()
            let formatSummary = exportFormatSummary()
            onToast?(String(format: L("scan.preview.toast.savedWithFormats"), folderURL.lastPathComponent, formatSummary))
            if isEarServiceUnavailable {
                onToast?(L("scan.preview.toast.earUnavailable"))
            }
            onExportResult?(.success(
                folderName: folderURL.lastPathComponent,
                formatSummary: formatSummary,
                earServiceUnavailable: isEarServiceUnavailable
            ))
            scanFlowState.setPhase(.idle)
        }
    }

    func debugSavePrecheck(qualityReport: ScanQualityReport?, hasMesh: Bool) -> String {
        _ = qualityReport
        switch exportWorkflow.savePrecheck(qualityReport: qualityReport, meshAvailable: hasMesh) {
        case .gltfExportRequired:
            return "gltfExportRequired"
        case .meshNotReady:
            return "meshNotReady"
        case .qualityGateBlocked:
            return "qualityGateBlocked"
        case .ready:
            return "ready"
        }
    }
    #endif
}
