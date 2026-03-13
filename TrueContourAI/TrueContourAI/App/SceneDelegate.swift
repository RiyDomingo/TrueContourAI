//
//  SceneDelegate.swift
//  TrueContourAI
//

import UIKit

final class AppCoordinator {
    private let window: UIWindow
    private let dependencies: AppDependencies

    init(window: UIWindow, dependencies: AppDependencies) {
        self.window = window
        self.dependencies = dependencies
    }

    func start() {
        window.rootViewController = HomeViewController(dependencies: dependencies)
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
