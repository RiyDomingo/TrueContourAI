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
        let settingsStore = dependencies.settingsStore
        let processingConfig = settingsStore.processingConfig
        let captureTuning = suggestedCaptureTuning(for: processingConfig)
        let autoFinishSeconds = settingsStore.scanDurationSeconds
        let requiresManualFinish = true
        let developerModeEnabled = settingsStore.developerModeEnabled
        let generatesTexturedMeshes = true
        let orientationSource = ScanInterfaceOrientationSource()

        let captureConfiguration = ScanCaptureConfiguration(
            maxDepthResolution: captureTuning.maxDepthResolution,
            textureSaveInterval: captureTuning.textureSaveInterval,
            developerModeEnabled: developerModeEnabled
        )
        let runtimeConfiguration = ScanRuntimeConfiguration(
            processingConfig: processingConfig,
            texturedMeshEnabled: generatesTexturedMeshes,
            textureSaveInterval: captureTuning.textureSaveInterval
        )

        let captureService = ScanCaptureService(
            cameraManager: cameraManager,
            configuration: captureConfiguration,
            orientationProvider: { orientationSource.current }
        )

        let metalContext = AppScanningViewController.makeMetalContextForAssembly()
        let runtimeEngine: ScanRuntimeEngining
        if let metalContext {
            runtimeEngine = ScanRuntimeEngine(
                reconstructionManager: reconstructionManagerFactory(
                    metalContext.device,
                    metalContext.algorithmCommandQueue,
                    2
                ),
                configuration: runtimeConfiguration,
                developerModeEnabled: developerModeEnabled,
                requiresManualFinish: requiresManualFinish,
                backgroundWorkRunner: backgroundWorkRunner
            )
        } else {
            runtimeEngine = AppScanningViewController.makeUnavailableRuntimeEngineForAssembly()
        }

        let store = ScanStore(
            captureService: captureService,
            runtimeEngine: runtimeEngine,
            autoFinishSeconds: autoFinishSeconds,
            requiresManualFinish: requiresManualFinish,
            developerModeEnabled: developerModeEnabled,
            hapticEngine: hapticEngine
        )

        return AppScanningViewController(
            store: store,
            runtimeEngine: runtimeEngine,
            autoFinishSeconds: autoFinishSeconds,
            requiresManualFinish: requiresManualFinish,
            developerModeEnabled: developerModeEnabled,
            maxDepthResolution: captureTuning.maxDepthResolution,
            generatesTexturedMeshes: generatesTexturedMeshes,
            texturedMeshColorBufferSaveInterval: captureTuning.textureSaveInterval,
            processingConfig: processingConfig,
            orientationSource: orientationSource,
            metalContext: metalContext
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
