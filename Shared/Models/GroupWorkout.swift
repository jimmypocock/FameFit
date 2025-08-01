//
//  GroupWorkout.swift
//  FameFit
//
//  Model for group workout scheduling with proper timezone handling
//

import CloudKit
import Foundation

// MARK: - Group Workout Model

struct GroupWorkout: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let workoutType: String // HKWorkoutActivityType string representation
    let scheduledDate: Date // Always stored in UTC
    let timeZone: String // IANA timezone identifier (e.g., "America/New_York")
    let location: String?
    let notes: String?
    let maxParticipants: Int
    let createdBy: String // CloudKit User ID
    let createdAt: Date
    let updatedAt: Date
    let isPublic: Bool
    let tags: [String]
    let recordID: CKRecord.ID?
    
    // Computed properties for timezone handling
    var localScheduledDate: Date {
        guard let tz = TimeZone(identifier: timeZone) else { return scheduledDate }
        let offset = tz.secondsFromGMT(for: scheduledDate)
        return scheduledDate.addingTimeInterval(TimeInterval(offset))
    }
    
    var formattedScheduledTime: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZone) ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: scheduledDate)
    }
    
    var isUpcoming: Bool {
        scheduledDate > Date()
    }
    
    var isPast: Bool {
        scheduledDate <= Date()
    }
    
    init(
        id: String = UUID().uuidString,
        title: String,
        workoutType: String,
        scheduledDate: Date,
        timeZone: String = TimeZone.current.identifier,
        location: String? = nil,
        notes: String? = nil,
        maxParticipants: Int = 10,
        createdBy: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPublic: Bool = false,
        tags: [String] = [],
        recordID: CKRecord.ID? = nil
    ) {
        self.id = id
        self.title = title
        self.workoutType = workoutType
        self.scheduledDate = scheduledDate
        self.timeZone = timeZone
        self.location = location
        self.notes = notes
        self.maxParticipants = maxParticipants
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPublic = isPublic
        self.tags = tags
        self.recordID = recordID
    }
}

// MARK: - CloudKit Conversion

extension GroupWorkout {
    init?(from record: CKRecord) {
        guard
            let id = record["id"] as? String,
            let title = record["title"] as? String,
            let workoutType = record["workoutType"] as? String,
            let scheduledDate = record["scheduledDate"] as? Date,
            let timeZone = record["timeZone"] as? String,
            let maxParticipants = record["maxParticipants"] as? Int,
            let createdBy = record["createdBy"] as? String,
            let createdAt = record["createdAt"] as? Date,
            let updatedAt = record["updatedAt"] as? Date,
            let isPublic = record["isPublic"] as? Int
        else {
            return nil
        }
        
        self.id = id
        self.title = title
        self.workoutType = workoutType
        self.scheduledDate = scheduledDate
        self.timeZone = timeZone
        self.location = record["location"] as? String
        self.notes = record["notes"] as? String
        self.maxParticipants = maxParticipants
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPublic = isPublic == 1
        self.tags = (record["tags"] as? [String]) ?? []
        self.recordID = record.recordID
    }
    
    func toCKRecord() -> CKRecord {
        let record = recordID != nil ? CKRecord(recordType: "GroupWorkout", recordID: recordID!) : CKRecord(recordType: "GroupWorkout")
        
        record["id"] = id
        record["title"] = title
        record["workoutType"] = workoutType
        record["scheduledDate"] = scheduledDate
        record["timeZone"] = timeZone
        record["location"] = location
        record["notes"] = notes
        record["maxParticipants"] = maxParticipants
        record["createdBy"] = createdBy
        record["createdAt"] = createdAt
        record["updatedAt"] = updatedAt
        record["isPublic"] = isPublic ? 1 : 0
        record["tags"] = tags
        
        return record
    }
}

// MARK: - Group Workout Participant

struct GroupWorkoutParticipant: Identifiable, Codable {
    let id: String
    let groupWorkoutId: String
    let userId: String // CloudKit User ID
    let userProfileId: String // Profile UUID
    let status: ParticipantStatus
    let joinedAt: Date
    let recordID: CKRecord.ID?
    
