//
//  WorkoutCommentsService.swift
//  FameFit
//
//  Service for managing comments on workout activities
//

import CloudKit
import Combine
import Foundation

// MARK: - Protocol

protocol WorkoutCommentsServicing {
    func fetchComments(for workoutId: String, limit: Int) async throws -> [CommentWithUser]
    func postComment(workoutId: String, workoutOwnerId: String, content: String, parentCommentId: String?) async throws
        -> WorkoutComment
    func updateComment(commentId: String, newContent: String) async throws -> WorkoutComment
    func deleteComment(commentId: String) async throws
    func likeComment(commentId: String) async throws -> Int
    func unlikeComment(commentId: String) async throws -> Int
    func fetchCommentCount(for workoutId: String) async throws -> Int
}

// MARK: - Service Implementation

final class WorkoutCommentsService: WorkoutCommentsServicing {
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

    // MARK: - Public Methods

    func fetchComments(for workoutId: String, limit: Int = 50) async throws -> [CommentWithUser] {
        // Query comments for the workout
        let predicate = NSPredicate(format: "workoutId == %@", workoutId)
        let query = CKQuery(recordType: "WorkoutComments", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]

        do {
            let results = try await publicDatabase.records(matching: query, resultsLimit: limit)

            // Convert to WorkoutComment objects
            let comments = results.matchResults.compactMap { _, result in
                try? result.get()
            }.compactMap { WorkoutComment(from: $0) }

            // Fetch user profiles for all comments
            let userIds = Array(Set(comments.map(\.userId)))
            var userProfiles: [String: UserProfile] = [:]

            // Batch fetch user profiles
            await withTaskGroup(of: (String, UserProfile?).self) { group in
                for userId in userIds {
                    group.addTask { [weak self] in
                        let profile = try? await self?.userProfileService.fetchProfile(userId: userId)
                        return (userId, profile)
                    }
                }

                for await (userId, profile) in group {
                    if let profile {
                        userProfiles[userId] = profile
                    }
                }
            }

            // Combine comments with user profiles
            let commentsWithUsers = comments.compactMap { comment -> CommentWithUser? in
                guard let user = userProfiles[comment.userId] else { return nil }
                return CommentWithUser(comment: comment, user: user)
            }

            // Organize into threads if needed
            return organizeCommentThreads(commentsWithUsers)
        } catch {
            throw error
        }
    }

    func postComment(
        workoutId: String,
        workoutOwnerId: String,
        content: String,
        parentCommentId: String? = nil
    ) async throws -> WorkoutComment {
        // Validate content
        guard WorkoutComment.isValidComment(content) else {
            throw CommentError.invalidContent
        }

        // Check rate limiting
        guard let userId = cloudKitManager.currentUserID else {
            throw CommentError.notAuthenticated
        }

        do {
            _ = try await rateLimiter.checkLimit(for: .comment, userId: userId)
        } catch {
            throw CommentError.rateLimited
        }

        // Content moderation
        try moderateContent(content)

        // Create comment
        let comment = WorkoutComment(
            id: UUID().uuidString,
            workoutId: workoutId,
            userId: userId,
            workoutOwnerId: workoutOwnerId,
            content: content,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            parentCommentId: parentCommentId,
            isEdited: false,
            likeCount: 0
        )

        // Save to CloudKit
        let record = comment.toCKRecord()

        do {
            let savedRecord = try await publicDatabase.save(record)
            guard let savedComment = WorkoutComment(from: savedRecord) else {
                throw CommentError.saveFailed
            }

            // Record the action for rate limiting
            await rateLimiter.recordAction(.comment, userId: userId)

            // Send notification to workout owner if it's not their own comment
            if userId != workoutOwnerId {
                await sendCommentNotification(comment: savedComment, workoutOwnerId: workoutOwnerId)
            }

            // If it's a reply, notify the parent comment author
            if let parentCommentId {
                await sendReplyNotification(comment: savedComment, parentCommentId: parentCommentId)
            }

            return savedComment
        } catch {
            throw CommentError.saveFailed
        }
    }

    func updateComment(commentId: String, newContent: String) async throws -> WorkoutComment {
        // Validate content
        guard WorkoutComment.isValidComment(newContent) else {
            throw CommentError.invalidContent
        }

        guard let userId = cloudKitManager.currentUserID else {
            throw CommentError.notAuthenticated
        }

        // Content moderation
        try moderateContent(newContent)

        // Fetch existing comment
        let recordID = CKRecord.ID(recordName: commentId)

        do {
            let record = try await publicDatabase.record(for: recordID)

            // Verify ownership
            guard record["userId"] as? String == userId else {
                throw CommentError.notAuthorized
            }

            // Update content
            record["content"] = newContent
            record["modifiedTimestamp"] = Date()
            record["isEdited"] = Int64(1)

            let savedRecord = try await publicDatabase.save(record)
            guard let updatedComment = WorkoutComment(from: savedRecord) else {
                throw CommentError.saveFailed
            }

            return updatedComment
        } catch {
            throw CommentError.updateFailed
        }
    }

