//
//  SceneDelegate.swift
//  TrueContourAI
//

import UIKit

final class AppCoordinator {
    private let window: UIWindow
    private let scanAssembler: ScanAssembler
    private let previewAssembler: PreviewAssembler
    private let homeAssembler: HomeAssembler
    private let settingsAssembler: SettingsAssembler

    init(window: UIWindow, dependencies: AppDependencies) {
        self.window = window
        let scanAssembler = ScanAssembler(dependencies: dependencies)
        self.scanAssembler = scanAssembler
        let previewAssembler = PreviewAssembler(dependencies: dependencies)
        self.previewAssembler = previewAssembler
        let settingsAssembler = SettingsAssembler(dependencies: dependencies)
        self.settingsAssembler = settingsAssembler
        self.homeAssembler = HomeAssembler(
            dependencies: dependencies,
            makeSettingsViewController: { [settingsAssembler] onScansChanged in
                settingsAssembler.makeSettingsViewController(onScansChanged: onScansChanged)
            },
            makeScanCoordinator: {
                scanAssembler.makeScanCoordinator()
            },
            makePreviewCoordinator: { presenter, scanFlowState, previewSessionState, onToast in
                previewAssembler.makePreviewCoordinator(
                    presenter: presenter,
                    scanFlowState: scanFlowState,
                    previewSessionState: previewSessionState,
                    onToast: onToast
                )
            }
        )
    }

    func start() {
        window.rootViewController = homeAssembler.makeHomeViewController()
        window.makeKeyAndVisible()
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let dependencies = AppDependencies()
        let coordinator = AppCoordinator(window: window, dependencies: dependencies)
        coordinator.start()
        appCoordinator = coordinator
        self.window = window
    }
}
