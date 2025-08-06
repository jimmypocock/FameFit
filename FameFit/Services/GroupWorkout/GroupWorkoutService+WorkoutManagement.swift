//
//  GroupWorkoutService+WorkoutManagement.swift
//  FameFit
//
//  Workout CRUD operations for GroupWorkoutService
//

import CloudKit
import Foundation
import HealthKit

extension GroupWorkoutService {
    // MARK: - Workout Management
    
    func createGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout {
        FameFitLogger.info("Creating group workout: \(workout.name)", category: FameFitLogger.social)
        
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Verify user is the host
        guard workout.hostId == userId else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Check rate limiting
        _ = try await rateLimiter.checkLimit(for: .workoutPost, userId: userId)
        
        // Validate workout
        try validateWorkout(workout)
        
        // Create the workout
        var newWorkout = workout
        newWorkout.participantCount = 1 // Host is the first participant
        
        // Save to CloudKit
        let record = newWorkout.toCKRecord()
        let savedRecord = try await cloudKitManager.save(record)
        
        guard let savedWorkout = GroupWorkout(from: savedRecord) else {
            throw GroupWorkoutError.saveFailed
        }
        
        // Create the host as first participant
        FameFitLogger.debug("Fetching profile for userId: \(userId)", category: FameFitLogger.social)
        let hostProfile = try await userProfileService.fetchProfileByUserID(userId)
        FameFitLogger.debug("Successfully fetched profile: \(hostProfile.username)", category: FameFitLogger.social)
        let hostParticipant = GroupWorkoutParticipant(
            id: UUID().uuidString,
            groupWorkoutId: savedWorkout.id,
            userId: userId,
            username: hostProfile.username,
            profileImageURL: hostProfile.profileImageURL,
            status: .joined
        )
        
        let participantRecord = hostParticipant.toCKRecord()
        _ = try await cloudKitManager.save(participantRecord)
        
        // Record action for rate limiting
        await rateLimiter.recordAction(.workoutPost, userId: userId)
        
        // Cache the workout
        await cacheWorkout(savedWorkout)
        
        // Schedule reminder notification
        await scheduleWorkoutReminder(savedWorkout)
        
        // Send update
        sendUpdate(.created(savedWorkout))
        
        return savedWorkout
    }
    
    func updateGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout {
        FameFitLogger.info("Updating group workout: \(workout.name)", category: FameFitLogger.social)
        
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Only host can update
        guard workout.hostId == userId else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Update the workout
        var updatedWorkout = workout
        updatedWorkout.modifiedTimestamp = Date()
        
        // Save to CloudKit
        let record = updatedWorkout.toCKRecord()
        let savedRecord = try await cloudKitManager.save(record)
        
        guard let savedWorkout = GroupWorkout(from: savedRecord) else {
            throw GroupWorkoutError.updateFailed
        }
        
        // Update cache
        await cacheWorkout(savedWorkout)
        
        // Notify participants
        await notifyParticipantsOfUpdate(savedWorkout)
        
        // Send update
        sendUpdate(.updated(savedWorkout))
        
        return savedWorkout
    }
    
    func deleteGroupWorkout(_ workoutId: String) async throws {
        FameFitLogger.info("Deleting group workout: \(workoutId)", category: FameFitLogger.social)
        
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Find the workout
        let workout = try await fetchWorkout(workoutId)
        
        // Check if current user is the creator
        guard workout.hostId == userId else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Delete the workout
        let recordID = CKRecord.ID(recordName: workoutId)
        try await cloudKitManager.delete(withRecordID: recordID)
        
        // Delete all participants
        let participantPredicate = GroupWorkoutQueryBuilder.participantsForWorkoutQuery(workoutId: workoutId)
        let participantRecords = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutParticipants",
            predicate: participantPredicate,
            sortDescriptors: nil,
            limit: 100
        )
        
        for participantRecord in participantRecords {
            try await cloudKitManager.delete(withRecordID: participantRecord.recordID)
        }
        
        // Delete all invites
        let invitePredicate = GroupWorkoutQueryBuilder.invitesForWorkoutQuery(workoutId: workoutId)
        let inviteRecords = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutInvites",
            predicate: invitePredicate,
            sortDescriptors: nil,
            limit: 100
        )
        
        for inviteRecord in inviteRecords {
            try await cloudKitManager.delete(withRecordID: inviteRecord.recordID)
        }
        
        // Remove from cache
        await cache.remove(workoutId: workoutId)
        
        // Send update
        sendUpdate(.deleted(workoutId))
    }
    
    func cancelGroupWorkout(_ workoutId: String) async throws {
        FameFitLogger.info("Cancelling group workout: \(workoutId)", category: FameFitLogger.social)
        
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutId)
        
        // Only host can cancel
        guard workout.hostId == userId else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Update status
        workout.status = .cancelled
        _ = try await updateGroupWorkout(workout)
        
        // Notify all participants
        await notifyParticipantsOfCancellation(workout)
    }
    
    func startGroupWorkout(_ workoutId: String) async throws -> GroupWorkout {
        FameFitLogger.info("Starting group workout: \(workoutId)", category: FameFitLogger.social)
        
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutId)
        
        // Verify user is host or participant
        let participants = try await getParticipants(workoutId)
        guard workout.hostId == userId || participants.contains(where: { $0.userId == userId }) else {
            throw GroupWorkoutError.notParticipant
        }
        
        // Update status
        workout.status = .active
        let updatedWorkout = try await updateGroupWorkout(workout)
        
        // Update participant status
        try await updateParticipantStatus(workoutId, status: .active)
        
        // Send real-time update
        sendUpdate(.statusChanged(workoutId: workoutId, status: .active))
        
        // Notify other participants
        await notifyParticipantsOfStart(updatedWorkout, startedBy: userId)
        
        return updatedWorkout
    }
    
    func completeGroupWorkout(_ workoutId: String) async throws -> GroupWorkout {
        FameFitLogger.info("Completing group workout: \(workoutId)", category: FameFitLogger.social)
        
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutId)
        
        // Update participant status
        try await updateParticipantStatus(workoutId, status: .completed)
        
        // Check if all participants completed
        let allParticipants = try await getParticipants(workoutId)
        let allCompleted = allParticipants.allSatisfy {
            $0.status == .completed || $0.status == .dropped
        }
        
        if allCompleted || workout.hostId == userId {
            workout.status = .completed
        }
        
        let updatedWorkout = try await updateGroupWorkout(workout)
        
        // Send real-time update
        sendUpdate(.statusChanged(workoutId: workoutId, status: workout.status))
        
        // Award XP for group workout completion
        await awardGroupWorkoutXP(updatedWorkout, for: userId)
        
        return updatedWorkout
    }
}