//
//  MockNotificationStore.swift
//  FameFitTests
//
//  Mock implementation of NotificationStoringProtocol for unit testing
//

@testable import FameFit
import Foundation
import SwiftUI

/// Mock notification store for testing
class MockNotificationStore: ObservableObject, NotificationStoringProtocol {
    @Published var notifications: [FameFitNotification] = []
    @Published var unreadCount: Int = 0

    var notificationsPublisher: Published<[FameFitNotification]>.Publisher { $notifications }
    var unreadCountPublisher: Published<Int>.Publisher { $unreadCount }

    // Test control properties
    var addNotificationCalled = false
    var markAsReadCalled = false
    var markAllAsReadCalled = false
    var clearAllCalled = false
    var deleteNotificationCalled = false
    var loadNotificationsCalled = false
    var saveNotificationsCalled = false

    var lastAddedNotification: FameFitNotification?
    var lastMarkedReadId: String?
    var lastDeletedOffsets: IndexSet?

    // Control test behavior
    var shouldFailOperations = false
    var notificationsToLoad: [FameFitNotification] = []

    private let maxNotifications = 50

    func addFameFitNotification(_ item: FameFitNotification) {
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

    func deleteFameFitNotification(at offsets: IndexSet) {
        deleteNotificationCalled = true
        lastDeletedOffsets = offsets

        if !shouldFailOperations {
            notifications.remove(atOffsets: offsets)
            updateUnreadCount()
            saveNotifications()
        }
    }

    func deleteFameFitNotification(_ id: String) {
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
            let notification = FameFitNotification(
                type: .workoutCompleted,
                title: "Test Notification \(index)",
                body: "Body \(index)"
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
