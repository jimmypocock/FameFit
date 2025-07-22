//
//  NotificationManager.swift
//  FameFit
//
//  Central notification management for all app notifications
//

import Foundation
import UserNotifications

// MARK: - Notification Manager Protocol

protocol NotificationManaging {
    // Permission management
    func requestNotificationPermission() async -> Bool
    func checkNotificationPermission() async -> UNAuthorizationStatus
    
    // Workout notifications
    func notifyWorkoutCompleted(_ workout: WorkoutHistoryItem) async
    func notifyXPMilestone(previousXP: Int, currentXP: Int) async
    func notifyStreakUpdate(streak: Int, isAtRisk: Bool) async
    
    // Social notifications
    func notifyNewFollower(from user: UserProfile) async
    func notifyFollowRequest(from user: UserProfile) async
    func notifyFollowAccepted(by user: UserProfile) async
    func notifyWorkoutKudos(from user: UserProfile, for workoutId: String) async
    func notifyWorkoutComment(from user: UserProfile, comment: String, for workoutId: String) async
    func notifyMention(by user: UserProfile, in context: String) async
    
    // System notifications
    func notifySecurityAlert(title: String, message: String) async
    func notifyFeatureAnnouncement(feature: String, description: String) async
    
    // Preference management
    func updatePreferences(_ preferences: NotificationPreferences)
    func getPreferences() -> NotificationPreferences
}

// MARK: - Notification Manager

final class NotificationManager: NotificationManaging {
    private let scheduler: NotificationScheduling
    private let notificationStore: any NotificationStoring
    private let unlockService: UnlockNotificationServiceProtocol
    private let messageProvider: MessageProviding
    private var apnsManager: APNSManaging?
    
