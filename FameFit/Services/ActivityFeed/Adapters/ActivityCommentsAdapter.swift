//
//  ActivityFeedCommentsAdapter.swift
//  FameFit
//
//  Adapter to make ActivityFeedCommentsService conform to the unified CommentServiceProtocol protocol
//

import Foundation

// MARK: - Make existing types conform to protocols

extension ActivityFeedComment: CommentProtocol {}

extension ActivityFeedCommentWithUser: ActivityFeedCommentWithUserProtocol {
    typealias CommentType = ActivityFeedComment
}

// MARK: - Adapter for ActivityFeedCommentsService

class ActivityFeedCommentsAdapter: CommentServiceProtocol {
    typealias CommentType = ActivityFeedComment
    typealias ActivityFeedCommentWithUserType = ActivityFeedCommentWithUser
    
    private let activityCommentsService: ActivityFeedCommentsProtocol
    
    init(activityCommentsService: ActivityFeedCommentsProtocol) {
        self.activityCommentsService = activityCommentsService
    }
    
    func fetchComments(for resourceID: String, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        // For activity comments, resourceIDcould be either activityFeedID or sourceRecordID
        // Default to using it as activityFeedID
        try await activityCommentsService.fetchComments(for: resourceID, limit: limit)
    }
    
    func postComment(
        resourceID: String,
        resourceOwnerID: String,
        content: String,
        parentCommentID: String?,
        metadata: CommentMetadata
    ) async throws -> ActivityFeedComment {
        try await activityCommentsService.postComment(
            activityFeedID: resourceID,
            sourceType: metadata.resourceType,
            sourceID: metadata.sourceRecordID ?? resourceID,
            activityOwnerID: resourceOwnerID,
            content: content,
            parentCommentID: parentCommentID
        )
    }
    
    func updateComment(commentID: String, newContent: String) async throws -> ActivityFeedComment {
        try await activityCommentsService.updateComment(
            commentID: commentID,
            newContent: newContent
        )
    }
    
    func deleteComment(commentID: String) async throws {
        try await activityCommentsService.deleteComment(commentID: commentID)
    }
    
    func likeComment(commentID: String) async throws -> Int {
        try await activityCommentsService.likeComment(commentID: commentID)
    }
    
    func unlikeComment(commentID: String) async throws -> Int {
        try await activityCommentsService.unlikeComment(commentID: commentID)
    }
    
    func fetchCommentCount(for resourceID: String) async throws -> Int {
        try await activityCommentsService.fetchCommentCount(for: resourceID)
    }
    
    // Additional method to fetch by source when needed
    func fetchCommentsBySource(sourceType: String, sourceRecordID: String, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        try await activityCommentsService.fetchCommentsBySource(
            sourceType: sourceType,
            sourceID: sourceRecordID,
            limit: limit
        )
    }
}
