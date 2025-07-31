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
    var participants: [GroupWorkoutParticipant]
    let maxParticipants: Int
    let scheduledStart: Date
    let scheduledEnd: Date
    var status: GroupWorkoutStatus
    let createdTimestamp: Date
    var modifiedTimestamp: Date
    let isPublic: Bool
    let joinCode: String? // For private groups
    let tags: [String]

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
        participants.count < maxParticipants
    }

    var participantIds: [String] {
        participants.map(\.userId)
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        workoutType: HKWorkoutActivityType,
        hostId: String,
        participants: [GroupWorkoutParticipant] = [],
        maxParticipants: Int = 10,
        scheduledStart: Date,
        scheduledEnd: Date,
        status: GroupWorkoutStatus = .scheduled,
        createdTimestamp: Date = Date(),
        modifiedTimestamp: Date = Date(),
        isPublic: Bool = true,
        joinCode: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.workoutType = workoutType
        self.hostId = hostId
        self.participants = participants
        self.maxParticipants = maxParticipants
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.status = status
        self.createdTimestamp = createdTimestamp
        self.modifiedTimestamp = modifiedTimestamp
        self.isPublic = isPublic
        self.joinCode = joinCode ?? (isPublic ? nil : Self.generateJoinCode())
        self.tags = tags
    }

    // MARK: - CloudKit Integration

    init?(from record: CKRecord) {
        guard record.recordType == "GroupWorkouts",
              let name = record["name"] as? String,
              let description = record["description"] as? String,
              let workoutTypeRaw = record["workoutType"] as? Int,
              let workoutType = HKWorkoutActivityType(rawValue: UInt(workoutTypeRaw)),
              let hostId = record["hostId"] as? String,
              let maxParticipants = record["maxParticipants"] as? Int64,
              let scheduledStart = record["scheduledStart"] as? Date,
              let scheduledEnd = record["scheduledEnd"] as? Date,
              let statusRaw = record["status"] as? String,
              let status = GroupWorkoutStatus(rawValue: statusRaw),
              let createdTimestamp = record["createdTimestamp"] as? Date,
              let modifiedTimestamp = record["modifiedTimestamp"] as? Date,
              let isPublic = record["isPublic"] as? Int64
        else {
            return nil
        }

        // Decode participants from JSON
        var participants: [GroupWorkoutParticipant] = []
        if let participantsData = record["participants"] as? Data {
            participants = (try? JSONDecoder().decode([GroupWorkoutParticipant].self, from: participantsData)) ?? []
        }

        let tags = record["tags"] as? [String] ?? []

        self.init(
            id: record.recordID.recordName,
            name: name,
            description: description,
            workoutType: workoutType,
            hostId: hostId,
            participants: participants,
            maxParticipants: Int(maxParticipants),
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            status: status,
            createdTimestamp: createdTimestamp,
            modifiedTimestamp: modifiedTimestamp,
            isPublic: isPublic != 0,
            joinCode: record["joinCode"] as? String,
            tags: tags
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
        record["hostId"] = hostId
        record["participants"] = try? JSONEncoder().encode(participants)
        record["maxParticipants"] = Int64(maxParticipants)
        record["scheduledStart"] = scheduledStart
        record["scheduledEnd"] = scheduledEnd
        record["status"] = status.rawValue
        record["createdTimestamp"] = createdTimestamp
        record["modifiedTimestamp"] = modifiedTimestamp
        record["isPublic"] = isPublic ? Int64(1) : Int64(0)
        record["joinCode"] = joinCode
        record["tags"] = tags

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
        case id, name, description, workoutType, hostId, participants
        case maxParticipants, scheduledStart, scheduledEnd, status
        case createdTimestamp, modifiedTimestamp, isPublic, joinCode, tags
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
        participants = try container.decode([GroupWorkoutParticipant].self, forKey: .participants)
        maxParticipants = try container.decode(Int.self, forKey: .maxParticipants)
        scheduledStart = try container.decode(Date.self, forKey: .scheduledStart)
        scheduledEnd = try container.decode(Date.self, forKey: .scheduledEnd)
        status = try container.decode(GroupWorkoutStatus.self, forKey: .status)
        createdTimestamp = try container.decode(Date.self, forKey: .createdTimestamp)
        modifiedTimestamp = try container.decode(Date.self, forKey: .modifiedTimestamp)
        isPublic = try container.decode(Bool.self, forKey: .isPublic)
        joinCode = try container.decodeIfPresent(String.self, forKey: .joinCode)
        tags = try container.decode([String].self, forKey: .tags)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(workoutType.rawValue, forKey: .workoutType)
        try container.encode(hostId, forKey: .hostId)
        try container.encode(participants, forKey: .participants)
        try container.encode(maxParticipants, forKey: .maxParticipants)
        try container.encode(scheduledStart, forKey: .scheduledStart)
        try container.encode(scheduledEnd, forKey: .scheduledEnd)
        try container.encode(status, forKey: .status)
        try container.encode(createdTimestamp, forKey: .createdTimestamp)
        try container.encode(modifiedTimestamp, forKey: .modifiedTimestamp)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encodeIfPresent(joinCode, forKey: .joinCode)
        try container.encode(tags, forKey: .tags)
    }
}

// MARK: - Group Workout Participant

struct GroupWorkoutParticipant: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let username: String
    let profileImageURL: String?
    let joinedAt: Date
    var status: ParticipantStatus
    var workoutData: GroupWorkoutData?

    init(
        id: String = UUID().uuidString,
        userId: String,
        username: String,
        profileImageURL: String? = nil,
        joinedAt: Date = Date(),
        status: ParticipantStatus = .joined,
        workoutData: GroupWorkoutData? = nil
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.profileImageURL = profileImageURL
        self.joinedAt = joinedAt
        self.status = status
        self.workoutData = workoutData
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

enum ParticipantStatus: String, Codable {
    case joined
    case active
    case completed
    case dropped

    var displayName: String {
        switch self {
        case .joined:
            "Ready"
        case .active:
            "Working Out"
        case .completed:
            "Finished"
        case .dropped:
            "Left"
        }
    }
}

// MARK: - Group Workout Update

struct GroupWorkoutUpdate {
    let workoutId: String
    let participantId: String
    let updateType: UpdateType
    let data: GroupWorkoutData?
    let timestamp: Date

    enum UpdateType: String {
        case joined
        case started
        case progress
        case completed
        case dropped
    }
}
