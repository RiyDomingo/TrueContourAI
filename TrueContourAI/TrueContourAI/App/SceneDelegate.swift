//
//  SceneDelegate.swift
//  TrueContourAI
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Create the window using the provided windowScene to avoid deprecated init(frame:) and UIScreen.main
        let window = UIWindow(windowScene: windowScene)
        let dependencies = AppDependencies()
        window.rootViewController = ViewController(dependencies: dependencies)
        window.makeKeyAndVisible()
        self.window = window
    }
}