    enum ParticipantStatus: String, Codable, CaseIterable {
        case pending = "pending"
        case accepted = "accepted"
        case declined = "declined"
        case maybe = "maybe"
        
        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .accepted: return "Going"
            case .declined: return "Not Going"
            case .maybe: return "Maybe"
            }
        }
    }
    
    init(
        id: String = UUID().uuidString,
        groupWorkoutId: String,
        userId: String,
        userProfileId: String,
        status: ParticipantStatus = .pending,
        joinedAt: Date = Date(),
        recordID: CKRecord.ID? = nil
    ) {
        self.id = id
        self.groupWorkoutId = groupWorkoutId
        self.userId = userId
        self.userProfileId = userProfileId
        self.status = status
        self.joinedAt = joinedAt
        self.recordID = recordID
    }
}

// MARK: - CloudKit Conversion

extension GroupWorkoutParticipant {
    init?(from record: CKRecord) {
        guard
            let id = record["id"] as? String,
            let groupWorkoutId = record["groupWorkoutId"] as? String,
            let userId = record["userId"] as? String,
            let userProfileId = record["userProfileId"] as? String,
            let statusString = record["status"] as? String,
            let status = ParticipantStatus(rawValue: statusString),
            let joinedAt = record["joinedAt"] as? Date
        else {
            return nil
        }
        
        self.id = id
        self.groupWorkoutId = groupWorkoutId
        self.userId = userId
        self.userProfileId = userProfileId
        self.status = status
        self.joinedAt = joinedAt
        self.recordID = record.recordID
    }
    
    func toCKRecord() -> CKRecord {
        let record = recordID != nil ? CKRecord(recordType: "GroupWorkoutParticipant", recordID: recordID!) : CKRecord(recordType: "GroupWorkoutParticipant")
        
        record["id"] = id
        record["groupWorkoutId"] = groupWorkoutId
        record["userId"] = userId
        record["userProfileId"] = userProfileId
        record["status"] = status.rawValue
        record["joinedAt"] = joinedAt
        
        return record
    }
}

// MARK: - Group Workout Invite

struct GroupWorkoutInvite: Identifiable, Codable {
    let id: String
    let groupWorkoutId: String
    let invitedBy: String // CloudKit User ID
    let invitedUser: String // CloudKit User ID
    let invitedAt: Date
    let expiresAt: Date
    let recordID: CKRecord.ID?
    
    var isExpired: Bool {
        expiresAt <= Date()
    }
    
    init(
        id: String = UUID().uuidString,
        groupWorkoutId: String,
        invitedBy: String,
        invitedUser: String,
        invitedAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days default
        recordID: CKRecord.ID? = nil
    ) {
        self.id = id
        self.groupWorkoutId = groupWorkoutId
        self.invitedBy = invitedBy
        self.invitedUser = invitedUser
        self.invitedAt = invitedAt
        self.expiresAt = expiresAt
        self.recordID = recordID
    }
}

// MARK: - CloudKit Conversion

extension GroupWorkoutInvite {
    init?(from record: CKRecord) {
        guard
            let id = record["id"] as? String,
            let groupWorkoutId = record["groupWorkoutId"] as? String,
            let invitedBy = record["invitedBy"] as? String,
            let invitedUser = record["invitedUser"] as? String,
            let invitedAt = record["invitedAt"] as? Date,
            let expiresAt = record["expiresAt"] as? Date
        else {
            return nil
        }
        
        self.id = id
        self.groupWorkoutId = groupWorkoutId
        self.invitedBy = invitedBy
        self.invitedUser = invitedUser
        self.invitedAt = invitedAt
        self.expiresAt = expiresAt
        self.recordID = record.recordID
    }
    
    func toCKRecord() -> CKRecord {
        let record = recordID != nil ? CKRecord(recordType: "GroupWorkoutInvite", recordID: recordID!) : CKRecord(recordType: "GroupWorkoutInvite")
        
        record["id"] = id
        record["groupWorkoutId"] = groupWorkoutId
        record["invitedBy"] = invitedBy
        record["invitedUser"] = invitedUser
        record["invitedAt"] = invitedAt
        record["expiresAt"] = expiresAt
        
        return record
    }
}