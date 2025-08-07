//
//  ActivityFeedCommentsAdapter.swift
//  FameFit
//
//  Adapter to make ActivityFeedCommentsService conform to the unified CommentServicing protocol
//

import Foundation

// MARK: - Make existing types conform to protocols

extension ActivityFeedComment: Comment {}

extension ActivityFeedCommentWithUser: ActivityFeedCommentWithUserProtocol {
    typealias CommentType = ActivityFeedComment
}

// MARK: - Adapter for ActivityFeedCommentsService

class ActivityFeedCommentsAdapter: CommentServicing {
    typealias CommentType = ActivityFeedComment
    typealias ActivityFeedCommentWithUserType = ActivityFeedCommentWithUser
    
    private let activityCommentsService: ActivityFeedCommentsServicing
    
    init(activityCommentsService: ActivityFeedCommentsServicing) {
        self.activityCommentsService = activityCommentsService
    }
    
    func fetchComments(for resourceId: String, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        // For activity comments, resourceId could be either activityFeedID or sourceRecordId
        // Default to using it as activityFeedID
        try await activityCommentsService.fetchComments(for: resourceId, limit: limit)
    }
    
    func postComment(
        resourceId: String,
        resourceOwnerId: String,
        content: String,
        parentCommentId: String?,
        metadata: CommentMetadata
    ) async throws -> ActivityFeedComment {
        try await activityCommentsService.postComment(
            activityFeedID: resourceId,
            sourceType: metadata.resourceType,
            sourceID: metadata.sourceRecordId ?? resourceId,
            activityOwnerID: resourceOwnerId,
            content: content,
            parentCommentID: parentCommentId
        )
    }
    
    func updateComment(commentId: String, newContent: String) async throws -> ActivityFeedComment {
        try await activityCommentsService.updateComment(
            commentId: commentId,
            newContent: newContent
        )
    }
    
    func deleteComment(commentId: String) async throws {
        try await activityCommentsService.deleteComment(commentId: commentId)
    }
    
    func likeComment(commentId: String) async throws -> Int {
        try await activityCommentsService.likeComment(commentId: commentId)
    }
    
    func unlikeComment(commentId: String) async throws -> Int {
        try await activityCommentsService.unlikeComment(commentId: commentId)
    }
    
    func fetchCommentCount(for resourceId: String) async throws -> Int {
        try await activityCommentsService.fetchCommentCount(for: resourceId)
    }
    
    // Additional method to fetch by source when needed
    func fetchCommentsBySource(sourceType: String, sourceRecordId: String, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        try await activityCommentsService.fetchCommentsBySource(
            sourceType: sourceType,
            sourceID: sourceRecordId,
            limit: limit
        )
    }
}