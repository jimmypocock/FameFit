//
//  GroupWorkoutInvite.swift
//  FameFit
//
//  Model for group workout invitations
//

import CloudKit
import Foundation

// MARK: - Group Workout Invite

struct GroupWorkoutInvite: Identifiable, Codable {
    let id: String
    let groupWorkoutID: String
    let invitedBy: String // User ID who sent the invite
    let invitedUser: String // User ID who was invited
    let invitedAt: Date
    let expiresAt: Date
    
    var isExpired: Bool {
        expiresAt <= Date()
    }
    
    init(
        id: String = UUID().uuidString,
        groupWorkoutID: String,
        invitedBy: String,
        invitedUser: String,
        invitedAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days default
    ) {
        self.id = id
        self.groupWorkoutID = groupWorkoutID
        self.invitedBy = invitedBy
        self.invitedUser = invitedUser
        self.invitedAt = invitedAt
        self.expiresAt = expiresAt
    }
}

// MARK: - CloudKit Conversion

extension GroupWorkoutInvite {
    init?(from record: CKRecord) {
        guard
            let id = record["id"] as? String,
            let groupWorkoutRef = record["groupWorkoutID"] as? CKRecord.Reference,
            let invitedBy = record["invitedByID"] as? String,
            let invitedUser = record["invitedUserID"] as? String,
            let expiresAt = record["expiresTimestamp"] as? Date
        else {
            return nil
        }
        
        self.id = id
        self.groupWorkoutID = groupWorkoutRef.recordID.recordName
        self.invitedBy = invitedBy
        self.invitedUser = invitedUser
        self.invitedAt = record.creationDate ?? Date()
        self.expiresAt = expiresAt
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "GroupWorkoutInvites", recordID: CKRecord.ID(recordName: id))
        
        record["id"] = id
        record["groupWorkoutID"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: groupWorkoutID), action: .deleteSelf)
        record["invitedByID"] = invitedBy
        record["invitedUserID"] = invitedUser
        // invitedAt is stored in system creationDate field
        record["expiresTimestamp"] = expiresAt
        
        return record
    }
}