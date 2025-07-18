//
//  UserDefaultsAchievementPersister.swift
//  FameFit Watch App
//
//  UserDefaults implementation of AchievementPersisting
//

import Foundation

/// UserDefaults-based achievement persistence
class UserDefaultsAchievementPersister: AchievementPersisting {
    private let userDefaults: UserDefaults
    private let achievementsKey: String
    
    init(userDefaults: UserDefaults = .standard, achievementsKey: String = "ToughLoveAchievements") {
        self.userDefaults = userDefaults
        self.achievementsKey = achievementsKey
    }
    
    func saveAchievements(_ achievements: [String]) {
        userDefaults.set(achievements, forKey: achievementsKey)
    }
    
    func loadAchievements() -> [String]? {
        return userDefaults.array(forKey: achievementsKey) as? [String]
    }
}