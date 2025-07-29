//
//  MockWorkoutCommentsService.swift
//  FameFitTests
//
//  Mock implementation of WorkoutCommentsServicing for testing and previews
//

@testable import FameFit
import Foundation

final class MockWorkoutCommentsService: WorkoutCommentsServicing {
    var comments: [CommentWithUser] = []
    var shouldFail = false
    var commentCount = 0
    var currentUserId: String = "current-user"
    var rateLimiter: (any RateLimitingServicing)?
    var notificationManager: (any NotificationManaging)?

    func fetchComments(for _: String, limit: Int) async throws -> [CommentWithUser] {
        if shouldFail {
            throw CommentError.fetchFailed
        }

        // Return mock comments if empty
        if comments.isEmpty {
            createMockComments()
        }

        return Array(comments.prefix(limit))
    }

    func postComment(
        workoutId: String,
        workoutOwnerId: String,
        content: String,
        parentCommentId: String? = nil
    ) async throws -> WorkoutComment {
        // Validate content
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContent.isEmpty {
            throw CommentError.invalidContent
        }

        if trimmedContent.count > 500 {
            throw CommentError.invalidContent
        }

        // Check rate limiting
        if let rateLimiter {
            do {
                _ = try await rateLimiter.checkLimit(for: .comment, userId: currentUserId)
                await rateLimiter.recordAction(.comment, userId: currentUserId)
            } catch {
                throw CommentError.rateLimited
            }
        }

        // Check authentication
        if currentUserId.isEmpty {
            throw CommentError.notAuthenticated
        }

        if shouldFail {
            throw CommentError.saveFailed
        }

        let newComment = WorkoutComment(
            id: UUID().uuidString,
            workoutId: workoutId,
            userId: currentUserId,
            workoutOwnerId: workoutOwnerId,
            content: trimmedContent,
            createdAt: Date(),
            updatedAt: Date(),
            parentCommentId: parentCommentId,
            isEdited: false,
            likeCount: 0
        )

        let user = UserProfile(
            id: currentUserId,
            userID: currentUserId,
            username: "currentuser",
            displayName: "Current User",
            bio: "Mock user",
            workoutCount: 35,
            totalXP: 1_000,
            joinedDate: Date().addingTimeInterval(-86_400 * 120),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )

        comments.append(CommentWithUser(comment: newComment, user: user))
        commentCount += 1

        // Send notification
        if let notificationManager {
            let user = UserProfile(
                id: currentUserId,
                userID: currentUserId,
                username: "currentuser",
                displayName: "Current User",
                bio: "Mock user",
                workoutCount: 35,
                totalXP: 1_000,
                joinedDate: Date().addingTimeInterval(-86_400 * 120),
                lastUpdated: Date(),
                isVerified: false,
                privacyLevel: .publicProfile,
                profileImageURL: nil
            )
            await notificationManager.notifyWorkoutComment(
                from: user,
                comment: trimmedContent,
                for: workoutId
            )
        }

        return newComment
    }

    func updateComment(commentId: String, newContent: String) async throws -> WorkoutComment {
        guard let index = comments.firstIndex(where: { $0.comment.id == commentId }) else {
            throw CommentError.updateFailed
        }

        // Check ownership
        let comment = comments[index].comment
        if comment.userId != currentUserId {
            throw CommentError.notAuthorized
        }

        if shouldFail {
            throw CommentError.updateFailed
        }

        var updatedComment = comments[index].comment
        updatedComment.content = newContent
        updatedComment.updatedAt = Date()
        updatedComment.isEdited = true

        comments[index] = CommentWithUser(comment: updatedComment, user: comments[index].user)

        return updatedComment
    }

    func deleteComment(commentId: String) async throws {
        guard let index = comments.firstIndex(where: { $0.comment.id == commentId }) else {
            throw CommentError.deleteFailed
        }

        let comment = comments[index].comment
        // Check if user owns the comment or the workout
        if comment.userId != currentUserId, comment.workoutOwnerId != currentUserId {
            throw CommentError.notAuthorized
        }

        if shouldFail {
            throw CommentError.deleteFailed
        }

        comments.remove(at: index)
        commentCount -= 1
    }

