//
//  ActivityCommentsAdapter.swift
//  FameFit
//
//  Adapter to make ActivityCommentsService conform to the unified CommentServicing protocol
//

import Foundation

// MARK: - Make existing types conform to protocols

extension ActivityComment: Comment {}

extension CommentWithUser: CommentWithUserProtocol {
    typealias CommentType = ActivityComment
}

// MARK: - Adapter for ActivityCommentsService

class ActivityCommentsAdapter: CommentServicing {
    typealias CommentType = ActivityComment
    typealias CommentWithUserType = CommentWithUser
    
    private let activityCommentsService: ActivityCommentsServicing
    
    init(activityCommentsService: ActivityCommentsServicing) {
        self.activityCommentsService = activityCommentsService
    }
    
    func fetchComments(for resourceId: String, limit: Int) async throws -> [CommentWithUser] {
        // For activity comments, resourceId could be either activityFeedId or sourceRecordId
        // Default to using it as activityFeedId
        try await activityCommentsService.fetchComments(for: resourceId, limit: limit)
    }
    
    func postComment(
        resourceId: String,
        resourceOwnerId: String,
        content: String,
        parentCommentId: String?,
        metadata: CommentMetadata
    ) async throws -> ActivityComment {
        try await activityCommentsService.postComment(
            activityFeedId: resourceId,
            sourceType: metadata.resourceType,
            sourceRecordId: metadata.sourceRecordId ?? resourceId,
            activityOwnerId: resourceOwnerId,
            content: content,
            parentCommentId: parentCommentId
        )
    }
    
    func updateComment(commentId: String, newContent: String) async throws -> ActivityComment {
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
    func fetchCommentsBySource(sourceType: String, sourceRecordId: String, limit: Int) async throws -> [CommentWithUser] {
        try await activityCommentsService.fetchCommentsBySource(
            sourceType: sourceType,
            sourceRecordId: sourceRecordId,
            limit: limit
        )
    }
}