    func deleteComment(commentId: String) async throws {
        guard let userId = cloudKitManager.currentUserID else {
            throw CommentError.notAuthenticated
        }

        let recordID = CKRecord.ID(recordName: commentId)

        do {
            // Fetch to verify ownership
            let record = try await publicDatabase.record(for: recordID)

            // Verify ownership
            guard record["userId"] as? String == userId else {
                throw CommentError.notAuthorized
            }

            // Delete the comment
            _ = try await publicDatabase.deleteRecord(withID: recordID)

            // TODO: Consider soft delete to preserve thread integrity

        } catch {
            throw CommentError.deleteFailed
        }
    }

    func likeComment(commentId _: String) async throws -> Int {
        // TODO: Implement comment likes with a separate CommentLikes table
        // For now, return mock data
        1
    }

    func unlikeComment(commentId _: String) async throws -> Int {
        // TODO: Implement comment unlikes
        // For now, return mock data
        0
    }

    func fetchCommentCount(for workoutId: String) async throws -> Int {
        let predicate = NSPredicate(format: "workoutId == %@", workoutId)
        let query = CKQuery(recordType: "WorkoutComments", predicate: predicate)

        do {
            // Use a smaller result limit for counting
            let results = try await publicDatabase.records(matching: query, resultsLimit: 1_000)
            return results.matchResults.count
        } catch {
            throw CommentError.fetchFailed
        }
    }

    // MARK: - Private Methods

    private func organizeCommentThreads(_ comments: [CommentWithUser]) -> [CommentWithUser] {
        // Separate parent comments and replies
        let parentComments = comments.filter { $0.comment.parentCommentId == nil }
        let replies = comments.filter { $0.comment.parentCommentId != nil }

        // Group replies by parent ID
        let replyGroups = Dictionary(grouping: replies) { $0.comment.parentCommentId ?? "" }

        // Build final list with threads
        var organizedComments: [CommentWithUser] = []

        for parent in parentComments {
            organizedComments.append(parent)

            // Add replies right after parent
            if let parentReplies = replyGroups[parent.comment.id] {
                organizedComments.append(contentsOf: parentReplies.sorted {
                    $0.comment.createdTimestamp < $1.comment.createdTimestamp
                })
            }
        }

        return organizedComments
    }

    private func moderateContent(_ content: String) throws {
        let lowercaseContent = content.lowercased()

        for word in inappropriateWords {
            if lowercaseContent.contains(word) {
                throw CommentError.contentModerated
            }
        }
    }

    private func sendCommentNotification(comment: WorkoutComment, workoutOwnerId _: String) async {
        // Fetch commenter's profile
        guard let commenterProfile = try? await userProfileService.fetchProfile(userId: comment.userId) else {
            return
        }

        _ = NotificationItem(
            type: .workoutComment,
            title: "New Comment on Your Workout",
            body: "\(commenterProfile.displayName) commented: \(String(comment.content.prefix(50)))...",
            metadata: .social(SocialNotificationMetadata(
                userID: comment.userId,
                username: commenterProfile.username,
                displayName: commenterProfile.displayName,
                profileImageUrl: commenterProfile.profileImageURL,
                relationshipType: "comment",
                actionCount: nil
            )),
            actions: [.view, .reply]
        )

        await notificationManager.notifyWorkoutComment(
            from: commenterProfile,
            comment: comment.content,
            for: comment.workoutId
        )
    }

    private func sendReplyNotification(comment: WorkoutComment, parentCommentId: String) async {
        // Fetch parent comment to get author
        let recordID = CKRecord.ID(recordName: parentCommentId)

        do {
            let parentRecord = try await publicDatabase.record(for: recordID)
            guard let parentUserId = parentRecord["userId"] as? String,
                  parentUserId != comment.userId
            else { // Don't notify self-replies
                return
            }

            // Fetch replier's profile
            guard let replierProfile = try? await userProfileService.fetchProfile(userId: comment.userId) else {
                return
            }

            _ = NotificationItem(
                type: .workoutComment,
                title: "New Reply to Your Comment",
                body: "\(replierProfile.displayName) replied: \(String(comment.content.prefix(50)))...",
                metadata: .social(SocialNotificationMetadata(
                    userID: comment.userId,
                    username: replierProfile.username,
                    displayName: replierProfile.displayName,
                    profileImageUrl: replierProfile.profileImageURL,
                    relationshipType: "reply",
                    actionCount: nil
                )),
                actions: [.view, .reply]
            )

            await notificationManager.notifyWorkoutComment(
                from: replierProfile,
                comment: comment.content,
                for: comment.workoutId
            )
        } catch {
            // Silently fail notification send
        }
    }
}

// MARK: - Comment Errors

enum CommentError: LocalizedError {
    case invalidContent
    case notAuthenticated
    case notAuthorized
    case rateLimited
    case contentModerated
    case saveFailed
    case updateFailed
    case deleteFailed
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .invalidContent:
            "Comment must be between 1 and 500 characters"
        case .notAuthenticated:
            "You must be signed in to comment"
        case .notAuthorized:
            "You can only edit or delete your own comments"
        case .rateLimited:
            "You're commenting too quickly. Please wait a moment."
        case .contentModerated:
            "Your comment contains inappropriate content"
        case .saveFailed:
            "Failed to save comment. Please try again."
        case .updateFailed:
            "Failed to update comment. Please try again."
        case .deleteFailed:
            "Failed to delete comment. Please try again."
        case .fetchFailed:
            "Failed to load comments. Please try again."
        }
    }
}
