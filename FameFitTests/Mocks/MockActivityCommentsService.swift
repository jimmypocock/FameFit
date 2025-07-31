//
//  MockActivityCommentsService.swift
//  FameFitTests
//
//  Mock implementation of ActivityCommentsServicing for testing
//

@testable import FameFit
import Foundation

final class MockActivityCommentsService: ActivityCommentsServicing {
    var shouldFail = false
    var error: Error = NSError(domain: "MockError", code: 0, userInfo: nil)
    
    private(set) var fetchCommentsCalled = false
    private(set) var postCommentCalled = false
    private(set) var deleteCommentCalled = false
    private(set) var updateCommentCalled = false
    private(set) var getCommentCountCalled = false
    
    var mockComments: [CommentWithUser] = []
    var mockCommentCount = 0
    
    func fetchComments(for activityFeedId: String, limit: Int) async throws -> [CommentWithUser] {
        fetchCommentsCalled = true
        if shouldFail {
            throw error
        }
        return mockComments
    }
    
    func postComment(
        activityFeedId: String,
        sourceType: String,
        sourceRecordId: String,
        activityOwnerId: String,
        content: String,
        parentCommentId: String?
    ) async throws -> ActivityComment {
        postCommentCalled = true
        if shouldFail {
            throw error
        }
        
        return ActivityComment(
            id: UUID().uuidString,
            activityFeedId: activityFeedId,
            sourceType: sourceType,
            sourceRecordId: sourceRecordId,
            userId: "test-user",
            activityOwnerId: activityOwnerId,
            content: content,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            parentCommentId: parentCommentId,
            isEdited: false,
            likeCount: 0
        )
    }
    
    func deleteComment(commentId: String) async throws {
        deleteCommentCalled = true
        if shouldFail {
            throw error
        }
    }
    
    func updateComment(commentId: String, newContent: String) async throws -> ActivityComment {
        updateCommentCalled = true
        if shouldFail {
            throw error
        }
        
        return ActivityComment(
            id: commentId,
            activityFeedId: "test-feed",
            sourceType: "workout",
            sourceRecordId: "test-workout",
            userId: "test-user",
            activityOwnerId: "test-owner",
            content: newContent,
            createdTimestamp: Date().addingTimeInterval(-3600),
            modifiedTimestamp: Date(),
            parentCommentId: nil,
            isEdited: true,
            likeCount: 0
        )
    }
    
    func fetchCommentsBySource(sourceType: String, sourceRecordId: String, limit: Int) async throws -> [CommentWithUser] {
        fetchCommentsCalled = true
        if shouldFail {
            throw error
        }
        return mockComments
    }
    
    func likeComment(commentId: String) async throws -> Int {
        if shouldFail {
            throw error
        }
        return 1
    }
    
    func unlikeComment(commentId: String) async throws -> Int {
        if shouldFail {
            throw error
        }
        return 0
    }
    
    func fetchCommentCount(for activityFeedId: String) async throws -> Int {
        getCommentCountCalled = true
        if shouldFail {
            throw error
        }
        return mockCommentCount
    }
    
    func fetchCommentCountBySource(sourceType: String, sourceRecordId: String) async throws -> Int {
        getCommentCountCalled = true
        if shouldFail {
            throw error
        }
        return mockCommentCount
    }
    
    func reset() {
        fetchCommentsCalled = false
        postCommentCalled = false
        deleteCommentCalled = false
        updateCommentCalled = false
        getCommentCountCalled = false
        shouldFail = false
        mockComments = []
        mockCommentCount = 0
    }
}