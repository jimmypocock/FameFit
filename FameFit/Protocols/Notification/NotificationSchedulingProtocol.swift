//
//  NotificationSchedulingProtocol.swift
//  FameFit
//
//  Protocol for notification scheduling operations
//

import Foundation
import UserNotifications

protocol NotificationSchedulingProtocol {
    func scheduleFameFitNotification(_ notification: NotificationRequest) async throws
    func cancelFameFitNotification(withID id: String) async
    func cancelAllNotifications() async
    func getPendingNotifications() async -> [NotificationRequest]
    func updatePreferences(_ preferences: NotificationPreferences)
}

// MARK: - Supporting Types

struct NotificationRequest {
    let id: String
    let type: NotificationType
    let title: String
    let body: String
    let metadata: NotificationMetadataContainer?
    let priority: NotificationPriority
    let actions: [NotificationAction]
    let groupID: String?
    let deliveryDate: Date?
    let sound: UNNotificationSound?
    
    init(
        id: String = UUID().uuidString,
        type: NotificationType,
        title: String,
        body: String,
        metadata: NotificationMetadataContainer? = nil,
        priority: NotificationPriority = .medium,
        actions: [NotificationAction] = [],
        groupID: String? = nil,
        deliveryDate: Date? = nil,
        sound: UNNotificationSound? = .default
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.metadata = metadata
        self.priority = priority
        self.actions = actions
        self.groupID = groupID
        self.deliveryDate = deliveryDate
        self.sound = sound
    }
}