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
    
    func sendInvites(_ workoutId: String, to userIds: [String]) async throws {
        FameFitLogger.info("Sending invites for workout: \(workoutId)", category: FameFitLogger.social)
        
        guard let currentUserId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        let workout = try await fetchWorkout(workoutId)
        
        // Only host can send invites
        guard workout.hostId == currentUserId else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Create invites
        for userId in userIds {
            let invite = GroupWorkoutInvite(
                groupWorkoutId: workoutId,
                invitedBy: currentUserId,
                invitedUser: userId
            )
            
            let record = invite.toCKRecord()
            _ = try await cloudKitManager.save(record)
            
            // Send push notification
            await notifyUserOfInvite(userId: userId, workout: workout)
        }
    }
    
    func inviteUser(_ userId: String, to workoutId: String) async throws {
        try await sendInvites(workoutId, to: [userId])
    }
    
    func acceptInvite(_ inviteId: String) async throws -> GroupWorkout {
        FameFitLogger.info("Accepting invite: \(inviteId)", category: FameFitLogger.social)
        
        guard let currentUserId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Fetch the invite
        let recordID = CKRecord.ID(recordName: inviteId)
        let inviteRecord = try await cloudKitManager.database.record(for: recordID)
        
        guard let invite = GroupWorkoutInvite(from: inviteRecord) else {
            throw GroupWorkoutError.inviteNotFound
        }
        
        // Verify this invite is for the current user
        guard invite.invitedUser == currentUserId else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Check if invite is expired
        guard !invite.isExpired else {
            throw GroupWorkoutError.inviteNotFound
        }
        
        // Join the workout
        try await joinGroupWorkout(invite.groupWorkoutId)
        
        // Delete the invite after accepting
        try await cloudKitManager.delete(withRecordID: recordID)
        
        // Return the workout
        return try await fetchWorkout(invite.groupWorkoutId)
    }
    
    func declineInvite(_ inviteId: String) async throws {
        FameFitLogger.info("Declining invite: \(inviteId)", category: FameFitLogger.social)
        
        guard let currentUserId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Fetch the invite
        let recordID = CKRecord.ID(recordName: inviteId)
        let inviteRecord = try await cloudKitManager.database.record(for: recordID)
        
        guard let invite = GroupWorkoutInvite(from: inviteRecord) else {
            throw GroupWorkoutError.inviteNotFound
        }
        
        // Verify this invite is for the current user
        guard invite.invitedUser == currentUserId else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Delete the invite
        try await cloudKitManager.delete(withRecordID: recordID)
    }
    
    func respondToInvite(_ inviteId: String, accept: Bool) async throws {
        if accept {
            _ = try await acceptInvite(inviteId)
        } else {
            try await declineInvite(inviteId)
        }
    }
    
    func fetchMyInvites() async throws -> [GroupWorkoutInvite] {
        try await getMyInvites()
    }
    
    func getMyInvites() async throws -> [GroupWorkoutInvite] {
        FameFitLogger.info("Getting invites for current user", category: FameFitLogger.social)
        
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Fetch invites for the current user that haven't expired
        let now = Date()
        let predicate = NSPredicate(format: "invitedUserID == %@ AND expiresTimestamp > %@", userId, now as NSDate)
        
        let sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutInvites",
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: 50
        )
        
        return records.compactMap { GroupWorkoutInvite(from: $0) }
    }
    
    func getWorkoutInvites(_ workoutId: String) async throws -> [GroupWorkoutInvite] {
        FameFitLogger.info("Getting invites for workout: \(workoutId)", category: FameFitLogger.social)
        
        let predicate = GroupWorkoutQueryBuilder.invitesForWorkoutQuery(workoutId: workoutId)
        let sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutInvites",
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: 100
        )
        
        return records.compactMap { GroupWorkoutInvite(from: $0) }
    }
    
    func cancelInvite(_ inviteId: String) async throws {
        FameFitLogger.info("Cancelling invite: \(inviteId)", category: FameFitLogger.social)
        
        guard let currentUserId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Fetch the invite
        let recordID = CKRecord.ID(recordName: inviteId)
        let inviteRecord = try await cloudKitManager.database.record(for: recordID)
        
        guard let invite = GroupWorkoutInvite(from: inviteRecord) else {
            throw GroupWorkoutError.inviteNotFound
        }
        
        // Only host can cancel invites
        guard invite.invitedBy == currentUserId else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Delete the invite
        try await cloudKitManager.delete(withRecordID: recordID)
    }
}