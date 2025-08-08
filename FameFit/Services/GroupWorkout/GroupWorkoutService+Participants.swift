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
    
    func joinGroupWorkout(_ workoutID: String) async throws {
        FameFitLogger.info("Joining group workout: \(workoutID)", category: FameFitLogger.social)
        
        guard let userID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutID)
        
        // Check if already joined
        let participants = try await getParticipants(workoutID)
        guard !participants.contains(where: { $0.userID == userID }) else {
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
        _ = try await rateLimiter.checkLimit(for: .followRequest, userID: userID)
        
        // Add participant
        let userProfile = try await userProfileService.fetchProfileByUserID(userID)
        
        // If workout is already active, participant starts as active
        let initialStatus: ParticipantStatus = workout.status == .active ? .active : .joined
        
        let participant = GroupWorkoutParticipant(
            id: UUID().uuidString,
            groupWorkoutID: workoutID,
            userID: userID,
            username: userProfile.username,
            profileImageURL: userProfile.profileImageURL,
            status: initialStatus
        )
        
        // Save participant record
        let participantRecord = participant.toCKRecord()
        _ = try await cloudKitManager.save(participantRecord)
        
        // Update workout participant count and participantIDs
        workout.participantCount += 1
        if !workout.participantIDs.contains(userID) {
            workout.participantIDs.append(userID)
        }
        _ = try await updateGroupWorkout(workout)
        
        // If workout is active, track start time for this participant
        if workout.status == .active, let processor = workoutProcessor {
            try await processor.processGroupWorkoutJoin(groupWorkout: workout, participantID: userID)
        }
        
        // Record action
        await rateLimiter.recordAction(.followRequest, userID: userID)
        
        // Send notification to host
        await notifyHostOfNewParticipant(workout, participantID: userID)
        
        // Send real-time update
        sendUpdate(.participantJoined(workoutID: workoutID, participant: participant))
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
    
    func leaveGroupWorkout(_ workoutID: String) async throws {
        FameFitLogger.info("Leaving group workout: \(workoutID)", category: FameFitLogger.social)
        
        guard let userID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        let workout = try await fetchWorkout(workoutID)
        
        // Can't leave if host (must cancel instead)
        guard workout.hostID != userID else {
            throw GroupWorkoutError.hostCannotLeave
        }
        
        // Find participant record
        let predicate = GroupWorkoutQueryBuilder.participantInWorkoutQuery(
            workoutID: workoutID,
            userID: userID
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
                try await processor.processGroupWorkoutLeave(groupWorkout: workout, participantID: userID)
            }
            
            // Update status to dropped
            record["status"] = ParticipantStatus.dropped.rawValue
            _ = try await cloudKitManager.save(record)
            
            // Update workout participant count and participantIDs
            var updatedWorkout = workout
            updatedWorkout.participantCount = max(0, updatedWorkout.participantCount - 1)
            updatedWorkout.participantIDs.removeAll { $0 == userID }
            _ = try await updateGroupWorkout(updatedWorkout)
            
            // Send real-time update
            sendUpdate(.participantLeft(workoutID: workoutID, userID: userID))
        }
    }
    
    func updateParticipantStatus(_ workoutID: String, status: ParticipantStatus) async throws {
        FameFitLogger.info("Updating participant status: \(workoutID) to \(status.rawValue)", category: FameFitLogger.social)
        
        guard let userID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        let predicate = GroupWorkoutQueryBuilder.participantInWorkoutQuery(
            workoutID: workoutID,
            userID: userID
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
    
    func updateParticipantData(_ workoutID: String, data: GroupWorkoutData) async throws {
        FameFitLogger.info("Updating participant data: \(workoutID)", category: FameFitLogger.social)
        
        guard let userID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        _ = try await fetchWorkout(workoutID)
        
        // Find participant record
        let predicate = GroupWorkoutQueryBuilder.participantInWorkoutQuery(
            workoutID: workoutID,
            userID: userID
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
        if await shouldUpdateCloudKit(for: workoutID) {
            _ = try await cloudKitManager.save(record)
        }
        
        // Always send real-time update
        if let participant = GroupWorkoutParticipant(from: record) {
            sendUpdate(.participantDataUpdated(workoutID: workoutID, participant: participant))
        }
    }
    
    func getParticipants(_ workoutID: String) async throws -> [GroupWorkoutParticipant] {
        FameFitLogger.info("Getting participants for workout: \(workoutID)", category: FameFitLogger.social)
        
        let predicate = GroupWorkoutQueryBuilder.participantsForWorkoutQuery(workoutID: workoutID)
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
