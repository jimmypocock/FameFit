//
//  NotificationStoreProtocolTests.swift
//  FameFitTests
//
//  Tests for NotificationStoring protocol implementations
//

@testable import FameFit
import XCTest

class NotificationStoreProtocolTests: XCTestCase {
    private var mockStore: MockNotificationStore!
    private var realStore: NotificationStore!

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: Notification.storageKey)

        mockStore = MockNotificationStore()
        realStore = NotificationStore()
    }

    override func tearDown() {
        mockStore = nil
        realStore = nil
        UserDefaults.standard.removeObject(forKey: Notification.storageKey)
        super.tearDown()
    }

    // MARK: - Protocol Conformance Tests

    func testMockStoreConformsToProtocol() {
        // Given
        let protocolStore: any NotificationStoring = mockStore

        // When
        let notification = FameFitNotification(
            title: "Test",
            body: "Test",
            character: .chad,
            workoutDuration: 30,
            calories: 200,
            followersEarned: 5
        )
        protocolStore.addFameFitNotification(notification)

        // Then
        XCTAssertEqual(protocolStore.notifications.count, 1)
        XCTAssertEqual(protocolStore.unreadCount, 1)
    }

    func testRealStoreConformsToProtocol() {
        // Given
        let protocolStore: any NotificationStoring = realStore

        // When
        let notification = FameFitNotification(
            title: "Test",
            body: "Test",
            character: .sierra,
            workoutDuration: 45,
            calories: 300,
            followersEarned: 5
        )
        protocolStore.addFameFitNotification(notification)

        // Then
        XCTAssertEqual(protocolStore.notifications.count, 1)
        XCTAssertEqual(protocolStore.unreadCount, 1)
    }

    // MARK: - Mock Store Behavior Tests

    func testMockStoreTracksMethodCalls() {
        // Given
        let notification = FameFitNotification(
            title: "Track",
            body: "Track",
            character: .zen,
            workoutDuration: 60,
            calories: 400,
            followersEarned: 5
        )

        // When
        mockStore.addFameFitNotification(notification)
        mockStore.markAsRead(notification.id)
        mockStore.markAllAsRead()
        mockStore.deleteFameFitNotification(at: IndexSet(integer: 0))
        mockStore.clearAll()
        mockStore.loadNotifications()
        mockStore.saveNotifications()

        // Then
        XCTAssertTrue(mockStore.addNotificationCalled)
        XCTAssertTrue(mockStore.markAsReadCalled)
        XCTAssertTrue(mockStore.markAllAsReadCalled)
        XCTAssertTrue(mockStore.deleteNotificationCalled)
        XCTAssertTrue(mockStore.clearAllCalled)
        XCTAssertTrue(mockStore.loadNotificationsCalled)
        XCTAssertTrue(mockStore.saveNotificationsCalled)

        XCTAssertEqual(mockStore.lastAddedNotification?.title, "Track")
        XCTAssertEqual(mockStore.lastMarkedReadId, notification.id)
        XCTAssertEqual(mockStore.lastDeletedOffsets, IndexSet(integer: 0))
    }

    func testMockStoreCanSimulateFailure() {
        // Given
        mockStore.shouldFailOperations = true
        let initialCount = mockStore.notifications.count

        // When
        let notification = FameFitNotification(
            title: "Fail",
            body: "Fail",
            character: .chad,
            workoutDuration: 30,
            calories: 200,
            followersEarned: 5
        )
        mockStore.addFameFitNotification(notification)

        // Then
        XCTAssertTrue(mockStore.addNotificationCalled)
        XCTAssertEqual(mockStore.notifications.count, initialCount) // No change
    }

    func testMockStoreSimulateNotifications() {
        // Given & When
        mockStore.simulateNotifications(count: 10, unreadCount: 3)

        // Then
        XCTAssertEqual(mockStore.notifications.count, 10)
        XCTAssertEqual(mockStore.unreadCount, 3)

        // Verify the last 3 are unread
        let unreadNotifications = mockStore.notifications.filter { !$0.isRead }
        XCTAssertEqual(unreadNotifications.count, 3)
    }


    // MARK: - Protocol Usage in Business Logic Tests

    func testBusinessLogicCanUseProtocol() {
        // Given
        let store: any NotificationStoring = mockStore

        // Simulate a business logic function that uses the protocol
        func processWorkoutFameFitNotification(store: any NotificationStoring, workout: String) {
            let notification = FameFitNotification(
                title: workout,
                body: "Completed",
                character: .chad,
                workoutDuration: 30,
                calories: 200,
                followersEarned: 5
            )
            store.addFameFitNotification(notification)
        }

        // When
        processWorkoutFameFitNotification(store: store, workout: "Morning Run")

        // Then
        XCTAssertEqual(store.notifications.count, 1)
        XCTAssertEqual(store.notifications.first?.title, "Morning Run")
    }
}
