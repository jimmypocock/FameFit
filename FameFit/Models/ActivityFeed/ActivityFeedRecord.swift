//
//  ActivityFeedRecord.swift
//  FameFit
//
//  Core activity feed record model stored in CloudKit
//

import Foundation
import CloudKit

struct ActivityFeedRecord: Codable, Identifiable, Equatable {
    let id: String
    let userID: String
    let activityType: String
    let workoutID: String?
    let content: String // JSON encoded content
    let visibility: String // "private", "friends_only", "public"
    let creationDate: Date
    let expiresAt: Date
    let xpEarned: Int?
    let achievementName: String?

    // Computed properties for UI display
    var privacyLevel: WorkoutPrivacy {
        WorkoutPrivacy(rawValue: visibility) ?? .private
    }

    var contentData: ActivityFeedContent? {
        guard let data = content.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ActivityFeedContent.self, from: data)
    }
}

// MARK: - CloudKit Extensions

extension ActivityFeedRecord {
    init?(from record: CKRecord) {
        guard let userID = record["userID"] as? String,
              let activityType = record["activityType"] as? String,
              let content = record["content"] as? String,
              let visibility = record["visibility"] as? String,
              let creationDate = record.creationDate,
              let expiresAt = record["expiresAt"] as? Date
        else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.userID = userID
        self.activityType = activityType
        self.workoutID = record["workoutID"] as? String
        self.content = content
        self.visibility = visibility
        self.creationDate = creationDate
        self.expiresAt = expiresAt
        self.xpEarned = record["xpEarned"] as? Int
        self.achievementName = record["achievementName"] as? String
    }
    
    func toCKRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let record = if let recordID {
            CKRecord(recordType: "ActivityFeed", recordID: recordID)
        } else {
            CKRecord(recordType: "ActivityFeed")
        }
        
        record["userID"] = userID
        record["activityType"] = activityType
        if let workoutID {
            record["workoutID"] = workoutID
        }
        record["content"] = content
        record["visibility"] = visibility
        
        record["expiresAt"] = expiresAt
        
        if let xpEarned {
            record["xpEarned"] = Int64(xpEarned)
        }
        
        if let achievementName {
            record["achievementName"] = achievementName
        }
        
        return record
    }
}
