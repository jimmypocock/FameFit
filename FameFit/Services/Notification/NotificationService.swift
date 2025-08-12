//
//  NotificationService.swift
//  FameFit
//
//  Central notification management for all app notifications
//

import Foundation
import UserNotifications

// Protocol moved to Protocols/Notification/NotificationProtocol.swift

// MARK: - Notification Manager

final class NotificationService: NotificationProtocol {
    private let scheduler: NotificationSchedulingProtocol
    private let notificationStore: any NotificationStoringProtocol
    private let unlockService: UnlockNotificationProtocol
    private let messageProvider: MessagingProtocol
    private var apnsManager: APNSProtocol?

    init(
        scheduler: NotificationSchedulingProtocol,
        notificationStore: any NotificationStoringProtocol,
        unlockService: UnlockNotificationProtocol,
        messageProvider: MessagingProtocol,
        apnsManager: APNSProtocol? = nil
    ) {
        self.scheduler = scheduler
        self.notificationStore = notificationStore
        self.unlockService = unlockService
        self.messageProvider = messageProvider
        self.apnsManager = apnsManager

        // Set up notification categories for actions
        setupNotificationCategories()
    }

    // Allow setting APNS manager after init (for dependency injection order)
    func setAPNSService(_ manager: APNSProtocol) {
        apnsManager = manager
    }

    // MARK: - Permission Management

    func requestNotificationPermission() async -> Bool {
        await unlockService.requestNotificationPermission()
    }

    func checkNotificationPermission() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Workout Notifications

