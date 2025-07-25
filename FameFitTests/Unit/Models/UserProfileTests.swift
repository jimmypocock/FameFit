//
//  UserProfileTests.swift
//  FameFitTests
//
//  Tests for UserProfile and UserSettings models
//

@testable import FameFit
import XCTest

final class UserProfileTests: XCTestCase {
    // MARK: - UserProfile Tests

    func testUserProfileInitialization() {
        // Given
        let id = "test-user-123"
        let username = "fitnessfan"
        let displayName = "Fitness Fan"
        let bio = "Love working out!"
        let workoutCount = 42
        let totalXP = 12500
        let joinedDate = Date()
        let lastUpdated = Date()
        let isVerified = true
        let privacyLevel = ProfilePrivacyLevel.publicProfile

        // When
        let profile = UserProfile(
            id: id,
            userID: "test-user-id",
            username: username,
            displayName: displayName,
            bio: bio,
            workoutCount: workoutCount,
            totalXP: totalXP,
            joinedDate: joinedDate,
            lastUpdated: lastUpdated,
            isVerified: isVerified,
            privacyLevel: privacyLevel,
            profileImageURL: nil,
            headerImageURL: nil
        )

        // Then
        XCTAssertEqual(profile.id, id)
        XCTAssertEqual(profile.username, username)
        XCTAssertEqual(profile.displayName, displayName)
        XCTAssertEqual(profile.bio, bio)
        XCTAssertEqual(profile.workoutCount, workoutCount)
        XCTAssertEqual(profile.totalXP, totalXP)
        XCTAssertEqual(profile.joinedDate, joinedDate)
        XCTAssertEqual(profile.lastUpdated, lastUpdated)
        XCTAssertEqual(profile.isVerified, isVerified)
        XCTAssertEqual(profile.privacyLevel, privacyLevel)
        XCTAssertNil(profile.profileImageURL)
        XCTAssertNil(profile.headerImageURL)
    }

    func testUserProfileInitials() {
        // Test with two-word display name
        let profile1 = UserProfile(
            id: "1",
            userID: "test-user-1",
            username: "user1",
            displayName: "John Doe",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )
        XCTAssertEqual(profile1.initials, "JD")

        // Test with single-word display name
        let profile2 = UserProfile(
            id: "2",
            userID: "test-user-2",
            username: "user2",
            displayName: "Madonna",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )
        XCTAssertEqual(profile2.initials, "Ma")

        // Test with empty display name (falls back to username)
        let profile3 = UserProfile(
            id: "3",
            userID: "test-user-3",
            username: "cooluser",
            displayName: "",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )
        XCTAssertEqual(profile3.initials, "co")
    }

    func testIsActiveProperty() {
        // Test active user (last seen within 7 days)
        let activeProfile = UserProfile(
            id: "1",
            userID: "test-active-user",
            username: "active",
            displayName: "Active User",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: Date(),
            lastUpdated: Date().addingTimeInterval(-3 * 24 * 60 * 60), // 3 days ago
            isVerified: false,
            privacyLevel: .publicProfile
        )
        XCTAssertTrue(activeProfile.isActive)

        // Test inactive user (last seen more than 7 days ago)
        let inactiveProfile = UserProfile(
            id: "2",
            userID: "test-inactive-user",
            username: "inactive",
            displayName: "Inactive User",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: Date(),
            lastUpdated: Date().addingTimeInterval(-10 * 24 * 60 * 60), // 10 days ago
            isVerified: false,
            privacyLevel: .publicProfile
        )
        XCTAssertFalse(inactiveProfile.isActive)
    }

