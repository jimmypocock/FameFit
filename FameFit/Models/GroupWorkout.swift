//
//  GroupWorkout.swift
//  FameFit
//
//  Model for group workout sessions
//

import CloudKit
import Foundation
import HealthKit

// MARK: - Group Workout Model

struct GroupWorkout: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let workoutType: HKWorkoutActivityType
    let hostId: String
    let maxParticipants: Int
    var participantCount: Int = 0  // Cached count for performance
    let scheduledStart: Date
    let scheduledEnd: Date
    var status: GroupWorkoutStatus
    let createdTimestamp: Date
    var modifiedTimestamp: Date
    let isPublic: Bool
    let joinCode: String? // For private groups
    let tags: [String]
    let location: String? // Optional location
    let notes: String? // Optional notes

    // Computed Properties
    var duration: TimeInterval {
        scheduledEnd.timeIntervalSince(scheduledStart)
    }

    var isUpcoming: Bool {
        status == .scheduled && scheduledStart > Date()
    }

    var isActive: Bool {
        status == .active
    }

    var isCompleted: Bool {
        status == .completed
    }

    var hasSpace: Bool {
        participantCount < maxParticipants
    }
    
    var isJoinable: Bool {
        // Allow joining if workout starts within 5 minutes or has already started (but not ended)
        let fiveMinutesFromNow = Date().addingTimeInterval(5 * 60)
        let canJoinByTime = scheduledStart <= fiveMinutesFromNow && scheduledEnd > Date()
        return canJoinByTime && status.canJoin && hasSpace
    }
    
    var timeUntilJoinable: TimeInterval? {
        // If already joinable, return nil
        if isJoinable { return nil }
        
        // Calculate time until 5 minutes before start
        let joinableTime = scheduledStart.addingTimeInterval(-5 * 60)
        let timeUntil = joinableTime.timeIntervalSince(Date())
        
        return timeUntil > 0 ? timeUntil : nil
    }

    // Note: Participants are stored as separate CKRecords for scalability
    
    // Compatibility aliases for different naming conventions
    var title: String { name }
    var scheduledDate: Date { scheduledStart }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        workoutType: HKWorkoutActivityType,
        hostId: String,
        participantCount: Int = 0,
        maxParticipants: Int = 10,
        scheduledStart: Date,
        scheduledEnd: Date,
        status: GroupWorkoutStatus = .scheduled,
        createdTimestamp: Date = Date(),
        modifiedTimestamp: Date = Date(),
        isPublic: Bool = true,
        joinCode: String? = nil,
        tags: [String] = [],
        location: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.workoutType = workoutType
        self.hostId = hostId
        self.participantCount = participantCount
        self.maxParticipants = maxParticipants
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.status = status
        self.createdTimestamp = createdTimestamp
        self.modifiedTimestamp = modifiedTimestamp
        self.isPublic = isPublic
        self.joinCode = joinCode ?? (isPublic ? nil : Self.generateJoinCode())
        self.tags = tags
        self.location = location
        self.notes = notes
    }

    // MARK: - CloudKit Integration

    init?(from record: CKRecord) {
        guard record.recordType == "GroupWorkouts" else {
            FameFitLogger.warning("🏋️ GroupWorkout init failed: wrong record type \(record.recordType)", category: FameFitLogger.social)
            return nil
        }
        
        guard let name = record["name"] as? String else {
            FameFitLogger.warning("🏋️ GroupWorkout init failed: missing or invalid name", category: FameFitLogger.social)
            return nil
        }
        
        let description = record["description"] as? String ?? "Group workout session"
        
        guard let workoutTypeRaw = record["workoutType"] as? Int64 else {
            FameFitLogger.warning("🏋️ GroupWorkout init failed: missing or invalid workoutType. Value: \(record["workoutType"] ?? "nil")", category: FameFitLogger.social)
            return nil
        }
        
        guard let workoutType = HKWorkoutActivityType(rawValue: UInt(workoutTypeRaw)) else {
            FameFitLogger.warning("🏋️ GroupWorkout init failed: invalid workoutType value \(workoutTypeRaw)", category: FameFitLogger.social)
            return nil
        }
        
        guard let hostId = record["hostID"] as? String else {
            FameFitLogger.warning("🏋️ GroupWorkout init failed: missing or invalid hostID", category: FameFitLogger.social)
            return nil
        }
        
        let maxParticipants = record["maxParticipants"] as? Int64 ?? 10 // Default to 10 participants
        
        guard let scheduledStart = record["scheduledStart"] as? Date else {
            FameFitLogger.warning("🏋️ GroupWorkout init failed: missing or invalid scheduledStart", category: FameFitLogger.social)
            return nil
        }
        
        guard let scheduledEnd = record["scheduledEnd"] as? Date else {
            FameFitLogger.warning("🏋️ GroupWorkout init failed: missing or invalid scheduledEnd", category: FameFitLogger.social)
            return nil
        }
        
        let statusRaw = record["status"] as? String ?? "scheduled"
        let status = GroupWorkoutStatus(rawValue: statusRaw) ?? .scheduled
        
        let createdTimestamp = record["createdTimestamp"] as? Date ?? record.creationDate ?? Date()
        let modifiedTimestamp = record["modifiedTimestamp"] as? Date ?? record.modificationDate ?? Date()
        
        let isPublic = record["isPublic"] as? Int64 ?? 0 // Default to private

        // Participants are now stored as separate records
        let participantCount = record["participantCount"] as? Int64 ?? 0

        let tags = record["tags"] as? [String] ?? []
        let location = record["location"] as? String
        let notes = record["notes"] as? String

        self.init(
            id: record.recordID.recordName,
            name: name,
            description: description,
            workoutType: workoutType,
            hostId: hostId,
            participantCount: Int(participantCount),
            maxParticipants: Int(maxParticipants),
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            status: status,
            createdTimestamp: createdTimestamp,
            modifiedTimestamp: modifiedTimestamp,
            isPublic: isPublic != 0,
            joinCode: record["joinCode"] as? String,
            tags: tags,
            location: location,
            notes: notes
        )
    }

    func toCKRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let record = CKRecord(
            recordType: "GroupWorkouts",
            recordID: recordID ?? CKRecord.ID(recordName: id)
        )

        record["name"] = name
        record["description"] = description
        record["workoutType"] = Int64(workoutType.rawValue)
        record["hostID"] = hostId
        record["participantCount"] = Int64(participantCount)
        record["maxParticipants"] = Int64(maxParticipants)
        record["scheduledStart"] = scheduledStart
        record["scheduledEnd"] = scheduledEnd
        record["status"] = status.rawValue
        record["createdTimestamp"] = createdTimestamp
        record["modifiedTimestamp"] = modifiedTimestamp
        record["isPublic"] = isPublic ? Int64(1) : Int64(0)
        record["joinCode"] = joinCode
        record["tags"] = tags
        record["location"] = location
        record["notes"] = notes

        return record
    }

    // MARK: - Helper Methods

    static func generateJoinCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0 ..< 6).map { _ in letters.randomElement()! })
    }
}

