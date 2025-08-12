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

struct GroupWorkout: Identifiable, Equatable, Hashable {
    // MARK: - Constants
    
    enum Constants {
        /// Default maximum number of participants for a group workout
        static let defaultMaxParticipants = 100
        
        /// Minimum number of participants
        static let minParticipants = 2
        
        /// Maximum allowed participants
        static let maxParticipantsLimit = 100
    }
    
    // MARK: - Properties
    
    let id: String
    let name: String
    let description: String
    let workoutType: HKWorkoutActivityType
    let hostID: String
    let maxParticipants: Int
    var participantCount: Int = 0  // Cached count for performance
    let scheduledStart: Date
    let scheduledEnd: Date
    var status: GroupWorkoutStatus
    let creationDate: Date
    var modificationDate: Date
    let isPublic: Bool
    let joinCode: String? // For private groups
    let tags: [String]
    let location: String? // Optional location
    let notes: String? // Optional notes
    var participantIDs: [String] = [] // Array of user IDs who have joined (excluding host for cleaner data model)

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
        hostID: String,
        participantCount: Int = 0,
        maxParticipants: Int = Constants.defaultMaxParticipants,
        scheduledStart: Date,
        scheduledEnd: Date,
        status: GroupWorkoutStatus = .scheduled,
        creationDate: Date = Date(),
        modificationDate: Date = Date(),
        isPublic: Bool = true,
        joinCode: String? = nil,
        tags: [String] = [],
        location: String? = nil,
        notes: String? = nil,
        participantIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.workoutType = workoutType
        self.hostID = hostID
        self.participantCount = participantCount
        self.maxParticipants = maxParticipants
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.status = status
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.isPublic = isPublic
        self.joinCode = joinCode ?? (isPublic ? nil : Self.generateJoinCode())
        self.tags = tags
        self.location = location
        self.notes = notes
        self.participantIDs = participantIDs
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
        
        let description = record["description"] as? String ?? ""
        
        guard let workoutTypeRaw = record["workoutType"] as? Int64 else {
            FameFitLogger.warning("🏋️ GroupWorkout init failed: missing or invalid workoutType. Value: \(record["workoutType"] ?? "nil")", category: FameFitLogger.social)
            return nil
        }
        
        guard let workoutType = HKWorkoutActivityType(rawValue: UInt(workoutTypeRaw)) else {
            FameFitLogger.warning("🏋️ GroupWorkout init failed: invalid workoutType value \(workoutTypeRaw)", category: FameFitLogger.social)
            return nil
        }
        
        guard let hostID = record["hostID"] as? String else {
            FameFitLogger.warning("🏋️ GroupWorkout init failed: missing or invalid hostID", category: FameFitLogger.social)
            return nil
        }
        
        let maxParticipants = record["maxParticipants"] as? Int64 ?? Int64(Constants.defaultMaxParticipants)
        
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
        
        let creationDate = record.creationDate ?? record.creationDate ?? Date()
        let modificationDate = record.modificationDate ?? record.modificationDate ?? Date()
        
        let isPublic = record["isPublic"] as? Int64 ?? 0 // Default to private

        // Participants are now stored as separate records
        let participantCount = record["participantCount"] as? Int64 ?? 0

        let tags = record["tags"] as? [String] ?? []
        let location = record["location"] as? String
        let notes = record["notes"] as? String
        let participantIDs = record["participantIDs"] as? [String] ?? []

        self.init(
            id: record.recordID.recordName,
            name: name,
            description: description,
            workoutType: workoutType,
            hostID: hostID,
            participantCount: Int(participantCount),
            maxParticipants: Int(maxParticipants),
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            status: status,
            creationDate: creationDate,
            modificationDate: modificationDate,
            isPublic: isPublic != 0,
            joinCode: record["joinCode"] as? String,
            tags: tags,
            location: location,
            notes: notes,
            participantIDs: participantIDs
        )
    }

    func toCKRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let record = CKRecord(
            recordType: "GroupWorkouts",
            recordID: recordID ?? CKRecord.ID(recordName: id)
        )
        
        updateCKRecord(record)
        return record
    }
    
    /// Updates an existing CKRecord with current values
    func updateCKRecord(_ record: CKRecord) {
        record["name"] = name
        record["description"] = description
        record["workoutType"] = Int64(workoutType.rawValue)
        record["hostID"] = hostID
        record["participantCount"] = Int64(participantCount)
        record["maxParticipants"] = Int64(maxParticipants)
        record["scheduledStart"] = scheduledStart
        record["scheduledEnd"] = scheduledEnd
        record["status"] = status.rawValue
        
        
        record["isPublic"] = isPublic ? Int64(1) : Int64(0)
        record["joinCode"] = joinCode
        record["tags"] = tags
        record["location"] = location
        record["notes"] = notes
        record["participantIDs"] = participantIDs
    }

    // MARK: - Helper Methods

    static func generateJoinCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0 ..< 6).map { _ in letters.randomElement()! })
    }
}

// MARK: - Hashable Conformance

extension GroupWorkout {
    func hash(into hasher: inout Hasher) {
        // Since id is unique, we only need to hash the id
        hasher.combine(id)
    }
}

// MARK: - Codable Conformance

extension GroupWorkout: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, description, workoutType, hostID, participantCount
        case maxParticipants, scheduledStart, scheduledEnd, status
        case creationDate, modificationDate, isPublic, joinCode, tags
        case location, notes, participantIDs
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

        hostID = try container.decode(String.self, forKey: .hostID)
        participantCount = try container.decodeIfPresent(Int.self, forKey: .participantCount) ?? 0
        maxParticipants = try container.decode(Int.self, forKey: .maxParticipants)
        scheduledStart = try container.decode(Date.self, forKey: .scheduledStart)
        scheduledEnd = try container.decode(Date.self, forKey: .scheduledEnd)
        status = try container.decode(GroupWorkoutStatus.self, forKey: .status)
        creationDate = try container.decode(Date.self, forKey: .creationDate)
        modificationDate = try container.decode(Date.self, forKey: .modificationDate)
        isPublic = try container.decode(Bool.self, forKey: .isPublic)
        joinCode = try container.decodeIfPresent(String.self, forKey: .joinCode)
        tags = try container.decode([String].self, forKey: .tags)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        participantIDs = try container.decodeIfPresent([String].self, forKey: .participantIDs) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(workoutType.rawValue, forKey: .workoutType)
        try container.encode(hostID, forKey: .hostID)
        try container.encode(participantCount, forKey: .participantCount)
        try container.encode(maxParticipants, forKey: .maxParticipants)
        try container.encode(scheduledStart, forKey: .scheduledStart)
        try container.encode(scheduledEnd, forKey: .scheduledEnd)
        try container.encode(status, forKey: .status)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(modificationDate, forKey: .modificationDate)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encodeIfPresent(joinCode, forKey: .joinCode)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(participantIDs, forKey: .participantIDs)
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

