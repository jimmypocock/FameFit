//
//  WorkoutSyncPolicy.swift
//  FameFit
//
//  Defines the policy for syncing workouts from HealthKit
//  Game-based approach: Only sync workouts after profile creation
//

import Foundation
import HealthKit

/// Policy for determining which workouts to sync and award XP for
struct WorkoutSyncPolicy {
    
    // MARK: - Configuration
    
    /// Maximum window for syncing historical workouts (30 days)
    static let maxSyncWindow: TimeInterval = 30 * 24 * 60 * 60
    
    /// Recent sync window for new workouts (24 hours)
    static let recentSyncWindow: TimeInterval = 24 * 60 * 60
    
    // MARK: - Properties
    
    /// When the user's profile was created (game start date)
    let profileCreatedAt: Date
    
    // MARK: - Initialization
    
    init(profileCreatedAt: Date) {
        self.profileCreatedAt = profileCreatedAt
    }
    
    // MARK: - Sync Date Calculation
    
    /// Calculate the start date for workout sync based on policy
    /// - Returns: The earliest date from which to sync workouts
    func getSyncStartDate() -> Date {
        // Three boundaries:
        // 1. Never before profile creation (game start)
        // 2. At most 30 days ago (prevent massive syncs)
        // 3. At least 24 hours ago (always get recent)
        
        let now = Date()
        let thirtyDaysAgo = now.addingTimeInterval(-Self.maxSyncWindow)
        let twentyFourHoursAgo = now.addingTimeInterval(-Self.recentSyncWindow)
        
        // Take the most recent of: profile creation or 30 days ago
        let syncStart = max(profileCreatedAt, thirtyDaysAgo)
        
        // But always get at least the last 24 hours
        return min(syncStart, twentyFourHoursAgo)
    }
    
    /// Get the end date for workout sync (always now)
    func getSyncEndDate() -> Date {
        return Date()
    }
    
    // MARK: - Workout Validation
    
    /// Check if a workout should be synced to CloudKit
    /// - Parameter workout: The workout to check
    /// - Returns: True if the workout should be synced
    func shouldSyncWorkout(_ workout: HKWorkout) -> Bool {
        let syncStart = getSyncStartDate()
        return workout.endDate > syncStart && workout.endDate <= Date()
    }
    
    /// Check if a workout is eligible for XP
    /// - Parameter workout: The workout to check
    /// - Returns: True if the workout can earn XP
    func shouldAwardXP(_ workout: HKWorkout) -> Bool {
        // Only award XP for workouts after joining the game
        return workout.endDate > profileCreatedAt && workout.endDate <= Date()
    }
    
    /// Check if a workout date is eligible for XP
    /// - Parameter workoutDate: The workout end date to check
    /// - Returns: True if a workout on this date can earn XP
    func shouldAwardXP(for workoutDate: Date) -> Bool {
        return workoutDate > profileCreatedAt && workoutDate <= Date()
    }
    
    // MARK: - Logging Support
    
    /// Get a description of the current sync window for logging
    var syncWindowDescription: String {
        let syncStart = getSyncStartDate()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let daysSinceProfile = Int(Date().timeIntervalSince(profileCreatedAt) / (24 * 60 * 60))
        let syncDays = Int(Date().timeIntervalSince(syncStart) / (24 * 60 * 60))
        
        return """
        Sync Window: Last \(syncDays) days (from \(formatter.string(from: syncStart)))
        Profile Age: \(daysSinceProfile) days
        Game Start: \(formatter.string(from: profileCreatedAt))
        """
    }
}

// MARK: - HealthKit Query Helper

extension WorkoutSyncPolicy {
    
    /// Create a HealthKit predicate for querying workouts within the sync window
    /// - Returns: An NSPredicate for HealthKit queries
    func createHealthKitPredicate() -> NSPredicate {
        let syncStart = getSyncStartDate()
        let syncEnd = getSyncEndDate()
        
        return HKQuery.predicateForSamples(
            withStart: syncStart,
            end: syncEnd,
            options: .strictEndDate
        )
    }
    
    /// Create a HealthKit predicate for initial sync
    /// - Returns: An NSPredicate that includes all workouts since profile creation (max 30 days)
    func createInitialSyncPredicate() -> NSPredicate {
        return createHealthKitPredicate()
    }
    
    /// Create a HealthKit predicate for incremental sync
    /// - Parameter lastSyncDate: The date of the last successful sync
    /// - Returns: An NSPredicate for workouts since last sync
    func createIncrementalSyncPredicate(since lastSyncDate: Date) -> NSPredicate {
        let syncStart = max(lastSyncDate, getSyncStartDate())
        let syncEnd = getSyncEndDate()
        
        return HKQuery.predicateForSamples(
            withStart: syncStart,
            end: syncEnd,
            options: .strictEndDate
        )
    }
}