//
//  MockNotificationStore.swift
//  FameFitTests
//
//  Mock implementation of NotificationStoring for unit testing
//

@testable import FameFit
import Foundation
import SwiftUI

/// Mock notification store for testing
class MockNotificationStore: ObservableObject, NotificationStoring {
    @Published var notifications: [NotificationItem] = []
    @Published var unreadCount: Int = 0

    var notificationsPublisher: Published<[NotificationItem]>.Publisher { $notifications }
    var unreadCountPublisher: Published<Int>.Publisher { $unreadCount }

    // Test control properties
    var addNotificationCalled = false
    var markAsReadCalled = false
    var markAllAsReadCalled = false
    var clearAllCalled = false
    var deleteNotificationCalled = false
    var loadNotificationsCalled = false
    var saveNotificationsCalled = false

    var lastAddedNotification: NotificationItem?
    var lastMarkedReadId: String?
    var lastDeletedOffsets: IndexSet?

    // Control test behavior
    var shouldFailOperations = false
    var notificationsToLoad: [NotificationItem] = []

    private let maxNotifications = 50

    func addNotification(_ item: NotificationItem) {
        addNotificationCalled = true
        lastAddedNotification = item

        if !shouldFailOperations {
            notifications.insert(item, at: 0)
            // Trim to max notifications if needed
            if notifications.count > maxNotifications {
                notifications = Array(notifications.prefix(maxNotifications))
            }
            updateUnreadCount()
            saveNotifications()
        }
    }

    func markAsRead(_ id: String) {
        markAsReadCalled = true
        lastMarkedReadId = id

        if !shouldFailOperations {
            if let index = notifications.firstIndex(where: { $0.id == id }) {
                notifications[index].isRead = true
                updateUnreadCount()
                saveNotifications()
            }
        }
    }

    func markAllAsRead() {
        markAllAsReadCalled = true

        if !shouldFailOperations {
            for index in notifications.indices {
                notifications[index].isRead = true
            }
            updateUnreadCount()
            saveNotifications()
        }
    }

    func clearAll() {
        clearAllCalled = true

        if !shouldFailOperations {
            notifications.removeAll()
            updateUnreadCount()
            saveNotifications()
        }
    }

    func deleteNotification(at offsets: IndexSet) {
        deleteNotificationCalled = true
        lastDeletedOffsets = offsets

        if !shouldFailOperations {
            notifications.remove(atOffsets: offsets)
            updateUnreadCount()
            saveNotifications()
        }
    }

    func deleteNotification(_ id: String) {
        deleteNotificationCalled = true

        if !shouldFailOperations {
            notifications.removeAll { $0.id == id }
            updateUnreadCount()
            saveNotifications()
        }
    }

    func clearAllNotifications() {
        clearAll()
    }

    func loadNotifications() {
        loadNotificationsCalled = true

        if !shouldFailOperations {
            notifications = notificationsToLoad
            updateUnreadCount()
        }
    }

    func saveNotifications() {
        saveNotificationsCalled = true
    }

    // Helper methods
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }

    // Test helper methods
    func reset() {
        notifications.removeAll()
        unreadCount = 0

        addNotificationCalled = false
        markAsReadCalled = false
        markAllAsReadCalled = false
        clearAllCalled = false
        deleteNotificationCalled = false
        loadNotificationsCalled = false
        saveNotificationsCalled = false

        lastAddedNotification = nil
        lastMarkedReadId = nil
        lastDeletedOffsets = nil

        shouldFailOperations = false
        notificationsToLoad.removeAll()
    }

    func simulateNotifications(count: Int, unreadCount: Int = 0) {
        notifications.removeAll()

        for index in 1 ... count {
            let notification = NotificationItem(
                title: "Test Notification \(index)",
                body: "Body \(index)",
                character: FameFitCharacter.allCases.randomElement()!,
                workoutDuration: 30 * index,
                calories: 100 * index,
                followersEarned: 5
            )

            if index > (count - unreadCount) {
                // Make the last 'unreadCount' notifications unread
                notifications.append(notification)
            } else {
                var readNotification = notification
                readNotification.isRead = true
                notifications.append(readNotification)
            }
        }

        updateUnreadCount()
    }
}
