//
//  QueueItemTypes.swift
//  FameFit
//
//  Queue item types and structures
//

import Foundation

// MARK: - Base Queue Item

/// Base structure for all queue items
struct QueueItem: Codable, Sendable {
    let id: String
    let type: ItemType
    let data: Data
    var attempts: Int
    var lastAttemptDate: Date
    let priority: Priority
    let createdDate: Date
    
    init(id: String = UUID().uuidString,
         type: ItemType,
         data: Data,
         priority: Priority = .medium) {
        self.id = id
        self.type = type
        self.data = data
        self.attempts = 0
        self.lastAttemptDate = Date()
        self.priority = priority
        self.createdDate = Date()
    }
}

// MARK: - Item Types

extension QueueItem {
    enum ItemType: String, Codable, Sendable {
        // Workout operations
        case workoutSave
        case xpTransaction
        case statsUpdate
        
        // Social operations
        case activityFeed
        case notification
        
        // Challenge operations
        case challengeLink
        case challengeVerification
        
        // Profile operations
        case profileUpdate
        case profileStatsUpdate
    }
}

// MARK: - Priority

extension QueueItem {
    enum Priority: Int, Codable, Sendable, Comparable {
        case low = 0
        case medium = 1
        case high = 2
        case critical = 3
        
        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - Specific Queue Item Payloads

/// Workout save operation data
struct WorkoutSavePayload: Codable, Sendable {
    let workout: Workout
    let userID: String
}

/// XP transaction operation data
struct XPTransactionPayload: Codable, Sendable {
    let workoutID: String
    let userID: String
    let baseXP: Int
    let finalXP: Int
    let factors: XPCalculationFactors
}

/// Stats update operation data
struct StatsUpdatePayload: Codable, Sendable {
    let userID: String
    let xpEarned: Int
    let workoutCompleted: Bool
}

/// Activity feed post operation data
struct ActivityFeedPayload: Codable, Sendable {
    let workout: Workout
    let privacy: WorkoutPrivacy
    let includeDetails: Bool
}

/// Notification operation data
struct NotificationPayload: Codable, Sendable {
    let workoutID: String
    let xpEarned: Int
    let workoutType: String
    let previousXP: Int
    let currentXP: Int
}

/// Challenge link operation data
struct ChallengeLinkPayload: Codable, Sendable {
    let workout: Workout
    let userID: String
    let challengeIDs: [String]
}

// MARK: - Helper Extensions

extension QueueItem {
    /// Check if this item is critical (should be processed first)
    var isCritical: Bool {
        switch type {
        case .workoutSave, .xpTransaction, .statsUpdate:
            return true
        default:
            return false
        }
    }
    
    /// Check if this item can be retried
    var isRetryable: Bool {
        // All items are retryable up to max attempts
        return attempts < 5
    }
    
    /// Get a human-readable description
    var description: String {
        "\(type.rawValue) (priority: \(priority.rawValue), attempts: \(attempts))"
    }
}