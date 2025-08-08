//
//  SocialFollowingServicing.swift
//  FameFit
//
//  Protocol for social following service operations with security
//

import CloudKit
import Combine
import Foundation

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
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case let .rateLimitExceeded(action, resetTime):
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
        case let .networkError(error):
            return "Network error: \(error.localizedDescription)"
        case .invalidRequest:
            return "Invalid request. Please try again."
        case .unauthorized:
            return "You are not authorized to perform this action."
        case .authenticationRequired:
            return "Authentication is required to perform this action."
        }
    }
}

// MARK: - Relationship Types

enum RelationshipStatus: String, CaseIterable {
    case following
    case notFollowing = "not_following"
    case blocked
    case muted
    case pending
    case mutualFollow = "mutual"
}

struct FollowRequest: Codable, Identifiable {
    let id: String
    let requesterID: String
    let requesterProfile: UserProfile?
    let targetID: String
    let status: String // "pending", "accepted", "rejected", "expired"
    let creationDate: Date
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

    static func makeID(followerID: String, followingID: String) -> String {
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
    func follow(userID: String) async throws
    func unfollow(userID: String) async throws
    func requestFollow(userID: String, message: String?) async throws
    func respondToFollowRequest(requestID: String, accept: Bool) async throws

    // Relationship queries
    func getFollowers(for userID: String, limit: Int) async throws -> [UserProfile]
    func getFollowing(for userID: String, limit: Int) async throws -> [UserProfile]
    func checkRelationship(between userID: String, and targetID: String) async throws -> RelationshipStatus
    func getMutualFollowers(with userID: String, limit: Int) async throws -> [UserProfile]

    // Counts
    func getFollowerCount(for userID: String) async throws -> Int
    func getFollowingCount(for userID: String) async throws -> Int

    // Block/Mute operations
    func blockUser(_ userID: String) async throws
    func unblockUser(_ userID: String) async throws
    func muteUser(_ userID: String) async throws
    func unmuteUser(_ userID: String) async throws
    func getBlockedUsers() async throws -> [String]
    func getMutedUsers() async throws -> [String]

    // Follow requests
    func getPendingFollowRequests() async throws -> [FollowRequest]
    func getSentFollowRequests() async throws -> [FollowRequest]
    func cancelFollowRequest(requestID: String) async throws

    // Caching
    func clearRelationshipCache()
    func preloadRelationships(for userIDs: [String]) async
}

// MARK: - Rate Limiting Service Protocol

protocol RateLimitingServicing {
    func checkLimit(for action: RateLimitAction, userID: String) async throws -> Bool
    func recordAction(_ action: RateLimitAction, userID: String) async
    func resetLimits(for userID: String) async
    func getRemainingActions(for action: RateLimitAction, userID: String) async -> Int
    func getResetTime(for action: RateLimitAction, userID: String) async -> Date?
}

struct RateLimits {
    let minutely: Int?
    let hourly: Int
    let daily: Int
    let weekly: Int?
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

    var limits: RateLimits {
        switch self {
        case .follow:
            RateLimits(minutely: 5, hourly: 60, daily: 500, weekly: 1_000)
        case .unfollow:
            RateLimits(minutely: 3, hourly: 30, daily: 100, weekly: 500)
        case .search:
            RateLimits(minutely: 20, hourly: 200, daily: 1_000, weekly: nil)
        case .feedRefresh:
            RateLimits(minutely: 10, hourly: 100, daily: 1_000, weekly: nil)
        case .profileView:
            RateLimits(minutely: 30, hourly: 500, daily: 5_000, weekly: nil)
        case .workoutPost:
            RateLimits(minutely: 5, hourly: 30, daily: 100, weekly: nil)
        case .followRequest:
            RateLimits(minutely: 2, hourly: 20, daily: 100, weekly: nil)
        case .report:
            RateLimits(minutely: 1, hourly: 5, daily: 20, weekly: nil)
        case .like:
            RateLimits(minutely: 60, hourly: 600, daily: 2_000, weekly: nil)
        case .comment:
            RateLimits(minutely: 10, hourly: 100, daily: 500, weekly: nil)
        }
    }
}

// MARK: - Anti-Spam Service Protocol

protocol AntiSpamServicing {
    func checkForSpam(userID: String, action: SpamCheckAction) async -> SpamCheckResult
    func reportSpam(userID: String, targetID: String, reason: SpamReason) async throws
    func getSpamScore(for userID: String) async -> Double
}

enum SpamCheckAction {
    case follow(targetID: String)
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
    case harassment
    case fakeAccount = "fake_account"
    case other
}
