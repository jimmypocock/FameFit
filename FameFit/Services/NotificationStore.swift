import Foundation
import SwiftUI
import UserNotifications

class NotificationStore: ObservableObject {
    @Published var notifications: [NotificationItem] = []
    @Published var unreadCount: Int = 0
    
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
        saveNotifications()
        updateUnreadCount()
        updateBadgeCount()
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
    
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    private func updateBadgeCount() {
        UNUserNotificationCenter.current().setBadgeCount(unreadCount) { error in
            if let error = error {
                FameFitLogger.error("Failed to update badge count", error: error, category: FameFitLogger.workout)
            }
        }
    }
    
    private func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                FameFitLogger.error("Failed to clear badge", error: error, category: FameFitLogger.workout)
            }
        }
    }
}