    func notifyWorkoutCompleted(_ workout: Workout) async {
        // Get character message
        let message = messageProvider.getWorkoutEndMessage(
            workoutType: workout.workoutType,
            duration: Int(workout.duration / 60),
            calories: Int(workout.totalEnergyBurned),
            xpEarned: workout.xpEarned ?? 0
        )

        let metadata = NotificationMetadataContainer.workout(
            WorkoutNotificationMetadata(
                workoutID: workout.id,
                workoutType: workout.workoutType,
                duration: Int(workout.duration / 60),
                calories: Int(workout.totalEnergyBurned),
                xpEarned: workout.xpEarned ?? 0,
                distance: workout.totalDistance,
                averageHeartRate: workout.averageHeartRate != nil ? Int(workout.averageHeartRate!) : nil
            )
        )

        let request = NotificationRequest(
            type: .workoutCompleted,
            title: "Workout Complete! 💪",
            body: message,
            metadata: metadata,
            actions: [.view]
        )

        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            print("Failed to schedule workout notification: \(error)")
        }
    }

    func notifyXPMilestone(previousXP: Int, currentXP: Int) async {
        // Delegate to unlock service for XP-related notifications
        await unlockService.checkForNewUnlocks(previousXP: previousXP, currentXP: currentXP)
    }

    func notifyStreakUpdate(streak: Int, isAtRisk: Bool) async {
        let type: NotificationType = isAtRisk ? .streakAtRisk : .streakMaintained

        let title: String
        let body: String

        if isAtRisk {
            title = "Streak at Risk! ⚠️"
            body = "Don't lose your \(streak)-day streak! Complete a workout today to keep it going."
        } else {
            title = "Streak Maintained! 🔥"
            body = "Amazing! You've maintained your \(streak)-day workout streak!"
        }

        let request = NotificationRequest(
            type: type,
            title: title,
            body: body,
            priority: isAtRisk ? .high : .medium
        )

        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            print("Failed to schedule streak notification: \(error)")
        }
    }

    // MARK: - Social Notifications

    func notifyNewFollower(from user: UserProfile) async {
        let metadata = NotificationMetadataContainer.social(
            SocialNotificationMetadata(
                userID: user.userID,
                username: user.username,
                displayName: user.username,
                profileImageUrl: user.profileImageURL,
                relationshipType: "follower",
                actionCount: nil
            )
        )

        let request = NotificationRequest(
            type: .newFollower,
            title: "New Follower! 👥",
            body: "\(user.username) (@\(user.username)) started following you",
            metadata: metadata,
            actions: [.view]
        )

        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            print("Failed to schedule new follower notification: \(error)")
        }
    }

    func notifyFollowRequest(from user: UserProfile) async {
        let metadata = NotificationMetadataContainer.social(
            SocialNotificationMetadata(
                userID: user.userID,
                username: user.username,
                displayName: user.username,
                profileImageUrl: user.profileImageURL,
                relationshipType: nil,
                actionCount: nil
            )
        )

        let request = NotificationRequest(
            type: .followRequest,
            title: "Follow Request",
            body: "\(user.username) wants to follow your fitness journey",
            metadata: metadata,
            priority: .immediate,
            actions: [.accept, .decline]
        )

        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            print("Failed to schedule follow request notification: \(error)")
        }
    }

    func notifyFollowAccepted(by user: UserProfile) async {
        let metadata = NotificationMetadataContainer.social(
            SocialNotificationMetadata(
                userID: user.userID,
                username: user.username,
                displayName: user.username,
                profileImageUrl: user.profileImageURL,
                relationshipType: "following",
                actionCount: nil
            )
        )

        let request = NotificationRequest(
            type: .followAccepted,
            title: "Follow Request Accepted",
            body: "\(user.username) accepted your follow request",
            metadata: metadata,
            actions: [.view]
        )

        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            print("Failed to schedule follow accepted notification: \(error)")
        }
    }

    func notifyWorkoutKudos(from user: UserProfile, for workoutID: String) async {
        let metadata = NotificationMetadataContainer.social(
            SocialNotificationMetadata(
                userID: user.userID,
                username: user.username,
                displayName: user.username,
                profileImageUrl: user.profileImageURL,
                relationshipType: nil,
                actionCount: 1
            )
        )

        let request = NotificationRequest(
            type: .workoutKudos,
            title: "Workout Kudos! ❤️",
            body: "\(user.username) cheered your workout",
            metadata: metadata,
            actions: [.view],
            groupID: "kudos_\(workoutID)"
        )

        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            print("Failed to schedule kudos notification: \(error)")
        }
    }

    func notifyWorkoutComment(from user: UserProfile, comment: String, for _: String) async {
        let metadata = NotificationMetadataContainer.social(
            SocialNotificationMetadata(
                userID: user.userID,
                username: user.username,
                displayName: user.username,
                profileImageUrl: user.profileImageURL,
                relationshipType: nil,
                actionCount: nil
            )
        )

        // Truncate comment for notification
        let truncatedComment = comment.count > 50 ? String(comment.prefix(47)) + "..." : comment

        let request = NotificationRequest(
            type: .workoutComment,
            title: "\(user.username) commented",
            body: truncatedComment,
            metadata: metadata,
            priority: .high,
            actions: [.view, .reply]
        )

        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            print("Failed to schedule comment notification: \(error)")
        }
    }

    func notifyMention(by user: UserProfile, in context: String) async {
        let metadata = NotificationMetadataContainer.social(
            SocialNotificationMetadata(
                userID: user.userID,
                username: user.username,
                displayName: user.username,
                profileImageUrl: user.profileImageURL,
                relationshipType: nil,
                actionCount: nil
            )
        )

        let request = NotificationRequest(
            type: .mentioned,
            title: "\(user.username) mentioned you",
            body: context,
            metadata: metadata,
            priority: .immediate,
            actions: [.view]
        )

        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            print("Failed to schedule mention notification: \(error)")
        }
    }
    
    // MARK: - Group Workout Notifications
    
    func notifyGroupWorkoutInvite(workout: GroupWorkout, from host: UserProfile) async {
        let metadata = NotificationMetadataContainer.groupWorkout(
            GroupWorkoutNotificationMetadata(
                workoutID: workout.id,
                workoutName: workout.name,
                workoutType: workout.workoutType.displayName,
                hostID: host.userID,
                hostName: host.username,
                scheduledStart: workout.scheduledStart,
                participantCount: workout.participantCount
            )
        )
        
        let request = NotificationRequest(
            type: .groupWorkoutInvite,
            title: "Group Workout Invite 🏃‍♂️",
            body: "\(host.username) invited you to \(workout.name)",
            metadata: metadata,
            priority: .high,
            actions: [.accept, .decline],
            deliveryDate: nil // Send immediately
        )
        
        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            FameFitLogger.error("Failed to schedule group workout invite notification", error: error, category: FameFitLogger.notifications)
        }
    }
    
    func notifyGroupWorkoutStart(workout: GroupWorkout) async {
        let metadata = NotificationMetadataContainer.groupWorkout(
            GroupWorkoutNotificationMetadata(
                workoutID: workout.id,
                workoutName: workout.name,
                workoutType: workout.workoutType.displayName,
                hostID: workout.hostID,
                hostName: "",
                scheduledStart: workout.scheduledStart,
                participantCount: workout.participantCount
            )
        )
        
        let request = NotificationRequest(
            type: .groupWorkoutStarting,
            title: "Workout Starting Now! 🎯",
            body: "\(workout.name) is starting with \(workout.participantCount) participants",
            metadata: metadata,
            priority: .immediate,
            actions: [.view]
        )
        
        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            FameFitLogger.error("Failed to schedule group workout start notification", error: error, category: FameFitLogger.notifications)
        }
    }
    
    func notifyGroupWorkoutUpdate(workout: GroupWorkout, changeType: String) async {
        let metadata = NotificationMetadataContainer.groupWorkout(
            GroupWorkoutNotificationMetadata(
                workoutID: workout.id,
                workoutName: workout.name,
                workoutType: workout.workoutType.displayName,
                hostID: workout.hostID,
                hostName: "",
                scheduledStart: workout.scheduledStart,
                participantCount: workout.participantCount
            )
        )
        
        let request = NotificationRequest(
            type: .groupWorkoutUpdated,
            title: "Workout Updated 📝",
            body: "\(workout.name) has been \(changeType)",
            metadata: metadata,
            actions: [.view]
        )
        
        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            FameFitLogger.error("Failed to schedule group workout update notification", error: error, category: FameFitLogger.notifications)
        }
    }
    
    func notifyGroupWorkoutCancellation(workout: GroupWorkout) async {
        let metadata = NotificationMetadataContainer.groupWorkout(
            GroupWorkoutNotificationMetadata(
                workoutID: workout.id,
                workoutName: workout.name,
                workoutType: workout.workoutType.displayName,
                hostID: workout.hostID,
                hostName: "",
                scheduledStart: workout.scheduledStart,
                participantCount: workout.participantCount
            )
        )
        
        let request = NotificationRequest(
            type: .groupWorkoutCancelled,
            title: "Workout Cancelled ❌",
            body: "\(workout.name) has been cancelled",
            metadata: metadata,
            priority: .high,
            actions: []
        )
        
        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            FameFitLogger.error("Failed to schedule group workout cancellation notification", error: error, category: FameFitLogger.notifications)
        }
    }
    
    func notifyGroupWorkoutParticipantJoined(workout: GroupWorkout, participant: UserProfile) async {
        let metadata = NotificationMetadataContainer.groupWorkout(
            GroupWorkoutNotificationMetadata(
                workoutID: workout.id,
                workoutName: workout.name,
                workoutType: workout.workoutType.displayName,
                hostID: workout.hostID,
                hostName: "",
                scheduledStart: workout.scheduledStart,
                participantCount: workout.participantCount
            )
        )
        
        let request = NotificationRequest(
            type: .groupWorkoutParticipantJoined,
            title: "New Participant 👥",
            body: "\(participant.username) joined \(workout.name)",
            metadata: metadata,
            groupID: "group_workout_\(workout.id)"
        )
        
        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            FameFitLogger.error("Failed to schedule participant joined notification", error: error, category: FameFitLogger.notifications)
        }
    }
    
    func notifyGroupWorkoutParticipantLeft(workout: GroupWorkout, participant: UserProfile) async {
        let metadata = NotificationMetadataContainer.groupWorkout(
            GroupWorkoutNotificationMetadata(
                workoutID: workout.id,
                workoutName: workout.name,
                workoutType: workout.workoutType.displayName,
                hostID: workout.hostID,
                hostName: "",
                scheduledStart: workout.scheduledStart,
                participantCount: workout.participantCount
            )
        )
        
        let request = NotificationRequest(
            type: .groupWorkoutParticipantLeft,
            title: "Participant Left 👤",
            body: "\(participant.username) left \(workout.name)",
            metadata: metadata,
            groupID: "group_workout_\(workout.id)"
        )
        
        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            FameFitLogger.error("Failed to schedule participant left notification", error: error, category: FameFitLogger.notifications)
        }
    }
    
    func scheduleGroupWorkoutReminder(workout: GroupWorkout) async {
        // Schedule reminder 15 minutes before workout
        let reminderDate = workout.scheduledStart.addingTimeInterval(-900)
        
        guard reminderDate > Date() else { 
            FameFitLogger.debug("Reminder time has passed, not scheduling", category: FameFitLogger.notifications)
            return 
        }
        
        let metadata = NotificationMetadataContainer.groupWorkout(
            GroupWorkoutNotificationMetadata(
                workoutID: workout.id,
                workoutName: workout.name,
                workoutType: workout.workoutType.displayName,
                hostID: workout.hostID,
                hostName: "",
                scheduledStart: workout.scheduledStart,
                participantCount: workout.participantCount
            )
        )
        
        let request = NotificationRequest(
            type: .groupWorkoutReminder,
            title: "Workout Starting Soon! ⏰",
            body: "\(workout.name) starts in 15 minutes",
            metadata: metadata,
            priority: .high,
            actions: [.view],
            deliveryDate: reminderDate
        )
        
        do {
            try await scheduler.scheduleFameFitNotification(request)
            FameFitLogger.info("Scheduled reminder for workout \(workout.name)", category: FameFitLogger.notifications)
        } catch {
            FameFitLogger.error("Failed to schedule group workout reminder", error: error, category: FameFitLogger.notifications)
        }
    }
    
    // MARK: - Challenge Notifications
    
    func notifyChallengeInvite(challenge: WorkoutChallenge, from user: UserProfile) async {
        let metadata = NotificationMetadataContainer.challenge(
            ChallengeNotificationMetadata(
                workoutChallengeID: challenge.id,
                challengeName: challenge.name,
                challengeType: challenge.type.rawValue,
                creatorID: user.userID,
                creatorName: user.username,
                targetValue: challenge.targetValue,
                endDate: challenge.endDate
            )
        )
        
        let request = NotificationRequest(
            type: .challengeInvite,
            title: "Challenge Invite! \(challenge.type.icon)",
            body: "\(user.username) challenged you: \(challenge.name)",
            metadata: metadata,
            priority: .high,
            actions: [.accept, .decline]
        )
        
        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            FameFitLogger.error("Failed to schedule challenge invite notification", error: error, category: FameFitLogger.notifications)
        }
    }
    
    func notifyChallengeStart(challenge: WorkoutChallenge) async {
        let metadata = NotificationMetadataContainer.challenge(
            ChallengeNotificationMetadata(
                workoutChallengeID: challenge.id,
                challengeName: challenge.name,
                challengeType: challenge.type.rawValue,
                creatorID: challenge.creatorID,
                creatorName: nil,
                targetValue: challenge.targetValue,
                endDate: challenge.endDate
            )
        )
        
        let request = NotificationRequest(
            type: .challengeStarted,
            title: "Challenge Started! 🏁",
            body: "\(challenge.name) is now active. Good luck!",
            metadata: metadata,
            actions: [.view]
        )
        
        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            FameFitLogger.error("Failed to schedule challenge start notification", error: error, category: FameFitLogger.notifications)
        }
    }
    
    func notifyChallengeComplete(challenge: WorkoutChallenge, isWinner: Bool) async {
        let title = isWinner ? "You Won! 🏆" : "Challenge Complete!"
        let body = isWinner 
            ? "Congratulations! You won \(challenge.name)!"
            : "The challenge '\(challenge.name)' has ended. Check the results!"
        
        let metadata = NotificationMetadataContainer.challenge(
            ChallengeNotificationMetadata(
                workoutChallengeID: challenge.id,
                challengeName: challenge.name,
                challengeType: challenge.type.rawValue,
                creatorID: challenge.creatorID,
                creatorName: nil,
                targetValue: challenge.targetValue,
                endDate: challenge.endDate
            )
        )
        
        let request = NotificationRequest(
            type: .challengeCompleted,
            title: title,
            body: body,
            metadata: metadata,
            priority: isWinner ? .immediate : .high,
            actions: [.view]
        )
        
        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            FameFitLogger.error("Failed to schedule challenge complete notification", error: error, category: FameFitLogger.notifications)
        }
    }
    
    func notifyChallengeVerificationFailure(linkID: String, workoutName: String) async {
        let metadata = NotificationMetadataContainer.system(
            SystemNotificationMetadata(
                severity: "warning",
                actionUrl: "famefit://verification/\(linkID)",
                requiresAction: true
            )
        )
        
        let request = NotificationRequest(
            type: .workoutVerificationFailed,
            title: "Verification Issue ⚠️",
            body: "Your \(workoutName) couldn't be verified. Tap to request manual verification.",
            metadata: metadata,
            priority: .high,
            actions: [.view]
        )
        
        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            FameFitLogger.error("Failed to schedule verification failure notification", error: error, category: FameFitLogger.notifications)
        }
    }

    // MARK: - System Notifications

    func notifySecurityAlert(title: String, message: String) async {
        let metadata = NotificationMetadataContainer.system(
            SystemNotificationMetadata(
                severity: "critical",
                actionUrl: nil,
                requiresAction: true
            )
        )

        let request = NotificationRequest(
            type: .securityAlert,
            title: title,
            body: message,
            metadata: metadata,
            priority: .immediate,
            actions: [.view]
        )

        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            print("Failed to schedule security alert: \(error)")
        }
    }

    func notifyFeatureAnnouncement(feature: String, description: String) async {
        let metadata = NotificationMetadataContainer.system(
            SystemNotificationMetadata(
                severity: "info",
                actionUrl: nil,
                requiresAction: false
            )
        )

        let request = NotificationRequest(
            type: .featureAnnouncement,
            title: "New Feature: \(feature)",
            body: description,
            metadata: metadata,
            priority: .low,
            actions: [.view]
        )

        do {
            try await scheduler.scheduleFameFitNotification(request)
        } catch {
            print("Failed to schedule feature announcement: \(error)")
        }
    }

    // MARK: - Preference Management

    func updatePreferences(_ preferences: NotificationSettings) {
        scheduler.updatePreferences(preferences)
    }

    func getPreferences() -> NotificationSettings {
        NotificationSettings.load()
    }

    // MARK: - Private Methods

    private func setupNotificationCategories() {
        var categories: [UNNotificationCategory] = []

        // Follow request category
        let acceptAction = UNNotificationAction(
            identifier: NotificationAction.accept.rawValue,
            title: NotificationAction.accept.displayName,
            options: [.authenticationRequired]
        )
        let declineAction = UNNotificationAction(
            identifier: NotificationAction.decline.rawValue,
            title: NotificationAction.decline.displayName,
            options: [.authenticationRequired, .destructive]
        )
        let followCategory = UNNotificationCategory(
            identifier: NotificationType.followRequest.rawValue,
            actions: [acceptAction, declineAction],
            intentIdentifiers: []
        )
        categories.append(followCategory)

        // Comment category
        let replyAction = UNNotificationAction(
            identifier: NotificationAction.reply.rawValue,
            title: NotificationAction.reply.displayName,
            options: [.authenticationRequired]
        )
        let viewAction = UNNotificationAction(
            identifier: NotificationAction.view.rawValue,
            title: NotificationAction.view.displayName,
            options: [.foreground]
        )
        let commentCategory = UNNotificationCategory(
            identifier: NotificationType.workoutComment.rawValue,
            actions: [replyAction, viewAction],
            intentIdentifiers: []
        )
        categories.append(commentCategory)

        // Set categories
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
    }
}

