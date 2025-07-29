//
//  UserProfileServicing.swift
//  FameFit
//
//  Protocol for user profile service operations
//

import CloudKit
import Combine
import Foundation

// MARK: - Profile Service Errors

enum ProfileServiceError: Error, LocalizedError, Equatable {
    case usernameAlreadyTaken
    case invalidUsername
    case invalidDisplayName
    case invalidBio
    case profileNotFound
    case networkError(Error)
    case insufficientPermissions
    case contentModerated
    case quotaExceeded

    static func == (lhs: ProfileServiceError, rhs: ProfileServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.usernameAlreadyTaken, .usernameAlreadyTaken),
             (.invalidUsername, .invalidUsername),
             (.invalidDisplayName, .invalidDisplayName),
             (.invalidBio, .invalidBio),
             (.profileNotFound, .profileNotFound),
             (.insufficientPermissions, .insufficientPermissions),
             (.contentModerated, .contentModerated),
             (.quotaExceeded, .quotaExceeded):
            true
        case let (.networkError(lhsError), .networkError(rhsError)):
            lhsError.localizedDescription == rhsError.localizedDescription
        default:
            false
        }
    }

    var errorDescription: String? {
        switch self {
        case .usernameAlreadyTaken:
            "This username is already taken. Please choose another."
        case .invalidUsername:
            "Username must be 3-30 characters and contain only letters, numbers, and underscores."
        case .invalidDisplayName:
            "Display name must be 1-50 characters."
        case .invalidBio:
            "Bio must be 500 characters or less."
        case .profileNotFound:
            "Profile not found."
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case .insufficientPermissions:
            "You don't have permission to perform this action."
        case .contentModerated:
            "Your content was flagged for inappropriate language."
        case .quotaExceeded:
            "Too many requests. Please try again later."
        }
    }
}

// MARK: - Profile Service Protocol

protocol UserProfileServicing {
    // Publishers
    var currentProfilePublisher: AnyPublisher<UserProfile?, Never> { get }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }

    // Profile operations
    func fetchProfile(userId: String) async throws -> UserProfile
    func fetchCurrentUserProfile() async throws -> UserProfile
    func createProfile(_ profile: UserProfile) async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile
    func deleteProfile(userId: String) async throws

    // Username validation
    func isUsernameAvailable(_ username: String) async throws -> Bool
    func validateUsername(_ username: String) -> Result<Void, ProfileServiceError>

    // Settings operations
    func fetchSettings(userId: String) async throws -> UserSettings
    func updateSettings(_ settings: UserSettings) async throws -> UserSettings

    // Search and discovery
    func searchProfiles(query: String, limit: Int) async throws -> [UserProfile]
    func fetchLeaderboard(limit: Int) async throws -> [UserProfile]
    func fetchLeaderboardWithTimeFilter(limit: Int, startDate: Date, endDate: Date) async throws -> [UserProfile]
    func fetchRecentlyActiveProfiles(limit: Int) async throws -> [UserProfile]

    // Caching
    func clearCache()
    func clearCache(for userId: String)
    func preloadProfiles(_ userIds: [String]) async
}
