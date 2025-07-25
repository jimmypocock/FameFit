@testable import FameFit
import XCTest

class NotificationStoreTests: XCTestCase {
    private var sut: NotificationStore!

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: NotificationItem.storageKey)
        sut = NotificationStore()
    }

    override func tearDown() {
        sut = nil
        UserDefaults.standard.removeObject(forKey: NotificationItem.storageKey)
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(sut.notifications.count, 0)
        XCTAssertEqual(sut.unreadCount, 0)
    }

    func testAddNotification() {
        // Given
        let notification = NotificationItem(
            title: "Test Title",
            body: "Test Body",
            character: .chad,
            workoutDuration: 30,
            calories: 200,
            followersEarned: 5
        )

        // When
        sut.addNotification(notification)

        // Then
        XCTAssertEqual(sut.notifications.count, 1)
        XCTAssertEqual(sut.unreadCount, 1)
        XCTAssertEqual(sut.notifications.first?.title, "Test Title")
        XCTAssertEqual(sut.notifications.first?.followersEarned, 5)
    }

    func testMarkAsRead() {
        // Given
        let notification = NotificationItem(
            title: "Test",
            body: "Test",
            character: .sierra,
            workoutDuration: 45,
            calories: 300,
            followersEarned: 5
        )
        sut.addNotification(notification)
        XCTAssertEqual(sut.unreadCount, 1)

        // When
        sut.markAsRead(notification.id)

        // Then
        XCTAssertEqual(sut.unreadCount, 0)
        XCTAssertTrue(sut.notifications.first?.isRead ?? false)
    }

    func testMarkAllAsRead() {
        // Given
        for index in 1 ... 3 {
            let notification = NotificationItem(
                title: "Test \(index)",
                body: "Body \(index)",
                character: .zen,
                workoutDuration: 20 * index,
                calories: 100 * index,
                followersEarned: 5
            )
            sut.addNotification(notification)
        }
        XCTAssertEqual(sut.unreadCount, 3)

        // When
        sut.markAllAsRead()

        // Then
        XCTAssertEqual(sut.unreadCount, 0)
        XCTAssertTrue(sut.notifications.allSatisfy(\.isRead))
    }

    func testDeleteNotification() {
        // Given
        let notification1 = NotificationItem(
            title: "Keep",
            body: "Keep",
            character: .chad,
            workoutDuration: 30,
            calories: 200,
            followersEarned: 5
        )
        let notification2 = NotificationItem(
            title: "Delete",
            body: "Delete",
            character: .sierra,
            workoutDuration: 45,
            calories: 300,
            followersEarned: 5
        )
        sut.addNotification(notification1)
        sut.addNotification(notification2)
        XCTAssertEqual(sut.notifications.count, 2)

        // When - Delete the first notification (most recent, which is "Delete")
        sut.deleteNotification(at: IndexSet(integer: 0))

        // Then
        XCTAssertEqual(sut.notifications.count, 1)
        XCTAssertEqual(sut.notifications.first?.title, "Keep")
    }

    func testClearAll() {
        // Given
        for index in 1 ... 5 {
            let notification = NotificationItem(
                title: "Test \(index)",
                body: "Body \(index)",
                character: .zen,
                workoutDuration: 20 * index,
                calories: 100 * index,
                followersEarned: 5
            )
            sut.addNotification(notification)
        }
        XCTAssertEqual(sut.notifications.count, 5)
        XCTAssertEqual(sut.unreadCount, 5)

        // When
        sut.clearAll()

        // Then
        XCTAssertEqual(sut.notifications.count, 0)
        XCTAssertEqual(sut.unreadCount, 0)
    }

    func testNotificationLimit() {
        // Given - Add more than the limit (50)
        for index in 1 ... 55 {
            let notification = NotificationItem(
                title: "Test \(index)",
                body: "Body \(index)",
                character: .chad,
                workoutDuration: index,
                calories: index * 10,
                followersEarned: 5
            )
            sut.addNotification(notification)
        }

        // Then - Should only keep the most recent 50
        XCTAssertEqual(sut.notifications.count, 50)
        // The oldest notifications (1-5) should have been removed
        XCTAssertEqual(sut.notifications.first?.title, "Test 55") // Most recent (at index 0)
        XCTAssertEqual(sut.notifications.last?.title, "Test 6") // Oldest kept (at index 49)
    }

    func testNotificationPersistence() {
        // Given
        let notification = NotificationItem(
            title: "Persistent",
            body: "Should persist",
            character: .sierra,
            workoutDuration: 60,
            calories: 400,
            followersEarned: 5
        )
        sut.addNotification(notification)

        // When - Create a new store (simulating app restart)
        let newStore = NotificationStore()

        // Then
        XCTAssertEqual(newStore.notifications.count, 1)
        XCTAssertEqual(newStore.notifications.first?.title, "Persistent")
        XCTAssertEqual(newStore.notifications.first?.followersEarned, 5)
    }

    func testBadgeCountUpdate() {
        // Given
        let expectation = XCTestExpectation(description: "Badge count update")
        var badgeCount: Int?

        // Subscribe to badge count changes
        let cancellable = sut.$unreadCount.sink { unreadCount in
            badgeCount = unreadCount
            if unreadCount > 0 {
                expectation.fulfill()
            }
        }

        // When
        let notification = NotificationItem(
            title: "Badge Test",
            body: "Badge Test",
            character: .zen,
            workoutDuration: 30,
            calories: 200,
            followersEarned: 5
        )
        sut.addNotification(notification)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(badgeCount, 1)

        cancellable.cancel()
    }

    func testNotificationWithDifferentCharacters() {
        // Given
        let characters: [FameFitCharacter] = [.chad, .sierra, .zen]

        // When
        for (index, character) in characters.enumerated() {
            let notification = NotificationItem(
                title: "\(character.emoji) \(character.fullName)",
                body: character.workoutCompletionMessage(followers: 5),
                character: character,
                workoutDuration: 30 + (index * 10),
                calories: 200 + (index * 50),
                followersEarned: 5
            )
            sut.addNotification(notification)
        }

        // Then
        XCTAssertEqual(sut.notifications.count, 3)
        // Notifications are added at index 0, so order is reversed
        XCTAssertEqual(sut.notifications[0].character, .zen) // Most recent
        XCTAssertEqual(sut.notifications[1].character, .sierra) // Middle
        XCTAssertEqual(sut.notifications[2].character, .chad) // Oldest

        // Verify each notification has correct follower count
        XCTAssertTrue(sut.notifications.allSatisfy { $0.followersEarned == 5 })
    }
}
