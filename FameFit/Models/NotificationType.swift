//
//  NotificationType.swift
//  FameFit
//
//  Defines all notification types and their properties
//

import Foundation

// MARK: - Notification Category

enum NotificationCategory: String, Codable, CaseIterable {
    case workout
    case social
    case system

    var displayName: String {
        switch self {
        case .workout:
            "Workout"
        case .social:
            "Social"
        case .system:
            "System"
        }
    }
}

// MARK: - Notification Type

enum NotificationType: String, Codable, CaseIterable {
    // Workout notifications
    case workoutCompleted = "workout_completed"
    case workoutShared = "workout_shared"
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
    case mentioned
    case challengeInvite = "challenge_invite"
    case challengeStarted = "challenge_started"
    case challengeCompleted = "challenge_completed"
    case leaderboardChange = "leaderboard_change"
    
    // Group workout notifications
    case groupWorkoutInvite = "group_workout_invite"
    case groupWorkoutStarting = "group_workout_starting"
    case groupWorkoutUpdated = "group_workout_updated"
    case groupWorkoutCancelled = "group_workout_cancelled"
    case groupWorkoutParticipantJoined = "group_workout_participant_joined"
    case groupWorkoutParticipantLeft = "group_workout_participant_left"
    case groupWorkoutReminder = "group_workout_reminder"
    
    // Verification notifications
    case workoutVerificationFailed = "workout_verification_failed"

    // System notifications
    case securityAlert = "security_alert"
    case privacyUpdate = "privacy_update"
    case featureAnnouncement = "feature_announcement"
    case maintenanceNotice = "maintenance_notice"

    var category: NotificationCategory {
        switch self {
        case .workoutCompleted, .workoutShared, .xpMilestone, .levelUp, .streakMaintained, .streakAtRisk, .unlockAchieved:
            .workout
        case .newFollower, .followRequest, .followAccepted, .workoutKudos, .workoutComment, .mentioned,
             .challengeInvite, .challengeStarted, .challengeCompleted, .leaderboardChange,
             .groupWorkoutInvite, .groupWorkoutStarting, .groupWorkoutUpdated, .groupWorkoutCancelled,
             .groupWorkoutParticipantJoined, .groupWorkoutParticipantLeft, .groupWorkoutReminder:
            .social
        case .workoutVerificationFailed:
            .system
        case .securityAlert, .privacyUpdate, .featureAnnouncement, .maintenanceNotice:
            .system
        }
    }

    var defaultPriority: NotificationPriority {
        switch self {
        case .securityAlert, .mentioned, .followRequest:
            .immediate
        case .workoutCompleted, .workoutShared, .xpMilestone, .levelUp, .followAccepted, .challengeInvite, .challengeStarted,
             .groupWorkoutInvite, .groupWorkoutStarting:
            .high
        case .newFollower, .workoutComment, .streakMaintained, .unlockAchieved,
             .groupWorkoutUpdated, .groupWorkoutParticipantJoined, .groupWorkoutParticipantLeft:
            .medium
        case .workoutKudos, .leaderboardChange, .streakAtRisk,
             .groupWorkoutCancelled, .groupWorkoutReminder:
            .low
        case .privacyUpdate, .featureAnnouncement, .maintenanceNotice, .challengeCompleted,
             .workoutVerificationFailed:
            .low
        }
    }

    var defaultSetting: NotificationSetting {
        switch self {
        case .workoutCompleted, .workoutShared, .xpMilestone, .levelUp, .unlockAchieved:
            .enabled
        case .streakMaintained, .streakAtRisk:
            .enabled
        case .newFollower, .followRequest, .followAccepted:
            .enabled
        case .workoutKudos:
            .batched
        case .workoutComment, .mentioned, .challengeInvite:
            .immediate
        case .challengeStarted:
            .enabled
        case .leaderboardChange:
            .weekly
        case .securityAlert:
            .immediate
        case .privacyUpdate, .featureAnnouncement, .maintenanceNotice:
            .enabled
        case .challengeCompleted:
            .enabled
        case .groupWorkoutInvite, .groupWorkoutStarting:
            .immediate
        case .groupWorkoutUpdated, .groupWorkoutCancelled, .groupWorkoutParticipantJoined,
             .groupWorkoutParticipantLeft, .groupWorkoutReminder:
            .enabled
        case .workoutVerificationFailed:
            .enabled
        }
    }

