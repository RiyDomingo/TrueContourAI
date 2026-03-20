import UIKit
import Metal
import StandardCyborgUI

struct ScanAssembler {
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func makeScanCoordinator(
        scanningViewControllerFactory: ScanCoordinator.ScanningViewControllerFactory? = nil
    ) -> ScanCoordinator {
        ScanCoordinator(
            environment: dependencies.environment,
            scanningViewControllerFactory: scanningViewControllerFactory ?? { makeScanningViewController() }
        )
    }

    func makeScanningViewController(
        reconstructionManagerFactory: @escaping (MTLDevice, MTLCommandQueue, Int32) -> ReconstructionManaging = {
            SCReconstructionManagerAdapter(device: $0, commandQueue: $1, maxThreadCount: $2)
        },
        cameraManager: CameraManaging = CameraManagerAdapter(),
        hapticEngine: ScanningHapticFeedbackProviding = ScanningHapticFeedbackEngine.shared,
        backgroundWorkRunner: @escaping (@escaping () -> Void) -> Void = { work in
            DispatchQueue.global(qos: .userInitiated).async(execute: work)
        }
    ) -> AppScanningViewController {
        let settingsStore = dependencies.runtimeSettings
        let configuration = resolvedConfiguration(settingsStore: settingsStore)
        let orientationSource = ScanInterfaceOrientationSource()

        let captureService = ScanCaptureService(
            cameraManager: cameraManager,
            configuration: configuration.captureConfiguration,
            orientationProvider: { orientationSource.current }
        )

        let metalContext = AppScanningViewController.makeMetalContextForAssembly()
        let runtimeEngine: ScanRuntimeEngining
        let initialFailure: ScanFailureViewData?
        if let metalContext {
            runtimeEngine = ScanRuntimeEngine(
                reconstructionManager: reconstructionManagerFactory(
                    metalContext.device,
                    metalContext.algorithmCommandQueue,
                    2
                ),
                configuration: configuration.runtimeConfiguration,
                developerModeEnabled: configuration.viewConfiguration.developerModeEnabled,
                requiresManualFinish: configuration.requiresManualFinish,
                backgroundWorkRunner: backgroundWorkRunner
            )
            initialFailure = nil
        } else {
            runtimeEngine = AppScanningViewController.makeUnavailableRuntimeEngineForAssembly()
            initialFailure = ScanFailureViewData(
                title: L("scan.start.unavailable.title"),
                message: L("scan.start.cameraUnavailable.message"),
                allowsRetry: false
            )
        }

        let store = ScanStore(
            captureService: captureService,
            runtimeEngine: runtimeEngine,
            autoFinishSeconds: configuration.viewConfiguration.autoFinishSeconds,
            requiresManualFinish: configuration.requiresManualFinish,
            developerModeEnabled: configuration.viewConfiguration.developerModeEnabled,
            initialFailure: initialFailure,
            initialFailureAlertIdentifier: "metalUnavailable",
            hapticEngine: hapticEngine
        )

        return AppScanningViewController(
            store: store,
            runtimeEngine: runtimeEngine,
            viewConfiguration: configuration.viewConfiguration,
            orientationSource: orientationSource,
            metalContext: metalContext
        )
    }

    func resolvedConfiguration(settingsStore: any AppSettingsReading) -> ResolvedScanFeatureConfiguration {
        let processingConfig = settingsStore.processingConfig
        let captureTuning = suggestedCaptureTuning(for: processingConfig)
        let texturedMeshEnabled = true
        let requiresManualFinish = true

        return ResolvedScanFeatureConfiguration(
            captureConfiguration: ScanCaptureConfiguration(
                maxDepthResolution: captureTuning.maxDepthResolution,
                textureSaveInterval: captureTuning.textureSaveInterval,
                developerModeEnabled: settingsStore.developerModeEnabled
            ),
            runtimeConfiguration: ScanRuntimeConfiguration(
                processingConfig: processingConfig,
                texturedMeshEnabled: texturedMeshEnabled,
                textureSaveInterval: captureTuning.textureSaveInterval
            ),
            viewConfiguration: ScanViewConfiguration(
                autoFinishSeconds: settingsStore.scanDurationSeconds,
                developerModeEnabled: settingsStore.developerModeEnabled
            ),
            requiresManualFinish: requiresManualFinish,
            texturedMeshEnabled: texturedMeshEnabled
        )
    }

    private func suggestedCaptureTuning(for config: SettingsStore.ProcessingConfig) -> ScanCaptureTuning {
        let isHeavyConfig = config.decimateRatio > 1.25 || config.meshResolution <= 5
        let maxDepthResolution = isHeavyConfig ? 256 : 320
        let scaledInterval = Int(round(8.0 * Double(max(0.5, config.decimateRatio))))
        let minimumInterval = isHeavyConfig ? 6 : 4
        let maximumInterval = isHeavyConfig ? 20 : 16
        let textureSaveInterval = max(
            minimumInterval,
            min(maximumInterval, scaledInterval + (isHeavyConfig ? 2 : 0))
        )
        return ScanCaptureTuning(
            maxDepthResolution: maxDepthResolution,
            textureSaveInterval: textureSaveInterval
        )
    }
}
