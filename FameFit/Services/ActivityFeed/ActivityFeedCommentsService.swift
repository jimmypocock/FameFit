//
//  ActivityFeedCommentsService.swift
//  FameFit
//
//  Service for managing comments on any activity feed item
//

import CloudKit
import Combine
import Foundation


// MARK: - Service Implementation

final class ActivityFeedCommentsService: ActivityFeedCommentsProtocol {
    // MARK: - Properties
    
    private let publicDatabase: CKDatabase
    private let cloudKitManager: any CloudKitProtocol
    private let userProfileService: any UserProfileProtocol
    private let notificationManager: any NotificationProtocol
    private let rateLimiter: any RateLimitingProtocol
    
    // Content moderation word list (basic implementation)
    private let inappropriateWords = Set<String>([
        // Add inappropriate words here
        // This is a simplified version - in production, use a proper content moderation service
    ])
    
    // MARK: - Initialization
    
    init(
        cloudKitManager: any CloudKitProtocol,
        userProfileService: any UserProfileProtocol,
        notificationManager: any NotificationProtocol,
        rateLimiter: any RateLimitingProtocol
    ) {
        self.cloudKitManager = cloudKitManager
        self.userProfileService = userProfileService
        self.notificationManager = notificationManager
        self.rateLimiter = rateLimiter
        publicDatabase = CKContainer.default().publicCloudDatabase
    }
    
    // MARK: - Fetch Comments
    
    func fetchComments(for activityFeedID: String, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        let predicate = NSPredicate(format: "activityFeedID == %@", activityFeedID)
        return try await fetchCommentsWithPredicate(predicate, limit: limit)
    }
    
    func fetchCommentsBySource(sourceType: String, sourceID: String, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        let predicate = NSPredicate(
            format: "sourceType == %@ AND sourceID == %@",
            sourceType, sourceID
        )
        return try await fetchCommentsWithPredicate(predicate, limit: limit)
    }
    
    private func fetchCommentsWithPredicate(_ predicate: NSPredicate, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        let query = CKQuery(recordType: "ActivityFeedComments", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        // TODO: Implement actual CloudKit query when available
        // For now, return empty array
        return []
    }
    
    // MARK: - Post Comment
    
    func postComment(
        activityFeedID: String,
        sourceType: String,
        sourceID: String,
        activityOwnerID: String,
        content: String,
        parentCommentID: String?
    ) async throws -> ActivityFeedComment {
        // Validate content
        guard ActivityFeedComment.isValidComment(content) else {
            throw ActivityFeedCommentError.invalidContent
        }
        
        // Rate limiting check
        _ = try await rateLimiter.checkLimit(for: .comment, userID: cloudKitManager.currentUserID ?? "")
        
        // Content moderation
        if containsInappropriateContent(content) {
            throw ActivityFeedCommentError.inappropriateContent
        }
        
        // Create comment
        let comment = ActivityFeedComment(
            id: UUID().uuidString,
            activityFeedID: activityFeedID,
            sourceType: sourceType,
            sourceID: sourceID,
            userID: cloudKitManager.currentUserID ?? "",
            activityOwnerID: activityOwnerID,
            content: content,
            creationDate: Date(),
            modificationDate: Date(),
            parentCommentID: parentCommentID,
            isEdited: false,
            likeCount: 0
        )
        
        // Save to CloudKit
        _ = comment.toCKRecord()
        // TODO: Implement actual save when CloudKit is available
        
        // Send notification if not commenting on own activity
        if activityOwnerID != cloudKitManager.currentUserID {
            Task {
                await sendCommentFameFitNotification(
                    to: activityOwnerID,
                    sourceType: sourceType,
                    sourceID: sourceID
                )
            }
        }
        
        return comment
    }
    
    // MARK: - Update/Delete
    
    func updateComment(commentID: String, newContent: String) async throws -> ActivityFeedComment {
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
    
    func deleteComment(commentID: String) async throws {
        // TODO: Implement actual delete when CloudKit is available
        throw ActivityFeedCommentError.notImplemented
    }
    
    // MARK: - Interactions
    
    func likeComment(commentID: String) async throws -> Int {
        // TODO: Implement when CloudKit is available
        throw ActivityFeedCommentError.notImplemented
    }
    
    func unlikeComment(commentID: String) async throws -> Int {
        // TODO: Implement when CloudKit is available
        throw ActivityFeedCommentError.notImplemented
    }
    
    // MARK: - Count
    
    func fetchCommentCount(for activityFeedID: String) async throws -> Int {
        // TODO: Implement when CloudKit is available
        return 0
    }
    
    func fetchCommentCountBySource(sourceType: String, sourceID: String) async throws -> Int {
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
    
    private func sendCommentFameFitNotification(to userID: String, sourceType: String, sourceID: String) async {
        // Get the commenter's profile
        guard let currentUserID = cloudKitManager.currentUserID,
              let commenterProfile = try? await userProfileService.fetchProfile(userID: currentUserID) else {
            return
        }
        
        // For now, we use the workout comment notification for all activity types
        // In the future, we might want to add more specific notification types
        await notificationManager.notifyWorkoutComment(
            from: commenterProfile,
            comment: "commented on your \(sourceType)",
            for: sourceID
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
