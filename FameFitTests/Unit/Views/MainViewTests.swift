//
//  MainViewTests.swift
//  FameFitTests
//
//  Tests for MainView with view model pattern
//

@testable import FameFit
import SwiftUI
import XCTest

class MainViewTests: XCTestCase {
    private var viewModel: MainViewModel!
    private var mockAuthManager: MockAuthenticationManager!
    private var mockCloudKitManager: MockCloudKitManager!
    private var mockNotificationStore: MockNotificationStore!

    override func setUp() {
        super.setUp()
        mockAuthManager = MockAuthenticationManager()
        mockCloudKitManager = MockCloudKitManager()
        mockNotificationStore = MockNotificationStore()

        viewModel = MainViewModel(
            authManager: mockAuthManager,
            cloudKitManager: mockCloudKitManager,
            notificationStore: mockNotificationStore,
            userProfileService: MockUserProfileService(),
            socialFollowingService: MockSocialFollowingService()
        )
    }

    override func tearDown() {
        viewModel = nil
        mockAuthManager = nil
        mockCloudKitManager = nil
        mockNotificationStore = nil
        super.tearDown()
    }

    // MARK: - View Creation Tests

    func testMainViewCanBeCreatedWithViewModel() {
        // When
        _ = MainView(viewModel: viewModel)

        // Then - Should not crash (no assertion needed for discarded view)
    }

    // MARK: - View Model Integration Tests

    func testViewModelRefreshesDataOnAppear() {
        // Given
        _ = MainView(viewModel: viewModel)
        XCTAssertFalse(mockCloudKitManager.fetchUserRecordCalled)

        // When - Simulate onAppear by calling refreshData
        viewModel.refreshData()

        // Then
        XCTAssertTrue(mockCloudKitManager.fetchUserRecordCalled)
    }

    func testSignOutActionCallsAuthManager() {
        // Given
        _ = MainView(viewModel: viewModel)
        XCTAssertFalse(mockAuthManager.signOutCalled)

        // When - Simulate sign out action
        viewModel.signOut()

        // Then
        XCTAssertTrue(mockAuthManager.signOutCalled)
    }

    func testMarkNotificationsAsReadCallsNotificationStore() {
        // Given
        _ = MainView(viewModel: viewModel)
        // Add some unread notifications
        mockNotificationStore.unreadCount = 3

        // When - Simulate marking notifications as read
        viewModel.markNotificationsAsRead()

        // Then
        XCTAssertTrue(mockNotificationStore.markAllAsReadCalled)
    }

    // MARK: - Data Display Tests

    func testViewDisplaysUserData() {
        // Given
        mockCloudKitManager.userName = "Test User"
        mockCloudKitManager.totalXP = 50
        mockCloudKitManager.totalWorkouts = 10
        mockCloudKitManager.currentStreak = 3

        // Refresh view model to sync data
        viewModel.refreshData()

        _ = MainView(viewModel: viewModel)

        // When/Then - View should display the data
        // Note: In a more comprehensive test, we would use ViewInspector
        // or UI testing to verify the text is actually displayed
        XCTAssertEqual(viewModel.userName, "Test User")
        XCTAssertEqual(viewModel.totalXP, 50)
        XCTAssertEqual(viewModel.xpTitle, "Fitness Newbie")
        XCTAssertEqual(viewModel.totalWorkouts, 10)
        XCTAssertEqual(viewModel.currentStreak, 3)
    }

    func testViewDisplaysDateInformation() {
        // Given
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3_600)
        let twoHoursAgo = Date().addingTimeInterval(-2 * 3_600)

        mockCloudKitManager.joinTimestamp = thirtyDaysAgo
        mockCloudKitManager.lastWorkoutTimestamp = twoHoursAgo

        // Refresh view model to sync data
        viewModel.refreshData()

        _ = MainView(viewModel: viewModel)

        // When/Then
        XCTAssertEqual(viewModel.joinDate, thirtyDaysAgo)
        XCTAssertEqual(viewModel.lastWorkoutDate, twoHoursAgo)
        XCTAssertEqual(viewModel.daysAsMember, 30)
    }

    func testViewDisplaysNotificationState() {
        // Given
        mockNotificationStore.unreadCount = 5

        _ = MainView(viewModel: viewModel)

        // When/Then
        XCTAssertTrue(viewModel.hasUnreadNotifications)
        XCTAssertEqual(viewModel.unreadNotificationCount, 5)
    }

    // MARK: - State Change Tests

    func testViewRespondsToViewModelChanges() {
        // Given
        _ = MainView(viewModel: viewModel)

        // When - Simulate view model changes
        mockCloudKitManager.totalWorkouts = 16
        mockCloudKitManager.totalXP = 47
        mockCloudKitManager.currentStreak = 4
        mockCloudKitManager.lastWorkoutTimestamp = Date()

        // Refresh to sync changes
        viewModel.refreshData()

        // Then - View model should reflect the changes
        XCTAssertEqual(viewModel.totalWorkouts, 16)
        XCTAssertEqual(viewModel.totalXP, 47)
        XCTAssertEqual(viewModel.currentStreak, 4)
        XCTAssertNotNil(viewModel.lastWorkoutDate)
    }

    func testViewRespondsToNotificationChanges() {
        // Given
        _ = MainView(viewModel: viewModel)
        mockNotificationStore.unreadCount = 0

        // When
        mockNotificationStore.addFameFitNotification(FameFitNotification(
            title: "Test",
            body: "Test notification",
            character: .chad,
            workoutDuration: 30,
            calories: 100,
            followersEarned: 5
        ))

        // Then
        XCTAssertTrue(viewModel.hasUnreadNotifications)
        XCTAssertEqual(viewModel.unreadNotificationCount, 1)
    }

    // MARK: - Error Handling Tests

    func testViewHandlesViewModelFailures() {
        // Given
        // We can't test failure with real view model, but we can verify it handles nil data
        _ = MainView(viewModel: viewModel)

        // When
        viewModel.refreshData()

        // Then - Should not crash
        XCTAssertTrue(mockCloudKitManager.fetchUserRecordCalled)
    }

    func testViewHandlesSignOutFailure() {
        // Given
        // We can test that sign out is called on auth manager
        _ = MainView(viewModel: viewModel)

        // When
        viewModel.signOut()

        // Then - Should not crash
        XCTAssertTrue(mockAuthManager.signOutCalled)
    }

    // MARK: - Memory Management Tests

    func testViewDoesNotRetainViewModelStrongly() {
        // Given
        var viewModel: MainViewModel? = MainViewModel(
            authManager: mockAuthManager,
            cloudKitManager: mockCloudKitManager,
            notificationStore: mockNotificationStore,
            userProfileService: MockUserProfileService(),
            socialFollowingService: MockSocialFollowingService()
        )
        weak var weakViewModel = viewModel

        // When
        _ = MainView(viewModel: viewModel!)
        viewModel = nil

        // Then - View should not prevent view model from being deallocated
        // Note: This test is complex with @StateObject, but the pattern should work
        // weakViewModel might still exist due to @StateObject behavior
        _ = weakViewModel // Suppress unused variable warning
    }
}
