//
//  AchievementManager.swift
//  CyborgRugby
//
//  Achievement system for rugby scrum cap scanning
//

import Foundation

class AchievementManager {
    static let shared = AchievementManager()
    
    private init() {
        loadAchievements()
    }
    
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
    
    // Track user achievements with persistence and thread safety
    private var unlockedAchievements: Set<Achievement> = []
    private let userDefaultsKey = "UnlockedAchievements"
    private let queue = DispatchQueue(label: "AchievementManager.queue", attributes: .concurrent)
    
    func unlockAchievement(_ achievement: Achievement) -> Bool {
        return queue.sync(flags: .barrier) {
            if !unlockedAchievements.contains(achievement) {
                unlockedAchievements.insert(achievement)
                DispatchQueue.main.async {
                    self.saveAchievements()
                }
                return true
            }
            return false
        }
    }
    
    func isUnlocked(_ achievement: Achievement) -> Bool {
        return queue.sync {
            return unlockedAchievements.contains(achievement)
        }
    }
    
    func getAllAchievements() -> [Achievement] {
        return Achievement.allCases
    }
    
    func getUnlockedAchievements() -> [Achievement] {
        return queue.sync {
            return Array(unlockedAchievements)
        }
    }
    
    func getLockedAchievements() -> [Achievement] {
        return queue.sync {
            return Achievement.allCases.filter { !unlockedAchievements.contains($0) }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadAchievements() {
        if let achievementStrings = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
            unlockedAchievements = Set(achievementStrings.compactMap { Achievement(rawValue: $0) })
        }
    }
    
    private func saveAchievements() {
        let achievementStrings = unlockedAchievements.map { $0.rawValue }
        UserDefaults.standard.set(achievementStrings, forKey: userDefaultsKey)
    }
    
    func resetAchievements() {
        unlockedAchievements.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}