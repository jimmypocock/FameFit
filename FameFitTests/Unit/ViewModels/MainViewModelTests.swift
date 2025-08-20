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
    private var mockWatchConnectivityManager: MockWatchConnectivityManager!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockAuthManager = MockAuthenticationService()
        mockCloudKitService = MockCloudKitService()
        mockNotificationStore = MockNotificationStore()
        mockWatchConnectivityManager = MockWatchConnectivityManager()
        cancellables = []

        sut = MainViewModel(
            authManager: mockAuthManager,
            cloudKitManager: mockCloudKitService,
            notificationStore: mockNotificationStore,
            userProfileService: MockUserProfileService(),
            socialFollowingService: MockSocialFollowingService(),
            watchConnectivityManager: mockWatchConnectivityManager
        )
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockAuthManager = nil
        mockCloudKitService = nil
        mockNotificationStore = nil
        mockWatchConnectivityManager = nil
        super.tearDown()
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
        let profile = UserProfile(
            id: "test-id",
            userID: "test-user",
            username: "testuser",
            bio: "Test bio",
            workoutCount: 10,
            totalXP: 100,
            creationDate: thirtyDaysAgo,
            modificationDate: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )

        // When
        sut.userProfile = profile

        // Then
        XCTAssertEqual(sut.daysAsMember, 30)
    }

    func testDaysAsMemberCalculationWithNilJoinDate() {
        // Given/When
        sut.userProfile = nil

        // Then
        XCTAssertEqual(sut.daysAsMember, 0)
    }



    // MARK: - Integration Tests

    func testCompleteWorkflowUpdatesAllProperties() {
        // Given - Set initial state
        mockCloudKitService.username = "Initial User"
        mockCloudKitService.totalXP = 10
        mockCloudKitService.totalWorkouts = 5
        mockCloudKitService.currentStreak = 1
        mockNotificationStore.unreadCount = 0

        // When - Simulate a workout completion
        mockCloudKitService.username = "Updated User"
        mockCloudKitService.totalXP = 15
        mockCloudKitService.totalWorkouts = 6
        mockCloudKitService.currentStreak = 2
        mockNotificationStore.unreadCount = 1

        // Then - All properties should update
        XCTAssertEqual(sut.username, "Updated User")
        XCTAssertEqual(sut.totalXP, 15)
        XCTAssertEqual(sut.totalWorkouts, 6)
        XCTAssertEqual(sut.currentStreak, 2)
        XCTAssertTrue(sut.hasUnreadNotifications)
        XCTAssertEqual(sut.unreadNotificationCount, 1)
    }

}
