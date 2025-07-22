//
//  UserProfileServicing.swift
//  FameFit
//
//  Protocol for user profile service operations
//

import Foundation
import Combine
import CloudKit

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
            return true
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .usernameAlreadyTaken:
            return "This username is already taken. Please choose another."
        case .invalidUsername:
            return "Username must be 3-30 characters and contain only letters, numbers, and underscores."
        case .invalidDisplayName:
            return "Display name must be 1-50 characters."
        case .invalidBio:
            return "Bio must be 500 characters or less."
        case .profileNotFound:
            return "Profile not found."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .insufficientPermissions:
            return "You don't have permission to perform this action."
        case .contentModerated:
            return "Your content was flagged for inappropriate language."
        case .quotaExceeded:
            return "Too many requests. Please try again later."
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
    func fetchRecentlyActiveProfiles(limit: Int) async throws -> [UserProfile]
    
    // Caching
    func clearCache()
    func preloadProfiles(_ userIds: [String]) async
}

// MARK: - Mock Implementation

final class MockUserProfileService: UserProfileServicing {
    @Published private var currentProfile: UserProfile?
    @Published private var isLoading = false
    
    var profiles: [String: UserProfile] = [:]
    private var settings: [String: UserSettings] = [:]
    var shouldFail = false
    
    var currentProfilePublisher: AnyPublisher<UserProfile?, Never> {
        $currentProfile.eraseToAnyPublisher()
    }
    
    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }
    
    init() {
        // Pre-populate with mock data
        profiles[UserProfile.mockProfile.id] = UserProfile.mockProfile
        profiles[UserProfile.mockPrivateProfile.id] = UserProfile.mockPrivateProfile
        
        // Add all the additional mock profiles
        for profile in UserProfile.mockProfiles {
            profiles[profile.id] = profile
        }
        
        settings[UserSettings.mockSettings.userID] = UserSettings.mockSettings
        settings[UserSettings.mockPrivateSettings.userID] = UserSettings.mockPrivateSettings
    }
    
    func fetchProfile(userId: String) async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        if shouldFail {
            throw ProfileServiceError.profileNotFound
        }
        
        guard let profile = profiles[userId] else {
            throw ProfileServiceError.profileNotFound
        }
        
        return profile
    }
    
    func fetchCurrentUserProfile() async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)
        
        if currentProfile == nil {
            currentProfile = UserProfile.mockProfile
        }
        
        return currentProfile!
    }
    
    func createProfile(_ profile: UserProfile) async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }
        
        // Validate
        guard case .success = validateUsername(profile.username) else {
            throw ProfileServiceError.invalidUsername
        }
        
        guard UserProfile.isValidDisplayName(profile.displayName) else {
            throw ProfileServiceError.invalidDisplayName
        }
        
        guard UserProfile.isValidBio(profile.bio) else {
            throw ProfileServiceError.invalidBio
        }
        
        // Check username availability
        let isAvailable = try await isUsernameAvailable(profile.username)
        guard isAvailable else {
            throw ProfileServiceError.usernameAlreadyTaken
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Store profile
        profiles[profile.id] = profile
        currentProfile = profile
        
        // Create default settings
        let defaultSettings = UserSettings.defaultSettings(for: profile.id)
        settings[profile.id] = defaultSettings
        
        return profile
    }
    
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }
        
        // Validate
        guard UserProfile.isValidDisplayName(profile.displayName) else {
            throw ProfileServiceError.invalidDisplayName
        }
        
        guard UserProfile.isValidBio(profile.bio) else {
            throw ProfileServiceError.invalidBio
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Update profile
        profiles[profile.id] = profile
        if currentProfile?.id == profile.id {
            currentProfile = profile
        }
        
        return profile
    }
    
    func deleteProfile(userId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Remove profile and settings
        profiles.removeValue(forKey: userId)
        settings.removeValue(forKey: userId)
        
        if currentProfile?.id == userId {
            currentProfile = nil
        }
    }
    
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Check if username exists in any profile
        return !profiles.values.contains { $0.username.lowercased() == username.lowercased() }
    }
    
    func validateUsername(_ username: String) -> Result<Void, ProfileServiceError> {
        guard UserProfile.isValidUsername(username) else {
            return .failure(.invalidUsername)
        }
        return .success(())
    }
    
    func fetchSettings(userId: String) async throws -> UserSettings {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 50_000_000)
        
        return settings[userId] ?? UserSettings.defaultSettings(for: userId)
    }
    
    func updateSettings(_ settings: UserSettings) async throws -> UserSettings {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Update settings
        self.settings[settings.userID] = settings
        
        return settings
    }
    
    func searchProfiles(query: String, limit: Int) async throws -> [UserProfile] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 150_000_000)
        
        let lowercaseQuery = query.lowercased()
        let results = profiles.values.filter { profile in
            profile.username.lowercased().contains(lowercaseQuery) ||
            profile.displayName.lowercased().contains(lowercaseQuery)
        }
        
        return Array(results.prefix(limit))
    }
    
    func fetchLeaderboard(limit: Int) async throws -> [UserProfile] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let publicProfiles = profiles.values.filter { $0.privacyLevel == .publicProfile }
        let sorted = publicProfiles.sorted { $0.totalXP > $1.totalXP }
        
        return Array(sorted.prefix(limit))
    }
    
    func fetchRecentlyActiveProfiles(limit: Int) async throws -> [UserProfile] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let publicProfiles = profiles.values.filter { $0.privacyLevel == .publicProfile }
        let sorted = publicProfiles.sorted { $0.lastUpdated > $1.lastUpdated }
        
        return Array(sorted.prefix(limit))
    }
    
    func clearCache() {
        // No-op for mock
    }
    
    func preloadProfiles(_ userIds: [String]) async {
        // No-op for mock
    }
}