//
//  UserProfileServiceTests.swift
//  FameFitTests
//
//  Tests for UserProfileService
//

import Combine
@testable import FameFit
import XCTest

final class UserProfileServiceTests: XCTestCase {
    private var mockService: MockUserProfileService!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockService = MockUserProfileService()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        mockService = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Fetch Profile Tests

    func testFetchProfileSuccess() async throws {
        // When
        let profile = try await mockService.fetchProfile(userId: UserProfile.mockProfile.id)

        // Then
        XCTAssertEqual(profile.id, UserProfile.mockProfile.id)
        XCTAssertEqual(profile.username, UserProfile.mockProfile.username)
    }

    func testFetchProfileNotFound() async {
        // When/Then
        do {
            _ = try await mockService.fetchProfile(userId: "non-existent")
            XCTFail("Should throw profile not found error")
        } catch ProfileServiceError.profileNotFound {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchCurrentUserProfile() async throws {
        // When
        let profile = try await mockService.fetchCurrentUserProfile()

        // Then
        XCTAssertEqual(profile.id, UserProfile.mockProfile.id)
        XCTAssertEqual(profile.userID, UserProfile.mockProfile.userID)
    }

    // MARK: - Create Profile Tests

    func testCreateProfileSuccess() async throws {
        // Given
        let newProfile = UserProfile(
            id: "new-profile",
            userID: "new-user",
            username: "newuser",
            bio: "Just joined!",
            workoutCount: 0,
            totalXP: 0,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )

        // When
        let createdProfile = try await mockService.createProfile(newProfile)

        // Then
        XCTAssertEqual(createdProfile.id, newProfile.id)
        XCTAssertEqual(createdProfile.username, newProfile.username)

        // Verify it can now be fetched
        let fetchedProfile = try await mockService.fetchProfile(userId: newProfile.id)
        XCTAssertEqual(fetchedProfile.id, newProfile.id)
    }

    func testCreateProfileWithInvalidUsername() async {
        // Given
        let invalidProfile = UserProfile(
            id: "invalid-profile",
            userID: "invalid-user",
            username: "ab", // Too short
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )

        // When/Then
        do {
            _ = try await mockService.createProfile(invalidProfile)
            XCTFail("Should throw invalid username error")
        } catch ProfileServiceError.invalidUsername {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateProfileWithDuplicateUsername() async {
        // Given - existing profile already has username "fitnessfanatic"
        let duplicateProfile = UserProfile(
            id: "duplicate-profile",
            userID: "duplicate-user",
            username: "fitnessfanatic", // Already taken by mockProfile
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )

        // When/Then
        do {
            _ = try await mockService.createProfile(duplicateProfile)
            XCTFail("Should throw username already taken error")
        } catch ProfileServiceError.usernameAlreadyTaken {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // Display name test removed - no longer applicable

    func testCreateProfileWithInvalidBio() async {
        // Given
        let invalidProfile = UserProfile(
            id: "invalid-profile",
            userID: "invalid-user",
            username: "validusername",
            bio: String(repeating: "a", count: 501), // Too long
            workoutCount: 0,
            totalXP: 0,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )

        // When/Then
        do {
            _ = try await mockService.createProfile(invalidProfile)
            XCTFail("Should throw invalid bio error")
        } catch ProfileServiceError.invalidBio {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Update Profile Tests

    func testUpdateProfileSuccess() async throws {
        // Given - Create a new profile with updated values
        let updatedProfile = UserProfile(
            id: UserProfile.mockProfile.id,
            userID: UserProfile.mockProfile.userID,
            username: UserProfile.mockProfile.username,
            displayName: "Updated Name",
            bio: "Updated bio",
            workoutCount: UserProfile.mockProfile.workoutCount,
            totalXP: UserProfile.mockProfile.totalXP,
            createdTimestamp: UserProfile.mockProfile.createdTimestamp,
            modifiedTimestamp: Date(),
            isVerified: UserProfile.mockProfile.isVerified,
            privacyLevel: UserProfile.mockProfile.privacyLevel
        )

        // When
        let result = try await mockService.updateProfile(updatedProfile)

        // Then
        XCTAssertEqual(result.displayName, "Updated Name")
        XCTAssertEqual(result.bio, "Updated bio")
    }

    // MARK: - Delete Profile Tests

    func testDeleteProfileSuccess() async throws {
        // Given
        let profileId = UserProfile.mockProfile.id

        // Verify profile exists
        _ = try await mockService.fetchProfile(userId: profileId)

        // When
        try await mockService.deleteProfile(userId: profileId)

        // Then - profile should no longer exist
        do {
            _ = try await mockService.fetchProfile(userId: profileId)
            XCTFail("Profile should have been deleted")
        } catch ProfileServiceError.profileNotFound {
            // Expected
        }
    }

    // MARK: - Username Validation Tests

    func testIsUsernameAvailable() async throws {
        // Test available username
        let isAvailable1 = try await mockService.isUsernameAvailable("newusername")
        XCTAssertTrue(isAvailable1)

        // Test taken username
        let isAvailable2 = try await mockService.isUsernameAvailable("fitnessfanatic")
        XCTAssertFalse(isAvailable2)

        // Test case insensitive
        let isAvailable3 = try await mockService.isUsernameAvailable("FITNESSFANATIC")
        XCTAssertFalse(isAvailable3)
    }

    func testValidateUsername() {
        // Valid username
        let result1 = mockService.validateUsername("validuser")
        XCTAssertNoThrow(try result1.get())

        // Invalid username
        let result2 = mockService.validateUsername("ab")
        XCTAssertThrowsError(try result2.get()) { error in
            XCTAssertEqual(error as? ProfileServiceError, .invalidUsername)
        }
    }

    // MARK: - Settings Tests

    func testFetchSettingsForExistingUser() async throws {
        // When
        let settings = try await mockService.fetchSettings(userId: UserSettings.mockSettings.userID)

        // Then
        XCTAssertEqual(settings.userID, UserSettings.mockSettings.userID)
        XCTAssertTrue(settings.emailNotifications)
    }

    func testFetchSettingsForNewUser() async throws {
        // When - fetch settings for user without saved settings
        let settings = try await mockService.fetchSettings(userId: "new-user")

        // Then - should return default settings
        XCTAssertEqual(settings.userID, "new-user")
        XCTAssertTrue(settings.emailNotifications) // Default is true
        XCTAssertEqual(settings.workoutPrivacy, .friendsOnly) // Default
    }

    func testUpdateSettings() async throws {
        // Given
        var settings = UserSettings.mockSettings
        settings.emailNotifications = false
        settings.workoutPrivacy = .privateProfile

        // When
        let updatedSettings = try await mockService.updateSettings(settings)

        // Then
        XCTAssertFalse(updatedSettings.emailNotifications)
        XCTAssertEqual(updatedSettings.workoutPrivacy, .privateProfile)
    }

    // MARK: - Search Tests

    func testSearchProfiles() async throws {
        // When
        let results = try await mockService.searchProfiles(query: "fitness", limit: 10)

        // Then
        XCTAssertEqual(results.count, 2) // fitnessfanatic and Fitness Newbie
        XCTAssertTrue(results.contains { $0.username == "fitnessfanatic" })
        XCTAssertTrue(results.contains { $0.displayName == "Fitness Newbie" })
    }

    func testSearchProfilesCaseInsensitive() async throws {
        // When
        let results = try await mockService.searchProfiles(query: "FITNESS", limit: 10)

        // Then
        XCTAssertEqual(results.count, 2) // Case insensitive search still finds both
    }

    func testSearchProfilesByDisplayName() async throws {
        // When
        let results = try await mockService.searchProfiles(query: "Fanatic", limit: 10)

        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.displayName, "Fitness Fanatic")
    }

    // MARK: - Leaderboard Tests

    func testFetchLeaderboard() async throws {
        // When
        let leaderboard = try await mockService.fetchLeaderboard(limit: 10)

        // Then
        XCTAssertEqual(leaderboard.count, 5) // All mock profiles except private one are public
        XCTAssertEqual(leaderboard.first?.username, "strengthbeast") // Highest XP (67800)
        // Private profile should not appear
        XCTAssertFalse(leaderboard.contains { $0.username == "privateperson" })
    }

    func testFetchRecentlyActiveProfiles() async throws {
        // When
        let profiles = try await mockService.fetchRecentlyActiveProfiles(limit: 10)

        // Then
        XCTAssertEqual(profiles.count, 5) // All mock profiles except private one are public
        XCTAssertTrue(profiles.first?.modifiedTimestamp ?? Date.distantPast > profiles.last?.modifiedTimestamp ?? Date.distantPast)
    }

    // MARK: - Publisher Tests

    func testCurrentProfilePublisher() {
        // Given
        let expectation = XCTestExpectation(description: "Profile published")
        var receivedProfile: UserProfile?

        mockService.currentProfilePublisher
            .dropFirst() // Skip initial nil
            .sink { profile in
                receivedProfile = profile
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        Task {
            _ = try await mockService.fetchCurrentUserProfile()
        }

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedProfile)
        XCTAssertEqual(receivedProfile?.id, UserProfile.mockProfile.id)
    }

    func testIsLoadingPublisher() {
        // Given
        let expectation = XCTestExpectation(description: "Loading states")
        expectation.expectedFulfillmentCount = 2
        var loadingStates: [Bool] = []

        mockService.isLoadingPublisher
            .dropFirst() // Skip initial false
            .sink { isLoading in
                loadingStates.append(isLoading)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        Task {
            _ = try await mockService.fetchProfile(userId: UserProfile.mockProfile.id)
        }

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(loadingStates, [true, false])
    }

    // MARK: - Cache Tests

    func testClearCache() {
        // This is a no-op for mock service
        mockService.clearCache()
        // Just verify it doesn't crash
    }

    func testPreloadProfiles() async {
        // This is a no-op for mock service
        await mockService.preloadProfiles(["user1", "user2"])
        // Just verify it doesn't crash
    }
}
