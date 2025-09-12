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
    
    // Player information with validation
    var name: String {
        get { return UserDefaults.standard.string(forKey: "PlayerName") ?? "Player Name" }
        set { 
            let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedValue.isEmpty && trimmedValue.count <= 50 {
                UserDefaults.standard.set(trimmedValue, forKey: "PlayerName")
            }
        }
    }
    
    var position: String {
        get { return UserDefaults.standard.string(forKey: "PlayerPosition") ?? "Hooker" }
        set { 
            let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedValue.isEmpty && trimmedValue.count <= 30 {
                UserDefaults.standard.set(trimmedValue, forKey: "PlayerPosition")
            }
        }
    }
    
    var team: String {
        get { return UserDefaults.standard.string(forKey: "PlayerTeam") ?? "Crusaders" }
        set { 
            let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedValue.isEmpty && trimmedValue.count <= 50 {
                UserDefaults.standard.set(trimmedValue, forKey: "PlayerTeam")
            }
        }
    }
    
    var scanCount: Int {
        get { return UserDefaults.standard.integer(forKey: "ScanCount") }
        set { 
            let validatedValue = max(0, newValue) // Ensure non-negative
            UserDefaults.standard.set(validatedValue, forKey: "ScanCount") 
        }
    }
    
    var totalScanTime: Int {
        get { return UserDefaults.standard.integer(forKey: "TotalScanTime") }
        set { 
            let validatedValue = max(0, newValue) // Ensure non-negative
            UserDefaults.standard.set(validatedValue, forKey: "TotalScanTime") 
        }
    }
    
    // Methods to update profile
    func incrementScanCount() {
        scanCount += 1
    }
    
    func addScanTime(_ seconds: Int) {
        if seconds > 0 {
            totalScanTime += seconds
        }
    }
    
    func resetProfile() {
        UserDefaults.standard.removeObject(forKey: "PlayerName")
        UserDefaults.standard.removeObject(forKey: "PlayerPosition")
        UserDefaults.standard.removeObject(forKey: "PlayerTeam")
        UserDefaults.standard.set(0, forKey: "ScanCount")
        UserDefaults.standard.set(0, forKey: "TotalScanTime")
    }
}