// MARK: - Mock Implementation

final class MockNotificationService: NotificationProtocol {
    var requestPermissionResult = true
    var currentAuthStatus = UNAuthorizationStatus.authorized
    var preferences = NotificationSettings()
    var sentNotifications: [String] = []

    func requestNotificationPermission() async -> Bool {
        requestPermissionResult
    }

    func checkNotificationPermission() async -> UNAuthorizationStatus {
        currentAuthStatus
    }

    func notifyWorkoutCompleted(_ workout: Workout) async {
        sentNotifications.append("workout_completed_\(workout.id)")
    }

    func notifyXPMilestone(previousXP _: Int, currentXP: Int) async {
        sentNotifications.append("xp_milestone_\(currentXP)")
    }

    func notifyStreakUpdate(streak: Int, isAtRisk: Bool) async {
        sentNotifications.append("streak_\(streak)_risk_\(isAtRisk)")
    }

    func notifyNewFollower(from user: UserProfile) async {
        sentNotifications.append("new_follower_\(user.id)")
    }

    func notifyFollowRequest(from user: UserProfile) async {
        sentNotifications.append("follow_request_\(user.id)")
    }

    func notifyFollowAccepted(by user: UserProfile) async {
        sentNotifications.append("follow_accepted_\(user.id)")
    }

