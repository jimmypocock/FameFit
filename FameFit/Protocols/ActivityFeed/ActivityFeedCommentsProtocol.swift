//
//  ActivityFeedCommentsProtocol.swift
//  FameFit
//
//  Protocol for activity feed comments service operations
//

import Foundation

protocol ActivityFeedCommentsProtocol {
    // Fetch comments for any activity
    func fetchComments(for activityFeedID: String, limit: Int) async throws -> [ActivityFeedCommentWithUser]
    func fetchCommentsBySource(sourceType: String, sourceID: String, limit: Int) async throws -> [ActivityFeedCommentWithUser]
    
    // Post comment
    func postComment(
        activityFeedID: String,
        sourceType: String,
        sourceID: String,
        activityOwnerID: String,
        content: String,
        parentCommentID: String?
    ) async throws -> ActivityFeedComment
    
    // Update/Delete
    func updateComment(commentID: String, newContent: String) async throws -> ActivityFeedComment
    func deleteComment(commentID: String) async throws
    
    // Interactions
    func likeComment(commentID: String) async throws -> Int
    func unlikeComment(commentID: String) async throws -> Int
    
    // Count
    func fetchCommentCount(for activityFeedID: String) async throws -> Int
    func fetchCommentCountBySource(sourceType: String, sourceID: String) async throws -> Int
}