//
//  WorkoutKudos.swift
//  FameFit
//
//  Model for workout kudos/cheers (like reactions)
//

import CloudKit
import Foundation

// MARK: - Kudos Model

struct WorkoutKudos: Identifiable, Codable, Equatable {
    let id: String
    let workoutID: String
    let userID: String // User who gave the kudos
    let workoutOwnerID: String // User who owns the workout
    let createdTimestamp: Date

    init(
        id: String = UUID().uuidString,
        workoutID: String,
        userID: String,
        workoutOwnerID: String,
        createdTimestamp: Date = Date()
    ) {
        self.id = id
        self.workoutID = workoutID
        self.userID = userID
        self.workoutOwnerID = workoutOwnerID
        self.createdTimestamp = createdTimestamp
    }
}

// MARK: - Kudos Summary

struct WorkoutKudosSummary: Codable, Equatable {
    let workoutID: String
    let totalCount: Int
    let hasUserKudos: Bool // Whether current user has given kudos
    let recentUsers: [KudosUser] // Recent users who gave kudos

    struct KudosUser: Codable, Equatable {
        let userID: String
        let username: String
        let profileImageURL: String?
    }
}

// MARK: - CloudKit Extensions

extension WorkoutKudos {
    static let recordType = "WorkoutKudos"

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let workoutID = record["workoutID"] as? String,
              let userID = record["userID"] as? String,
              let workoutOwnerID = record["workoutOwnerID"] as? String,
              let createdTimestamp = record["createdTimestamp"] as? Date
        else {
            return nil
        }

        id = record.recordID.recordName
        self.workoutID = workoutID
        self.userID = userID
        self.workoutOwnerID = workoutOwnerID
        self.createdTimestamp = createdTimestamp
    }

    func toCloudKitRecord(in _: CKDatabase) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        record["workoutID"] = workoutID
        record["userID"] = userID
        record["workoutOwnerID"] = workoutOwnerID
        record["createdTimestamp"] = createdTimestamp

        return record
    }
}

// MARK: - Kudos Action Result

enum KudosActionResult: Equatable {
    case added
    case removed
    case error(Error)

    static func == (lhs: KudosActionResult, rhs: KudosActionResult) -> Bool {
        switch (lhs, rhs) {
        case (.added, .added), (.removed, .removed):
            true
        case let (.error(error1), .error(error2)):
            error1.localizedDescription == error2.localizedDescription
        default:
            false
        }
    }
}
