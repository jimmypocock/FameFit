//
//  NotificationCenterViewModelTests.swift
//  FameFitTests
//
//  Unit tests for NotificationCenterViewModel
//

import Combine
@testable import FameFit
import XCTest

@MainActor
class NotificationCenterViewModelTests: XCTestCase {
    private var sut: NotificationCenterViewModel!
    private var mockNotificationStore: MockNotificationStore!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        sut = NotificationCenterViewModel()
        mockNotificationStore = MockNotificationStore()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        sut = nil
        mockNotificationStore = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testConfigure_SetsUpNotificationStore() {
        // When
        sut.configure(notificationStore: mockNotificationStore)

        // Then
        XCTAssertEqual(sut.notifications.count, 0)
        XCTAssertEqual(sut.unreadCount, 0)
    }

    func testConfigure_SubscribesToNotificationUpdates() {
        // Given
        let testNotification = createTestNotification(.workoutCompleted)
        let expectation = XCTestExpectation(description: "Notification received")

        // When
        sut.configure(notificationStore: mockNotificationStore)

        // Subscribe to check when notification is received
        sut.$notifications
            .dropFirst() // Skip initial empty value
            .sink { notifications in
                if notifications.count == 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        mockNotificationStore.addNotification(testNotification)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(sut.notifications.count, 1)
        XCTAssertEqual(sut.notifications.first?.id, testNotification.id)
    }

    func testConfigure_SubscribesToUnreadCountUpdates() {
        // Given
        let unreadNotification = createTestNotification(.workoutCompleted, isRead: false)
        let expectation = XCTestExpectation(description: "Unread count updated")

        // When
        sut.configure(notificationStore: mockNotificationStore)

        // Subscribe to check when unread count is updated
        sut.$unreadCount
            .dropFirst() // Skip initial 0 value
            .sink { count in
                if count == 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        mockNotificationStore.addNotification(unreadNotification)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(sut.unreadCount, 1)
    }

    // MARK: - Data Loading Tests

    func testLoadNotifications_CallsNotificationStore() {
        // Given
        sut.configure(notificationStore: mockNotificationStore)
        mockNotificationStore.loadNotificationsCalled = false

        // When
        sut.loadNotifications()

        // Then
        XCTAssertTrue(mockNotificationStore.loadNotificationsCalled)
        XCTAssertFalse(sut.isLoading)
    }

    func testRefreshNotifications_CallsNotificationStore() async {
        // Given
        sut.configure(notificationStore: mockNotificationStore)
        mockNotificationStore.loadNotificationsCalled = false

        // When
        await sut.refreshNotifications()

        // Then
        XCTAssertTrue(mockNotificationStore.loadNotificationsCalled)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Filtering Tests

    func testFilteredNotifications_AllTab_ReturnsAllNotifications() {
        // Given
        let notifications = [
            createTestNotification(.workoutCompleted),
            createTestNotification(.newFollower),
            createTestNotification(.unlockAchieved)
        ]
        sut.notifications = notifications

        // When
        let filtered = sut.filteredNotifications(for: 0) // All tab

        // Then
        XCTAssertEqual(filtered.count, 3)
    }

    func testFilteredNotifications_UnreadTab_ReturnsUnreadOnly() {
        // Given
        let readNotification = createTestNotification(.workoutCompleted, isRead: true)
        let unreadNotification = createTestNotification(.newFollower, isRead: false)
        sut.notifications = [readNotification, unreadNotification]

        // When
        let filtered = sut.filteredNotifications(for: 1) // Unread tab

        // Then
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, unreadNotification.id)
    }

    func testFilteredNotifications_SocialTab_ReturnsSocialNotificationsOnly() {
        // Given
        let workoutNotification = createTestNotification(.workoutCompleted)
        let socialNotification = createTestNotification(.newFollower)
        let achievementNotification = createTestNotification(.unlockAchieved)
        sut.notifications = [workoutNotification, socialNotification, achievementNotification]

        // When
        let filtered = sut.filteredNotifications(for: 2) // Social tab

        // Then
        XCTAssertEqual(filtered.count, 1) // Only social notifications
        XCTAssertTrue(filtered.contains { $0.type == .newFollower })
        XCTAssertFalse(filtered.contains { $0.type == .unlockAchieved })
    }

    func testFilteredNotifications_WorkoutsTab_ReturnsWorkoutNotificationsOnly() {
        // Given
        let workoutNotification = createTestNotification(.workoutCompleted)
        let socialNotification = createTestNotification(.newFollower)
        let achievementNotification = createTestNotification(.unlockAchieved)
        sut.notifications = [workoutNotification, socialNotification, achievementNotification]

        // When
        let filtered = sut.filteredNotifications(for: 3) // Workouts tab

        // Then
        XCTAssertEqual(filtered.count, 2) // Workout + Achievement (workout-related)
        XCTAssertTrue(filtered.contains { $0.type == .workoutCompleted })
        XCTAssertTrue(filtered.contains { $0.type == .unlockAchieved })
    }

    // MARK: - Action Tests

    func testMarkAsRead_CallsNotificationStore() {
        // Given
        sut.configure(notificationStore: mockNotificationStore)
        let testId = "test-id"

        // When
        sut.markAsRead(testId)

        // Then
        XCTAssertTrue(mockNotificationStore.markAsReadCalled)
        XCTAssertEqual(mockNotificationStore.lastMarkedReadId, testId)
    }

    func testMarkAllAsRead_CallsNotificationStore() {
        // Given
        sut.configure(notificationStore: mockNotificationStore)

        // When
        sut.markAllAsRead()

        // Then
        XCTAssertTrue(mockNotificationStore.markAllAsReadCalled)
    }

    func testClearAllNotifications_CallsNotificationStore() {
        // Given
        sut.configure(notificationStore: mockNotificationStore)

        // When
        sut.clearAllNotifications()

        // Then
        XCTAssertTrue(mockNotificationStore.clearAllCalled)
    }

    func testDeleteNotification_CallsNotificationStore() {
        // Given
        sut.configure(notificationStore: mockNotificationStore)
        let testId = "test-id"

        // When
        sut.deleteNotification(testId)

        // Then
        XCTAssertTrue(mockNotificationStore.deleteNotificationCalled)
    }

    // MARK: - Interaction Handling Tests

    func testHandleNotificationTap_MarksUnreadAsRead() {
        // Given
        sut.configure(notificationStore: mockNotificationStore)
        let unreadNotification = createTestNotification(.workoutCompleted, isRead: false)

        // When
        sut.handleNotificationTap(unreadNotification)

        // Then
        XCTAssertTrue(mockNotificationStore.markAsReadCalled)
        XCTAssertEqual(mockNotificationStore.lastMarkedReadId, unreadNotification.id)
    }

    func testHandleNotificationTap_DoesNotMarkReadAsRead() {
        // Given
        sut.configure(notificationStore: mockNotificationStore)
        let readNotification = createTestNotification(.workoutCompleted, isRead: true)
        mockNotificationStore.markAsReadCalled = false

        // When
        sut.handleNotificationTap(readNotification)

        // Then
        // Should not call markAsRead since it's already read
        XCTAssertFalse(mockNotificationStore.markAsReadCalled)
    }

    func testHandleNotificationAction_Accept_HandlesAcceptAction() {
        // Given
        sut.configure(notificationStore: mockNotificationStore)
        let notification = createTestNotification(.followRequest)

        // When
        sut.handleNotificationAction(notification, action: .accept)

        // Then
        // This test mainly ensures no crash - actual implementation would involve navigation
        XCTAssertNoThrow(sut.handleNotificationAction(notification, action: .accept))
    }

    func testHandleNotificationAction_Ignore_MarksAsRead() {
        // Given
        sut.configure(notificationStore: mockNotificationStore)
        let notification = createTestNotification(.followRequest)

        // When
        sut.handleNotificationAction(notification, action: .dismiss)

        // Then
        XCTAssertTrue(mockNotificationStore.markAsReadCalled)
        XCTAssertEqual(mockNotificationStore.lastMarkedReadId, notification.id)
    }

    // MARK: - Helper Methods

    private func createTestNotification(_ type: NotificationType, isRead: Bool = false) -> NotificationItem {
        var notification = NotificationItem(
            type: type,
            title: "Test \(type.displayName)",
            body: "Test notification body"
        )
        notification.isRead = isRead
        return notification
    }
}
