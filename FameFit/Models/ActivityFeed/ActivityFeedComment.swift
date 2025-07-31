//
//  ActivityFeedComment.swift
//  FameFit
//
//  Model for comments on any activity feed item
//

import CloudKit
import Foundation

struct ActivityFeedComment: Identifiable, Codable, Equatable {
    let id: String // CKRecord.ID as String
    
    // Dual reference system
    let activityFeedId: String // Reference to ActivityFeed item (might expire)
    let sourceType: String // "workout", "achievement", "level_up", etc.
    let sourceRecordId: String // The permanent record ID (workout ID, achievement ID, etc.)
    
    // User info
    let userId: String // User who posted the comment
    let activityOwnerId: String // Owner of the activity (for notifications)
    
    // Content
    var content: String
    let createdTimestamp: Date
    var modifiedTimestamp: Date
    
    // Optional fields
    var parentCommentId: String? // For threaded replies
    var isEdited: Bool = false
    var likeCount: Int = 0
    
    // Validation
    static func isValidComment(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 500
    }
}

// MARK: - CloudKit Extensions

extension ActivityFeedComment {
    init?(from record: CKRecord) {
        guard let activityFeedId = record["activityFeedId"] as? String,
              let sourceType = record["sourceType"] as? String,
              let sourceRecordId = record["sourceRecordId"] as? String,
              let userId = record["userId"] as? String,
              let activityOwnerId = record["activityOwnerId"] as? String,
              let content = record["content"] as? String,
              let createdTimestamp = record["createdTimestamp"] as? Date,
              let modifiedTimestamp = record["modifiedTimestamp"] as? Date
        else {
            return nil
        }
        
        id = record.recordID.recordName
        self.activityFeedId = activityFeedId
        self.sourceType = sourceType
        self.sourceRecordId = sourceRecordId
        self.userId = userId
        self.activityOwnerId = activityOwnerId
        self.content = content
        self.createdTimestamp = createdTimestamp
        self.modifiedTimestamp = modifiedTimestamp
        parentCommentId = record["parentCommentId"] as? String
        isEdited = (record["isEdited"] as? Int64) == 1
        likeCount = Int(record["likeCount"] as? Int64 ?? 0)
    }
    
    func toCKRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let record = if let recordID {
            CKRecord(recordType: "ActivityFeedComments", recordID: recordID)
        } else {
            CKRecord(recordType: "ActivityFeedComments")
        }
        
        record["activityFeedId"] = activityFeedId
        record["sourceType"] = sourceType
        record["sourceRecordId"] = sourceRecordId
        record["userId"] = userId
        record["activityOwnerId"] = activityOwnerId
        record["content"] = content
        record["createdTimestamp"] = createdTimestamp
        record["modifiedTimestamp"] = modifiedTimestamp
        
        if let parentCommentId {
            record["parentCommentId"] = parentCommentId
        }
        
        record["isEdited"] = isEdited ? Int64(1) : Int64(0)
        record["likeCount"] = Int64(likeCount)
        
        return record
    }
}


// MARK: - Comment with User Info

struct ActivityFeedCommentWithUser: Identifiable {
    var comment: ActivityFeedComment
    let user: UserProfile
    
    var id: String { comment.id }
}

// MARK: - Comment Thread

struct CommentThread {
    let parentComment: ActivityFeedCommentWithUser
    var replies: [ActivityFeedCommentWithUser]
    
    var totalComments: Int {
        1 + replies.count
    }
}

// MARK: - Source Type Enum

enum ActivitySourceType: String, CaseIterable {
    case workout = "workout"
    case achievement = "achievement"
    case levelUp = "level_up"
    case challenge = "challenge"
    case groupWorkout = "group_workout"
    
    var displayName: String {
        switch self {
        case .workout:
            "Workout"
        case .achievement:
            "Achievement"
        case .levelUp:
            "Level Up"
        case .challenge:
            "Challenge"
        case .groupWorkout:
            "Group Workout"
        }
    }
}