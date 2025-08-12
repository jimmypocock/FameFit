//
//  GroupWorkoutParticipant.swift
//  FameFit
//
//  Model for group workout participants and their workout data
//

import CloudKit
import Foundation

// MARK: - Group Workout Participant

struct GroupWorkoutParticipant: Codable, Identifiable, Equatable {
    let id: String
    let groupWorkoutID: String  // Reference to parent workout
    let userID: String
    let username: String
    let profileImageURL: String?
    let joinedAt: Date
    var status: ParticipantStatus
    var workoutData: GroupWorkoutData?

    init(
        id: String = UUID().uuidString,
        groupWorkoutID: String,
        userID: String,
        username: String,
        profileImageURL: String? = nil,
        joinedAt: Date = Date(),
        status: ParticipantStatus = .joined,
        workoutData: GroupWorkoutData? = nil
    ) {
        self.id = id
        self.groupWorkoutID = groupWorkoutID
        self.userID = userID
        self.username = username
        self.profileImageURL = profileImageURL
        self.joinedAt = joinedAt
        self.status = status
        self.workoutData = workoutData
    }
}

// MARK: - CloudKit Conversion

extension GroupWorkoutParticipant {
    init?(from record: CKRecord) {
        guard
            let id = record["id"] as? String,
            let groupWorkoutRef = record["groupWorkoutID"] as? CKRecord.Reference,
            let userID = record["userID"] as? String,
            let username = record["username"] as? String,
            let joinedAt = record["joinedTimestamp"] as? Date,
            let statusRaw = record["status"] as? String,
            let status = ParticipantStatus(rawValue: statusRaw)
        else {
            return nil
        }
        
        self.id = id
        self.groupWorkoutID = groupWorkoutRef.recordID.recordName
        self.userID = userID
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
        record["groupWorkoutID"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: groupWorkoutID), action: .deleteSelf)
        record["userID"] = userID
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

// MARK: - Participant Status

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