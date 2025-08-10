//
//  MainViewModelTests.swift
//  FameFitTests
//
//  Tests for MainViewModel implementation
//

import Combine
@testable import FameFit
import XCTest

class MainViewModelTests: XCTestCase {
    private var sut: MainViewModel!
    private var mockAuthManager: MockAuthenticationService!
    private var mockCloudKitService: MockCloudKitService!
    private var mockNotificationStore: MockNotificationStore!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockAuthManager = MockAuthenticationService()
        mockCloudKitService = MockCloudKitService()
        mockNotificationStore = MockNotificationStore()
        cancellables = []

        sut = MainViewModel(
            authManager: mockAuthManager,
            cloudKitManager: mockCloudKitService,
            notificationStore: mockNotificationStore,
            userProfileService: MockUserProfileService(),
            socialFollowingService: MockSocialFollowingService()
        )
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockAuthManager = nil
        mockCloudKitService = nil
        mockNotificationStore = nil
        super.tearDown()
    }

    // MARK: - Protocol Conformance Tests

    func testConformsToMainViewModeling() {
        // Given
        let protocolInstance: any MainViewModeling = sut

        // When/Then - Should compile without errors
        XCTAssertNotNil(protocolInstance.userName)
        XCTAssertNotNil(protocolInstance.totalXP)
        XCTAssertNotNil(protocolInstance.xpTitle)
        XCTAssertNotNil(protocolInstance.totalWorkouts)
        XCTAssertNotNil(protocolInstance.currentStreak)
        XCTAssertNotNil(protocolInstance.daysAsMember)
        XCTAssertNotNil(protocolInstance.hasUnreadNotifications)
        XCTAssertNotNil(protocolInstance.unreadNotificationCount)
    }

    // MARK: - Property Binding Tests

    func testUserNameBindsToCloudKitService() {
        // Given
        let expectedName = "Test User"

        // When
        mockCloudKitService.userName = expectedName

        // Then
        XCTAssertEqual(sut.userName, expectedName)
    }

    func testInfluencerXPBindsToCloudKitService() {
        // Given
        let expectedCount = 42

        // When
        mockCloudKitService.totalXP = expectedCount

        // Then
        XCTAssertEqual(sut.totalXP, expectedCount)
    }

    func testTotalWorkoutsBindsToCloudKitService() {
        // Given
        let expectedWorkouts = 15

        // When
        mockCloudKitService.totalWorkouts = expectedWorkouts

        // Then
        XCTAssertEqual(sut.totalWorkouts, expectedWorkouts)
    }

    func testCurrentStreakBindsToCloudKitService() {
        // Given
        let expectedStreak = 7

        // When
        mockCloudKitService.currentStreak = expectedStreak

        // Then
        XCTAssertEqual(sut.currentStreak, expectedStreak)
    }

    func testJoinDateBindsToCloudKitService() {
        // Given
        let expectedDate = Date().addingTimeInterval(-30 * 24 * 3_600) // 30 days ago

        // When
        mockCloudKitService.joinTimestamp = expectedDate

        // Then
        XCTAssertEqual(sut.joinDate, expectedDate)
    }

    func testLastWorkoutDateBindsToCloudKitService() {
        // Given
        let expectedDate = Date().addingTimeInterval(-2 * 3_600) // 2 hours ago

        // When
        mockCloudKitService.lastWorkoutTimestamp = expectedDate

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

    func testXPTitleUpdatesWhenInfluencerXPChanges() {
        // Given
        mockCloudKitService.totalXP = 50
        sut.refreshData() // Sync initial state
        let initialTitle = sut.xpTitle

        // When
        mockCloudKitService.totalXP = 1_000
        sut.refreshData() // Sync new state
        let newTitle = sut.xpTitle

        // Then
        XCTAssertEqual(initialTitle, "Fitness Newbie") // 50 XP
        XCTAssertEqual(newTitle, "Rising Star") // 1000 XP
        XCTAssertNotEqual(initialTitle, newTitle)
    }

    func testDaysAsMemberCalculationWithValidJoinDate() {
        // Given
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3_600)

        // When
        mockCloudKitService.joinTimestamp = thirtyDaysAgo

        // Then
        XCTAssertEqual(sut.daysAsMember, 30)
    }

    func testDaysAsMemberCalculationWithNilJoinDate() {
        // Given
        mockCloudKitService.joinTimestamp = nil

        // When/Then
        XCTAssertEqual(sut.daysAsMember, 0)
    }

    // MARK: - Action Method Tests

    func testRefreshDataCallsCloudKitService() {
        // When
        sut.refreshData()

        // Then
        XCTAssertTrue(mockCloudKitService.fetchUserRecordCalled)
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

    func testUserNameChangesReactToCloudKitService() {
        // Given
        let initialName = sut.userName

        // When
        mockCloudKitService.userName = "New User"

        // Then
        XCTAssertNotEqual(sut.userName, initialName)
        XCTAssertEqual(sut.userName, "New User")
    }

    func testInfluencerXPChangesReactToCloudKitService() {
        // Given
        let initialCount = sut.totalXP

        // When
        mockCloudKitService.totalXP = 999

        // Then
        XCTAssertNotEqual(sut.totalXP, initialCount)
        XCTAssertEqual(sut.totalXP, 999)
    }

    // MARK: - Integration Tests

    func testCompleteWorkflowUpdatesAllProperties() {
        // Given - Set initial state
        mockCloudKitService.userName = "Initial User"
        mockCloudKitService.totalXP = 10
        mockCloudKitService.totalWorkouts = 5
        mockCloudKitService.currentStreak = 1
        mockNotificationStore.unreadCount = 0

        // When - Simulate a workout completion
        mockCloudKitService.userName = "Updated User"
        mockCloudKitService.totalXP = 15
        mockCloudKitService.totalWorkouts = 6
        mockCloudKitService.currentStreak = 2
        mockNotificationStore.unreadCount = 1

        // Then - All properties should update
        XCTAssertEqual(sut.userName, "Updated User")
        XCTAssertEqual(sut.totalXP, 15)
        XCTAssertEqual(sut.totalWorkouts, 6)
        XCTAssertEqual(sut.currentStreak, 2)
        XCTAssertTrue(sut.hasUnreadNotifications)
        XCTAssertEqual(sut.unreadNotificationCount, 1)
    }

    func testMemoryManagementWithWeakReferences() {
        // Given
        weak var weakSut = sut
        weak var weakMockCloudKit = mockCloudKitService
        weak var weakMockNotificationStore = mockNotificationStore

        // When
        sut = nil
        mockCloudKitService = nil
        mockNotificationStore = nil

        // Then - Should not create retain cycles
        // Note: This test might be flaky due to ARC behavior, but it's good to have
        XCTAssertNil(weakSut)
        XCTAssertNil(weakMockCloudKit)
        XCTAssertNil(weakMockNotificationStore)
    }
}
