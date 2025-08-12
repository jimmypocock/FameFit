//
//  GroupWorkoutService+Invites.swift
//  FameFit
//
//  Invite management operations for GroupWorkoutService
//

import CloudKit
import Foundation

extension GroupWorkoutService {
    // MARK: - Invite Management
    
    func sendInvites(_ workoutID: String, to userIDs: [String]) async throws {
        FameFitLogger.info("Sending invites for workout: \(workoutID)", category: FameFitLogger.social)
        
        guard let currentUserID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        let workout = try await fetchWorkout(workoutID)
        
        // Only host can send invites
        guard workout.hostID == currentUserID else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Create invites
        for userID in userIDs {
            let invite = GroupWorkoutInvite(
                groupWorkoutID: workoutID,
                invitedBy: currentUserID,
                invitedUser: userID
            )
            
            let record = invite.toCKRecord()
            _ = try await cloudKitManager.save(record)
            
            // Send push notification
            await notifyUserOfInvite(userID: userID, workout: workout)
        }
    }
    
    func inviteUser(_ userID: String, to workoutID: String) async throws {
        try await sendInvites(workoutID, to: [userID])
    }
    
    func acceptInvite(_ inviteID: String) async throws -> GroupWorkout {
        FameFitLogger.info("Accepting invite: \(inviteID)", category: FameFitLogger.social)
        
        guard let currentUserID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Fetch the invite
        let recordID = CKRecord.ID(recordName: inviteID)
        
        // Fetch using a query to ensure we use the public database
        let predicate = NSPredicate(format: "recordID == %@", recordID)
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutInvites",
            predicate: predicate,
            sortDescriptors: nil,
            limit: 1
        )
        
        guard let inviteRecord = records.first,
              let invite = GroupWorkoutInvite(from: inviteRecord) else {
            throw GroupWorkoutError.inviteNotFound
        }
        
        // Verify this invite is for the current user
        guard invite.invitedUser == currentUserID else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Check if invite is expired
        guard !invite.isExpired else {
            throw GroupWorkoutError.inviteNotFound
        }
        
        // Join the workout
        try await joinGroupWorkout(invite.groupWorkoutID)
        
        // Delete the invite after accepting
        try await cloudKitManager.delete(withRecordID: recordID)
        
        // Return the workout
        return try await fetchWorkout(invite.groupWorkoutID)
    }
    
    func declineInvite(_ inviteID: String) async throws {
        FameFitLogger.info("Declining invite: \(inviteID)", category: FameFitLogger.social)
        
        guard let currentUserID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Fetch the invite
        let recordID = CKRecord.ID(recordName: inviteID)
        
        // Fetch using a query to ensure we use the public database
        let predicate = NSPredicate(format: "recordID == %@", recordID)
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutInvites",
            predicate: predicate,
            sortDescriptors: nil,
            limit: 1
        )
        
        guard let inviteRecord = records.first,
              let invite = GroupWorkoutInvite(from: inviteRecord) else {
            throw GroupWorkoutError.inviteNotFound
        }
        
        // Verify this invite is for the current user
        guard invite.invitedUser == currentUserID else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Delete the invite
        try await cloudKitManager.delete(withRecordID: recordID)
    }
    
    func respondToInvite(_ inviteID: String, accept: Bool) async throws {
        if accept {
            _ = try await acceptInvite(inviteID)
        } else {
            try await declineInvite(inviteID)
        }
    }
    
    func fetchMyInvites() async throws -> [GroupWorkoutInvite] {
        try await getMyInvites()
    }
    
    func getMyInvites() async throws -> [GroupWorkoutInvite] {
        FameFitLogger.info("Getting invites for current user", category: FameFitLogger.social)
        
        guard let userID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Fetch invites for the current user that haven't expired
        let now = Date()
        let predicate = NSPredicate(format: "invitedUserID == %@ AND expiresTimestamp > %@", userID, now as NSDate)
        
        let sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutInvites",
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: 50
        )
        
        return records.compactMap { GroupWorkoutInvite(from: $0) }
    }
    
    func getWorkoutInvites(_ workoutID: String) async throws -> [GroupWorkoutInvite] {
        FameFitLogger.info("Getting invites for workout: \(workoutID)", category: FameFitLogger.social)
        
        let predicate = GroupWorkoutQueryBuilder.invitesForWorkoutQuery(workoutID: workoutID)
        let sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutInvites",
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: 100
        )
        
        return records.compactMap { GroupWorkoutInvite(from: $0) }
    }
    
    func cancelInvite(_ inviteID: String) async throws {
        FameFitLogger.info("Cancelling invite: \(inviteID)", category: FameFitLogger.social)
        
        guard let currentUserID = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Fetch the invite
        let recordID = CKRecord.ID(recordName: inviteID)
        
        // Fetch using a query to ensure we use the public database
        let predicate = NSPredicate(format: "recordID == %@", recordID)
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutInvites",
            predicate: predicate,
            sortDescriptors: nil,
            limit: 1
        )
        
        guard let inviteRecord = records.first,
              let invite = GroupWorkoutInvite(from: inviteRecord) else {
            throw GroupWorkoutError.inviteNotFound
        }
        
        // Only host can cancel invites
        guard invite.invitedBy == currentUserID else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Delete the invite
        try await cloudKitManager.delete(withRecordID: recordID)
    }
}