// MARK: - Codable Conformance

extension GroupWorkout: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, description, workoutType, hostId, participantCount
        case maxParticipants, scheduledStart, scheduledEnd, status
        case createdTimestamp, modifiedTimestamp, isPublic, joinCode, tags
        case location, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)

        // Decode workout type from raw value
        let workoutTypeRaw = try container.decode(UInt.self, forKey: .workoutType)
        guard let type = HKWorkoutActivityType(rawValue: workoutTypeRaw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .workoutType,
                in: container,
                debugDescription: "Invalid workout type"
            )
        }
        workoutType = type

        hostId = try container.decode(String.self, forKey: .hostId)
        participantCount = try container.decodeIfPresent(Int.self, forKey: .participantCount) ?? 0
        maxParticipants = try container.decode(Int.self, forKey: .maxParticipants)
        scheduledStart = try container.decode(Date.self, forKey: .scheduledStart)
        scheduledEnd = try container.decode(Date.self, forKey: .scheduledEnd)
        status = try container.decode(GroupWorkoutStatus.self, forKey: .status)
        createdTimestamp = try container.decode(Date.self, forKey: .createdTimestamp)
        modifiedTimestamp = try container.decode(Date.self, forKey: .modifiedTimestamp)
        isPublic = try container.decode(Bool.self, forKey: .isPublic)
        joinCode = try container.decodeIfPresent(String.self, forKey: .joinCode)
        tags = try container.decode([String].self, forKey: .tags)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(workoutType.rawValue, forKey: .workoutType)
        try container.encode(hostId, forKey: .hostId)
        try container.encode(participantCount, forKey: .participantCount)
        try container.encode(maxParticipants, forKey: .maxParticipants)
        try container.encode(scheduledStart, forKey: .scheduledStart)
        try container.encode(scheduledEnd, forKey: .scheduledEnd)
        try container.encode(status, forKey: .status)
        try container.encode(createdTimestamp, forKey: .createdTimestamp)
        try container.encode(modifiedTimestamp, forKey: .modifiedTimestamp)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encodeIfPresent(joinCode, forKey: .joinCode)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

// MARK: - Group Workout Participant

struct GroupWorkoutParticipant: Codable, Identifiable, Equatable {
    let id: String
    let groupWorkoutId: String  // Reference to parent workout
    let userId: String
    let username: String
    let profileImageURL: String?
    let joinedAt: Date
    var status: ParticipantStatus
    var workoutData: GroupWorkoutData?

