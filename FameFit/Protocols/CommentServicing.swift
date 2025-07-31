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
    var userId: String { get }
    var content: String { get }
    var createdTimestamp: Date { get }
    var modifiedTimestamp: Date { get }
    var parentCommentId: String? { get }
    var isEdited: Bool { get }
    var likeCount: Int { get }
}

// MARK: - Comment with User Protocol

protocol CommentWithUserProtocol {
    associatedtype CommentType: Comment
    var comment: CommentType { get }
    var user: UserProfile { get }
}

// MARK: - Unified Comment Service Protocol

protocol CommentServicing {
    associatedtype CommentType: Comment
    associatedtype CommentWithUserType: CommentWithUserProtocol where CommentWithUserType.CommentType == CommentType
    
    // Core functionality that all comment services must implement
    func fetchComments(for resourceId: String, limit: Int) async throws -> [CommentWithUserType]
    func postComment(
        resourceId: String,
        resourceOwnerId: String,
        content: String,
        parentCommentId: String?,
        metadata: CommentMetadata
    ) async throws -> CommentType
    func updateComment(commentId: String, newContent: String) async throws -> CommentType
    func deleteComment(commentId: String) async throws
    func likeComment(commentId: String) async throws -> Int
    func unlikeComment(commentId: String) async throws -> Int
    func fetchCommentCount(for resourceId: String) async throws -> Int
}

// MARK: - Comment Metadata

struct CommentMetadata {
    let resourceType: String // "workout", "achievement", "level_up", etc.
    let sourceRecordId: String? // For dual reference system
    let context: [String: String] // Additional context data
    
    init(resourceType: String, sourceRecordId: String? = nil, context: [String: String] = [:]) {
        self.resourceType = resourceType
        self.sourceRecordId = sourceRecordId
        self.context = context
    }
}

// MARK: - Type Erasure for Protocol

struct AnyCommentWithUser: CommentWithUserProtocol, Identifiable {
    let comment: AnyComment
    let user: UserProfile
    
    var id: String { comment.id }
    
    init<T: CommentWithUserProtocol>(_ commentWithUser: T) {
        self.comment = AnyComment(commentWithUser.comment)
        self.user = commentWithUser.user
    }
}

struct AnyComment: Comment {
    let id: String
    let userId: String
    let content: String
    let createdTimestamp: Date
    let modifiedTimestamp: Date
    let parentCommentId: String?
    let isEdited: Bool
    let likeCount: Int
    
    init<T: Comment>(_ comment: T) {
        self.id = comment.id
        self.userId = comment.userId
        self.content = comment.content
        self.createdTimestamp = comment.createdTimestamp
        self.modifiedTimestamp = comment.modifiedTimestamp
        self.parentCommentId = comment.parentCommentId
        self.isEdited = comment.isEdited
        self.likeCount = comment.likeCount
    }
}

// MARK: - Service Type Erasure

class AnyCommentService: CommentServicing {
    typealias CommentType = AnyComment
    typealias CommentWithUserType = AnyCommentWithUser
    
    private let _fetchComments: (String, Int) async throws -> [AnyCommentWithUser]
    private let _postComment: (String, String, String, String?, CommentMetadata) async throws -> AnyComment
    private let _updateComment: (String, String) async throws -> AnyComment
    private let _deleteComment: (String) async throws -> Void
    private let _likeComment: (String) async throws -> Int
    private let _unlikeComment: (String) async throws -> Int
    private let _fetchCommentCount: (String) async throws -> Int
    
    init<Service: CommentServicing>(_ service: Service) {
        self._fetchComments = { resourceId, limit in
            let comments = try await service.fetchComments(for: resourceId, limit: limit)
            return comments.map { AnyCommentWithUser($0) }
        }
        
        self._postComment = { resourceId, ownerId, content, parentId, metadata in
            let comment = try await service.postComment(
                resourceId: resourceId,
                resourceOwnerId: ownerId,
                content: content,
                parentCommentId: parentId,
                metadata: metadata
            )
            return AnyComment(comment)
        }
        
        self._updateComment = { commentId, newContent in
            let comment = try await service.updateComment(commentId: commentId, newContent: newContent)
            return AnyComment(comment)
        }
        
        self._deleteComment = { commentId in
            try await service.deleteComment(commentId: commentId)
        }
        
        self._likeComment = { commentId in
            try await service.likeComment(commentId: commentId)
        }
        
        self._unlikeComment = { commentId in
            try await service.unlikeComment(commentId: commentId)
        }
        
        self._fetchCommentCount = { resourceId in
            try await service.fetchCommentCount(for: resourceId)
        }
    }
    
    func fetchComments(for resourceId: String, limit: Int) async throws -> [AnyCommentWithUser] {
        try await _fetchComments(resourceId, limit)
    }
    
    func postComment(
        resourceId: String,
        resourceOwnerId: String,
        content: String,
        parentCommentId: String?,
        metadata: CommentMetadata
    ) async throws -> AnyComment {
        try await _postComment(resourceId, resourceOwnerId, content, parentCommentId, metadata)
    }
    
    func updateComment(commentId: String, newContent: String) async throws -> AnyComment {
        try await _updateComment(commentId, newContent)
    }
    
    func deleteComment(commentId: String) async throws {
        try await _deleteComment(commentId)
    }
    
    func likeComment(commentId: String) async throws -> Int {
        try await _likeComment(commentId)
    }
    
    func unlikeComment(commentId: String) async throws -> Int {
        try await _unlikeComment(commentId)
    }
    
    func fetchCommentCount(for resourceId: String) async throws -> Int {
        try await _fetchCommentCount(resourceId)
    }
}