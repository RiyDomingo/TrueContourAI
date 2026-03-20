import UIKit

struct PreviewAssembler {
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func makePreviewCoordinator(
        presenter: UIViewController,
        scanFlowState: ScanFlowState,
        previewSessionState: PreviewSessionState = PreviewSessionState(),
        onToast: ((String) -> Void)? = nil,
        onExportResult: ((PreviewExportResultEvent) -> Void)? = nil
    ) -> PreviewCoordinator {
        PreviewCoordinator(
            presenter: presenter,
            scanFlowState: scanFlowState,
            onToast: onToast,
            onExportResult: onExportResult,
            previewViewControllerFactory: { [dependencies] input in
                PreviewViewController(
                    input: input,
                    scanReader: dependencies.scanRepository,
                    settingsStore: dependencies.settingsStore,
                    scanFlowState: scanFlowState,
                    previewSessionState: previewSessionState,
                    environment: dependencies.environment,
                    scanExporter: dependencies.scanExporter,
                    earServiceFactory: dependencies.earServiceFactory,
                    onToast: onToast,
                    onExportResult: onExportResult
                )
            }
        )
    }
}
