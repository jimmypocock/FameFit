//
//  NotificationStoring.swift
//  FameFit
//
//  Protocol abstraction for notification management
//

import Foundation
import SwiftUI

/// Protocol defining the interface for managing workout notifications
protocol NotificationStoring: ObservableObject {
    /// All notifications, ordered from most recent to oldest
    var notifications: [NotificationItem] { get }
    
    /// Count of unread notifications
    var unreadCount: Int { get }
    
    /// Published notifications for SwiftUI binding
    var notificationsPublisher: Published<[NotificationItem]>.Publisher { get }
    
    /// Published unread count for SwiftUI binding
    var unreadCountPublisher: Published<Int>.Publisher { get }
    
    /// Add a new notification
    /// - Parameter item: The notification to add
    func addNotification(_ item: NotificationItem)
    
    /// Mark a specific notification as read
    /// - Parameter id: The ID of the notification to mark as read
    func markAsRead(_ id: String)
    
    /// Mark all notifications as read
    func markAllAsRead()
    
    /// Clear all notifications
    func clearAll()
    
    /// Delete notifications at the specified offsets
    /// - Parameter offsets: The index set of notifications to delete
    func deleteNotification(at offsets: IndexSet)
    
    /// Load notifications from persistent storage
    func loadNotifications()
    
    /// Save notifications to persistent storage
    func saveNotifications()
}