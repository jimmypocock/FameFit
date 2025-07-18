//
//  MainViewModelTests.swift
//  FameFitTests
//
//  Tests for MainViewModel implementation
//

import XCTest
import Combine
@testable import FameFit

class MainViewModelTests: XCTestCase {
    private var sut: MainViewModel!
    private var mockAuthManager: MockAuthenticationManager!
    private var mockCloudKitManager: MockCloudKitManager!
    private var mockNotificationStore: MockNotificationStore!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockAuthManager = MockAuthenticationManager()
        mockCloudKitManager = MockCloudKitManager()
        mockNotificationStore = MockNotificationStore()
        cancellables = []
        
        sut = MainViewModel(
            authManager: mockAuthManager,
            cloudKitManager: mockCloudKitManager,
            notificationStore: mockNotificationStore
        )
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockAuthManager = nil
        mockCloudKitManager = nil
        mockNotificationStore = nil
        super.tearDown()
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testConformsToMainViewModeling() {
        // Given
        let protocolInstance: any MainViewModeling = sut
        
        // When/Then - Should compile without errors
        XCTAssertNotNil(protocolInstance.userName)
        XCTAssertNotNil(protocolInstance.followerCount)
        XCTAssertNotNil(protocolInstance.followerTitle)
        XCTAssertNotNil(protocolInstance.totalWorkouts)
        XCTAssertNotNil(protocolInstance.currentStreak)
        XCTAssertNotNil(protocolInstance.daysAsMember)
        XCTAssertNotNil(protocolInstance.hasUnreadNotifications)
        XCTAssertNotNil(protocolInstance.unreadNotificationCount)
    }
    
    // MARK: - Property Binding Tests
    
    func testUserNameBindsToCloudKitManager() {
        // Given
        let expectedName = "Test User"
        
        // When
        mockCloudKitManager.userName = expectedName
        
        // Then
        XCTAssertEqual(sut.userName, expectedName)
    }
    
    func testFollowerCountBindsToCloudKitManager() {
        // Given
        let expectedCount = 42
        
        // When
        mockCloudKitManager.followerCount = expectedCount
        
        // Then
        XCTAssertEqual(sut.followerCount, expectedCount)
    }
    
    func testTotalWorkoutsBindsToCloudKitManager() {
        // Given
        let expectedWorkouts = 15
        
        // When
        mockCloudKitManager.totalWorkouts = expectedWorkouts
        
        // Then
        XCTAssertEqual(sut.totalWorkouts, expectedWorkouts)
    }
    
    func testCurrentStreakBindsToCloudKitManager() {
        // Given
        let expectedStreak = 7
        
        // When
        mockCloudKitManager.currentStreak = expectedStreak
        
        // Then
        XCTAssertEqual(sut.currentStreak, expectedStreak)
    }
    
    func testJoinDateBindsToCloudKitManager() {
        // Given
        let expectedDate = Date().addingTimeInterval(-30 * 24 * 3600) // 30 days ago
        
        // When
        mockCloudKitManager.joinTimestamp = expectedDate
        
        // Then
        XCTAssertEqual(sut.joinDate, expectedDate)
    }
    
    func testLastWorkoutDateBindsToCloudKitManager() {
        // Given
        let expectedDate = Date().addingTimeInterval(-2 * 3600) // 2 hours ago
        
        // When
        mockCloudKitManager.lastWorkoutTimestamp = expectedDate
        
        // Then
        XCTAssertEqual(sut.lastWorkoutDate, expectedDate)
    }
    
    func testUnreadNotificationCountBindsToNotificationStore() {
        // Given
        let expectedCount = 3
        
        // When
        mockNotificationStore.unreadCount = expectedCount
        
        // Then
        XCTAssertEqual(sut.unreadNotificationCount, expectedCount)
    }
    
    func testHasUnreadNotificationsUpdatesCorrectly() {
        // Given - Initially false
        mockNotificationStore.unreadCount = 0
        XCTAssertFalse(sut.hasUnreadNotifications)
        
        // When
        mockNotificationStore.unreadCount = 1
        
        // Then
        XCTAssertTrue(sut.hasUnreadNotifications)
    }
    
