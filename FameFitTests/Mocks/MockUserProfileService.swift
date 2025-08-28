//
//  MockUserProfileService.swift
//  FameFitTests
//
//  Mock implementation of UserProfileProtocol for testing
//

import CloudKit
import Combine
@testable import FameFit
import Foundation

final class MockUserProfileService: UserProfileProtocol {
    @Published private var currentProfile: UserProfile?
    @Published private var isLoading = false

    var profiles: [String: UserProfile] = [:]
    private var settings: [String: UserSettings] = [:]
    var shouldFail = false
    var clearedCacheUserIds: [String] = []

    // Allow setting current profile for testing
    func setCurrentProfile(_ profile: UserProfile?) {
        currentProfile = profile
    }

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

    func fetchProfile(userID: String) async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }

        // Reduce delay for UI testing
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI-Testing")
        let delay: UInt64 = isUITesting ? 10_000_000 : 100_000_000 // 0.01s for UI tests, 0.1s otherwise

        // Simulate network delay
        try await Task.sleep(nanoseconds: delay)

        if shouldFail {
            throw ProfileServiceError.profileNotFound
        }

        guard let profile = profiles[userID] else {
            throw ProfileServiceError.profileNotFound
        }

        return profile
    }
    
    func fetchProfileByUserID(_ userID: String) async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }
        
        // Reduce delay for UI testing
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI-Testing")
        let delay: UInt64 = isUITesting ? 10_000_000 : 100_000_000 // 0.01s for UI tests, 0.1s otherwise
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: delay)
        
        if shouldFail {
            throw ProfileServiceError.profileNotFound
        }
        
        // For mock, search by userID field in profiles
        guard let profile = profiles.values.first(where: { $0.userID == userID }) else {
            throw ProfileServiceError.profileNotFound
        }
        
        return profile
    }

    func fetchCurrentUserProfile() async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }

        // Reduce delay for UI testing
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI-Testing")
        let delay: UInt64 = isUITesting ? 10_000_000 : 100_000_000 // 0.01s for UI tests, 0.1s otherwise

        // Simulate network delay
        try await Task.sleep(nanoseconds: delay)
        
        return try await fetchCurrentUserProfileFresh()
    }
    
    func fetchCurrentUserProfileFresh() async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }

        // Reduce delay for UI testing
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI-Testing")
        let delay: UInt64 = isUITesting ? 10_000_000 : 100_000_000 // 0.01s for UI tests, 0.1s otherwise

        // Simulate network delay
        try await Task.sleep(nanoseconds: delay)

        if currentProfile == nil {
            // Check if we have a profile for "test-user" first (UI testing)
            if let testProfile = profiles["test-user"] {
                currentProfile = testProfile
            } else {
                currentProfile = UserProfile.mockProfile
            }
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

        // Display name validation no longer needed

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
        // Display name validation no longer needed

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

    func deleteProfile(userID: String) async throws {
        isLoading = true
        defer { isLoading = false }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000)

        // Remove profile and settings
        profiles.removeValue(forKey: userID)
        settings.removeValue(forKey: userID)

        if currentProfile?.id == userID {
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

    func fetchSettings(userID: String) async throws -> UserSettings {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 50_000_000)

        return settings[userID] ?? UserSettings.defaultSettings(for: userID)
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
            profile.username.lowercased().contains(lowercaseQuery)
        }

        return Array(results.prefix(limit))
    }

    func fetchLeaderboard(limit: Int) async throws -> [UserProfile] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)

        if shouldFail {
            throw ProfileServiceError.networkError(NSError(
                domain: "MockError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Mock service error"]
            ))
        }

        let publicProfiles = profiles.values.filter { $0.privacyLevel == .publicProfile }
        let sorted = publicProfiles.sorted { $0.totalXP > $1.totalXP }

        return Array(sorted.prefix(limit))
    }

    func fetchLeaderboardWithTimeFilter(limit: Int, startDate: Date, endDate: Date) async throws -> [UserProfile] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)

        let publicProfiles = profiles.values.filter { profile in
            profile.privacyLevel == .publicProfile &&
                profile.modificationDate >= startDate &&
                profile.modificationDate <= endDate
        }

        let sorted = publicProfiles.sorted { $0.totalXP > $1.totalXP }

        return Array(sorted.prefix(limit))
    }

    func fetchRecentlyActiveProfiles(limit: Int) async throws -> [UserProfile] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)

        let publicProfiles = profiles.values.filter { $0.privacyLevel == .publicProfile }
        let sorted = publicProfiles.sorted { $0.modificationDate > $1.modificationDate }

        return Array(sorted.prefix(limit))
    }

    func clearCache() {
        // No-op for mock
    }

    func clearCache(for userID: String) {
        // Mock implementation - track cleared cache user IDs
        clearedCacheUserIds.append(userID)
    }
    
    func clearAllCaches() {
        // Clear all mock data
        profiles.removeAll()
        currentProfile = nil
        clearedCacheUserIds.removeAll()
    }

    func preloadProfiles(_: [String]) async {
        // No-op for mock
    }
}
