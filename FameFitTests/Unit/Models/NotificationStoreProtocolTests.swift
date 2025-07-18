//
//  NotificationStoreProtocolTests.swift
//  FameFitTests
//
//  Tests for NotificationStoring protocol implementations
//

import XCTest
@testable import FameFit

class NotificationStoreProtocolTests: XCTestCase {
    private var mockStore: MockNotificationStore!
    private var realStore: NotificationStore!
    
    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: NotificationItem.storageKey)
        
        mockStore = MockNotificationStore()
        realStore = NotificationStore()
    }
    
    override func tearDown() {
        mockStore = nil
        realStore = nil
        UserDefaults.standard.removeObject(forKey: NotificationItem.storageKey)
        super.tearDown()
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testMockStoreConformsToProtocol() {
        // Given
        let protocolStore: any NotificationStoring = mockStore
        
        // When
        let notification = NotificationItem(
            title: "Test",
            body: "Test",
            character: .chad,
            workoutDuration: 30,
            calories: 200,
            followersEarned: 5
        )
        protocolStore.addNotification(notification)
        
        // Then
        XCTAssertEqual(protocolStore.notifications.count, 1)
        XCTAssertEqual(protocolStore.unreadCount, 1)
    }
    
    func testRealStoreConformsToProtocol() {
        // Given
        let protocolStore: any NotificationStoring = realStore
        
        // When
        let notification = NotificationItem(
            title: "Test",
            body: "Test",
            character: .sierra,
            workoutDuration: 45,
            calories: 300,
            followersEarned: 5
        )
        protocolStore.addNotification(notification)
        
        // Then
        XCTAssertEqual(protocolStore.notifications.count, 1)
        XCTAssertEqual(protocolStore.unreadCount, 1)
    }
    
    // MARK: - Mock Store Behavior Tests
    
    func testMockStoreTracksMethodCalls() {
        // Given
        let notification = NotificationItem(
            title: "Track",
            body: "Track",
            character: .zen,
            workoutDuration: 60,
            calories: 400,
            followersEarned: 5
        )
        
        // When
        mockStore.addNotification(notification)
        mockStore.markAsRead(notification.id)
        mockStore.markAllAsRead()
        mockStore.deleteNotification(at: IndexSet(integer: 0))
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
        let notification = NotificationItem(
            title: "Fail",
            body: "Fail",
            character: .chad,
            workoutDuration: 30,
            calories: 200,
            followersEarned: 5
        )
        mockStore.addNotification(notification)
        
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
    
    // MARK: - Type-Erased Wrapper Tests
    
    func testAnyNotificationStoreWithMock() {
        // Given
        let anyStore = AnyNotificationStore(mockStore)
        
        // When
        let notification = NotificationItem(
            title: "Wrapped",
            body: "Wrapped",
            character: .sierra,
            workoutDuration: 45,
            calories: 300,
            followersEarned: 5
        )
        anyStore.addNotification(notification)
        
        // Then
        XCTAssertEqual(anyStore.notifications.count, 1)
        XCTAssertEqual(anyStore.unreadCount, 1)
        XCTAssertTrue(mockStore.addNotificationCalled)
    }
    
    func testAnyNotificationStoreWithReal() {
        // Given
        let anyStore = AnyNotificationStore(realStore)
        
        // When
        let notification = NotificationItem(
            title: "Wrapped Real",
            body: "Wrapped Real",
            character: .zen,
            workoutDuration: 60,
            calories: 400,
            followersEarned: 5
        )
        anyStore.addNotification(notification)
        
        // Then
        XCTAssertEqual(anyStore.notifications.count, 1)
        XCTAssertEqual(anyStore.unreadCount, 1)
    }
    
    func testAnyNotificationStorePublishesChanges() {
        // Given
        let anyStore = AnyNotificationStore(mockStore)
        var receivedNotificationCount = 0
        
        let expectation = XCTestExpectation(description: "Notification published")
        let cancellable = anyStore.$notifications.sink { notifications in
            receivedNotificationCount = notifications.count
            if !notifications.isEmpty {
                expectation.fulfill()
            }
        }
        
        // When
        let notification = NotificationItem(
            title: "Publish",
            body: "Publish",
            character: .chad,
            workoutDuration: 30,
            calories: 200,
            followersEarned: 5
        )
        anyStore.addNotification(notification)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedNotificationCount, 1)
        
        cancellable.cancel()
    }
    
    // MARK: - Protocol Usage in Business Logic Tests
    
    func testBusinessLogicCanUseProtocol() {
        // Given
        let store: any NotificationStoring = mockStore
        
        // Simulate a business logic function that uses the protocol
        func processWorkoutNotification(store: any NotificationStoring, workout: String) {
            let notification = NotificationItem(
                title: workout,
                body: "Completed",
                character: .chad,
                workoutDuration: 30,
                calories: 200,
                followersEarned: 5
            )
            store.addNotification(notification)
        }
        
        // When
        processWorkoutNotification(store: store, workout: "Morning Run")
        
        // Then
        XCTAssertEqual(store.notifications.count, 1)
        XCTAssertEqual(store.notifications.first?.title, "Morning Run")
    }
}