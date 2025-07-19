//
//  UnlockNotificationServiceTests.swift
//  FameFitTests
//
//  Tests for unlock notification service
//

import XCTest
@testable import FameFit

final class UnlockNotificationServiceTests: XCTestCase {
    private var service: UnlockNotificationService!
    private var mockNotificationStore: MockNotificationStore!
    private var mockUnlockStorage: MockUnlockStorageService!
    private var testUserDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        
        mockNotificationStore = MockNotificationStore()
        mockUnlockStorage = MockUnlockStorageService()
        testUserDefaults = UserDefaults(suiteName: "com.jimmypocock.FameFit.tests")!
        
        // Clear all keys to ensure test isolation
        let keys = testUserDefaults.dictionaryRepresentation().keys
        for key in keys {
            testUserDefaults.removeObject(forKey: key)
        }
        testUserDefaults.synchronize()
        
        service = UnlockNotificationService(
            notificationStore: mockNotificationStore,
            unlockStorage: mockUnlockStorage,
            userDefaults: testUserDefaults
        )
    }
    
    override func tearDown() {
        service = nil
        mockNotificationStore = nil
        mockUnlockStorage = nil
        
        // Clear all keys
        let keys = testUserDefaults.dictionaryRepresentation().keys
        for key in keys {
            testUserDefaults.removeObject(forKey: key)
        }
        testUserDefaults.synchronize()
        testUserDefaults = nil
        
        super.tearDown()
    }
    
    // MARK: - Unlock Detection Tests
    
    func testDetectsNewUnlockWhenCrossingThreshold() async {
        // Given - Bronze Badge unlocks at 100 XP
        let previousXP = 50
        let currentXP = 150
        
        // When
        await service.checkForNewUnlocks(previousXP: previousXP, currentXP: currentXP)
        
        // Then - Should have notifications for Bronze Badge, Custom Messages, and Level Up
        XCTAssertEqual(mockNotificationStore.notifications.count, 3, "Should have 2 unlocks + 1 level up")
        
        // Check we have unlock notifications
        let unlockNotifications = mockNotificationStore.notifications.filter { $0.title.contains("New Unlock") }
        XCTAssertEqual(unlockNotifications.count, 2, "Should have 2 unlock notifications")
        
        // Check we have level up notification
        let levelUpNotification = mockNotificationStore.notifications.first { $0.title.contains("Level Up") }
        XCTAssertNotNil(levelUpNotification, "Should have level up notification")
        
        // And - Should have recorded both unlocks
        let unlockedItems = mockUnlockStorage.getUnlockedItems()
        XCTAssertEqual(unlockedItems.count, 2, "Should have 2 unlocks at 100 XP")
        
        let unlockedNames = Set(unlockedItems.map { $0.name })
        XCTAssertTrue(unlockedNames.contains("Bronze Badge"))
        XCTAssertTrue(unlockedNames.contains("Custom Messages"))
    }
    
    func testDetectsMultipleUnlocksInOneUpdate() async {
        // Given - Multiple unlocks: Bronze (100), Custom Messages (100), Silver (500)
        let previousXP = 50
        let currentXP = 600
        
        // When
        await service.checkForNewUnlocks(previousXP: previousXP, currentXP: currentXP)
        
        // Then - Should have notifications for all unlocks plus level ups
        // Bronze (100), Custom Messages (100), Silver (500), Profile Theme (500)
        // Plus level ups: Level 2 (100 XP) and Level 3 (500 XP)
        XCTAssertEqual(mockNotificationStore.notifications.count, 6, "Should have 4 unlocks + 2 level ups")
        
        // And - Should have recorded all unlocks
        let unlockedItems = mockUnlockStorage.getUnlockedItems()
        XCTAssertEqual(unlockedItems.count, 4, "Should have 4 unlocks")
        
        let unlockedNames = Set(unlockedItems.map { $0.name })
        XCTAssertTrue(unlockedNames.contains("Bronze Badge"))
        XCTAssertTrue(unlockedNames.contains("Custom Messages"))
        XCTAssertTrue(unlockedNames.contains("Silver Badge"))
        XCTAssertTrue(unlockedNames.contains("Profile Theme"))
    }
    
    func testDoesNotDuplicateNotifications() async {
        // Given
        let previousXP = 50
        let currentXP = 150
        
        // When - First check
        await service.checkForNewUnlocks(previousXP: previousXP, currentXP: currentXP)
        let firstCount = mockNotificationStore.notifications.count
        
        // When - Second check with same XP
        await service.checkForNewUnlocks(previousXP: currentXP, currentXP: currentXP + 10)
        
        // Then - Should not re-notify about Bronze Badge
        XCTAssertEqual(mockNotificationStore.notifications.count, firstCount)
    }
    
    func testIgnoresNegativeXPChanges() async {
        // Given
        let previousXP = 150
        let currentXP = 100
        
        // When
        await service.checkForNewUnlocks(previousXP: previousXP, currentXP: currentXP)
        
        // Then - Should not create any notifications
        XCTAssertEqual(mockNotificationStore.notifications.count, 0)
        XCTAssertEqual(mockUnlockStorage.getUnlockedItems().count, 0)
    }
    
    // MARK: - Level Up Tests
    
    func testDetectsLevelUp() async {
        // Given - Level 1 to 2 happens at 100 XP
        let previousXP = 50
        let currentXP = 150
        
        // When
        await service.checkForNewUnlocks(previousXP: previousXP, currentXP: currentXP)
        
        // Then - Should have level up notification
        let levelUpNotification = mockNotificationStore.notifications.first { $0.title.contains("Level Up") }
        XCTAssertNotNil(levelUpNotification)
        XCTAssertTrue(levelUpNotification?.body.contains("Level 2") ?? false)
        XCTAssertTrue(levelUpNotification?.body.contains("Fitness Newbie") ?? false)
    }
    
    func testNotifiesLevelUpDirectly() async {
        // When
        await service.notifyLevelUp(newLevel: 5, title: "Workout Warrior")
        
        // Then
        XCTAssertEqual(mockNotificationStore.notifications.count, 1)
        let notification = mockNotificationStore.notifications.first!
        XCTAssertTrue(notification.title.contains("Level Up"))
        XCTAssertTrue(notification.body.contains("Level 5"))
        XCTAssertTrue(notification.body.contains("Workout Warrior"))
    }
    
    func testDoesNotDuplicateLevelUpNotifications() async {
        // When - First notification
        await service.notifyLevelUp(newLevel: 3, title: "Gym Regular")
        let firstCount = mockNotificationStore.notifications.count
        
        // When - Try same level again
        await service.notifyLevelUp(newLevel: 3, title: "Gym Regular")
        
        // Then - Should not duplicate
        XCTAssertEqual(mockNotificationStore.notifications.count, firstCount)
    }
    
    // MARK: - Character Selection Tests
    
    func testSelectsCorrectCharacterForLevel() async {
        // Test different level ranges
        let testCases: [(level: Int, expectedCharacter: FameFitCharacter)] = [
            (1, .zen),
            (3, .zen),
            (5, .sierra),
            (7, .sierra),
            (10, .chad),
            (13, .chad)
        ]
        
        for testCase in testCases {
            mockNotificationStore.reset()
            
            await service.notifyLevelUp(newLevel: testCase.level, title: "Test Title")
            
            let notification = mockNotificationStore.notifications.first
            XCTAssertEqual(notification?.character, testCase.expectedCharacter,
                          "Level \(testCase.level) should use character \(testCase.expectedCharacter)")
        }
    }
    
    // MARK: - Permission Tests
    
    func testRequestNotificationPermission() async {
        // Note: This test can't fully test the system permission dialog
        // but ensures the method exists and returns a boolean
        let result = await service.requestNotificationPermission()
        XCTAssertTrue(result == true || result == false) // Just verify it returns a bool
    }
}