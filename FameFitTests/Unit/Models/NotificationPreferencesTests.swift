//
//  NotificationSettingsTests.swift
//  FameFitTests
//
//  Tests for NotificationSettings model and persistence
//

@testable import FameFit
import XCTest

class NotificationSettingsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test to ensure clean state
        UserDefaults.standard.removeObject(forKey: NotificationSettings.storageKey)
    }

    override func tearDown() {
        // Clear UserDefaults after each test - use the correct storage key
        UserDefaults.standard.removeObject(forKey: NotificationSettings.storageKey)
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testDefaultInitialization_SetsCorrectDefaults() {
        // When
        let preferences = NotificationSettings()

        // Then
        XCTAssertTrue(preferences.pushNotificationsEnabled)
        XCTAssertEqual(preferences.maxNotificationsPerHour, 10)
        XCTAssertFalse(preferences.quietHoursEnabled)
        XCTAssertNil(preferences.quietHoursStart)
        XCTAssertNil(preferences.quietHoursEnd)
        XCTAssertTrue(preferences.groupSimilarNotifications)
        XCTAssertTrue(preferences.showPreviewsWhenLocked)

        // Check all notification types are enabled by default
        for type in NotificationType.allCases {
            XCTAssertTrue(preferences.enabledTypes[type] ?? true)
        }
    }

    // MARK: - Persistence Tests

    func testSave_PersistsToUserDefaults() {
        // Given
        var preferences = NotificationSettings()
        preferences.pushNotificationsEnabled = false
        preferences.maxNotificationsPerHour = 5
        preferences.quietHoursEnabled = true
        preferences.quietHoursStart = Date()
        preferences.enabledTypes[.workoutCompleted] = false

        // When
        preferences.save()

        // Then
        let loaded = NotificationSettings.load()
        XCTAssertEqual(loaded.pushNotificationsEnabled, false)
        XCTAssertEqual(loaded.maxNotificationsPerHour, 5)
        XCTAssertTrue(loaded.quietHoursEnabled)
        XCTAssertNotNil(loaded.quietHoursStart)
        XCTAssertEqual(loaded.enabledTypes[.workoutCompleted], false)
    }

    func testLoad_ReturnsDefaultsWhenNoSavedData() {
        // Given - No saved preferences
        UserDefaults.standard.removeObject(forKey: NotificationSettings.storageKey)

        // When
        let loaded = NotificationSettings.load()

        // Then
        XCTAssertTrue(loaded.pushNotificationsEnabled)
        XCTAssertEqual(loaded.maxNotificationsPerHour, 10)
    }

    // MARK: - Quiet Hours Tests

    func testIsInQuietHours_WhenDisabled_ReturnsFalse() {
        // Given
        let preferences = NotificationSettings()
        XCTAssertFalse(preferences.quietHoursEnabled)

        // When/Then
        XCTAssertFalse(preferences.isInQuietHours())
    }

    func testIsInQuietHours_WhenEnabledButNoTimes_ReturnsFalse() {
        // Given
        var preferences = NotificationSettings()
        preferences.quietHoursEnabled = true
        // No start/end times set

        // When/Then
        XCTAssertFalse(preferences.isInQuietHours())
    }

    func testIsInQuietHours_DuringQuietHours_ReturnsTrue() {
        // Given
        var preferences = NotificationSettings()
        preferences.quietHoursEnabled = true

        let calendar = Calendar.current
        let now = Date()
        preferences.quietHoursStart = calendar.date(byAdding: .hour, value: -1, to: now)
        preferences.quietHoursEnd = calendar.date(byAdding: .hour, value: 1, to: now)

        // When/Then
        XCTAssertTrue(preferences.isInQuietHours(at: now))
    }

    func testIsInQuietHours_OutsideQuietHours_ReturnsFalse() {
        // Given
        var preferences = NotificationSettings()
        preferences.quietHoursEnabled = true

        let calendar = Calendar.current
        let now = Date()
        preferences.quietHoursStart = calendar.date(byAdding: .hour, value: -3, to: now)
        preferences.quietHoursEnd = calendar.date(byAdding: .hour, value: -1, to: now)

        // When/Then
        XCTAssertFalse(preferences.isInQuietHours(at: now))
    }

    func testIsInQuietHours_AcrossMidnight_HandlesCorrectly() {
        // Given
        var preferences = NotificationSettings()
        preferences.quietHoursEnabled = true

        let calendar = Calendar.current
        // Set quiet hours from 10 PM to 6 AM
        preferences.quietHoursStart = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: Date())
        preferences.quietHoursEnd = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: Date())

        // Test at 11 PM
        let elevenPM = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        XCTAssertTrue(preferences.isInQuietHours(at: elevenPM))

        // Test at 2 AM
        let twoAM = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: Date())!
        XCTAssertTrue(preferences.isInQuietHours(at: twoAM))

        // Test at 7 AM (outside quiet hours)
        let sevenAM = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        XCTAssertFalse(preferences.isInQuietHours(at: sevenAM))
    }

    // MARK: - Notification Type Tests

    func testIsNotificationTypeEnabled_DefaultsToTrue() {
        // Given
        let preferences = NotificationSettings()

        // When/Then
        for type in NotificationType.allCases {
            XCTAssertTrue(preferences.isNotificationTypeEnabled(type))
        }
    }

    func testIsNotificationTypeEnabled_RespectsDisabledTypes() {
        // Given
        var preferences = NotificationSettings()
        preferences.enabledTypes[.workoutCompleted] = false
        preferences.enabledTypes[.newFollower] = false

        // When/Then
        XCTAssertFalse(preferences.isNotificationTypeEnabled(.workoutCompleted))
        XCTAssertFalse(preferences.isNotificationTypeEnabled(.newFollower))
        XCTAssertTrue(preferences.isNotificationTypeEnabled(.workoutKudos))
    }

    func testIsNotificationTypeEnabled_WhenPushDisabled_ReturnsFalse() {
        // Given
        var preferences = NotificationSettings()
        preferences.pushNotificationsEnabled = false

        // When/Then
        for type in NotificationType.allCases {
            XCTAssertFalse(preferences.isNotificationTypeEnabled(type))
        }
    }

    // MARK: - Codable Tests

    func testCodable_EncodesAndDecodes() throws {
        // Given
        var original = NotificationSettings()
        original.pushNotificationsEnabled = false
        original.maxNotificationsPerHour = 7
        original.quietHoursEnabled = true
        original.quietHoursStart = Date()
        original.quietHoursEnd = Date().addingTimeInterval(3_600)
        original.groupSimilarNotifications = false
        original.showPreviewsWhenLocked = false
        original.enabledTypes[.workoutCompleted] = false
        original.enabledTypes[.newFollower] = true

        // When
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotificationSettings.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.pushNotificationsEnabled, original.pushNotificationsEnabled)
        XCTAssertEqual(decoded.maxNotificationsPerHour, original.maxNotificationsPerHour)
        XCTAssertEqual(decoded.quietHoursEnabled, original.quietHoursEnabled)
        XCTAssertEqual(decoded.groupSimilarNotifications, original.groupSimilarNotifications)
        XCTAssertEqual(decoded.showPreviewsWhenLocked, original.showPreviewsWhenLocked)
        XCTAssertEqual(decoded.enabledTypes[.workoutCompleted], false)
        XCTAssertEqual(decoded.enabledTypes[.newFollower], true)
    }

    // MARK: - Equatable Tests

    func testEquatable_SameValues_AreEqual() {
        // Given
        let preferences1 = NotificationSettings()
        let preferences2 = NotificationSettings()

        // When/Then
        XCTAssertEqual(preferences1, preferences2)
    }

    func testEquatable_DifferentValues_AreNotEqual() {
        // Given
        let preferences1 = NotificationSettings()
        var preferences2 = NotificationSettings()
        preferences2.maxNotificationsPerHour = 5

        // When/Then
        XCTAssertNotEqual(preferences1, preferences2)
    }
}
