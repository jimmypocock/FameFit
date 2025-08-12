//
//  SocialFollowingProtocol.swift
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

// RelationshipStatus is now defined in UserSettings.swift to avoid circular dependencies

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

protocol SocialFollowingProtocol {
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
