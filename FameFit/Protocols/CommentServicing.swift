//
//  CommentServicing.swift
//  FameFit
//
//  Unified protocol for all comment services - supports both workout-specific and generic activity comments
//

import Foundation

// MARK: - Base Comment Protocol

protocol Comment {
    var id: String { get }
    var userID: String { get }
    var content: String { get }
    var createdTimestamp: Date { get }
    var modifiedTimestamp: Date { get }
    var parentCommentID: String? { get }
    var isEdited: Bool { get }
    var likeCount: Int { get }
}

// MARK: - Comment with User Protocol

protocol ActivityFeedCommentWithUserProtocol {
    associatedtype CommentType: Comment
    var comment: CommentType { get }
    var user: UserProfile { get }
}

// MARK: - Unified Comment Service Protocol

protocol CommentServicing {
    associatedtype CommentType: Comment
    associatedtype ActivityFeedCommentWithUserType: ActivityFeedCommentWithUserProtocol where ActivityFeedCommentWithUserType.CommentType == CommentType
    
    // Core functionality that all comment services must implement
    func fetchComments(for resourceID: String, limit: Int) async throws -> [ActivityFeedCommentWithUserType]
    func postComment(
        resourceID: String,
        resourceOwnerID: String,
        content: String,
        parentCommentID: String?,
        metadata: CommentMetadata
    ) async throws -> CommentType
    func updateComment(commentID: String, newContent: String) async throws -> CommentType
    func deleteComment(commentID: String) async throws
    func likeComment(commentID: String) async throws -> Int
    func unlikeComment(commentID: String) async throws -> Int
    func fetchCommentCount(for resourceID: String) async throws -> Int
}

// MARK: - Comment Metadata

struct CommentMetadata {
    let resourceType: String // "workout", "achievement", "level_up", etc.
    let sourceRecordID: String? // For dual reference system
    let context: [String: String] // Additional context data
    
    init(resourceType: String, sourceRecordID: String? = nil, context: [String: String] = [:]) {
        self.resourceType = resourceType
        self.sourceRecordID = sourceRecordID
        self.context = context
    }
}

// MARK: - Type Erasure for Protocol

struct AnyActivityFeedCommentWithUser: ActivityFeedCommentWithUserProtocol, Identifiable {
    let comment: AnyComment
    let user: UserProfile
    
    var id: String { comment.id }
    
    init<T: ActivityFeedCommentWithUserProtocol>(_ commentWithUser: T) {
        self.comment = AnyComment(commentWithUser.comment)
        self.user = commentWithUser.user
    }
}

struct AnyComment: Comment {
    let id: String
    let userID: String
    let content: String
    let createdTimestamp: Date
    let modifiedTimestamp: Date
    let parentCommentID: String?
    let isEdited: Bool
    let likeCount: Int
    
    init<T: Comment>(_ comment: T) {
        self.id = comment.id
        self.userID = comment.userID
        self.content = comment.content
        self.createdTimestamp = comment.createdTimestamp
        self.modifiedTimestamp = comment.modifiedTimestamp
        self.parentCommentID = comment.parentCommentID
        self.isEdited = comment.isEdited
        self.likeCount = comment.likeCount
    }
}

// MARK: - Service Type Erasure

class AnyCommentService: CommentServicing {
    typealias CommentType = AnyComment
    typealias ActivityFeedCommentWithUserType = AnyActivityFeedCommentWithUser
    
    private let _fetchComments: (String, Int) async throws -> [AnyActivityFeedCommentWithUser]
    private let _postComment: (String, String, String, String?, CommentMetadata) async throws -> AnyComment
    private let _updateComment: (String, String) async throws -> AnyComment
    private let _deleteComment: (String) async throws -> Void
    private let _likeComment: (String) async throws -> Int
    private let _unlikeComment: (String) async throws -> Int
    private let _fetchCommentCount: (String) async throws -> Int
    
    init<Service: CommentServicing>(_ service: Service) {
        self._fetchComments = { resourceID, limit in
            let comments = try await service.fetchComments(for: resourceID, limit: limit)
            return comments.map { AnyActivityFeedCommentWithUser($0) }
        }
        
        self._postComment = { resourceID, ownerID, content, parentID, metadata in
            let comment = try await service.postComment(
                resourceID: resourceID,
                resourceOwnerID: ownerID,
                content: content,
                parentCommentID: parentID,
                metadata: metadata
            )
            return AnyComment(comment)
        }
        
        self._updateComment = { commentID, newContent in
            let comment = try await service.updateComment(commentID: commentID, newContent: newContent)
            return AnyComment(comment)
        }
        
        self._deleteComment = { commentID in
            try await service.deleteComment(commentID: commentID)
        }
        
        self._likeComment = { commentID in
            try await service.likeComment(commentID: commentID)
        }
        
        self._unlikeComment = { commentID in
            try await service.unlikeComment(commentID: commentID)
        }
        
        self._fetchCommentCount = { resourceID in
            try await service.fetchCommentCount(for: resourceID)
        }
    }
    
    func fetchComments(for resourceID: String, limit: Int) async throws -> [AnyActivityFeedCommentWithUser] {
        try await _fetchComments(resourceID, limit)
    }
    
    func postComment(
        resourceID: String,
        resourceOwnerID: String,
        content: String,
        parentCommentID: String?,
        metadata: CommentMetadata
    ) async throws -> AnyComment {
        try await _postComment(resourceID, resourceOwnerID, content, parentCommentID, metadata)
    }
    
    func updateComment(commentID: String, newContent: String) async throws -> AnyComment {
        try await _updateComment(commentID, newContent)
    }
    
    func deleteComment(commentID: String) async throws {
        try await _deleteComment(commentID)
    }
    
    func likeComment(commentID: String) async throws -> Int {
        try await _likeComment(commentID)
    }
    
    func unlikeComment(commentID: String) async throws -> Int {
        try await _unlikeComment(commentID)
    }
    
    func fetchCommentCount(for resourceID: String) async throws -> Int {
        try await _fetchCommentCount(resourceID)
    }
}
