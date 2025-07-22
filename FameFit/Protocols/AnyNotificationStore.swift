//
//  AnyNotificationStore.swift
//  FameFit
//
//  Type-erased wrapper for NotificationStoring protocol
//

import Foundation
import SwiftUI
import Combine

/// Type-erased wrapper for NotificationStoring to enable protocol usage in SwiftUI
final class AnyNotificationStore: ObservableObject, NotificationStoring {
    @Published var notifications: [NotificationItem] = []
    @Published var unreadCount: Int = 0
    
    var notificationsPublisher: Published<[NotificationItem]>.Publisher { $notifications }
    var unreadCountPublisher: Published<Int>.Publisher { $unreadCount }
    
    private let _addNotification: (NotificationItem) -> Void
    private let _markAsRead: (String) -> Void
    private let _markAllAsRead: () -> Void
    private let _clearAll: () -> Void
    private let _deleteNotification: (IndexSet) -> Void
    private let _deleteNotificationById: (String) -> Void
    private let _clearAllNotifications: () -> Void
    private let _loadNotifications: () -> Void
    private let _saveNotifications: () -> Void
    
    private var cancellables = Set<AnyCancellable>()
    
    init<Store: NotificationStoring>(_ store: Store) where Store.ObjectWillChangePublisher == ObservableObjectPublisher {
        // Initialize closures first
        self._addNotification = { [weak store] item in
            store?.addNotification(item)
        }
        
        self._markAsRead = { [weak store] id in
            store?.markAsRead(id)
        }
        
        self._markAllAsRead = { [weak store] in
            store?.markAllAsRead()
        }
        
        self._clearAll = { [weak store] in
            store?.clearAll()
        }
        
        self._deleteNotification = { [weak store] offsets in
            store?.deleteNotification(at: offsets)
        }
        
        self._deleteNotificationById = { [weak store] id in
            store?.deleteNotification(id)
        }
        
        self._clearAllNotifications = { [weak store] in
            store?.clearAllNotifications()
        }
        
        self._loadNotifications = { [weak store] in
            store?.loadNotifications()
        }
        
        self._saveNotifications = { [weak store] in
            store?.saveNotifications()
        }
        
        // Now set up property bindings
        store.notificationsPublisher
            .assign(to: &$notifications)
        
        store.unreadCountPublisher
            .assign(to: &$unreadCount)
        
        // Forward objectWillChange events
        store.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    func addNotification(_ item: NotificationItem) {
        _addNotification(item)
    }
    
    func markAsRead(_ id: String) {
        _markAsRead(id)
    }
    
    func markAllAsRead() {
        _markAllAsRead()
    }
    
    func clearAll() {
        _clearAll()
    }
    
    func deleteNotification(at offsets: IndexSet) {
        _deleteNotification(offsets)
    }
    
    func loadNotifications() {
        _loadNotifications()
    }
    
    func deleteNotification(_ id: String) {
        _deleteNotificationById(id)
    }
    
    func clearAllNotifications() {
        _clearAllNotifications()
    }
    
    func saveNotifications() {
        _saveNotifications()
    }
}