    func testUsernameValidation() {
        // Valid usernames
        XCTAssertTrue(UserProfile.isValidUsername("john"))
        XCTAssertTrue(UserProfile.isValidUsername("john_doe"))
        XCTAssertTrue(UserProfile.isValidUsername("user123"))
        XCTAssertTrue(UserProfile.isValidUsername("_underscore_"))
        XCTAssertTrue(UserProfile.isValidUsername("ABC")) // Minimum 3 chars
        XCTAssertTrue(UserProfile.isValidUsername("a" + String(repeating: "b", count: 29))) // 30 chars

        // Invalid usernames
        XCTAssertFalse(UserProfile.isValidUsername("ab")) // Too short
        XCTAssertFalse(UserProfile.isValidUsername("a" + String(repeating: "b", count: 30))) // Too long
        XCTAssertFalse(UserProfile.isValidUsername("john doe")) // Contains space
        XCTAssertFalse(UserProfile.isValidUsername("john-doe")) // Contains hyphen
        XCTAssertFalse(UserProfile.isValidUsername("john@doe")) // Contains @
        XCTAssertFalse(UserProfile.isValidUsername("")) // Empty
        XCTAssertFalse(UserProfile.isValidUsername("émoji")) // Contains non-ASCII
    }

    func testDisplayNameValidation() {
        // Valid display names
        XCTAssertTrue(UserProfile.isValidDisplayName("J"))
        XCTAssertTrue(UserProfile.isValidDisplayName("John Doe"))
        XCTAssertTrue(UserProfile.isValidDisplayName(String(repeating: "a", count: 50)))

        // Invalid display names
        XCTAssertFalse(UserProfile.isValidDisplayName(""))
        XCTAssertFalse(UserProfile.isValidDisplayName("   ")) // Only whitespace
        XCTAssertFalse(UserProfile.isValidDisplayName(String(repeating: "a", count: 51)))
    }

    func testBioValidation() {
        // Valid bios
        XCTAssertTrue(UserProfile.isValidBio(""))
        XCTAssertTrue(UserProfile.isValidBio("Short bio"))
        XCTAssertTrue(UserProfile.isValidBio(String(repeating: "a", count: 500)))

        // Invalid bios
        XCTAssertFalse(UserProfile.isValidBio(String(repeating: "a", count: 501)))
    }

    func testFormattedJoinDate() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let date = Date()
        let expectedFormat = "Joined \(formatter.string(from: date))"

        let profile = UserProfile(
            id: "1",
            userID: "test-user-id",
            username: "user",
            displayName: "User",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: date,
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )

