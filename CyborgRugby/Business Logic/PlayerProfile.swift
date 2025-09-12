//
//  PlayerProfile.swift
//  CyborgRugby
//
//  Player profile data model
//

import Foundation

class PlayerProfile {
    static let shared = PlayerProfile()
    
    private init() {}
    
    // Player information
    var name: String {
        get { return UserDefaults.standard.string(forKey: "PlayerName") ?? "Player Name" }
        set { UserDefaults.standard.set(newValue, forKey: "PlayerName") }
    }
    
    var position: String {
        get { return UserDefaults.standard.string(forKey: "PlayerPosition") ?? "Hooker" }
        set { UserDefaults.standard.set(newValue, forKey: "PlayerPosition") }
    }
    
    var team: String {
        get { return UserDefaults.standard.string(forKey: "PlayerTeam") ?? "Crusaders" }
        set { UserDefaults.standard.set(newValue, forKey: "PlayerTeam") }
    }
    
    var scanCount: Int {
        get { return UserDefaults.standard.integer(forKey: "ScanCount") }
        set { UserDefaults.standard.set(newValue, forKey: "ScanCount") }
    }
    
    var totalScanTime: Int {
        get { return UserDefaults.standard.integer(forKey: "TotalScanTime") }
        set { UserDefaults.standard.set(newValue, forKey: "TotalScanTime") }
    }
    
    // Methods to update profile
    func incrementScanCount() {
        scanCount += 1
    }
    
    func addScanTime(_ seconds: Int) {
        totalScanTime += seconds
    }
    
    func resetProfile() {
        UserDefaults.standard.removeObject(forKey: "PlayerName")
        UserDefaults.standard.removeObject(forKey: "PlayerPosition")
        UserDefaults.standard.removeObject(forKey: "PlayerTeam")
        UserDefaults.standard.set(0, forKey: "ScanCount")
        UserDefaults.standard.set(0, forKey: "TotalScanTime")
    }
}