    // MARK: - Computed Property Tests
    
    func testFollowerTitleUpdatesWhenFollowerCountChanges() {
        // Given
        mockCloudKitManager.followerCount = 50
        sut.refreshData() // Sync initial state
        let initialTitle = sut.followerTitle
        
        // When
        mockCloudKitManager.followerCount = 1000
        sut.refreshData() // Sync new state
        let newTitle = sut.followerTitle
        
        // Then
        XCTAssertEqual(initialTitle, "Fitness Newbie") // 50 followers
        XCTAssertEqual(newTitle, "Rising Star") // 1000 followers
        XCTAssertNotEqual(initialTitle, newTitle)
    }
    
    func testDaysAsMemberCalculationWithValidJoinDate() {
        // Given
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
        
        // When
        mockCloudKitManager.joinTimestamp = thirtyDaysAgo
        
        // Then
        XCTAssertEqual(sut.daysAsMember, 30)
    }
    
    func testDaysAsMemberCalculationWithNilJoinDate() {
        // Given
        mockCloudKitManager.joinTimestamp = nil
        
        // When/Then
        XCTAssertEqual(sut.daysAsMember, 0)
    }
    
    // MARK: - Action Method Tests
    
    func testRefreshDataCallsCloudKitManager() {
        // When
        sut.refreshData()
        
        // Then
        XCTAssertTrue(mockCloudKitManager.fetchUserRecordCalled)
    }
    
    func testSignOutCallsAuthManager() {
        // When
        sut.signOut()
        
        // Then
        XCTAssertTrue(mockAuthManager.signOutCalled)
    }
    
    func testMarkNotificationsAsReadCallsNotificationStore() {
        // When
        sut.markNotificationsAsRead()
        
        // Then
        XCTAssertTrue(mockNotificationStore.markAllAsReadCalled)
    }
    
    // MARK: - Reactive Property Tests
    
    func testUserNameChangesReactToCloudKitManager() {
        // Given
        let initialName = sut.userName
        
        // When
        mockCloudKitManager.userName = "New User"
        
        // Then
        XCTAssertNotEqual(sut.userName, initialName)
        XCTAssertEqual(sut.userName, "New User")
    }
    
    func testFollowerCountChangesReactToCloudKitManager() {
        // Given
        let initialCount = sut.followerCount
        
        // When
        mockCloudKitManager.followerCount = 999
        
        // Then
        XCTAssertNotEqual(sut.followerCount, initialCount)
        XCTAssertEqual(sut.followerCount, 999)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflowUpdatesAllProperties() {
        // Given - Set initial state
        mockCloudKitManager.userName = "Initial User"
        mockCloudKitManager.followerCount = 10
        mockCloudKitManager.totalWorkouts = 5
        mockCloudKitManager.currentStreak = 1
        mockNotificationStore.unreadCount = 0
        
        // When - Simulate a workout completion
        mockCloudKitManager.userName = "Updated User"
        mockCloudKitManager.followerCount = 15
        mockCloudKitManager.totalWorkouts = 6
        mockCloudKitManager.currentStreak = 2
        mockNotificationStore.unreadCount = 1
        
        // Then - All properties should update
        XCTAssertEqual(sut.userName, "Updated User")
        XCTAssertEqual(sut.followerCount, 15)
        XCTAssertEqual(sut.totalWorkouts, 6)
        XCTAssertEqual(sut.currentStreak, 2)
        XCTAssertTrue(sut.hasUnreadNotifications)
        XCTAssertEqual(sut.unreadNotificationCount, 1)
    }
    
    func testMemoryManagementWithWeakReferences() {
        // Given
        weak var weakSut = sut
        weak var weakMockCloudKit = mockCloudKitManager
        weak var weakMockNotificationStore = mockNotificationStore
        
        // When
        sut = nil
        mockCloudKitManager = nil
        mockNotificationStore = nil
        
        // Then - Should not create retain cycles
        // Note: This test might be flaky due to ARC behavior, but it's good to have
        XCTAssertNil(weakSut)
        XCTAssertNil(weakMockCloudKit)
        XCTAssertNil(weakMockNotificationStore)
    }
}