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
        
        guard let userID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Verify user is the host
        guard workout.hostID == userID else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Check rate limiting
        _ = try await rateLimiter.checkLimit(for: .workoutPost, userID: userID)
        
        // Validate workout
        try validateWorkout(workout)
        
        // Create the workout
        var newWorkout = workout
        newWorkout.participantCount = 0 // Don't count host as participant
        
        // Save to CloudKit
        let record = newWorkout.toCKRecord()
        let savedRecord = try await cloudKitManager.save(record)
        
        guard let savedWorkout = GroupWorkout(from: savedRecord) else {
            throw GroupWorkoutError.saveFailed
        }
        
        // Don't create host as participant - host is separate from participants
        
        // Record action for rate limiting
        await rateLimiter.recordAction(.workoutPost, userID: userID)
        
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
        
        guard let userID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Only host can update
        guard workout.hostID == userID else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Update the workout
        var updatedWorkout = workout
        updatedWorkout.modifiedTimestamp = Date()
        
        // Fetch the existing record first to avoid "record already exists" error
        let recordID = CKRecord.ID(recordName: workout.id)
        
        // Try to fetch the existing record, if it fails, create a new one
        let record: CKRecord
        do {
            // Use a predicate query to fetch the record since we don't have direct fetch
            let predicate = NSPredicate(format: "recordID == %@", recordID)
            let records = try await cloudKitManager.fetchRecords(
                ofType: "GroupWorkouts",
                predicate: predicate,
                sortDescriptors: nil,
                limit: 1
            )
            
            if let existingRecord = records.first {
                // Update the existing record
                record = existingRecord
                updatedWorkout.updateCKRecord(record)
            } else {
                // No existing record found, create new one
                record = updatedWorkout.toCKRecord(recordID: recordID)
            }
        } catch {
            // If fetch fails, create new record
            FameFitLogger.warning("Could not fetch existing record, creating new: \(error)", category: FameFitLogger.social)
            record = updatedWorkout.toCKRecord(recordID: recordID)
        }
        
        // Save the record
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
    
    func deleteGroupWorkout(_ workoutID: String) async throws {
        FameFitLogger.info("Deleting group workout: \(workoutID)", category: FameFitLogger.social)
        
        guard let userID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Find the workout
        let workout = try await fetchWorkout(workoutID)
        
        // Check if current user is the creator
        guard workout.hostID == userID else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Delete the workout
        let recordID = CKRecord.ID(recordName: workoutID)
        try await cloudKitManager.delete(withRecordID: recordID)
        
        // Delete all participants
        let participantPredicate = GroupWorkoutQueryBuilder.participantsForWorkoutQuery(workoutID: workoutID)
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
        let invitePredicate = GroupWorkoutQueryBuilder.invitesForWorkoutQuery(workoutID: workoutID)
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
        await cache.remove(workoutID: workoutID)
        
        // Send update
        sendUpdate(.deleted(workoutID))
    }
    
    func cancelGroupWorkout(_ workoutID: String) async throws {
        FameFitLogger.info("Cancelling group workout: \(workoutID)", category: FameFitLogger.social)
        
        guard let userID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutID)
        
        // Only host can cancel
        guard workout.hostID == userID else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Update status
        workout.status = .cancelled
        _ = try await updateGroupWorkout(workout)
        
        // Notify all participants
        await notifyParticipantsOfCancellation(workout)
    }
    
    func startGroupWorkout(_ workoutID: String) async throws -> GroupWorkout {
        FameFitLogger.info("Starting group workout: \(workoutID)", category: FameFitLogger.social)
        
        guard let userID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutID)
        
        // Verify user is host or participant
        let participants = try await getParticipants(workoutID)
        let isHost = workout.hostID == userID
        let isParticipant = participants.contains(where: { $0.userID == userID })
        
        guard isHost || isParticipant else {
            throw GroupWorkoutError.notParticipant
        }
        
        // Update status
        workout.status = .active
        let updatedWorkout = try await updateGroupWorkout(workout)
        
        // Update participant status
        try await updateParticipantStatus(workoutID, status: .active)
        
        // Track workout start time using UnifiedWorkoutProcessor
        if let processor = workoutProcessor {
            if isHost {
                try await processor.processGroupWorkoutStart(groupWorkout: updatedWorkout, hostID: userID)
            } else {
                try await processor.processGroupWorkoutJoin(groupWorkout: updatedWorkout, participantID: userID)
            }
        }
        
        // Send real-time update
        sendUpdate(.statusChanged(workoutID: workoutID, status: .active))
        
        // Notify other participants
        await notifyParticipantsOfStart(updatedWorkout, startedBy: userID)
        
        return updatedWorkout
    }
    
    func completeGroupWorkout(_ workoutID: String) async throws -> GroupWorkout {
        FameFitLogger.info("Completing group workout: \(workoutID)", category: FameFitLogger.social)
        
        guard let userID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutID)
        let isHost = workout.hostID == userID
        
        // Update participant status
        try await updateParticipantStatus(workoutID, status: .completed)
        
        // Check if all participants completed
        let allParticipants = try await getParticipants(workoutID)
        let allCompleted = allParticipants.allSatisfy {
            $0.status == .completed || $0.status == .dropped
        }
        
        // Process workout completion using UnifiedWorkoutProcessor
        if let processor = workoutProcessor {
            if isHost {
                // Host ending the workout
                try await processor.processGroupWorkoutEnd(groupWorkout: workout, hostID: userID)
                
                // Also end for all active participants
                for participant in allParticipants where participant.status == .active {
                    try await processor.processGroupWorkoutLeave(groupWorkout: workout, participantID: participant.userID)
                }
                
                workout.status = .completed
            } else {
                // Participant marking as completed
                try await processor.processGroupWorkoutLeave(groupWorkout: workout, participantID: userID)
                
                if allCompleted {
                    workout.status = .completed
                }
            }
        } else {
            // Fallback to old XP award method if processor not available
            await awardGroupWorkoutXP(workout, for: userID)
        }
        
        let updatedWorkout = try await updateGroupWorkout(workout)
        
        // Send real-time update
        sendUpdate(.statusChanged(workoutID: workoutID, status: workout.status))
        
        return updatedWorkout
    }
}
