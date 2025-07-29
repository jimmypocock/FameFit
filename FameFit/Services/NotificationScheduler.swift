//
//  NotificationScheduler.swift
//  FameFit
//
//  Intelligent notification scheduling with rate limiting and batching
//

import Foundation
import UserNotifications

// MARK: - Notification Scheduler Protocol

protocol NotificationScheduling {
    func scheduleNotification(_ notification: NotificationRequest) async throws
    func cancelNotification(withId id: String) async
    func cancelAllNotifications() async
    func getPendingNotifications() async -> [NotificationRequest]
    func updatePreferences(_ preferences: NotificationPreferences)
}

// MARK: - Notification Request

struct NotificationRequest {
    let id: String
    let type: NotificationType
    let title: String
    let body: String
    let metadata: NotificationMetadataContainer?
    let priority: NotificationPriority
    let actions: [NotificationAction]
    let groupId: String?
    let deliveryDate: Date?
    let sound: UNNotificationSound?

    init(
        type: NotificationType,
        title: String,
        body: String,
        metadata: NotificationMetadataContainer? = nil,
        priority: NotificationPriority? = nil,
        actions: [NotificationAction] = [],
        groupId: String? = nil,
        deliveryDate: Date? = nil
    ) {
        id = UUID().uuidString
        self.type = type
        self.title = title
        self.body = body
        self.metadata = metadata
        self.priority = priority ?? type.defaultPriority
        self.actions = actions
        self.groupId = groupId
        self.deliveryDate = deliveryDate
        sound = type.soundEnabled ? .default : nil
    }
}

// MARK: - Notification Scheduler

final class NotificationScheduler: NotificationScheduling {
    private let notificationCenter: UNUserNotificationCenter
    private let notificationStore: any NotificationStoring
    private var preferences: NotificationPreferences

    // Rate limiting
    private var recentNotifications: [Date] = []
    private let recentNotificationsLock = NSLock()

    // Batching
    private var pendingBatches: [NotificationType: [NotificationRequest]] = [:]
    private var batchTimers: [NotificationType: Timer] = [:]
    private let batchingLock = NSLock()

    init(notificationStore: any NotificationStoring, notificationCenter: UNUserNotificationCenter? = nil) {
        self.notificationStore = notificationStore
        self.notificationCenter = notificationCenter ?? UNUserNotificationCenter.current()
        preferences = NotificationPreferences.load()

        // Clean up old notifications periodically
        Timer.scheduledTimer(withTimeInterval: 3_600, repeats: true) { _ in
            Task {
                await self.cleanupOldNotifications()
            }
        }
    }

    // MARK: - Public Methods

    func scheduleNotification(_ notification: NotificationRequest) async throws {
        // Check if notifications are enabled
        guard preferences.isEnabled(for: notification.type) else {
            print("Notifications disabled for type: \(notification.type)")
            return
        }

        // Check quiet hours
        if shouldDelayForQuietHours(notification) {
            let delayedDate = nextAvailableTimeAfterQuietHours()
            var delayedNotification = notification
            delayedNotification = NotificationRequest(
                type: notification.type,
                title: notification.title,
                body: notification.body,
                metadata: notification.metadata,
                priority: notification.priority,
                actions: notification.actions,
                groupId: notification.groupId,
                deliveryDate: delayedDate
            )
            try await scheduleLocalNotification(delayedNotification)
            return
        }

        // Check rate limits
        if isRateLimited(), notification.priority != .immediate {
            addToBatch(notification)
            return
        }

        // Check if should batch
        if shouldBatch(notification) {
            addToBatch(notification)
            return
        }

        // Schedule immediately
        try await deliverNotification(notification)
    }

