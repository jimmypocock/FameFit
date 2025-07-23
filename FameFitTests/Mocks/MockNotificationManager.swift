//
//  MockNotificationManager.swift
//  FameFitTests
//
//  Mock implementation of NotificationManaging for unit testing
//

import Foundation
import UserNotifications
@testable import FameFit

/// Mock notification manager for testing
class MockNotificationManager: NotificationManaging {
    // Track method calls
    var requestPermissionCalled = false
    var checkPermissionCalled = false
    var notifyWorkoutCompletedCalled = false
    var notifyXPMilestoneCalled = false
    var notifyStreakUpdateCalled = false
    var notifyNewFollowerCalled = false
    var notifyFollowRequestCalled = false
    var notifyFollowAcceptedCalled = false
    var notifyWorkoutKudosCalled = false
    var notifyWorkoutCommentCalled = false
    var notifyMentionCalled = false
    var notifySecurityAlertCalled = false
    var notifyFeatureAnnouncementCalled = false
    var updatePreferencesCalled = false
    var getPreferencesCalled = false
    
    // Test data
    var sentNotifications: [String] = []
    var lastWorkoutId: String?
    var lastComment: String?
    var lastUserId: String?
    var lastContext: String?
    
    // Control test behavior
    var mockPermissionStatus: UNAuthorizationStatus = .authorized
    var currentAuthStatus: UNAuthorizationStatus = .authorized
    var shouldRequestPermissionSucceed = true
    var mockPreferences = NotificationPreferences()
    
    // Additional tracking properties expected by tests
    var scheduleNotificationCalled = false
    var lastScheduledUserId: String?
    var lastScheduledNotification: NotificationItem?
    var allScheduledNotifications: [NotificationItem] = []
    
    // Permission management
    func requestNotificationPermission() async -> Bool {
        requestPermissionCalled = true
        return shouldRequestPermissionSucceed
    }
    
    func checkNotificationPermission() async -> UNAuthorizationStatus {
        checkPermissionCalled = true
        return mockPermissionStatus
    }
    
    // Workout notifications
    func notifyWorkoutCompleted(_ workout: WorkoutHistoryItem) async {
        notifyWorkoutCompletedCalled = true
        scheduleNotificationCalled = true
        sentNotifications.append("workout_completed")
        lastWorkoutId = workout.id.uuidString
        
        // Create mock notification for tracking
        let notification = NotificationItem(
            type: .workoutCompleted,
            title: "Workout Complete",
            body: "Great job!"
        )
        lastScheduledNotification = notification
        allScheduledNotifications.append(notification)
    }
    
    func notifyXPMilestone(previousXP: Int, currentXP: Int) async {
        notifyXPMilestoneCalled = true
        sentNotifications.append("xp_milestone")
    }
    
    func notifyStreakUpdate(streak: Int, isAtRisk: Bool) async {
        notifyStreakUpdateCalled = true
        sentNotifications.append("streak_update")
    }
    
    // Social notifications
    func notifyNewFollower(from user: UserProfile) async {
        notifyNewFollowerCalled = true
        sentNotifications.append("new_follower")
        lastUserId = user.id
    }
    
    func notifyFollowRequest(from user: UserProfile) async {
        notifyFollowRequestCalled = true
        sentNotifications.append("follow_request")
        lastUserId = user.id
    }
    
    func notifyFollowAccepted(by user: UserProfile) async {
        notifyFollowAcceptedCalled = true
        sentNotifications.append("follow_accepted")
        lastUserId = user.id
    }
    
    func notifyWorkoutKudos(from user: UserProfile, for workoutId: String) async {
        notifyWorkoutKudosCalled = true
        sentNotifications.append("workout_kudos")
        lastWorkoutId = workoutId
        lastUserId = user.id
    }
    
    func notifyWorkoutComment(from user: UserProfile, comment: String, for workoutId: String) async {
        notifyWorkoutCommentCalled = true
        scheduleNotificationCalled = true
        sentNotifications.append("workout_comment")
        lastWorkoutId = workoutId
        lastComment = comment
        lastUserId = user.id
        lastScheduledUserId = user.id
        
        // Create mock notification for tracking
        let notification = NotificationItem(
            type: .workoutComment,
            title: "New Comment",
            body: comment
        )
        lastScheduledNotification = notification
        allScheduledNotifications.append(notification)
    }
    
    func notifyMention(by user: UserProfile, in context: String) async {
        notifyMentionCalled = true
        sentNotifications.append("mention")
        lastUserId = user.id
        lastContext = context
    }
    
    // System notifications
    func notifySecurityAlert(title: String, message: String) async {
        notifySecurityAlertCalled = true
        sentNotifications.append("security_alert")
    }
    
    func notifyFeatureAnnouncement(feature: String, description: String) async {
        notifyFeatureAnnouncementCalled = true
        scheduleNotificationCalled = true // For GroupWorkoutService tests
        sentNotifications.append("feature_announcement")
    }
    
    // Preference management
    func updatePreferences(_ preferences: NotificationPreferences) {
        updatePreferencesCalled = true
        mockPreferences = preferences
    }
    
    func getPreferences() -> NotificationPreferences {
        getPreferencesCalled = true
        return mockPreferences
    }
    
    // Test helper methods
    func reset() {
        requestPermissionCalled = false
        checkPermissionCalled = false
        notifyWorkoutCompletedCalled = false
        notifyXPMilestoneCalled = false
        notifyStreakUpdateCalled = false
        notifyNewFollowerCalled = false
        notifyFollowRequestCalled = false
        scheduleNotificationCalled = false
        notifyFollowAcceptedCalled = false
        notifyWorkoutKudosCalled = false
        notifyWorkoutCommentCalled = false
        notifyMentionCalled = false
        notifySecurityAlertCalled = false
        notifyFeatureAnnouncementCalled = false
        updatePreferencesCalled = false
        getPreferencesCalled = false
        
        sentNotifications.removeAll()
        lastWorkoutId = nil
        lastComment = nil
        lastUserId = nil
        lastContext = nil
        
        mockPermissionStatus = .authorized
        shouldRequestPermissionSucceed = true
        mockPreferences = NotificationPreferences()
    }
}