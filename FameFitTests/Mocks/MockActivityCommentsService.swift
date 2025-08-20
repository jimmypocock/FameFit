//
//  MockActivityFeedCommentsService.swift
//  FameFitTests
//
//  Mock implementation of ActivityFeedCommentsProtocol for testing
//

@testable import FameFit
import Foundation

final class MockActivityFeedCommentsService: ActivityFeedCommentsProtocol {
    var shouldFail = false
    var error: Error = NSError(domain: "MockError", code: 0, userInfo: nil)
    
    private(set) var fetchCommentsCalled = false
    private(set) var postCommentCalled = false
    private(set) var deleteCommentCalled = false
    private(set) var updateCommentCalled = false
    private(set) var getCommentCountCalled = false
    
    var mockComments: [ActivityFeedCommentWithUser] = []
    var mockCommentCount = 0
    
    func fetchComments(for activityFeedID: String, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        fetchCommentsCalled = true
        if shouldFail {
            throw error
        }
        return mockComments
    }
    
    func postComment(
        activityFeedID: String,
        sourceType: String,
        sourceID: String,
        activityOwnerID: String,
        content: String,
        parentCommentID: String?
    ) async throws -> ActivityFeedComment {
        postCommentCalled = true
        if shouldFail {
            throw error
        }
        
        return ActivityFeedComment(
            id: UUID().uuidString,
            activityFeedID: activityFeedID,
            sourceType: sourceType,
            sourceID: sourceID,
            userID: "test-user",
            activityOwnerID: activityOwnerID,
            content: content,
            creationDate: Date(),
            modificationDate: Date(),
            parentCommentID: parentCommentID,
            isEdited: false,
            likeCount: 0
        )
    }
    
    func deleteComment(commentID: String) async throws {
        deleteCommentCalled = true
        if shouldFail {
            throw error
        }
    }
    
    func updateComment(commentID: String, newContent: String) async throws -> ActivityFeedComment {
        updateCommentCalled = true
        if shouldFail {
            throw error
        }
        
        return ActivityFeedComment(
            id: commentID,
            activityFeedID: "test-feed",
            sourceType: "workout",
            sourceID: "test-workout",
            userID: "test-user",
            activityOwnerID: "test-owner",
            content: newContent,
            creationDate: Date().addingTimeInterval(-3_600),
            modificationDate: Date(),
            parentCommentID: nil,
            isEdited: true,
            likeCount: 0
        )
    }
    
    func fetchCommentsBySource(sourceType: String, sourceID: String, limit: Int) async throws -> [ActivityFeedCommentWithUser] {
        fetchCommentsCalled = true
        if shouldFail {
            throw error
        }
        return mockComments
    }
    
    func likeComment(commentID: String) async throws -> Int {
        if shouldFail {
            throw error
        }
        return 1
    }
    
    func unlikeComment(commentID: String) async throws -> Int {
        if shouldFail {
            throw error
        }
        return 0
    }
    
    func fetchCommentCount(for activityFeedID: String) async throws -> Int {
        getCommentCountCalled = true
        if shouldFail {
            throw error
        }
        return mockCommentCount
    }
    
    func fetchCommentCountBySource(sourceType: String, sourceID: String) async throws -> Int {
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
