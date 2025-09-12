//
//  AchievementManager.swift
//  CyborgRugby
//
//  Achievement system for rugby scrum cap scanning
//

import Foundation

class AchievementManager {
    static let shared = AchievementManager()
    
    private init() {}
    
    // Define achievements
    enum Achievement: String, CaseIterable {
        case firstScan = "First Scan"
        case perfectPose = "Perfect Pose"
        case quickScan = "Quick Scan"
        case allPoses = "All Poses Master"
        case expertScanner = "Expert Scanner"
        
        var title: String {
            return self.rawValue
        }
        
        var description: String {
            switch self {
            case .firstScan:
                return "Complete your first 3D head scan"
            case .perfectPose:
                return "Hold a perfect position for 5 seconds"
            case .quickScan:
                return "Complete a full scan in under 2 minutes"
            case .allPoses:
                return "Complete all required scanning poses"
            case .expertScanner:
                return "Complete 10 successful scans"
            }
        }
        
        var icon: String {
            switch self {
            case .firstScan:
                return "figure.walk"
            case .perfectPose:
                return "star.fill"
            case .quickScan:
                return "clock.fill"
            case .allPoses:
                return "checkmark.seal.fill"
            case .expertScanner:
                return "rosette"
            }
        }
    }
    
    // Track user achievements
    private var unlockedAchievements: Set<Achievement> = []
    
    func unlockAchievement(_ achievement: Achievement) -> Bool {
        if !unlockedAchievements.contains(achievement) {
            unlockedAchievements.insert(achievement)
            return true
        }
        return false
    }
    
    func isUnlocked(_ achievement: Achievement) -> Bool {
        return unlockedAchievements.contains(achievement)
    }
    
    func getAllAchievements() -> [Achievement] {
        return Achievement.allCases
    }
    
    func getUnlockedAchievements() -> [Achievement] {
        return Array(unlockedAchievements)
    }
    
    func getLockedAchievements() -> [Achievement] {
        return Achievement.allCases.filter { !unlockedAchievements.contains($0) }
    }
}