    init(
        scheduler: NotificationScheduling,
        notificationStore: any NotificationStoring,
        unlockService: UnlockNotificationServiceProtocol,
        messageProvider: MessageProviding,
        apnsManager: APNSManaging? = nil
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
    func setAPNSManager(_ manager: APNSManaging) {
        self.apnsManager = manager
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission() async -> Bool {
        return await unlockService.requestNotificationPermission()
    }
    
    func checkNotificationPermission() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Workout Notifications
    
    func notifyWorkoutCompleted(_ workout: WorkoutHistoryItem) async {
        // Get character message
        let message = messageProvider.getWorkoutEndMessage(
            workoutType: workout.workoutType,
            duration: Int(workout.duration / 60),
            calories: Int(workout.totalEnergyBurned),
            xpEarned: workout.xpEarned ?? 0
        )
        
        let metadata = NotificationMetadataContainer.workout(
            WorkoutNotificationMetadata(
                workoutId: workout.id.uuidString,
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
            try await scheduler.scheduleNotification(request)
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
            try await scheduler.scheduleNotification(request)
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
                displayName: user.displayName,
                profileImageUrl: user.profileImageURL,
                relationshipType: "follower",
                actionCount: nil
            )
        )
        
        let request = NotificationRequest(
            type: .newFollower,
            title: "New Follower! 👥",
            body: "\(user.displayName) (@\(user.username)) started following you",
            metadata: metadata,
            actions: [.view]
        )
        
        do {
            try await scheduler.scheduleNotification(request)
        } catch {
            print("Failed to schedule new follower notification: \(error)")
        }
    }
    
    func notifyFollowRequest(from user: UserProfile) async {
        let metadata = NotificationMetadataContainer.social(
            SocialNotificationMetadata(
                userID: user.userID,
                username: user.username,
                displayName: user.displayName,
                profileImageUrl: user.profileImageURL,
                relationshipType: nil,
                actionCount: nil
            )
        )
        
        let request = NotificationRequest(
            type: .followRequest,
            title: "Follow Request",
            body: "\(user.displayName) wants to follow your fitness journey",
            metadata: metadata,
            priority: .immediate,
            actions: [.accept, .decline]
        )
        
        do {
            try await scheduler.scheduleNotification(request)
        } catch {
            print("Failed to schedule follow request notification: \(error)")
        }
    }
    
    func notifyFollowAccepted(by user: UserProfile) async {
        let metadata = NotificationMetadataContainer.social(
            SocialNotificationMetadata(
                userID: user.userID,
                username: user.username,
                displayName: user.displayName,
                profileImageUrl: user.profileImageURL,
                relationshipType: "following",
                actionCount: nil
            )
        )
        
        let request = NotificationRequest(
            type: .followAccepted,
            title: "Follow Request Accepted",
            body: "\(user.displayName) accepted your follow request",
            metadata: metadata,
            actions: [.view]
        )
        
        do {
            try await scheduler.scheduleNotification(request)
        } catch {
            print("Failed to schedule follow accepted notification: \(error)")
        }
    }
    
    func notifyWorkoutKudos(from user: UserProfile, for workoutId: String) async {
        let metadata = NotificationMetadataContainer.social(
            SocialNotificationMetadata(
                userID: user.userID,
                username: user.username,
                displayName: user.displayName,
                profileImageUrl: user.profileImageURL,
                relationshipType: nil,
                actionCount: 1
            )
        )
        
        let request = NotificationRequest(
            type: .workoutKudos,
            title: "Workout Kudos! ❤️",
            body: "\(user.displayName) cheered your workout",
            metadata: metadata,
            actions: [.view],
            groupId: "kudos_\(workoutId)"
        )
        
        do {
            try await scheduler.scheduleNotification(request)
        } catch {
            print("Failed to schedule kudos notification: \(error)")
        }
    }
    
    func notifyWorkoutComment(from user: UserProfile, comment: String, for workoutId: String) async {
        let metadata = NotificationMetadataContainer.social(
            SocialNotificationMetadata(
                userID: user.userID,
                username: user.username,
                displayName: user.displayName,
                profileImageUrl: user.profileImageURL,
                relationshipType: nil,
                actionCount: nil
            )
        )
        
        // Truncate comment for notification
        let truncatedComment = comment.count > 50 ? String(comment.prefix(47)) + "..." : comment
        
        let request = NotificationRequest(
            type: .workoutComment,
            title: "\(user.displayName) commented",
            body: truncatedComment,
            metadata: metadata,
            priority: .high,
            actions: [.view, .reply]
        )
        
        do {
            try await scheduler.scheduleNotification(request)
        } catch {
            print("Failed to schedule comment notification: \(error)")
        }
    }
    
    func notifyMention(by user: UserProfile, in context: String) async {
        let metadata = NotificationMetadataContainer.social(
            SocialNotificationMetadata(
                userID: user.userID,
                username: user.username,
                displayName: user.displayName,
                profileImageUrl: user.profileImageURL,
                relationshipType: nil,
                actionCount: nil
            )
        )
        
        let request = NotificationRequest(
            type: .mentioned,
            title: "\(user.displayName) mentioned you",
            body: context,
            metadata: metadata,
            priority: .immediate,
            actions: [.view]
        )
        
        do {
            try await scheduler.scheduleNotification(request)
        } catch {
            print("Failed to schedule mention notification: \(error)")
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
            try await scheduler.scheduleNotification(request)
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
            try await scheduler.scheduleNotification(request)
        } catch {
            print("Failed to schedule feature announcement: \(error)")
        }
    }
    
    // MARK: - Preference Management
    
    func updatePreferences(_ preferences: NotificationPreferences) {
        scheduler.updatePreferences(preferences)
    }
    
    func getPreferences() -> NotificationPreferences {
        return NotificationPreferences.load()
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

final class MockNotificationManager: NotificationManaging {
    var requestPermissionResult = true
    var currentAuthStatus = UNAuthorizationStatus.authorized
    var preferences = NotificationPreferences()
    var sentNotifications: [String] = []
    
    func requestNotificationPermission() async -> Bool {
        return requestPermissionResult
    }
    
    func checkNotificationPermission() async -> UNAuthorizationStatus {
        return currentAuthStatus
    }
    
    func notifyWorkoutCompleted(_ workout: WorkoutHistoryItem) async {
        sentNotifications.append("workout_completed_\(workout.id)")
    }
    
    func notifyXPMilestone(previousXP: Int, currentXP: Int) async {
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
    
    func notifyWorkoutKudos(from user: UserProfile, for workoutId: String) async {
        sentNotifications.append("kudos_\(user.id)_\(workoutId)")
    }
    
    func notifyWorkoutComment(from user: UserProfile, comment: String, for workoutId: String) async {
        sentNotifications.append("comment_\(user.id)_\(workoutId)")
    }
    
    func notifyMention(by user: UserProfile, in context: String) async {
        sentNotifications.append("mention_\(user.id)")
    }
    
    func notifySecurityAlert(title: String, message: String) async {
        sentNotifications.append("security_alert")
    }
    
    func notifyFeatureAnnouncement(feature: String, description: String) async {
        sentNotifications.append("feature_\(feature)")
    }
    
    func updatePreferences(_ preferences: NotificationPreferences) {
        self.preferences = preferences
    }
    
    func getPreferences() -> NotificationPreferences {
        return preferences
    }
}