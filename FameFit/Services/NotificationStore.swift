import Foundation
import SwiftUI
import UserNotifications

class NotificationStore: ObservableObject, NotificationStoring {
    @Published var notifications: [NotificationItem] = []
    @Published var unreadCount: Int = 0

    var notificationsPublisher: Published<[NotificationItem]>.Publisher { $notifications }
    var unreadCountPublisher: Published<Int>.Publisher { $unreadCount }

    private let maxNotifications = 50 // Keep last 50 notifications

    init() {
        loadNotifications()
    }

    func loadNotifications() {
        notifications = NotificationItem.loadAll()
        updateUnreadCount()
    }

    func saveNotifications() {
        // Keep only the most recent notifications
        let recentNotifications = notifications.prefix(maxNotifications)
        NotificationItem.saveAll(Array(recentNotifications))
    }

    func addNotification(_ item: NotificationItem) {
        notifications.insert(item, at: 0) // Add to beginning
        // Trim to max notifications if needed
        if notifications.count > maxNotifications {
            notifications = Array(notifications.prefix(maxNotifications))
        }
        saveNotifications()
        updateUnreadCount()
        updateBadgeCount()
    }

    func markAsRead(_ id: String) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead = true
            saveNotifications()
            updateUnreadCount()
            updateBadgeCount()
        }
    }

    func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        saveNotifications()
        updateUnreadCount()
        clearBadge()
    }

    func clearAll() {
        notifications.removeAll()
        saveNotifications()
        updateUnreadCount()
        clearBadge()
    }

    func deleteNotification(at offsets: IndexSet) {
        notifications.remove(atOffsets: offsets)
        saveNotifications()
        updateUnreadCount()
        updateBadgeCount()
    }

    func deleteNotification(_ id: String) {
        notifications.removeAll { $0.id == id }
        saveNotifications()
        updateUnreadCount()
        updateBadgeCount()
    }

    func clearAllNotifications() {
        clearAll()
    }

    private func updateUnreadCount() {
        let newCount = notifications.filter { !$0.isRead }.count
        if Thread.isMainThread {
            unreadCount = newCount
        } else {
            DispatchQueue.main.async {
                self.unreadCount = newCount
            }
        }
    }

    private func updateBadgeCount() {
        UNUserNotificationCenter.current().setBadgeCount(unreadCount) { error in
            if let error {
                FameFitLogger.error("Failed to update badge count", error: error, category: FameFitLogger.workout)
            }
        }
    }

    private func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error {
                FameFitLogger.error("Failed to clear badge", error: error, category: FameFitLogger.workout)
            }
        }
    }
}
