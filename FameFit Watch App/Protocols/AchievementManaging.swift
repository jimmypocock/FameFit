//
//  AchievementManaging.swift
//  FameFit Watch App
//
//  Protocol abstraction for achievement management
//

import Foundation
import HealthKit

/// Protocol defining the interface for managing workout achievements
protocol AchievementManaging: ObservableObject {
    associatedtype AchievementType: Hashable
    
    /// Set of unlocked achievements
    var unlockedAchievements: Set<AchievementType> { get }
    
    /// Most recently unlocked achievement
    var recentAchievement: AchievementType? { get }
    
    /// Check for new achievements based on workout data
    /// - Parameters:
    ///   - workout: The completed workout (optional)
    ///   - duration: Workout duration in seconds
    ///   - calories: Calories burned
    ///   - distance: Distance covered in meters
    ///   - averageHeartRate: Average heart rate during workout
    func checkAchievements(for workout: HKWorkout?,
                          duration: TimeInterval,
                          calories: Double,
                          distance: Double,
                          averageHeartRate: Double)
    
    /// Get achievement progress
    /// - Returns: Tuple of (unlocked count, total count)
    func getAchievementProgress() -> (unlocked: Int, total: Int)
}

/// Protocol for persisting achievements
protocol AchievementPersisting {
    /// Save achievements to persistent storage
    /// - Parameter achievements: Array of achievement identifiers
    func saveAchievements(_ achievements: [String])
    
    /// Load achievements from persistent storage
    /// - Returns: Array of achievement identifiers, or nil if none saved
    func loadAchievements() -> [String]?
}