    func notifyWorkoutKudos(from user: UserProfile, for workoutID: String) async {
        sentNotifications.append("kudos_\(user.id)_\(workoutID)")
    }

    func notifyWorkoutComment(from user: UserProfile, comment _: String, for workoutID: String) async {
        sentNotifications.append("comment_\(user.id)_\(workoutID)")
    }

    func notifyMention(by user: UserProfile, in _: String) async {
        sentNotifications.append("mention_\(user.id)")
    }

    func notifySecurityAlert(title _: String, message _: String) async {
        sentNotifications.append("security_alert")
    }

    func notifyFeatureAnnouncement(feature: String, description _: String) async {
        sentNotifications.append("feature_\(feature)")
    }
    
    // Group workout notifications
    func notifyGroupWorkoutInvite(workout: GroupWorkout, from host: UserProfile) async {
        sentNotifications.append("group_invite_\(workout.id)")
    }
    
    func notifyGroupWorkoutStart(workout: GroupWorkout) async {
        sentNotifications.append("group_start_\(workout.id)")
    }
    
    func notifyGroupWorkoutUpdate(workout: GroupWorkout, changeType: String) async {
        sentNotifications.append("group_update_\(workout.id)_\(changeType)")
    }
    
    func notifyGroupWorkoutCancellation(workout: GroupWorkout) async {
        sentNotifications.append("group_cancel_\(workout.id)")
    }
    