    var soundEnabled: Bool {
        switch self {
        case .workoutCompleted, .xpMilestone, .levelUp, .followRequest, .mentioned, .challengeInvite, .challengeStarted,
             .securityAlert:
            true
        default:
            false
        }
    }

    var displayName: String {
        switch self {
        case .workoutCompleted:
            "Workout Completed"
        case .workoutShared:
            "Workout Shared"
        case .xpMilestone:
            "XP Milestone"
        case .levelUp:
            "Level Up"
        case .streakMaintained:
            "Streak Maintained"
        case .streakAtRisk:
            "Streak at Risk"
        case .unlockAchieved:
            "New Unlock"
        case .newFollower:
            "New Follower"
        case .followRequest:
            "Follow Request"
        case .followAccepted:
            "Follow Accepted"
        case .workoutKudos:
            "Workout Kudos"
        case .workoutComment:
            "Workout Comment"
        case .mentioned:
            "Mentioned"
        case .challengeInvite:
            "Challenge Invite"
        case .challengeStarted:
            "Challenge Started"
        case .challengeCompleted:
            "Challenge Completed"
        case .leaderboardChange:
            "Leaderboard Update"
        case .securityAlert:
            "Security Alert"
        case .privacyUpdate:
            "Privacy Update"
        case .featureAnnouncement:
            "New Feature"
        case .maintenanceNotice:
            "Maintenance"
        case .groupWorkoutInvite:
            "Group Workout Invite"
        case .groupWorkoutStarting:
            "Group Workout Starting"
        case .groupWorkoutUpdated:
            "Group Workout Updated"
        case .groupWorkoutCancelled:
            "Group Workout Cancelled"
        case .groupWorkoutParticipantJoined:
            "Participant Joined"
        case .groupWorkoutParticipantLeft:
            "Participant Left"
        case .groupWorkoutReminder:
            "Group Workout Reminder"
        case .workoutVerificationFailed:
            "Verification Failed"
        }
    }

    var icon: String {
        switch self {
        case .workoutCompleted:
            "🏃"
        case .workoutShared:
            "📢"
        case .xpMilestone, .levelUp:
            "🎉"
        case .streakMaintained:
            "🔥"
        case .streakAtRisk:
            "⚠️"
        case .unlockAchieved:
            "🏆"
        case .newFollower, .followRequest, .followAccepted:
            "👥"
        case .workoutKudos:
            "❤️"
        case .workoutComment:
            "💬"
        case .mentioned:
            "@"
        case .challengeInvite, .challengeStarted, .challengeCompleted:
            "⚔️"
        case .leaderboardChange:
            "📊"
        case .securityAlert:
            "🔐"
        case .privacyUpdate:
            "🔒"
        case .featureAnnouncement:
            "✨"
        case .maintenanceNotice:
            "🔧"
        case .groupWorkoutInvite, .groupWorkoutStarting, .groupWorkoutUpdated,
             .groupWorkoutCancelled, .groupWorkoutParticipantJoined,
             .groupWorkoutParticipantLeft, .groupWorkoutReminder:
            "🏋️"
        case .workoutVerificationFailed:
            "❌"
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
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Notification Setting

enum NotificationSetting: String, Codable, CaseIterable {
    case disabled // Never notify
    case enabled // Notify immediately
    case batched // Group notifications
    case immediate // Always immediate, ignore batching
    case daily // Once per day summary
    case weekly // Once per week summary

    var displayName: String {
        switch self {
        case .disabled:
            "Off"
        case .enabled:
            "On"
        case .batched:
            "Grouped"
        case .immediate:
            "Instant"
        case .daily:
            "Daily Summary"
        case .weekly:
            "Weekly Summary"
        }
    }

    var isEnabled: Bool {
        self != .disabled
    }
}

// MARK: - Notification Action

enum NotificationAction: String, Codable {
    case view
    case kudos
    case reply
    case accept
    case decline
    case dismiss
    case join
    case verify

    var displayName: String {
        switch self {
        case .view:
            "View"
        case .kudos:
            "Kudos"
        case .reply:
            "Reply"
        case .accept:
            "Accept"
        case .decline:
            "Decline"
        case .dismiss:
            "Dismiss"
        case .join:
            "Join"
        case .verify:
            "Verify"
        }
    }
}
