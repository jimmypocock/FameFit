//
//  UnlockStorageServiceTests.swift
//  FameFitTests
//
//  Tests for unlock storage service
//

@testable import FameFit
import XCTest

final class UnlockStorageServiceTests: XCTestCase {
    private var service: UnlockStorageService!
    private var testUserDefaults: UserDefaults!

    override func setUp() {
        super.setUp()

        testUserDefaults = UserDefaults(suiteName: "com.jimmypocock.FameFit.storage.tests")!
        testUserDefaults.removePersistentDomain(forName: "com.jimmypocock.FameFit.storage.tests")
        testUserDefaults.synchronize()

        service = UnlockStorageService(userDefaults: testUserDefaults)
    }

    override func tearDown() {
        service = nil
        testUserDefaults.removePersistentDomain(forName: "com.jimmypocock.FameFit.storage.tests")
        testUserDefaults.synchronize()
        testUserDefaults = nil

        super.tearDown()
    }

    // MARK: - Basic Storage Tests

    func testStartsWithNoUnlocks() {
        let unlocks = service.getUnlockedItems()
        XCTAssertEqual(unlocks.count, 0)
    }

    func testRecordsUnlock() {
        // Given
        let bronzeBadge = XPCalculator.unlockables.first { $0.name == "Bronze Badge" }!

        // When
        service.recordUnlock(bronzeBadge)

        // Then
        let unlocks = service.getUnlockedItems()
        // Bronze Badge is at 100 XP, which also has Custom Messages
        XCTAssertEqual(unlocks.count, 2, "Should include all unlocks at 100 XP")
        XCTAssertTrue(unlocks.contains { $0.name == "Bronze Badge" })
        XCTAssertTrue(unlocks.contains { $0.name == "Custom Messages" })
        XCTAssertTrue(service.hasUnlocked(bronzeBadge))
    }

    func testDoesNotDuplicateUnlocks() {
        // Given
        let bronzeBadge = XPCalculator.unlockables.first { $0.name == "Bronze Badge" }!

        // When - Record same unlock twice
        service.recordUnlock(bronzeBadge)
        service.recordUnlock(bronzeBadge)

        // Then - Should still have 2 (Bronze Badge + Custom Messages at 100 XP)
        let unlocks = service.getUnlockedItems()
        XCTAssertEqual(unlocks.count, 2, "Should not duplicate, but includes all at 100 XP")
    }

    func testRecordsMultipleUnlocks() {
        // Given
        let bronzeBadge = XPCalculator.unlockables.first { $0.name == "Bronze Badge" }!
        let silverBadge = XPCalculator.unlockables.first { $0.name == "Silver Badge" }!
        let customMessages = XPCalculator.unlockables.first { $0.name == "Custom Messages" }!

        // When
        service.recordUnlock(bronzeBadge) // 100 XP
        service.recordUnlock(silverBadge) // 500 XP
        service.recordUnlock(customMessages) // 100 XP (same as Bronze)

        // Then
        let unlocks = service.getUnlockedItems()
        // We recorded 2 XP thresholds: 100 (Bronze + Custom) and 500 (Silver + Profile Theme)
        XCTAssertEqual(unlocks.count, 4, "Should have all unlocks at 100 and 500 XP")
        XCTAssertTrue(service.hasUnlocked(bronzeBadge))
        XCTAssertTrue(service.hasUnlocked(silverBadge))
        XCTAssertTrue(service.hasUnlocked(customMessages))
    }

    // MARK: - Timestamp Tests

    func testRecordsUnlockTimestamp() {
        // Given
        let bronzeBadge = XPCalculator.unlockables.first { $0.name == "Bronze Badge" }!
        let beforeTime = Date()

        // When
        service.recordUnlock(bronzeBadge)
        let afterTime = Date()

        // Then
        let timestamp = service.getUnlockTimestamp(for: bronzeBadge)
        XCTAssertNotNil(timestamp)
        XCTAssertTrue(timestamp! >= beforeTime)
        XCTAssertTrue(timestamp! <= afterTime)
    }

    func testReturnsNilTimestampForUnrecordedUnlock() {
        // Given
        let bronzeBadge = XPCalculator.unlockables.first { $0.name == "Bronze Badge" }!

        // When/Then
        XCTAssertNil(service.getUnlockTimestamp(for: bronzeBadge))
    }

    // MARK: - Category Filter Tests

    func testFiltersUnlocksByCategory() {
        // Given - Record specific unlocks at unique XP thresholds
        // Use unlocks that don't share XP values with other categories
        let goldBadge = XPCalculator.unlockables.first { $0.name == "Gold Badge" }! // 2500 XP
        let exclusiveWorkouts = XPCalculator.unlockables.first { $0.name == "Exclusive Workouts" }! // 100000 XP
        let animationPack = XPCalculator.unlockables.first { $0.name == "Animation Pack" }! // 10000 XP

        service.recordUnlock(goldBadge)
        service.recordUnlock(exclusiveWorkouts)
        service.recordUnlock(animationPack)

        // When/Then - Get actual counts based on XP thresholds
        let badges = service.getUnlockedBadges()
        let features = service.getUnlockedFeatures()
        let customizations = service.getUnlockedCustomizations()
        let achievements = service.getUnlockedAchievements()

        // At 2500 XP: Gold Badge + Workout Themes
        // At 10000 XP: Platinum Badge + Animation Pack + Rising Star
        // At 100000 XP: Exclusive Workouts + FameFit Elite (no badge at this level)
        XCTAssertEqual(badges.count, 2, "Should have Gold and Platinum badges")
        XCTAssertEqual(features.count, 1, "Should have Exclusive Workouts")
        XCTAssertEqual(customizations.count, 2, "Should have Workout Themes, Animation Pack")
        XCTAssertEqual(achievements.count, 2, "Should have Rising Star, FameFit Elite")
    }

    // MARK: - Reset Tests

    func testResetClearsAllUnlocks() {
        // Given - Record a single unlock first
        let bronzeBadge = XPCalculator.unlockables.first { $0.xpRequired == 100 }!
        service.recordUnlock(bronzeBadge)

        // Verify it was recorded
        XCTAssertTrue(service.hasUnlocked(bronzeBadge), "Should have recorded the unlock")
        let initialCount = service.getUnlockedItems().count
        XCTAssertGreaterThan(initialCount, 0, "Should have at least one unlock")

        // When
        service.resetAllUnlocks()

        // Then
        XCTAssertEqual(service.getUnlockedItems().count, 0, "Should have no unlocks after reset")
        XCTAssertFalse(service.hasUnlocked(bronzeBadge), "Bronze badge should not be unlocked")
        XCTAssertNil(service.getUnlockTimestamp(for: bronzeBadge), "Should have no timestamp")
    }

    // MARK: - Persistence Tests

    func testUnlocksPersistAcrossInstances() {
        // Given - Record unlocks with first instance
        let bronzeBadge = XPCalculator.unlockables.first { $0.name == "Bronze Badge" }!
        service.recordUnlock(bronzeBadge)

        // When - Create new instance with same UserDefaults
        let newService = UnlockStorageService(userDefaults: testUserDefaults)

        // Then - Should still have the unlocks (Bronze Badge + Custom Messages at 100 XP)
        XCTAssertTrue(newService.hasUnlocked(bronzeBadge))
        XCTAssertEqual(newService.getUnlockedItems().count, 2, "Should persist all unlocks at 100 XP")
    }
}