    func notifyGroupWorkoutParticipantJoined(workout: GroupWorkout, participant: UserProfile) async {
        sentNotifications.append("group_joined_\(workout.id)_\(participant.id)")
    }
    
    func notifyGroupWorkoutParticipantLeft(workout: GroupWorkout, participant: UserProfile) async {
        sentNotifications.append("group_left_\(workout.id)_\(participant.id)")
    }
    
    func scheduleGroupWorkoutReminder(workout: GroupWorkout) async {
        sentNotifications.append("group_reminder_\(workout.id)")
    }
    
    // Challenge notifications
    func notifyChallengeInvite(challenge: WorkoutChallenge, from user: UserProfile) async {
        sentNotifications.append("challenge_invite_\(challenge.id)")
    }
    
    func notifyChallengeStart(challenge: WorkoutChallenge) async {
        sentNotifications.append("challenge_start_\(challenge.id)")
    }
    
    func notifyChallengeComplete(challenge: WorkoutChallenge, isWinner: Bool) async {
        sentNotifications.append("challenge_complete_\(challenge.id)_\(isWinner)")
    }
    
    func notifyChallengeVerificationFailure(linkID: String, workoutName: String) async {
        sentNotifications.append("verification_failed_\(linkID)")
    }

    func updatePreferences(_ preferences: NotificationSettings) {
        self.preferences = preferences
    }

    func getPreferences() -> NotificationSettings {
        preferences
    }
}
