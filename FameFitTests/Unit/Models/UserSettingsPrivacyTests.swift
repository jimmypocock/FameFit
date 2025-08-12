//
//  UserSettingsPrivacyTests.swift
//  FameFitTests
//
//  Unit tests for user settings privacy functionality
//

@testable import FameFit
import HealthKit
import XCTest

final class UserSettingsPrivacyTests: XCTestCase {
    // MARK: - Default Values Tests

    func testDefaultValues() {
        // Given/When
        let settings = UserSettings.defaultSettings(for: "test-user")

        // Then
        XCTAssertEqual(settings.defaultWorkoutPrivacy, .friendsOnly)
        XCTAssertTrue(settings.workoutTypePrivacyOverrides.isEmpty)
        XCTAssertTrue(settings.allowDataSharing)
        XCTAssertTrue(settings.shareAchievements)
        XCTAssertFalse(settings.sharePersonalRecords)
        XCTAssertTrue(settings.allowPublicSharing)
    }

    // MARK: - Privacy Level Tests

    func testPrivacyLevelForWorkoutType_UsesDefault() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.defaultWorkoutPrivacy = .friendsOnly

        // When
        let privacy = settings.privacyLevel(for: .running)

        // Then
        XCTAssertEqual(privacy, .friendsOnly)
    }

    func testPrivacyLevelForWorkoutType_UsesOverride() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.defaultWorkoutPrivacy = .friendsOnly
        settings.workoutTypePrivacyOverrides[String(HKWorkoutActivityType.running.rawValue)] = .public

        // When
        let privacy = settings.privacyLevel(for: .running)

        // Then
        XCTAssertEqual(privacy, .public)
    }

    func testSetPrivacyForWorkoutType() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")

        // When
        settings.setPrivacyLevel(.public, for: .cycling)

        // Then
        XCTAssertEqual(settings.workoutTypePrivacyOverrides[String(HKWorkoutActivityType.cycling.rawValue)], .public)
        XCTAssertEqual(settings.privacyLevel(for: .cycling), .public)
    }

    // MARK: - Effective Privacy Tests

    func testEffectivePrivacy_RespectsPublicSharingRestriction() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.defaultWorkoutPrivacy = .public
        settings.allowPublicSharing = false

        // When
        let effectivePrivacy = settings.effectivePrivacy(for: .running)

        // Then
        XCTAssertEqual(effectivePrivacy, .friendsOnly)
    }

    func testEffectivePrivacy_AllowsPublicWhenEnabled() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.defaultWorkoutPrivacy = .public
        settings.allowPublicSharing = true

        // When
        let effectivePrivacy = settings.effectivePrivacy(for: .running)

        // Then
        XCTAssertEqual(effectivePrivacy, .public)
    }

    func testEffectivePrivacy_PrivateAlwaysPrivate() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.defaultWorkoutPrivacy = .private
        settings.allowPublicSharing = true

        // When
        let effectivePrivacy = settings.effectivePrivacy(for: .running)

        // Then
        XCTAssertEqual(effectivePrivacy, .private)
    }

    func testEffectivePrivacy_FriendsOnlyUnaffectedByPublicRestriction() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.defaultWorkoutPrivacy = .friendsOnly
        settings.allowPublicSharing = false

        // When
        let effectivePrivacy = settings.effectivePrivacy(for: .running)

        // Then
        XCTAssertEqual(effectivePrivacy, .friendsOnly)
    }

    // MARK: - Can Share Tests

    func testCanShare_PrivateWorkoutNeverShared() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.setPrivacyLevel(.private, for: .running)

        // When/Then
        XCTAssertFalse(settings.canShare(workoutType: .running, with: .following))
        XCTAssertFalse(settings.canShare(workoutType: .running, with: .mutualFollow))
        XCTAssertFalse(settings.canShare(workoutType: .running, with: .notFollowing))
    }

    func testCanShare_FriendsOnlyRequiresMutualFollow() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.setPrivacyLevel(.friendsOnly, for: .running)

        // When/Then
        XCTAssertFalse(settings.canShare(workoutType: .running, with: .following))
        XCTAssertTrue(settings.canShare(workoutType: .running, with: .mutualFollow))
        XCTAssertFalse(settings.canShare(workoutType: .running, with: .notFollowing))
    }

    func testCanShare_PublicAllowsFollowers() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.setPrivacyLevel(.public, for: .running)
        settings.allowPublicSharing = true

        // When/Then
        XCTAssertTrue(settings.canShare(workoutType: .running, with: .following))
        XCTAssertTrue(settings.canShare(workoutType: .running, with: .mutualFollow))
        XCTAssertFalse(settings.canShare(workoutType: .running, with: .notFollowing))
    }

    // MARK: - COPPA Compliance Tests

    func testCOPPAValidation_Valid() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.allowPublicSharing = true
        settings.defaultWorkoutPrivacy = .friendsOnly

        // Then
        XCTAssertTrue(settings.isValidForCOPPA)
    }

    func testCOPPAValidation_InvalidDefaultPrivacy() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.allowPublicSharing = false
        settings.defaultWorkoutPrivacy = .public

        // Then
        XCTAssertFalse(settings.isValidForCOPPA)
    }

    func testCOPPAValidation_InvalidWorkoutTypeOverride() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.allowPublicSharing = false
        settings.defaultWorkoutPrivacy = .friendsOnly
        settings.workoutTypePrivacyOverrides["running"] = .public

        // Then
        XCTAssertFalse(settings.isValidForCOPPA)
    }

    // MARK: - Codable Tests

    func testCodable() throws {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.defaultWorkoutPrivacy = .friendsOnly
        settings.workoutTypePrivacyOverrides = [
            String(HKWorkoutActivityType.running.rawValue): .public,
            String(HKWorkoutActivityType.yoga.rawValue): .private
        ]
        settings.allowDataSharing = true
        settings.shareAchievements = false
        settings.sharePersonalRecords = true
        settings.allowPublicSharing = false

        // When
        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(UserSettings.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.defaultWorkoutPrivacy, settings.defaultWorkoutPrivacy)
        XCTAssertEqual(decoded.workoutTypePrivacyOverrides, settings.workoutTypePrivacyOverrides)
        XCTAssertEqual(decoded.allowDataSharing, settings.allowDataSharing)
        XCTAssertEqual(decoded.shareAchievements, settings.shareAchievements)
        XCTAssertEqual(decoded.sharePersonalRecords, settings.sharePersonalRecords)
        XCTAssertEqual(decoded.allowPublicSharing, settings.allowPublicSharing)
    }

    // MARK: - Equatable Tests

    func testEquatable_Equal() {
        // Given
        let settings1 = UserSettings.defaultSettings(for: "test-user")
        let settings2 = UserSettings.defaultSettings(for: "test-user")

        // Then
        XCTAssertEqual(settings1, settings2)
    }

    func testEquatable_NotEqual() {
        // Given
        let settings1 = UserSettings.defaultSettings(for: "test-user")
        var settings2 = UserSettings.defaultSettings(for: "test-user")
        settings2.defaultWorkoutPrivacy = .public

        // Then
        XCTAssertNotEqual(settings1, settings2)
    }

    // MARK: - Edge Cases

    func testEmptyWorkoutTypeOverrides() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.defaultWorkoutPrivacy = .public
        settings.workoutTypePrivacyOverrides = [:] // Explicitly empty

        // When
        let privacy = settings.privacyLevel(for: .swimming)

        // Then
        XCTAssertEqual(privacy, .public) // Should use default
    }

    func testMultipleWorkoutTypeOverrides() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.defaultWorkoutPrivacy = .friendsOnly

        // When - Set different privacy levels for different workouts
        settings.setPrivacyLevel(.public, for: .running)
        settings.setPrivacyLevel(.private, for: .yoga)
        settings.setPrivacyLevel(.friendsOnly, for: .cycling)

        // Then
        XCTAssertEqual(settings.privacyLevel(for: .running), .public)
        XCTAssertEqual(settings.privacyLevel(for: .yoga), .private)
        XCTAssertEqual(settings.privacyLevel(for: .cycling), .friendsOnly)
        XCTAssertEqual(settings.privacyLevel(for: .swimming), .friendsOnly) // Uses default
    }

    func testRemovePrivacyOverride() {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.defaultWorkoutPrivacy = .friendsOnly
        settings.setPrivacyLevel(.public, for: .running)

        // When
        settings.removePrivacyOverride(for: .running)

        // Then
        XCTAssertEqual(settings.privacyLevel(for: .running), .friendsOnly) // Back to default
        XCTAssertNil(settings.workoutTypePrivacyOverrides[String(HKWorkoutActivityType.running.rawValue)])
    }
}