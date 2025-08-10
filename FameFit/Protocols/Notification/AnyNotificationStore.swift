//
//  AnyNotificationStore.swift
//  FameFit
//
//  Type-erased wrapper for NotificationStoringProtocol
//

import Combine
import Foundation
import SwiftUI

/// Type-erased wrapper for NotificationStoringProtocol to enable protocol usage in SwiftUI
final class AnyNotificationStore: ObservableObject, NotificationStoringProtocol {
    @Published var notifications: [FameFitNotification] = []
    @Published var unreadCount: Int = 0

    var notificationsPublisher: Published<[FameFitNotification]>.Publisher { $notifications }
    var unreadCountPublisher: Published<Int>.Publisher { $unreadCount }

    private let _addNotification: (FameFitNotification) -> Void
    private let _markAsRead: (String) -> Void
    private let _markAllAsRead: () -> Void
    private let _clearAll: () -> Void
    private let _deleteNotification: (IndexSet) -> Void
    private let _deleteNotificationByID: (String) -> Void
    private let _clearAllNotifications: () -> Void
    private let _loadNotifications: () -> Void
    private let _saveNotifications: () -> Void

    private var cancellables = Set<AnyCancellable>()

    init<Store: NotificationStoringProtocol>(_ store: Store)
        where Store.ObjectWillChangePublisher == ObservableObjectPublisher {
        // Initialize closures first
        _addNotification = { [weak store] item in
            store?.addFameFitNotification(item)
        }

        _markAsRead = { [weak store] id in
            store?.markAsRead(id)
        }

        _markAllAsRead = { [weak store] in
            store?.markAllAsRead()
        }

        _clearAll = { [weak store] in
            store?.clearAll()
        }

        _deleteNotification = { [weak store] offsets in
            store?.deleteFameFitNotification(at: offsets)
        }

        _deleteNotificationByID = { [weak store] id in
            store?.deleteFameFitNotification(id)
        }

        _clearAllNotifications = { [weak store] in
            store?.clearAllNotifications()
        }

        _loadNotifications = { [weak store] in
            store?.loadNotifications()
        }

        _saveNotifications = { [weak store] in
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

    func addFameFitNotification(_ item: FameFitNotification) {
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

    func deleteFameFitNotification(at offsets: IndexSet) {
        _deleteNotification(offsets)
    }

    func loadNotifications() {
        _loadNotifications()
    }

    func deleteFameFitNotification(_ id: String) {
        _deleteNotificationByID(id)
    }

    func clearAllNotifications() {
        _clearAllNotifications()
    }

    func saveNotifications() {
        _saveNotifications()
    }
}