    func likeComment(commentId: String) async throws -> Int {
        if shouldFail {
            throw CommentError.fetchFailed
        }

        guard let index = comments.firstIndex(where: { $0.comment.id == commentId }) else {
            return 1 // Default for test expectations
        }

        var updatedComment = comments[index].comment
        updatedComment.likeCount += 1
        comments[index] = CommentWithUser(comment: updatedComment, user: comments[index].user)
        return updatedComment.likeCount
    }

    func unlikeComment(commentId: String) async throws -> Int {
        if shouldFail {
            throw CommentError.fetchFailed
        }

        if let index = comments.firstIndex(where: { $0.comment.id == commentId }) {
            var updatedComment = comments[index].comment
            updatedComment.likeCount = max(0, updatedComment.likeCount - 1)
            comments[index] = CommentWithUser(comment: updatedComment, user: comments[index].user)
            return updatedComment.likeCount
        }

        return 0
    }

    func fetchCommentCount(for _: String) async throws -> Int {
        if shouldFail {
            throw CommentError.fetchFailed
        }

        return commentCount > 0 ? commentCount : comments.count
    }

    // MARK: - Helper Methods

    private func createMockComments() {
        let mockUsers = [
            UserProfile(
                id: "user1",
                userID: "user1",
                username: "fitnesscoach",
                displayName: "Sarah Wilson",
                bio: "Certified trainer",
                workoutCount: 245,
                totalXP: 8_500,
                joinedDate: Date().addingTimeInterval(-86_400 * 365),
                lastUpdated: Date(),
                isVerified: true,
                privacyLevel: .publicProfile,
                profileImageURL: nil
            ),
            UserProfile(
                id: "user2",
                userID: "user2",
                username: "runner_mike",
                displayName: "Mike Johnson",
                bio: "Marathon runner",
                workoutCount: 89,
                totalXP: 3_200,
                joinedDate: Date().addingTimeInterval(-86_400 * 180),
                lastUpdated: Date(),
                isVerified: false,
                privacyLevel: .publicProfile,
                profileImageURL: nil
            ),
            UserProfile(
                id: "user3",
                userID: "user3",
                username: "yoga_guru",
                displayName: "Emma Chen",
                bio: "Yoga instructor",
                workoutCount: 156,
                totalXP: 6_700,
                joinedDate: Date().addingTimeInterval(-86_400 * 300),
                lastUpdated: Date(),
                isVerified: true,
                privacyLevel: .publicProfile,
                profileImageURL: nil
            )
        ]

        let mockCommentsData = [
            ("Great workout! Your form looked amazing throughout. Keep it up! 💪", 0, 3, false),
            ("Thanks for the inspiration! Going to try this routine tomorrow.", 1, 1, false),
            ("That heart rate zone work is paying off! Your endurance has improved so much.", 2, 2, false),
            ("Awesome job! How long have you been training at this intensity?", 0, 0, false),
            ("Thanks Sarah! I've been following your program for about 3 months now.", 1, 1, true) // Reply to previous
        ]

        // Track parent comment for replies

        for (index, (content, userIndex, likes, isReply)) in mockCommentsData.enumerated() {
            let commentId = "comment_\(index + 1)"
            let user = mockUsers[userIndex]

            // Set parent for replies
            let parentId = isReply ? "comment_4" : nil

            let comment = WorkoutComment(
                id: commentId,
                workoutId: "sample-workout",
                userId: user.id,
                workoutOwnerId: "owner123",
                content: content,
                createdAt: Date().addingTimeInterval(-Double(3_600 * (5 - index))), // Spread over 5 hours
                updatedAt: Date().addingTimeInterval(-Double(3_600 * (5 - index))),
                parentCommentId: parentId,
                isEdited: index == 2, // Make one comment edited
                likeCount: likes
            )

            comments.append(CommentWithUser(comment: comment, user: user))
        }

        commentCount = comments.count
    }
}
