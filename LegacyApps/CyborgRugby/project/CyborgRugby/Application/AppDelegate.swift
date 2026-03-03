//
//  AppDelegate.swift
//  CyborgRugby
//
//  Dedicated app for rugby scrum cap fitting with 3D scanning
//

import UIKit
import AVFoundation

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
        // Check for actual TrueDepth camera capability
        
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInTrueDepthCamera]
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .front
        )
        
        let device = UIDevice.current
        if !discoverySession.devices.isEmpty {
            print("✅ TrueDepth camera available on \(device.model)")
            print("📊 iOS \(device.systemVersion) - Scanning supported")
        } else {
            print("❌ TrueDepth camera not available on \(device.model)")
            print("⚠️ 3D scanning functionality will be limited")
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