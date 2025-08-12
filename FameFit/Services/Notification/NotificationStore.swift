import Foundation
import SwiftUI
import UserNotifications

class NotificationStore: ObservableObject, NotificationStoringProtocol {
    @Published var notifications: [FameFitNotification] = []
    @Published var unreadCount: Int = 0

    var notificationsPublisher: Published<[FameFitNotification]>.Publisher { $notifications }
    var unreadCountPublisher: Published<Int>.Publisher { $unreadCount }

    private let maxNotifications = 50 // Keep last 50 notifications

    init() {
        loadNotifications()
    }

    func loadNotifications() {
        notifications = FameFitNotification.loadAll()
        updateUnreadCount()
    }

    func saveNotifications() {
        // Keep only the most recent notifications
        let recentNotifications = notifications.prefix(maxNotifications)
        FameFitNotification.saveAll(Array(recentNotifications))
    }

    func addFameFitNotification(_ item: FameFitNotification) {
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

    func deleteFameFitNotification(at offsets: IndexSet) {
        notifications.remove(atOffsets: offsets)
        saveNotifications()
        updateUnreadCount()
        updateBadgeCount()
    }

    func deleteFameFitNotification(_ id: String) {
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
