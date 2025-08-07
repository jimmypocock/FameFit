//
//  GroupWorkoutService+Participants.swift
//  FameFit
//
//  Participant management operations for GroupWorkoutService
//

import CloudKit
import Foundation

extension GroupWorkoutService {
    // MARK: - Participant Management
    
    func joinGroupWorkout(_ workoutId: String) async throws {
        FameFitLogger.info("Joining group workout: \(workoutId)", category: FameFitLogger.social)
        
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutId)
        
        // Check if already joined
        let participants = try await getParticipants(workoutId)
        guard !participants.contains(where: { $0.userId == userId }) else {
            return
        }
        
        // Check capacity
        guard workout.hasSpace else {
            throw GroupWorkoutError.workoutFull
        }
        
        // Check if can join
        guard workout.status.canJoin else {
            throw GroupWorkoutError.cannotJoin
        }
        
        // Check rate limiting
        _ = try await rateLimiter.checkLimit(for: .followRequest, userId: userId)
        
        // Add participant
        let userProfile = try await userProfileService.fetchProfileByUserID(userId)
        
        // If workout is already active, participant starts as active
        let initialStatus: ParticipantStatus = workout.status == .active ? .active : .joined
        
        let participant = GroupWorkoutParticipant(
            id: UUID().uuidString,
            groupWorkoutId: workoutId,
            userId: userId,
            username: userProfile.username,
            profileImageURL: userProfile.profileImageURL,
            status: initialStatus
        )
        
        // Save participant record
        let participantRecord = participant.toCKRecord()
        _ = try await cloudKitManager.save(participantRecord)
        
        // Update workout participant count and participantIDs
        workout.participantCount += 1
        if !workout.participantIDs.contains(userId) {
            workout.participantIDs.append(userId)
        }
        _ = try await updateGroupWorkout(workout)
        
        // If workout is active, track start time for this participant
        if workout.status == .active, let processor = workoutProcessor {
            try await processor.processGroupWorkoutJoin(groupWorkout: workout, participantId: userId)
        }
        
        // Record action
        await rateLimiter.recordAction(.followRequest, userId: userId)
        
        // Send notification to host
        await notifyHostOfNewParticipant(workout, participantId: userId)
        
        // Send real-time update
        sendUpdate(.participantJoined(workoutId: workoutId, participant: participant))
    }
    
    func joinWithCode(_ code: String) async throws -> GroupWorkout {
        FameFitLogger.info("Joining with code: \(code)", category: FameFitLogger.social)
        
        // Find workout by join code
        let predicate = NSPredicate(format: "joinCode == %@", code)
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkouts",
            predicate: predicate,
            sortDescriptors: nil,
            limit: 1
        )
        
        guard let record = records.first,
              let workout = GroupWorkout(from: record) else {
            throw GroupWorkoutError.invalidJoinCode
        }
        
        try await joinGroupWorkout(workout.id)
        return workout
    }
    
    func leaveGroupWorkout(_ workoutId: String) async throws {
        FameFitLogger.info("Leaving group workout: \(workoutId)", category: FameFitLogger.social)
        
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        let workout = try await fetchWorkout(workoutId)
        
        // Can't leave if host (must cancel instead)
        guard workout.hostId != userId else {
            throw GroupWorkoutError.hostCannotLeave
        }
        
        // Find participant record
        let predicate = GroupWorkoutQueryBuilder.participantInWorkoutQuery(
            workoutId: workoutId,
            userId: userId
        )
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutParticipants",
            predicate: predicate,
            sortDescriptors: nil,
            limit: 1
        )
        
        if let record = records.first {
            // If workout is active, process workout completion for this participant
            if workout.status == .active, let processor = workoutProcessor {
                try await processor.processGroupWorkoutLeave(groupWorkout: workout, participantId: userId)
            }
            
            // Update status to dropped
            record["status"] = ParticipantStatus.dropped.rawValue
            _ = try await cloudKitManager.save(record)
            
            // Update workout participant count and participantIDs
            var updatedWorkout = workout
            updatedWorkout.participantCount = max(0, updatedWorkout.participantCount - 1)
            updatedWorkout.participantIDs.removeAll { $0 == userId }
            _ = try await updateGroupWorkout(updatedWorkout)
            
            // Send real-time update
            sendUpdate(.participantLeft(workoutId: workoutId, userId: userId))
        }
    }
    
    func updateParticipantStatus(_ workoutId: String, status: ParticipantStatus) async throws {
        FameFitLogger.info("Updating participant status: \(workoutId) to \(status.rawValue)", category: FameFitLogger.social)
        
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        let predicate = GroupWorkoutQueryBuilder.participantInWorkoutQuery(
            workoutId: workoutId,
            userId: userId
        )
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutParticipants",
            predicate: predicate,
            sortDescriptors: nil,
            limit: 1
        )
        
        if let record = records.first {
            record["status"] = status.rawValue
            _ = try await cloudKitManager.save(record)
        }
    }
    
    func updateParticipantData(_ workoutId: String, data: GroupWorkoutData) async throws {
        FameFitLogger.info("Updating participant data: \(workoutId)", category: FameFitLogger.social)
        
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        _ = try await fetchWorkout(workoutId)
        
        // Find participant record
        let predicate = GroupWorkoutQueryBuilder.participantInWorkoutQuery(
            workoutId: workoutId,
            userId: userId
        )
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutParticipants",
            predicate: predicate,
            sortDescriptors: nil,
            limit: 1
        )
        
        guard let record = records.first else {
            throw GroupWorkoutError.notParticipant
        }
        
        // Update workout data
        record["startTimestamp"] = data.startTime
        record["endTimestamp"] = data.endTime
        record["totalEnergyBurned"] = data.totalEnergyBurned
        record["averageHeartRate"] = data.averageHeartRate
        record["totalDistance"] = data.totalDistance
        // Note: modifiedTimestamp is automatically updated by CloudKit
        
        // Save update (with rate limiting for frequent updates)
        if await shouldUpdateCloudKit(for: workoutId) {
            _ = try await cloudKitManager.save(record)
        }
        
        // Always send real-time update
        if let participant = GroupWorkoutParticipant(from: record) {
            sendUpdate(.participantDataUpdated(workoutId: workoutId, participant: participant))
        }
    }
    
    func getParticipants(_ workoutId: String) async throws -> [GroupWorkoutParticipant] {
        FameFitLogger.info("Getting participants for workout: \(workoutId)", category: FameFitLogger.social)
        
        let predicate = GroupWorkoutQueryBuilder.participantsForWorkoutQuery(workoutId: workoutId)
        let sortDescriptors = [GroupWorkoutQueryBuilder.joinedAtAscending]
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutParticipants",
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: 100
        )
        
        return records.compactMap { GroupWorkoutParticipant(from: $0) }
    }
}