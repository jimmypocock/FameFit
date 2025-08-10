//
//  GroupWorkoutService+Private.swift
//  FameFit
//
//  Private helpers and internal utilities for GroupWorkoutService
//

import CloudKit
import Foundation
import HealthKit

extension GroupWorkoutService {
    // MARK: - Validation
    
    func validateWorkout(_ workout: GroupWorkout) throws {
        // Validate required fields
        guard !workout.name.isEmpty else {
            throw GroupWorkoutError.invalidWorkout("Name is required")
        }
        
        guard workout.scheduledStart > Date() else {
            throw GroupWorkoutError.invalidWorkout("Start time must be in the future")
        }
        
        guard workout.scheduledEnd > workout.scheduledStart else {
            throw GroupWorkoutError.invalidWorkout("End time must be after start time")
        }
        
        guard workout.maxParticipants > 0 else {
            throw GroupWorkoutError.invalidWorkout("Max participants must be greater than 0")
        }
        
        guard workout.maxParticipants <= GroupWorkoutConstants.maxParticipantsLimit else {
            throw GroupWorkoutError.invalidWorkout("Max participants cannot exceed \(GroupWorkoutConstants.maxParticipantsLimit)")
        }
        
        // Validate workout duration (max 4 hours)
        let duration = workout.scheduledEnd.timeIntervalSince(workout.scheduledStart)
        guard duration <= 14400 else { // 4 hours
            throw GroupWorkoutError.invalidWorkout("Workout duration cannot exceed 4 hours")
        }
        
        // Validate workout type is one of the known types
        let validTypes: [HKWorkoutActivityType] = [.running, .cycling, .functionalStrengthTraining, .yoga, .swimming, .walking, .hiking, .other]
        guard validTypes.contains(workout.workoutType) else {
            throw GroupWorkoutError.invalidWorkout("Invalid workout type")
        }
    }
    
    // MARK: - Caching
    
    func getCachedWorkout(_ workoutID: String) async -> GroupWorkout? {
        await cache.get(workoutID: workoutID, expiration: cacheExpiration)
    }
    
    func cacheWorkout(_ workout: GroupWorkout) async {
        await cache.store(workout: workout)
    }
    
    func shouldUpdateCloudKit(for workoutID: String) async -> Bool {
        await cache.shouldThrottle(workoutID: workoutID, interval: 5.0)
    }
    
    // MARK: - Notifications
    
    func notifyHostOfNewParticipant(_ workout: GroupWorkout, participantID: String) async {
        FameFitLogger.info("Notifying host of new participant", category: FameFitLogger.social)
        
        guard workout.hostID != participantID else { return }
        
        // Fetch participant profile
        // participantID is a CloudKit user ID (from participant records), use fetchProfileByUserID
        guard let participant = try? await userProfileService.fetchProfileByUserID(participantID) else {
            FameFitLogger.warning("Could not fetch participant profile for notification", category: FameFitLogger.social)
            return
        }
        
        await notificationManager.notifyGroupWorkoutParticipantJoined(workout: workout, participant: participant)
    }
    
    func notifyParticipantsOfUpdate(_ workout: GroupWorkout) async {
        FameFitLogger.info("Notifying participants of workout update", category: FameFitLogger.social)
        
        await notificationManager.notifyGroupWorkoutUpdate(workout: workout, changeType: "updated")
    }
    
    func notifyParticipantsOfCancellation(_ workout: GroupWorkout) async {
        FameFitLogger.info("Notifying participants of workout cancellation", category: FameFitLogger.social)
        
        await notificationManager.notifyGroupWorkoutCancellation(workout: workout)
    }
    
    func notifyParticipantsOfStart(_ workout: GroupWorkout, startedBy: String) async {
        FameFitLogger.info("Notifying participants of workout start", category: FameFitLogger.social)
        
        await notificationManager.notifyGroupWorkoutStart(workout: workout)
    }
    
    func notifyUserOfInvite(userID: String, workout: GroupWorkout) async {
        FameFitLogger.info("Notifying user of workout invite", category: FameFitLogger.social)
        
        // Fetch host profile
        // workout.hostID is a CloudKit user ID (compared with cloudKitManager.currentUserID), use fetchProfileByUserID
        guard let host = try? await userProfileService.fetchProfileByUserID(workout.hostID) else {
            FameFitLogger.warning("Could not fetch host profile for notification", category: FameFitLogger.social)
            return
        }
        
        await notificationManager.notifyGroupWorkoutInvite(workout: workout, from: host)
    }
    
    func scheduleWorkoutReminder(_ workout: GroupWorkout) async {
        FameFitLogger.info("Scheduling workout reminder", category: FameFitLogger.social)
        
        await notificationManager.scheduleGroupWorkoutReminder(workout: workout)
    }
    
    // MARK: - XP & Rewards
    
    func awardGroupWorkoutXP(_ workout: GroupWorkout, for userID: String) async {
        FameFitLogger.info("Awarding XP for group workout completion", category: FameFitLogger.social)
        
        // Base XP for completing a group workout
        let baseXP = 50
        
        // Bonus XP based on participant count
        let participantBonus = min(workout.participantCount * 5, 50)
        
        // Total XP
        let totalXP = baseXP + participantBonus
        
        // Award XP through user profile service
        // NOTE: UserProfile.totalXP appears to be immutable, would need to check if there's an XP service
        FameFitLogger.info("Would award \(totalXP) XP to user \(userID) for group workout", category: FameFitLogger.social)
    }
    
    // MARK: - Subscriptions
    
    func setupSubscriptions() async {
        FameFitLogger.info("Setting up CloudKit subscriptions for group workouts", category: FameFitLogger.social)
        
        // TODO: Set up CloudKit subscriptions when subscription support is available
        FameFitLogger.info("CloudKit subscriptions setup would happen here", category: FameFitLogger.social)
    }
    
    private func handleWorkoutNotification(_ notification: CKQueryNotification) {
        guard let recordID = notification.recordID else { return }
        
        Task {
            do {
                // Fetch using a query to ensure we use the public database
                let predicate = NSPredicate(format: "recordID == %@", recordID)
                let records = try await cloudKitManager.fetchRecords(
                    ofType: "GroupWorkouts",
                    predicate: predicate,
                    sortDescriptors: nil,
                    limit: 1
                )
                
                if let record = records.first,
                   let workout = GroupWorkout(from: record) {
                    await cacheWorkout(workout)
                    sendUpdate(.updated(workout))
                }
            } catch {
                FameFitLogger.error("Failed to handle workout notification", error: error, category: FameFitLogger.social)
            }
        }
    }
    
    private func handleParticipantNotification(_ notification: CKQueryNotification) {
        guard let recordID = notification.recordID else { return }
        
        Task {
            do {
                // Fetch using a query to ensure we use the public database
                let predicate = NSPredicate(format: "recordID == %@", recordID)
                let records = try await cloudKitManager.fetchRecords(
                    ofType: "GroupWorkoutParticipants",
                    predicate: predicate,
                    sortDescriptors: nil,
                    limit: 1
                )
                
                if let record = records.first,
                   let participant = GroupWorkoutParticipant(from: record) {
                    sendUpdate(.participantDataUpdated(workoutID: participant.groupWorkoutID, participant: participant))
                }
            } catch {
                FameFitLogger.error("Failed to handle participant notification", error: error, category: FameFitLogger.social)
            }
        }
    }
}
