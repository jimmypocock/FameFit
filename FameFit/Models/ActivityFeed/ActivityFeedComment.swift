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
    let activityFeedID: String // Reference to ActivityFeed item (might expire)
    let sourceType: String // "workout", "achievement", "level_up", etc.
    let sourceID: String // The permanent record ID (workout ID, achievement ID, etc.)
    
    // User info
    let userID: String // User who posted the comment
    let activityOwnerID: String // Owner of the activity (for notifications)
    
    // Content
    var content: String
    let creationDate: Date
    var modificationDate: Date
    
    // Optional fields
    var parentCommentID: String? // For threaded replies
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
        guard let activityFeedID = record["activityFeedID"] as? String,
              let sourceType = record["sourceType"] as? String,
              let sourceID = record["sourceID"] as? String,
              let userID = record["userID"] as? String,
              let activityOwnerID = record["activityOwnerID"] as? String,
              let content = record["content"] as? String,
              let creationDate = record.creationDate,
              let modificationDate = record.modificationDate
        else {
            return nil
        }
        
        id = record.recordID.recordName
        self.activityFeedID = activityFeedID
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.userID = userID
        self.activityOwnerID = activityOwnerID
        self.content = content
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        parentCommentID = record["parentCommentID"] as? String
        isEdited = (record["isEdited"] as? Int64) == 1
        likeCount = Int(record["likeCount"] as? Int64 ?? 0)
    }
    
    func toCKRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let record = if let recordID {
            CKRecord(recordType: "ActivityFeedComments", recordID: recordID)
        } else {
            CKRecord(recordType: "ActivityFeedComments")
        }
        
        record["activityFeedID"] = activityFeedID
        record["sourceType"] = sourceType
        record["sourceID"] = sourceID
        record["userID"] = userID
        record["activityOwnerID"] = activityOwnerID
        record["content"] = content
        
        
        
        if let parentCommentID {
            record["parentCommentID"] = parentCommentID
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
