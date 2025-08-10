//
//  StatsSyncProtocol.swift
//  FameFit
//
//  Protocol for stats sync service operations
//

import Foundation

protocol StatsSyncProtocol {
    func syncStats(_ stats: UserStatsSnapshot) async
    func queueStatsSync(_ stats: UserStatsSnapshot)
    func processPendingSyncs() async
}

// MARK: - Supporting Types

struct UserStatsSnapshot {
    let userID: String
    let totalWorkouts: Int
    let totalXP: Int
    let currentStreak: Int?
    let lastWorkoutDate: Date?
    
    // Extensible - add new fields here
    let longestStreak: Int?
    let favoriteWorkoutType: String?
    let totalDistance: Double?
    let totalCalories: Double?
    let achievements: [String]?
    
    init(
        userID: String,
        totalWorkouts: Int,
        totalXP: Int,
        currentStreak: Int? = nil,
        lastWorkoutDate: Date? = nil,
        longestStreak: Int? = nil,
        favoriteWorkoutType: String? = nil,
        totalDistance: Double? = nil,
        totalCalories: Double? = nil,
        achievements: [String]? = nil
    ) {
        self.userID = userID
        self.totalWorkouts = totalWorkouts
        self.totalXP = totalXP
        self.currentStreak = currentStreak
        self.lastWorkoutDate = lastWorkoutDate
        self.longestStreak = longestStreak
        self.favoriteWorkoutType = favoriteWorkoutType
        self.totalDistance = totalDistance
        self.totalCalories = totalCalories
        self.achievements = achievements
    }
}