    init(
        id: String = UUID().uuidString,
        groupWorkoutId: String,
        userId: String,
        username: String,
        profileImageURL: String? = nil,
        joinedAt: Date = Date(),
        status: ParticipantStatus = .joined,
        workoutData: GroupWorkoutData? = nil
    ) {
        self.id = id
        self.groupWorkoutId = groupWorkoutId
        self.userId = userId
        self.username = username
        self.profileImageURL = profileImageURL
        self.joinedAt = joinedAt
        self.status = status
        self.workoutData = workoutData
    }
}

// MARK: - CloudKit Conversion for GroupWorkoutParticipant

extension GroupWorkoutParticipant {
    init?(from record: CKRecord) {
        guard
            let id = record["id"] as? String,
            let groupWorkoutRef = record["groupWorkoutID"] as? CKRecord.Reference,
            let userId = record["userID"] as? String,
            let username = record["username"] as? String,
            let joinedAt = record["joinedTimestamp"] as? Date,
            let statusRaw = record["status"] as? String,
            let status = ParticipantStatus(rawValue: statusRaw)
        else {
            return nil
        }
        
        self.id = id
        self.groupWorkoutId = groupWorkoutRef.recordID.recordName
        self.userId = userId
        self.username = username
        self.profileImageURL = record["profileImageURL"] as? String
        self.joinedAt = joinedAt
        self.status = status
        
        // Decode workout data if present
        if let workoutDataJSON = record["workoutData"] as? Data {
            self.workoutData = try? JSONDecoder().decode(GroupWorkoutData.self, from: workoutDataJSON)
        } else {
            self.workoutData = nil
        }
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "GroupWorkoutParticipants", recordID: CKRecord.ID(recordName: id))
        
        record["id"] = id
        record["groupWorkoutID"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: groupWorkoutId), action: .deleteSelf)
        record["userID"] = userId
        record["username"] = username
        record["profileImageURL"] = profileImageURL
        record["joinedTimestamp"] = joinedAt
        record["status"] = status.rawValue
        
        if let workoutData = workoutData {
            record["workoutData"] = try? JSONEncoder().encode(workoutData)
        }
        
        return record
    }
}

// MARK: - Group Workout Data

struct GroupWorkoutData: Codable, Equatable {
    let startTime: Date
    var endTime: Date?
    var totalEnergyBurned: Double // kcal
    var totalDistance: Double? // meters
    var averageHeartRate: Double?
    var currentHeartRate: Double?
    var lastUpdated: Date

    var isActive: Bool {
        endTime == nil
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
}

// MARK: - Enums

enum GroupWorkoutStatus: String, Codable, CaseIterable {
    case scheduled
    case active
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .scheduled:
            "Scheduled"
        case .active:
            "Active"
        case .completed:
            "Completed"
        case .cancelled:
            "Cancelled"
        }
    }

    var canJoin: Bool {
        switch self {
        case .scheduled, .active:
            true
        case .completed, .cancelled:
            false
        }
    }
}

enum ParticipantStatus: String, Codable, CaseIterable {
    case pending
    case joined
    case maybe
    case declined
    case active
    case completed
    case dropped

    var displayName: String {
        switch self {
        case .pending:
            "Pending"
        case .joined:
            "Ready"
        case .maybe:
            "Maybe"
        case .declined:
            "Declined"
        case .active:
            "Working Out"
        case .completed:
            "Finished"
        case .dropped:
            "Left"
        }
    }
}

// MARK: - Group Workout Invite

struct GroupWorkoutInvite: Identifiable, Codable {
    let id: String
    let groupWorkoutId: String
    let invitedBy: String // User ID who sent the invite
    let invitedUser: String // User ID who was invited
    let invitedAt: Date
    let expiresAt: Date
    
    var isExpired: Bool {
        expiresAt <= Date()
    }
    
    init(
        id: String = UUID().uuidString,
        groupWorkoutId: String,
        invitedBy: String,
        invitedUser: String,
        invitedAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days default
    ) {
        self.id = id
        self.groupWorkoutId = groupWorkoutId
        self.invitedBy = invitedBy
        self.invitedUser = invitedUser
        self.invitedAt = invitedAt
        self.expiresAt = expiresAt
    }
}

// MARK: - CloudKit Conversion for GroupWorkoutInvite

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
        self.groupWorkoutId = groupWorkoutRef.recordID.recordName
        self.invitedBy = invitedBy
        self.invitedUser = invitedUser
        self.invitedAt = record.creationDate ?? Date()
        self.expiresAt = expiresAt
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "GroupWorkoutInvites", recordID: CKRecord.ID(recordName: id))
        
        record["id"] = id
        record["groupWorkoutID"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: groupWorkoutId), action: .deleteSelf)
        record["invitedByID"] = invitedBy
        record["invitedUserID"] = invitedUser
        // invitedAt is stored in system createdTimestamp field
        record["expiresTimestamp"] = expiresAt
        
        return record
    }
}

