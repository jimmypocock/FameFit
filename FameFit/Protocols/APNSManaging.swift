//
//  APNSManaging.swift
//  FameFit
//
//  Protocol for Apple Push Notification Service management
//

import Foundation
import UserNotifications

protocol APNSManaging: AnyObject {
    // MARK: - Properties

    var isRegistered: Bool { get }
    var currentDeviceToken: String? { get }
    var notificationAuthorizationStatus: UNAuthorizationStatus { get }

    // MARK: - Methods

    /// Request notification permissions from the user
    func requestNotificationPermissions() async throws -> Bool

    /// Register for remote notifications with APNS
    func registerForRemoteNotifications()

    /// Handle device token received from APNS
    func handleDeviceToken(_ deviceToken: Data) async throws

    /// Handle registration error
    func handleRegistrationError(_ error: Error)

    /// Handle notification response when user taps notification
    func handleNotificationResponse(_ response: UNNotificationResponse) async

    /// Update app badge count
    func updateBadgeCount(_ count: Int) async

    /// Unregister device from push notifications
    func unregisterDevice() async throws
}

// MARK: - Push Notification Request

/// Structure for requesting push notifications to be sent
struct PushNotificationRequest {
    let userID: String
    let type: NotificationType
    let title: String
    let body: String
    let subtitle: String?
    let badge: Int?
    let sound: String?
    let metadata: [String: String]?
    let category: String?
    let threadID: String?

    init(
        userID: String,
        type: NotificationType,
        title: String,
        body: String,
        subtitle: String? = nil,
        badge: Int? = nil,
        sound: String? = "default",
        metadata: [String: String]? = nil,
        category: String? = nil,
        threadID: String? = nil
    ) {
        self.userID = userID
        self.type = type
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.badge = badge
        self.sound = sound
        self.metadata = metadata
        self.category = category
        self.threadID = threadID
    }
}
