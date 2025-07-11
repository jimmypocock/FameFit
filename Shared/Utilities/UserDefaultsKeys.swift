//
//  UserDefaultsKeys.swift
//  FameFit
//
//  Centralized UserDefaults key definitions
//

import Foundation

/// Keys for UserDefaults using reverse domain notation for safety
enum UserDefaultsKeys {
    static let lastProcessedWorkoutDate = "com.jimmypocock.FameFit.lastProcessedWorkoutDate"
    static let appInstallDate = "com.jimmypocock.FameFit.appInstallDate"
    static let hasCompletedOnboarding = "com.jimmypocock.FameFit.hasCompletedOnboarding"
    static let workoutSyncAnchor = "com.jimmypocock.FameFit.workoutSyncAnchor"
    static let lastSyncDate = "com.jimmypocock.FameFit.lastSyncDate"
    
    /// All keys for cleanup purposes
    static var allKeys: [String] {
        return [
            lastProcessedWorkoutDate,
            appInstallDate,
            hasCompletedOnboarding,
            workoutSyncAnchor,
            lastSyncDate
        ]
    }
    
    /// Clear all app data from UserDefaults
    static func clearAll() {
        allKeys.forEach { key in
            UserDefaults.standard.removeObject(forKey: key)
        }
        // UserDefaults automatically synchronizes
    }
}