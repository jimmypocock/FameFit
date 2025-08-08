//
//  CloudKitConfiguration.swift
//  FameFit
//
//  CloudKit configuration and constants
//

import CloudKit
import Foundation

/// CloudKit configuration and constants
enum CloudKitConfiguration {
    // MARK: - Record Types
    
    enum RecordType {
        static let users = "Users"
        static let workouts = "Workouts"
        static let userSettings = "UserSettings"
        static let deviceTokens = "DeviceTokens"
        static let userProfiles = "UserProfiles"
        static let userRelationships = "UserRelationships"
        static let activityFeed = "ActivityFeed"
        static let workoutKudos = "WorkoutKudos"
        static let workoutComments = "WorkoutComments"
        static let groupWorkouts = "GroupWorkouts"
        static let groupWorkoutParticipants = "GroupWorkoutParticipants"
        static let groupWorkoutInvites = "GroupWorkoutInvites"
        static let workoutChallenges = "WorkoutChallenges"
    }
    
    // MARK: - Field Names
    
    enum UserFields {
        static let displayName = "displayName"
        static let totalXP = "totalXP"
        static let totalWorkouts = "totalWorkouts"
        static let currentStreak = "currentStreak"
        static let joinTimestamp = "joinTimestamp"
        static let lastWorkoutTimestamp = "lastWorkoutTimestamp"
    }
    
    enum WorkoutFields {
        static let workoutID = "workoutID"
        static let workoutType = "workoutType"
        static let startDate = "startDate"
        static let endDate = "endDate"
        static let duration = "duration"
        static let totalEnergyBurned = "totalEnergyBurned"
        static let totalDistance = "totalDistance"
        static let averageHeartRate = "averageHeartRate"
        static let followersEarned = "followersEarned"
        static let xpEarned = "xpEarned"
        static let source = "source"
    }
    
    // MARK: - Configuration Values
    
    static let containerIdentifier = "iCloud.com.jimmypocock.FameFit"
    static let subscriptionPrefix = "FameFit"
    
    // Timeouts and intervals
    static let defaultTimeout: TimeInterval = 30.0
    static let syncInterval: TimeInterval = 300.0 // 5 minutes
    static let cacheExpiration: TimeInterval = 600.0 // 10 minutes
    
    // Limits
    static let batchSize = 100
    static let maxRetries = 3
    static let rateLimitDelay: TimeInterval = 1.0
    
    // MARK: - Error Messages
    
    enum ErrorMessage {
        static let notAuthenticated = "User must be signed in to iCloud"
        static let networkUnavailable = "Network connection required"
        static let quotaExceeded = "iCloud storage quota exceeded"
        static let permissionDenied = "Permission denied for this operation"
    }
}
