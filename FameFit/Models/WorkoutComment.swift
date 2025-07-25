//
//  WorkoutComment.swift
//  FameFit
//
//  Model for comments on workout activities
//

import CloudKit
import Foundation

struct WorkoutComment: Identifiable, Codable, Equatable {
    let id: String // CKRecord.ID as String
    let workoutId: String // Reference to workout activity
    let userId: String // User who posted the comment
    let workoutOwnerId: String // Owner of the workout (for notifications)
    var content: String
    let createdAt: Date
    var updatedAt: Date

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

extension WorkoutComment {
    init?(from record: CKRecord) {
        guard let workoutId = record["workoutId"] as? String,
              let userId = record["userId"] as? String,
              let workoutOwnerId = record["workoutOwnerId"] as? String,
              let content = record["content"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date
        else {
            return nil
        }

        id = record.recordID.recordName
        self.workoutId = workoutId
        self.userId = userId
        self.workoutOwnerId = workoutOwnerId
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        parentCommentId = record["parentCommentId"] as? String
        isEdited = (record["isEdited"] as? Int64) == 1
        likeCount = Int(record["likeCount"] as? Int64 ?? 0)
    }

    func toCKRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let record = if let recordID {
            CKRecord(recordType: "WorkoutComments", recordID: recordID)
        } else {
            CKRecord(recordType: "WorkoutComments")
        }

        record["workoutId"] = workoutId
        record["userId"] = userId
        record["workoutOwnerId"] = workoutOwnerId
        record["content"] = content
        record["createdAt"] = createdAt
        record["updatedAt"] = updatedAt

        if let parentCommentId {
            record["parentCommentId"] = parentCommentId
        }

        record["isEdited"] = isEdited ? Int64(1) : Int64(0)
        record["likeCount"] = Int64(likeCount)

        return record
    }
}

// MARK: - Comment with User Info

struct CommentWithUser: Identifiable {
    var comment: WorkoutComment
    let user: UserProfile

    var id: String { comment.id }
}

// MARK: - Comment Thread

struct CommentThread {
    let parentComment: CommentWithUser
    var replies: [CommentWithUser]

    var totalComments: Int {
        1 + replies.count
    }
}
