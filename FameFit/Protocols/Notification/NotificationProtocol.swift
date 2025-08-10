//
//  NotificationProtocol.swift
//  FameFit
//
//  Protocol for notification management services
//

import Foundation
import UserNotifications

protocol NotificationProtocol: AnyObject {
    // Permission management
    func requestNotificationPermission() async -> Bool
    func checkNotificationPermission() async -> UNAuthorizationStatus

    // Workout notifications
    func notifyWorkoutCompleted(_ workout: Workout) async
    func notifyXPMilestone(previousXP: Int, currentXP: Int) async
    func notifyStreakUpdate(streak: Int, isAtRisk: Bool) async

    // Social notifications
    func notifyNewFollower(from user: UserProfile) async
    func notifyFollowRequest(from user: UserProfile) async
    func notifyFollowAccepted(by user: UserProfile) async
    func notifyWorkoutKudos(from user: UserProfile, for workoutID: String) async
    func notifyWorkoutComment(from user: UserProfile, comment: String, for workoutID: String) async
    func notifyMention(by user: UserProfile, in context: String) async
    
    // Group workout notifications
    func notifyGroupWorkoutInvite(workout: GroupWorkout, from host: UserProfile) async
    func notifyGroupWorkoutStart(workout: GroupWorkout) async
    func notifyGroupWorkoutUpdate(workout: GroupWorkout, changeType: String) async
    func notifyGroupWorkoutCancellation(workout: GroupWorkout) async
    func notifyGroupWorkoutParticipantJoined(workout: GroupWorkout, participant: UserProfile) async
    func notifyGroupWorkoutParticipantLeft(workout: GroupWorkout, participant: UserProfile) async
    func scheduleGroupWorkoutReminder(workout: GroupWorkout) async
    
    // Challenge notifications  
    func notifyChallengeInvite(challenge: WorkoutChallenge, from user: UserProfile) async
    func notifyChallengeStart(challenge: WorkoutChallenge) async
    func notifyChallengeComplete(challenge: WorkoutChallenge, isWinner: Bool) async
    func notifyChallengeVerificationFailure(linkID: String, workoutName: String) async

    // System notifications
    func notifySecurityAlert(title: String, message: String) async
    func notifyFeatureAnnouncement(feature: String, description: String) async

    // Preference management
    func updatePreferences(_ preferences: NotificationPreferences)
    func getPreferences() -> NotificationPreferences
}