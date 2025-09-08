//
//  AppDelegate.swift
//  CyborgRugby
//
//  Dedicated app for rugby scrum cap fitting with 3D scanning
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Print startup info
        print("🏉 CyborgRugby MVP - Starting up...")
        print("📱 Device: \(UIDevice.current.model)")
        print("📊 iOS Version: \(UIDevice.current.systemVersion)")
        
        // Check for TrueDepth camera capability
        checkDeviceCapabilities()
        
        return true
    }
    
    private func checkDeviceCapabilities() {
        #if targetEnvironment(simulator)
        print("⚠️ Running on Simulator - TrueDepth camera not available")
        #else
        // Basic device check for TrueDepth support
        let device = UIDevice.current.model
        if device.contains("iPhone") {
            print("📱 iPhone detected - checking for TrueDepth support...")
        } else if device.contains("iPad") {
            print("📱 iPad detected - checking for TrueDepth support...")
        }
        #endif
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}