//
//  NotificationType.swift
//  FameFit
//
//  Defines all notification types and their properties
//

import Foundation

// MARK: - Notification Category

enum NotificationCategory: String, Codable, CaseIterable {
    case workout = "workout"
    case social = "social"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .workout:
            return "Workout"
        case .social:
            return "Social"
        case .system:
            return "System"
        }
    }
}

// MARK: - Notification Type

enum NotificationType: String, Codable, CaseIterable {
    // Workout notifications
    case workoutCompleted = "workout_completed"
    case xpMilestone = "xp_milestone"
    case levelUp = "level_up"
    case streakMaintained = "streak_maintained"
    case streakAtRisk = "streak_at_risk"
    case unlockAchieved = "unlock_achieved"
    
    // Social notifications
    case newFollower = "new_follower"
    case followRequest = "follow_request"
    case followAccepted = "follow_accepted"
    case workoutKudos = "workout_kudos"
    case workoutComment = "workout_comment"
    case mentioned = "mentioned"
    case challengeInvite = "challenge_invite"
    case challengeCompleted = "challenge_completed"
    case leaderboardChange = "leaderboard_change"
    
    // System notifications
    case securityAlert = "security_alert"
    case privacyUpdate = "privacy_update"
    case featureAnnouncement = "feature_announcement"
    case maintenanceNotice = "maintenance_notice"
    
    var category: NotificationCategory {
        switch self {
        case .workoutCompleted, .xpMilestone, .levelUp, .streakMaintained, .streakAtRisk, .unlockAchieved:
            return .workout
        case .newFollower, .followRequest, .followAccepted, .workoutKudos, .workoutComment, .mentioned, .challengeInvite, .challengeCompleted, .leaderboardChange:
            return .social
        case .securityAlert, .privacyUpdate, .featureAnnouncement, .maintenanceNotice:
            return .system
        }
    }
    
    var defaultPriority: NotificationPriority {
        switch self {
        case .securityAlert, .mentioned, .followRequest:
            return .immediate
        case .workoutCompleted, .xpMilestone, .levelUp, .followAccepted, .challengeInvite:
            return .high
        case .newFollower, .workoutComment, .streakMaintained, .unlockAchieved:
            return .medium
        case .workoutKudos, .leaderboardChange, .streakAtRisk:
            return .low
        case .privacyUpdate, .featureAnnouncement, .maintenanceNotice, .challengeCompleted:
            return .low
        }
    }
    
    var defaultSetting: NotificationSetting {
        switch self {
        case .workoutCompleted, .xpMilestone, .levelUp, .unlockAchieved:
            return .enabled
        case .streakMaintained, .streakAtRisk:
            return .enabled
        case .newFollower, .followRequest, .followAccepted:
            return .enabled
        case .workoutKudos:
            return .batched
        case .workoutComment, .mentioned, .challengeInvite:
            return .immediate
        case .leaderboardChange:
            return .weekly
        case .securityAlert:
            return .immediate
        case .privacyUpdate, .featureAnnouncement, .maintenanceNotice:
            return .enabled
        case .challengeCompleted:
            return .enabled
        }
    }
    
    var soundEnabled: Bool {
        switch self {
        case .workoutCompleted, .xpMilestone, .levelUp, .followRequest, .mentioned, .challengeInvite, .securityAlert:
            return true
        default:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .workoutCompleted:
            return "Workout Completed"
        case .xpMilestone:
            return "XP Milestone"
        case .levelUp:
            return "Level Up"
        case .streakMaintained:
            return "Streak Maintained"
        case .streakAtRisk:
            return "Streak at Risk"
        case .unlockAchieved:
            return "New Unlock"
        case .newFollower:
            return "New Follower"
        case .followRequest:
            return "Follow Request"
        case .followAccepted:
            return "Follow Accepted"
        case .workoutKudos:
            return "Workout Kudos"
        case .workoutComment:
            return "Workout Comment"
        case .mentioned:
            return "Mentioned"
        case .challengeInvite:
            return "Challenge Invite"
        case .challengeCompleted:
            return "Challenge Completed"
        case .leaderboardChange:
            return "Leaderboard Update"
        case .securityAlert:
            return "Security Alert"
        case .privacyUpdate:
            return "Privacy Update"
        case .featureAnnouncement:
            return "New Feature"
        case .maintenanceNotice:
            return "Maintenance"
        }
    }
    
    var icon: String {
        switch self {
        case .workoutCompleted:
            return "🏃"
        case .xpMilestone, .levelUp:
            return "🎉"
        case .streakMaintained:
            return "🔥"
        case .streakAtRisk:
            return "⚠️"
        case .unlockAchieved:
            return "🏆"
        case .newFollower, .followRequest, .followAccepted:
            return "👥"
        case .workoutKudos:
            return "❤️"
        case .workoutComment:
            return "💬"
        case .mentioned:
            return "@"
        case .challengeInvite, .challengeCompleted:
            return "⚔️"
        case .leaderboardChange:
            return "📊"
        case .securityAlert:
            return "🔐"
        case .privacyUpdate:
            return "🔒"
        case .featureAnnouncement:
            return "✨"
        case .maintenanceNotice:
            return "🔧"
        }
    }
}

// MARK: - Notification Priority

enum NotificationPriority: Int, Codable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case immediate = 3
    
    static func < (lhs: NotificationPriority, rhs: NotificationPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Notification Setting

enum NotificationSetting: String, Codable, CaseIterable {
    case disabled       // Never notify
    case enabled        // Notify immediately
    case batched        // Group notifications
    case immediate      // Always immediate, ignore batching
    case daily          // Once per day summary
    case weekly         // Once per week summary
    
    var displayName: String {
        switch self {
        case .disabled:
            return "Off"
        case .enabled:
            return "On"
        case .batched:
            return "Grouped"
        case .immediate:
            return "Instant"
        case .daily:
            return "Daily Summary"
        case .weekly:
            return "Weekly Summary"
        }
    }
    
    var isEnabled: Bool {
        return self != .disabled
    }
}

// MARK: - Notification Action

enum NotificationAction: String, Codable {
    case view = "view"
    case kudos = "kudos"
    case reply = "reply"
    case accept = "accept"
    case decline = "decline"
    case dismiss = "dismiss"
    
    var displayName: String {
        switch self {
        case .view:
            return "View"
        case .kudos:
            return "Kudos"
        case .reply:
            return "Reply"
        case .accept:
            return "Accept"
        case .decline:
            return "Decline"
        case .dismiss:
            return "Dismiss"
        }
    }
}