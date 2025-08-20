//
//  MockNotificationService.swift
//  FameFitTests
//
//  Mock implementation of NotificationProtocol for unit testing
//

@testable import FameFit
import Foundation
import UserNotifications

/// Mock notification manager for testing
class MockNotificationService: NotificationProtocol {
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
    var scheduleNotificationCallCount = 0 // Add this property

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
    var mockPreferences = NotificationSettings()

    // Additional tracking properties expected by tests
    var scheduleNotificationCalled = false
    var lastScheduledUserId: String?
    var lastScheduledNotification: FameFitNotification?
    var allScheduledNotifications: [FameFitNotification] = []

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
    func notifyWorkoutCompleted(_ workout: Workout) async {
        notifyWorkoutCompletedCalled = true
        scheduleNotificationCalled = true
        sentNotifications.append("workout_completed")
        lastWorkoutId = workout.id

        // Create mock notification for tracking
        let notification = FameFitNotification(
            type: .workoutCompleted,
            title: "Workout Complete",
            body: "Great job!"
        )
        lastScheduledNotification = notification
        allScheduledNotifications.append(notification)
    }

    func notifyXPMilestone(previousXP _: Int, currentXP _: Int) async {
        notifyXPMilestoneCalled = true
        sentNotifications.append("xp_milestone")
    }

    func notifyStreakUpdate(streak _: Int, isAtRisk _: Bool) async {
        notifyStreakUpdateCalled = true
        sentNotifications.append("streak_update")
    }
    
    // Group workout notifications
    func notifyGroupWorkoutInvite(workout: GroupWorkout, from host: UserProfile) async {
        sentNotifications.append("group_workout_invite")
        lastUserId = host.id
    }
    
    func notifyGroupWorkoutStart(workout: GroupWorkout) async {
        sentNotifications.append("group_workout_start")
    }
    
    func notifyGroupWorkoutUpdate(workout: GroupWorkout, changeType: String) async {
        sentNotifications.append("group_workout_update")
    }
    
    func notifyGroupWorkoutCancellation(workout: GroupWorkout) async {
        sentNotifications.append("group_workout_cancellation")
    }
    
    func notifyGroupWorkoutParticipantJoined(workout: GroupWorkout, participant: UserProfile) async {
        sentNotifications.append("group_workout_participant_joined")
        lastUserId = participant.id
    }
    
    func notifyGroupWorkoutParticipantLeft(workout: GroupWorkout, participant: UserProfile) async {
        sentNotifications.append("group_workout_participant_left")
        lastUserId = participant.id
    }
    
    func scheduleGroupWorkoutReminder(workout: GroupWorkout) async {
        scheduleNotificationCalled = true
        sentNotifications.append("group_workout_reminder")
    }
    
    // Challenge notifications
    func notifyChallengeInvite(challenge: WorkoutChallenge, from user: UserProfile) async {
        sentNotifications.append("challenge_invite")
        lastUserId = user.id
    }
    
    func notifyChallengeStart(challenge: WorkoutChallenge) async {
        sentNotifications.append("challenge_start")
    }
    
    func notifyChallengeComplete(challenge: WorkoutChallenge, isWinner: Bool) async {
        sentNotifications.append("challenge_complete")
    }
    
    func notifyChallengeVerificationFailure(linkID: String, workoutName: String) async {
        sentNotifications.append("challenge_verification_failure")
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

    func notifyWorkoutKudos(from user: UserProfile, for workoutID: String) async {
        notifyWorkoutKudosCalled = true
        sentNotifications.append("workout_kudos")
        lastWorkoutId = workoutID
        lastUserId = user.id
    }

    func notifyWorkoutComment(from user: UserProfile, comment: String, for workoutID: String) async {
        notifyWorkoutCommentCalled = true
        scheduleNotificationCalled = true
        sentNotifications.append("workout_comment")
        lastWorkoutId = workoutID
        lastComment = comment
        lastUserId = user.id
        lastScheduledUserId = user.id

        // Create mock notification for tracking
        let notification = FameFitNotification(
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
    func notifySecurityAlert(title _: String, message _: String) async {
        notifySecurityAlertCalled = true
        sentNotifications.append("security_alert")
    }

    func notifyFeatureAnnouncement(feature _: String, description _: String) async {
        notifyFeatureAnnouncementCalled = true
        scheduleNotificationCalled = true // For GroupWorkoutService tests
        sentNotifications.append("feature_announcement")
    }

    // Preference management
    func updatePreferences(_ preferences: NotificationSettings) {
        updatePreferencesCalled = true
        mockPreferences = preferences
    }

    func getPreferences() -> NotificationSettings {
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
        mockPreferences = NotificationSettings()
    }
}