        XCTAssertEqual(profile.formattedJoinDate, expectedFormat)
    }

    // MARK: - Privacy Level Tests

    func testPrivacyLevelDisplayNames() {
        XCTAssertEqual(ProfilePrivacyLevel.publicProfile.displayName, "Public")
        XCTAssertEqual(ProfilePrivacyLevel.friendsOnly.displayName, "Friends Only")
        XCTAssertEqual(ProfilePrivacyLevel.privateProfile.displayName, "Private")
    }

    func testPrivacyLevelDescriptions() {
        XCTAssertEqual(ProfilePrivacyLevel.publicProfile.description, "Anyone can view your profile and workouts")
        XCTAssertEqual(ProfilePrivacyLevel.friendsOnly.description, "Only approved friends can view your profile")
        XCTAssertEqual(ProfilePrivacyLevel.privateProfile.description, "Your profile is hidden from everyone")
    }

    // MARK: - UserSettings Tests

    func testUserSettingsDefaultValues() {
        // Given
        let userId = "test-user"

        // When
        let settings = UserSettings.defaultSettings(for: userId)

        // Then
        XCTAssertEqual(settings.userID, userId)
        XCTAssertTrue(settings.emailNotifications)
        XCTAssertTrue(settings.pushNotifications)
        XCTAssertEqual(settings.workoutPrivacy, .friendsOnly)
        XCTAssertEqual(settings.allowMessages, .friendsOnly)
        XCTAssertTrue(settings.blockedUsers.isEmpty)
        XCTAssertTrue(settings.mutedUsers.isEmpty)
        XCTAssertEqual(settings.contentFilter, .moderate)
        XCTAssertTrue(settings.showWorkoutStats)
        XCTAssertTrue(settings.allowFriendRequests)
        XCTAssertTrue(settings.showOnLeaderboards)
    }

    func testUserSettingsBlockedUsers() {
        var settings = UserSettings.defaultSettings(for: "user1")
        settings.blockedUsers = ["blocked1", "blocked2"]

        XCTAssertTrue(settings.isUserBlocked("blocked1"))
        XCTAssertTrue(settings.isUserBlocked("blocked2"))
        XCTAssertFalse(settings.isUserBlocked("notblocked"))
    }

    func testUserSettingsMutedUsers() {
        var settings = UserSettings.defaultSettings(for: "user1")
        settings.mutedUsers = ["muted1", "muted2"]

        XCTAssertTrue(settings.isUserMuted("muted1"))
        XCTAssertTrue(settings.isUserMuted("muted2"))
        XCTAssertFalse(settings.isUserMuted("notmuted"))
    }

    func testCanReceiveMessagesFrom() {
        var settings = UserSettings.defaultSettings(for: "user1")
        settings.blockedUsers = ["blocked1"]

        // Test with allowMessages = .friendsOnly (default)
        XCTAssertFalse(settings.canReceiveMessagesFrom("blocked1", isFriend: true)) // Blocked
        XCTAssertTrue(settings.canReceiveMessagesFrom("friend1", isFriend: true)) // Friend
        XCTAssertFalse(settings.canReceiveMessagesFrom("stranger1", isFriend: false)) // Not friend

        // Test with allowMessages = .all
        settings.allowMessages = .all
        XCTAssertFalse(settings.canReceiveMessagesFrom("blocked1", isFriend: false)) // Still blocked
        XCTAssertTrue(settings.canReceiveMessagesFrom("anyone", isFriend: false)) // Anyone can message

        // Test with allowMessages = .none
        settings.allowMessages = .none
        XCTAssertFalse(settings.canReceiveMessagesFrom("friend1", isFriend: true)) // Even friends can't
    }

    func testUserSettingsWithMethod() {
        let original = UserSettings.defaultSettings(for: "user1")

        let modified = original.with(
            emailNotifications: false,
            pushNotifications: false,
            workoutPrivacy: .privateProfile,
            contentFilter: .strict
        )

        // Original should be unchanged
        XCTAssertTrue(original.emailNotifications)
        XCTAssertTrue(original.pushNotifications)
        XCTAssertEqual(original.workoutPrivacy, .friendsOnly)
        XCTAssertEqual(original.contentFilter, .moderate)

        // Modified should have new values
        XCTAssertFalse(modified.emailNotifications)
        XCTAssertFalse(modified.pushNotifications)
        XCTAssertEqual(modified.workoutPrivacy, .privateProfile)
        XCTAssertEqual(modified.contentFilter, .strict)

        // Other values should remain the same
        XCTAssertEqual(modified.userID, original.userID)
        XCTAssertEqual(modified.allowMessages, original.allowMessages)
    }

    // MARK: - Notification Preference Tests

    func testNotificationPreferenceDisplayNames() {
        XCTAssertEqual(NotificationPreference.all.displayName, "Everyone")
        XCTAssertEqual(NotificationPreference.friendsOnly.displayName, "Friends Only")
        XCTAssertEqual(NotificationPreference.none.displayName, "None")
    }

    // MARK: - Content Filter Tests

    func testContentFilterDisplayNamesAndDescriptions() {
        XCTAssertEqual(ContentFilterLevel.strict.displayName, "Strict")
        XCTAssertEqual(ContentFilterLevel.strict.description, "Filters all potentially inappropriate content")

        XCTAssertEqual(ContentFilterLevel.moderate.displayName, "Moderate")
        XCTAssertEqual(ContentFilterLevel.moderate.description, "Filters only explicit content")

        XCTAssertEqual(ContentFilterLevel.off.displayName, "Off")
        XCTAssertEqual(ContentFilterLevel.off.description, "No content filtering")
    }

    // MARK: - Equatable Tests

    func testUserProfileEquatable() {
        let profile1 = UserProfile.mockProfile
        let profile2 = UserProfile.mockProfile
        let profile3 = UserProfile.mockPrivateProfile

        XCTAssertEqual(profile1, profile2)
        XCTAssertNotEqual(profile1, profile3)
    }

    func testUserSettingsEquatable() {
        let settings1 = UserSettings.mockSettings
        let settings2 = UserSettings.mockSettings
        let settings3 = UserSettings.mockPrivateSettings

        XCTAssertEqual(settings1, settings2)
        XCTAssertNotEqual(settings1, settings3)
    }
}
