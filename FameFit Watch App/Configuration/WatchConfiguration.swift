//
//  WatchConfiguration.swift
//  FameFit Watch App
//
//  Central configuration for all Watch app constants and settings
//

import Foundation
import HealthKit

enum WatchConfiguration {
    
    // MARK: - Display Mode Detection
    
    enum DisplayMode {
        case active        // Full brightness, user interacting
        case alwaysOn      // Dimmed display, minimal updates
        case background    // App not visible
        case inactive      // App suspended
    }
    
    // MARK: - Update Frequencies (Battery Optimized - Matches Apple Fitness+/Nike/Strava)
    
    enum UpdateFrequency {
        /// Elapsed time updates based on display mode
        static func elapsedTime(for mode: DisplayMode) -> TimeInterval {
            switch mode {
            case .active: return 1.0      // Every second when active
            case .alwaysOn: return 60.0    // Once per minute in AOD
            case .background: return 0     // No updates in background
            case .inactive: return 0       // No updates when inactive
            }
        }
        
        /// Metrics (HR, calories, distance) updates based on display mode
        static func metrics(for mode: DisplayMode) -> TimeInterval {
            switch mode {
            case .active: return 3.0       // Every 3 seconds when active
            case .alwaysOn: return 30.0    // Every 30 seconds in AOD
            case .background: return 60.0  // Every minute in background
            case .inactive: return 0       // No updates when inactive
            }
        }
        
        /// Background sync interval for non-critical updates
        static let backgroundSync: TimeInterval = 30.0
        
        /// Group workout sync interval (battery-conscious)
        /// Only sync every 2 minutes to preserve battery during long workouts
        static let groupWorkoutSync: TimeInterval = 120.0
        
        /// Challenge progress check interval
        static let challengeCheck: TimeInterval = 30.0
        
        /// WatchConnectivity batch interval
        static let watchConnectivityBatch: TimeInterval = 5.0
    }
    
    // MARK: - Cache Settings
    
    enum Cache {
        /// How long to cache user profile data
        static let profileCacheDuration: TimeInterval = 86400 // 24 hours
        
        /// How long to cache group workout data
        static let groupWorkoutCacheDuration: TimeInterval = 3600 // 1 hour
        
        /// How long to cache challenge data
        static let challengeCacheDuration: TimeInterval = 1800 // 30 minutes
        
        /// Maximum number of cached workouts
        static let maxCachedWorkouts = 10
    }
    
    // MARK: - HealthKit Settings
    
    enum HealthKit {
        /// Types to write to HealthKit
        static let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]
        
        /// Types to read from HealthKit
        static let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKQuantityType.quantityType(forIdentifier: .distanceSwimming)!,
            HKObjectType.workoutType()
        ]
        
        /// Minimum heart rate considered valid
        static let minValidHeartRate: Double = 30
        
        /// Maximum heart rate considered valid
        static let maxValidHeartRate: Double = 220
    }
    
    // MARK: - Network Settings
    
    enum Network {
        /// Timeout for WatchConnectivity messages
        static let messageTimeout: TimeInterval = 5.0
        
        /// Maximum retry attempts for failed syncs
        static let maxRetryAttempts = 3
        
        /// Delay between retry attempts
        static let retryDelay: TimeInterval = 2.0
    }
    
    // MARK: - UI Settings
    
    enum UI {
        /// Animation duration for view transitions
        static let animationDuration: TimeInterval = 0.3
        
        /// Haptic feedback enabled
        static let hapticsEnabled = true
        
        /// Show debug information in development
        #if DEBUG
        static let showDebugInfo = true
        #else
        static let showDebugInfo = false
        #endif
    }
    
    // MARK: - Storage Keys (Type-safe, organized by domain)
    
    enum StorageKeys {
        enum Profile: String, CaseIterable {
            case userData = "watch.profile.user_data"
            case username = "watch.profile.username"
            case totalXP = "watch.profile.total_xp"
            case timestamp = "watch.profile.timestamp"
            case allowWithoutAccount = "watch.profile.allow_without_account"
        }
        
        enum GroupWorkout: String, CaseIterable {
            case activeWorkouts = "watch.group.active_workouts"
            case pendingWorkoutID = "watch.group.pending_id"
            case pendingWorkoutName = "watch.group.pending_name"
            case pendingWorkoutType = "watch.group.pending_type"
            case pendingWorkoutIsHost = "watch.group.pending_is_host"
            case timestamp = "watch.group.timestamp"
        }
        
        enum Challenge: String, CaseIterable {
            case activeChallenges = "watch.challenge.active"
            case progress = "watch.challenge.progress"
            case timestamp = "watch.challenge.timestamp"
        }
        
        enum Sync: String, CaseIterable {
            case lastSync = "watch.sync.last_date"
            case lastWorkoutUpload = "watch.sync.last_workout_upload"
            case pendingUploads = "watch.sync.pending_uploads"
        }
        
        enum Workout: String, CaseIterable {
            case activeSession = "watch.workout.active_session"
            case lastCompletedID = "watch.workout.last_completed_id"
        }
        
        enum Complication: String, CaseIterable {
            case xp = "watch.complication.xp"
            case streak = "watch.complication.streak"
            case totalWorkouts = "watch.complication.total_workouts"
            case todayWorkouts = "watch.complication.today_workouts"
        }
    }
}