    func cancelNotification(withId id: String) async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [id])
    }

    func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }

    func getPendingNotifications() async -> [NotificationRequest] {
        _ = await notificationCenter.pendingNotificationRequests()
        // Convert UNNotificationRequest back to our NotificationRequest
        // This is simplified - in production would need proper conversion
        return []
    }

    func updatePreferences(_ preferences: NotificationPreferences) {
        self.preferences = preferences
        preferences.save()
    }

    // MARK: - Private Methods

    private func shouldDelayForQuietHours(_ notification: NotificationRequest) -> Bool {
        guard preferences.quietHoursEnabled else { return false }

        // Immediate priority notifications bypass quiet hours if configured
        if notification.priority == .immediate, preferences.quietHoursIgnoreImmediate {
            return false
        }

        return preferences.isInQuietHours()
    }

    private func nextAvailableTimeAfterQuietHours() -> Date {
        let calendar = Calendar.current
        let now = Date()

        guard let endTime = preferences.quietHoursEnd else {
            return now.addingTimeInterval(3_600) // Default to 1 hour later
        }

        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        guard let endHour = endComponents.hour,
              let endMinute = endComponents.minute
        else {
            return now.addingTimeInterval(3_600)
        }

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = endHour
        components.minute = endMinute

        guard let quietEndTime = calendar.date(from: components) else {
            return now.addingTimeInterval(3_600)
        }

        // If quiet end time is in the past (for today), move to tomorrow
        if quietEndTime <= now {
            return calendar.date(byAdding: .day, value: 1, to: quietEndTime) ?? now.addingTimeInterval(86_400)
        }

        return quietEndTime
    }

    private func isRateLimited() -> Bool {
        recentNotificationsLock.lock()
        defer { recentNotificationsLock.unlock() }

        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3_600)

        // Remove old entries
        recentNotifications.removeAll { $0 < oneHourAgo }

        return recentNotifications.count >= preferences.maxNotificationsPerHour
    }

    private func shouldBatch(_ notification: NotificationRequest) -> Bool {
        // Immediate priority always goes through
        if notification.priority == .immediate {
            return false
        }

        // Check user preference for this type
        return preferences.shouldBatch(for: notification.type)
    }

    private func addToBatch(_ notification: NotificationRequest) {
        batchingLock.lock()
        defer { batchingLock.unlock() }

        pendingBatches[notification.type, default: []].append(notification)

        // Schedule batch delivery if not already scheduled
        if batchTimers[notification.type] == nil {
            let timer = Timer.scheduledTimer(
                withTimeInterval: TimeInterval(preferences.batchingWindowMinutes * 60),
                repeats: false
            ) { _ in
                Task {
                    await self.deliverBatch(for: notification.type)
                }
            }
            batchTimers[notification.type] = timer
        }
    }

    private func deliverBatch(for type: NotificationType) async {
        let notifications = await withCheckedContinuation { continuation in
            batchingLock.lock()
            defer { batchingLock.unlock() }

            let batch = pendingBatches[type] ?? []
            pendingBatches[type] = nil
            batchTimers[type]?.invalidate()
            batchTimers[type] = nil

            continuation.resume(returning: batch)
        }

        guard !notifications.isEmpty else { return }

        // Create grouped notification
        let groupedNotification = createGroupedNotification(from: notifications, type: type)

        do {
            try await deliverNotification(groupedNotification)
        } catch {
            print("Failed to deliver batched notification: \(error)")
        }
    }

    private func createGroupedNotification(
        from notifications: [NotificationRequest],
        type: NotificationType
    ) -> NotificationRequest {
        let count = notifications.count

        let title: String
        let body: String

        switch type {
        case .workoutKudos:
            title = "\(count) Workout Kudos"
            body = "\(count) people cheered your recent workouts!"

        case .newFollower:
            if count == 1, let first = notifications.first {
                return first // Don't group single follower
            }
            title = "\(count) New Followers"
            body = "\(count) people started following you"

        case .workoutComment:
            title = "\(count) New Comments"
            body = "Check out what people are saying about your workouts"

        default:
            title = "\(count) New Notifications"
            body = "You have \(count) new \(type.displayName) notifications"
        }

        return NotificationRequest(
            type: type,
            title: title,
            body: body,
            metadata: nil,
            priority: .medium,
            groupId: "\(type.rawValue)_batch_\(Date().timeIntervalSince1970)"
        )
    }

    private func deliverNotification(_ notification: NotificationRequest) async throws {
        // Record for rate limiting
        await withCheckedContinuation { continuation in
            recentNotificationsLock.lock()
            defer { recentNotificationsLock.unlock() }
            recentNotifications.append(Date())
            continuation.resume()
        }

        // Add to notification store (in-app)
        let item = NotificationItem(
            type: notification.type,
            title: notification.title,
            body: notification.body,
            metadata: notification.metadata,
            actions: notification.actions,
            groupId: notification.groupId
        )
        Task { @MainActor in
            notificationStore.addNotification(item)
        }

        // Schedule push notification if enabled
        if preferences.pushNotificationsEnabled {
            try await scheduleLocalNotification(notification)
        }
    }

    private func scheduleLocalNotification(_ notification: NotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = preferences.shouldPlaySound(for: notification.type) ? notification.sound : nil
        content.badge = preferences.badgeEnabled ? NSNumber(value: notificationStore.unreadCount) : nil

        // Set category for actions
        if !notification.actions.isEmpty {
            content.categoryIdentifier = notification.type.rawValue
        }

        // Set thread identifier for grouping
        if let groupId = notification.groupId {
            content.threadIdentifier = groupId
        }

        // Create trigger
        let trigger: UNNotificationTrigger?
        if let deliveryDate = notification.deliveryDate {
            let timeInterval = deliveryDate.timeIntervalSinceNow
            if timeInterval > 0 {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            } else {
                trigger = nil // Deliver immediately
            }
        } else {
            trigger = nil // Deliver immediately
        }

        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    private func cleanupOldNotifications() async {
        await withCheckedContinuation { continuation in
            recentNotificationsLock.lock()
            defer { recentNotificationsLock.unlock() }
            let oneHourAgo = Date().addingTimeInterval(-3_600)
            recentNotifications.removeAll { $0 < oneHourAgo }
            continuation.resume()
        }
    }
}

// MARK: - Mock Implementation

final class MockNotificationScheduler: NotificationScheduling {
    var scheduledNotifications: [NotificationRequest] = []
    var preferences = NotificationPreferences()
    var shouldFailScheduling = false

    func scheduleNotification(_ notification: NotificationRequest) async throws {
        if shouldFailScheduling {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        scheduledNotifications.append(notification)
    }

    func cancelNotification(withId id: String) async {
        scheduledNotifications.removeAll { $0.id == id }
    }

    func cancelAllNotifications() async {
        scheduledNotifications.removeAll()
    }

    func getPendingNotifications() async -> [NotificationRequest] {
        scheduledNotifications
    }

    func updatePreferences(_ preferences: NotificationPreferences) {
        self.preferences = preferences
    }
}
