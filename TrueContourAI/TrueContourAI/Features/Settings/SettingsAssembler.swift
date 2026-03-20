import UIKit

struct SettingsAssembler {
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func makeSettingsViewController(onScansChanged: (() -> Void)? = nil) -> SettingsViewController {
        let storageUseCase = SettingsStorageUseCase(scanService: dependencies.scanRepository)
        let viewController = SettingsViewController(
            store: dependencies.settingsStore,
            storageUseCase: storageUseCase
        )
        viewController.onScansChanged = onScansChanged
        return viewController
    }
}
