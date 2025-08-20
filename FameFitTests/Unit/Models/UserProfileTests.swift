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


    func testUserProfileInitials() {
        // Test with two-word display name
        let profile1 = UserProfile(
            id: "1",
            userID: "test-user-1",
            username: "jimmy",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            creationDate: Date(),
            modificationDate: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )
        XCTAssertEqual(profile1.initials, "JI")

        // Test with single-word display name
        let profile2 = UserProfile(
            id: "2",
            userID: "test-user-2",
            username: "adam",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            creationDate: Date(),
            modificationDate: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )
        XCTAssertEqual(profile2.initials, "AD")

        // Test with empty display name (falls back to username)
        let profile3 = UserProfile(
            id: "3",
            userID: "test-user-3",
            username: "cooluser",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            creationDate: Date(),
            modificationDate: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )
        XCTAssertEqual(profile3.initials, "CO")
    }

    func testIsActiveProperty() {
        // Test active user (last seen within 7 days)
        let activeProfile = UserProfile(
            id: "1",
            userID: "test-active-user",
            username: "active",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            creationDate: Date(),
            modificationDate: Date().addingTimeInterval(-3 * 24 * 60 * 60), // 3 days ago
            isVerified: false,
            privacyLevel: .publicProfile
        )
        XCTAssertTrue(activeProfile.isActive)

        // Test inactive user (last seen more than 7 days ago)
        let inactiveProfile = UserProfile(
            id: "2",
            userID: "test-inactive-user",
            username: "inactive",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            creationDate: Date(),
            modificationDate: Date().addingTimeInterval(-10 * 24 * 60 * 60), // 10 days ago
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
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            creationDate: date,
            modificationDate: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )

        XCTAssertEqual(profile.formattedJoinDate, expectedFormat)
    }


    // MARK: - UserSettings Tests


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
