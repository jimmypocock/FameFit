//
//  ActivityFeedCommentsService.swift
//  FameFit
//
//  Service for managing comments on any activity feed item
//

import CloudKit
import Combine
import Foundation

// MARK: - Protocol

protocol ActivityFeedCommentsServicing {
    // Fetch comments for any activity
    func fetchComments(for activityFeedId: String, limit: Int) async throws -> [ActivityFeedCommentWithUser]
    func fetchCommentsBySource(sourceType: String, sourceRecordId: String, limit: Int) async throws -> [ActivityFeedCommentWithUser]
    
    // Post comment
    func postComment(
        activityFeedId: String,
        sourceType: String,
        sourceRecordId: String,
        activityOwnerId: String,
        content: String,
        parentCommentId: String?
    ) async throws -> ActivityFeedComment
    
    // Update/Delete
    func updateComment(commentId: String, newContent: String) async throws -> ActivityFeedComment
    func deleteComment(commentId: String) async throws
    
    // Interactions
    func likeComment(commentId: String) async throws -> Int
    func unlikeComment(commentId: String) async throws -> Int
    
    // Count
    func fetchCommentCount(for activityFeedId: String) async throws -> Int
    func fetchCommentCountBySource(sourceType: String, sourceRecordId: String) async throws -> Int
}

// MARK: - Service Implementation

final class ActivityFeedCommentsService: ActivityFeedCommentsServicing {
    // MARK: - Properties
    
    private let publicDatabase: CKDatabase
    private let cloudKitManager: any CloudKitManaging
    private let userProfileService: any UserProfileServicing
    private let notificationManager: any NotificationManaging
    private let rateLimiter: any RateLimitingServicing
    
    // Content moderation word list (basic implementation)
    private let inappropriateWords = Set<String>([
        // Add inappropriate words here
        // This is a simplified version - in production, use a proper content moderation service
    ])
    
    // MARK: - Initialization
    
    init(
        cloudKitManager: any CloudKitManaging,
        userProfileService: any UserProfileServicing,
        notificationManager: any NotificationManaging,
        rateLimiter: any RateLimitingServicing
    ) {
        self.cloudKitManager = cloudKitManager
        self.userProfileService = userProfileService
        self.notificationManager = notificationManager
        self.rateLimiter = rateLimiter
        publicDatabase = CKContainer.default().publicCloudDatabase
    }
    
    // MARK: - Fetch Comments
    
    func fetchComments(for activityFeedId: String, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        let predicate = NSPredicate(format: "activityFeedId == %@", activityFeedId)
        return try await fetchCommentsWithPredicate(predicate, limit: limit)
    }
    
    func fetchCommentsBySource(sourceType: String, sourceRecordId: String, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        let predicate = NSPredicate(
            format: "sourceType == %@ AND sourceRecordId == %@",
            sourceType, sourceRecordId
        )
        return try await fetchCommentsWithPredicate(predicate, limit: limit)
    }
    
    private func fetchCommentsWithPredicate(_ predicate: NSPredicate, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        let query = CKQuery(recordType: "ActivityFeedComments", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]
        
        // TODO: Implement actual CloudKit query when available
        // For now, return empty array
        return []
    }
    
    // MARK: - Post Comment
    
    func postComment(
        activityFeedId: String,
        sourceType: String,
        sourceRecordId: String,
        activityOwnerId: String,
        content: String,
        parentCommentId: String?
    ) async throws -> ActivityFeedComment {
        // Validate content
        guard ActivityFeedComment.isValidComment(content) else {
            throw ActivityFeedCommentError.invalidContent
        }
        
        // Rate limiting check
        _ = try await rateLimiter.checkLimit(for: .comment, userId: cloudKitManager.currentUserID ?? "")
        
        // Content moderation
        if containsInappropriateContent(content) {
            throw ActivityFeedCommentError.inappropriateContent
        }
        
        // Create comment
        let comment = ActivityFeedComment(
            id: UUID().uuidString,
            activityFeedId: activityFeedId,
            sourceType: sourceType,
            sourceRecordId: sourceRecordId,
            userId: cloudKitManager.currentUserID ?? "",
            activityOwnerId: activityOwnerId,
            content: content,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            parentCommentId: parentCommentId,
            isEdited: false,
            likeCount: 0
        )
        
        // Save to CloudKit
        _ = comment.toCKRecord()
        // TODO: Implement actual save when CloudKit is available
        
        // Send notification if not commenting on own activity
        if activityOwnerId != cloudKitManager.currentUserID {
            Task {
                await sendCommentFameFitNotification(
                    to: activityOwnerId,
                    sourceType: sourceType,
                    sourceRecordId: sourceRecordId
                )
            }
        }
        
        return comment
    }
    
    // MARK: - Update/Delete
    
    func updateComment(commentId: String, newContent: String) async throws -> ActivityFeedComment {
        // Validate content
        guard ActivityFeedComment.isValidComment(newContent) else {
            throw ActivityFeedCommentError.invalidContent
        }
        
        // Content moderation
        if containsInappropriateContent(newContent) {
            throw ActivityFeedCommentError.inappropriateContent
        }
        
        // TODO: Implement actual update when CloudKit is available
        throw ActivityFeedCommentError.notImplemented
    }
    
    func deleteComment(commentId: String) async throws {
        // TODO: Implement actual delete when CloudKit is available
        throw ActivityFeedCommentError.notImplemented
    }
    
    // MARK: - Interactions
    
    func likeComment(commentId: String) async throws -> Int {
        // TODO: Implement when CloudKit is available
        throw ActivityFeedCommentError.notImplemented
    }
    
    func unlikeComment(commentId: String) async throws -> Int {
        // TODO: Implement when CloudKit is available
        throw ActivityFeedCommentError.notImplemented
    }
    
    // MARK: - Count
    
    func fetchCommentCount(for activityFeedId: String) async throws -> Int {
        // TODO: Implement when CloudKit is available
        return 0
    }
    
    func fetchCommentCountBySource(sourceType: String, sourceRecordId: String) async throws -> Int {
        // TODO: Implement when CloudKit is available
        return 0
    }
    
    // MARK: - Private Helpers
    
    private func containsInappropriateContent(_ content: String) -> Bool {
        let lowercased = content.lowercased()
        let words = lowercased.components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            if inappropriateWords.contains(word) {
                return true
            }
        }
        
        return false
    }
    
    private func sendCommentFameFitNotification(to userId: String, sourceType: String, sourceRecordId: String) async {
        // Get the commenter's profile
        guard let currentUserId = cloudKitManager.currentUserID,
              let commenterProfile = try? await userProfileService.fetchProfile(userId: currentUserId) else {
            return
        }
        
        // For now, we use the workout comment notification for all activity types
        // In the future, we might want to add more specific notification types
        await notificationManager.notifyWorkoutComment(
            from: commenterProfile,
            comment: "commented on your \(sourceType)",
            for: sourceRecordId
        )
    }
}

// MARK: - Errors

enum ActivityFeedCommentError: LocalizedError {
    case invalidContent
    case inappropriateContent
    case unauthorized
    case notFound
    case notImplemented
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidContent:
            "Comment must be between 1 and 500 characters"
        case .inappropriateContent:
            "Comment contains inappropriate content"
        case .unauthorized:
            "You don't have permission to perform this action"
        case .notFound:
            "Comment not found"
        case .rateLimitExceeded:
            "You're commenting too quickly. Please wait a moment."
        case .notImplemented:
            "This feature is not yet implemented"
        }
    }
}