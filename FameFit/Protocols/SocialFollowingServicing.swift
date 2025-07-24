//
//  SocialFollowingServicing.swift
//  FameFit
//
//  Protocol for social following service operations with security
//

import Foundation
import Combine
import CloudKit

// MARK: - Social Service Errors

enum SocialServiceError: Error, LocalizedError {
    case rateLimitExceeded(action: String, resetTime: Date)
    case userBlocked
    case userNotFound
    case selfFollowAttempt
    case duplicateRelationship
    case privacyRestriction
    case ageRestriction
    case spamDetected
    case networkError(Error)
    case invalidRequest
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .rateLimitExceeded(let action, let resetTime):
            let formatter = RelativeDateTimeFormatter()
            let resetIn = formatter.localizedString(for: resetTime, relativeTo: Date())
            return "Too many \(action) actions. Try again \(resetIn)."
        case .userBlocked:
            return "This user has blocked you."
        case .userNotFound:
            return "User not found."
        case .selfFollowAttempt:
            return "You cannot follow yourself."
        case .duplicateRelationship:
            return "You are already following this user."
        case .privacyRestriction:
            return "This user's privacy settings prevent this action."
        case .ageRestriction:
            return "This feature is not available for users under 13."
        case .spamDetected:
            return "This action has been flagged as potential spam."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidRequest:
            return "Invalid request. Please try again."
        case .unauthorized:
            return "You are not authorized to perform this action."
        }
    }
}

// MARK: - Relationship Types

enum RelationshipStatus: String, CaseIterable {
    case following = "following"
    case notFollowing = "not_following"
    case blocked = "blocked"
    case muted = "muted"
    case pending = "pending"
    case mutualFollow = "mutual"
}

struct FollowRequest: Codable, Identifiable {
    let id: String
    let requesterId: String
    let requesterProfile: UserProfile?
    let targetId: String
    let status: String // "pending", "accepted", "rejected", "expired"
    let createdAt: Date
    let expiresAt: Date
    let message: String?
    
    var isExpired: Bool {
        Date() > expiresAt
    }
}

struct UserRelationship: Codable, Identifiable {
    let id: String
    let followerID: String
    let followingID: String
    let status: String // "active", "blocked", "muted"
    let notificationsEnabled: Bool
    
    static func makeId(followerID: String, followingID: String) -> String {
        "\(followerID)_follows_\(followingID)"
    }
}

// MARK: - Social Following Service Protocol

protocol SocialFollowingServicing {
    // Publishers
    var followersCountPublisher: AnyPublisher<[String: Int], Never> { get }
    var followingCountPublisher: AnyPublisher<[String: Int], Never> { get }
    var relationshipUpdatesPublisher: AnyPublisher<UserRelationship, Never> { get }
    
    // Follow operations
    func follow(userId: String) async throws
    func unfollow(userId: String) async throws
    func requestFollow(userId: String, message: String?) async throws
    func respondToFollowRequest(requestId: String, accept: Bool) async throws
    
    // Relationship queries
    func getFollowers(for userId: String, limit: Int) async throws -> [UserProfile]
    func getFollowing(for userId: String, limit: Int) async throws -> [UserProfile]
    func checkRelationship(between userId: String, and targetId: String) async throws -> RelationshipStatus
    func getMutualFollowers(with userId: String, limit: Int) async throws -> [UserProfile]
    
    // Counts
    func getFollowerCount(for userId: String) async throws -> Int
    func getFollowingCount(for userId: String) async throws -> Int
    
    // Block/Mute operations
    func blockUser(_ userId: String) async throws
    func unblockUser(_ userId: String) async throws
    func muteUser(_ userId: String) async throws
    func unmuteUser(_ userId: String) async throws
    func getBlockedUsers() async throws -> [String]
    func getMutedUsers() async throws -> [String]
    
    // Follow requests
    func getPendingFollowRequests() async throws -> [FollowRequest]
    func getSentFollowRequests() async throws -> [FollowRequest]
    func cancelFollowRequest(requestId: String) async throws
    
    // Caching
    func clearRelationshipCache()
    func preloadRelationships(for userIds: [String]) async
}

// MARK: - Rate Limiting Service Protocol

protocol RateLimitingServicing {
    func checkLimit(for action: RateLimitAction, userId: String) async throws -> Bool
    func recordAction(_ action: RateLimitAction, userId: String) async
    func resetLimits(for userId: String) async
    func getRemainingActions(for action: RateLimitAction, userId: String) async -> Int
    func getResetTime(for action: RateLimitAction, userId: String) async -> Date?
}

enum RateLimitAction: String, CaseIterable {
    case follow
    case unfollow
    case search
    case feedRefresh
    case profileView
    case workoutPost
    case followRequest
    case report
    case like
    case comment
    
    var limits: (minutely: Int?, hourly: Int, daily: Int, weekly: Int?) {
        switch self {
        case .follow:
            return (minutely: 5, hourly: 60, daily: 500, weekly: 1000)
        case .unfollow:
            return (minutely: 3, hourly: 30, daily: 100, weekly: 500)
        case .search:
            return (minutely: 20, hourly: 200, daily: 1000, weekly: nil)
        case .feedRefresh:
            return (minutely: 10, hourly: 100, daily: 1000, weekly: nil)
        case .profileView:
            return (minutely: 30, hourly: 500, daily: 5000, weekly: nil)
        case .workoutPost:
            return (minutely: 1, hourly: 10, daily: 50, weekly: nil)
        case .followRequest:
            return (minutely: 2, hourly: 20, daily: 100, weekly: nil)
        case .report:
            return (minutely: 1, hourly: 5, daily: 20, weekly: nil)
        case .like:
            return (minutely: 60, hourly: 600, daily: 2000, weekly: nil)
        case .comment:
            return (minutely: 10, hourly: 100, daily: 500, weekly: nil)
        }
    }
}

// MARK: - Anti-Spam Service Protocol

protocol AntiSpamServicing {
    func checkForSpam(userId: String, action: SpamCheckAction) async -> SpamCheckResult
    func reportSpam(userId: String, targetId: String, reason: SpamReason) async throws
    func getSpamScore(for userId: String) async -> Double
}

enum SpamCheckAction {
    case follow(targetId: String)
    case message(content: String)
    case profileUpdate(content: String)
    case workoutPost
}

struct SpamCheckResult {
    let isSpam: Bool
    let confidence: Double
    let reason: String?
    let suggestedAction: SpamAction?
}

enum SpamAction {
    case block
    case captcha
    case rateLimit
    case shadowBan
    case warn
}

enum SpamReason: String, CaseIterable {
    case massFollowing = "mass_following"
    case inappropriateContent = "inappropriate_content"
    case harassment = "harassment"
    case fakeAccount = "fake_account"
    case other = "other"
}