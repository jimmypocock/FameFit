//
//  APNSManager.swift
//  FameFit
//
//  Manages Apple Push Notification Service (APNS) integration
//

import CloudKit
import Foundation
import UIKit
import UserNotifications

// MARK: - APNS Error Types

enum APNSError: LocalizedError {
    case notAuthorized
    case tokenRegistrationFailed
    case invalidDeviceToken
    case cloudKitSaveFailed(Error)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Push notifications are not authorized"
        case .tokenRegistrationFailed:
            "Failed to register device for push notifications"
        case .invalidDeviceToken:
            "Invalid device token format"
        case let .cloudKitSaveFailed(error):
            "Failed to save device token: \(error.localizedDescription)"
        case .permissionDenied:
            "Push notification permission was denied"
        }
    }
}

// MARK: - Push Notification Payload

struct PushNotificationPayload: Codable {
    let aps: APSPayload
    let notificationType: String
    let metadata: [String: String]?

    struct APSPayload: Codable {
        let alert: Alert
        let badge: Int?
        let sound: String?
        let threadID: String?
        let category: String?

        struct Alert: Codable {
            let title: String
            let body: String
            let subtitle: String?
        }

        private enum CodingKeys: String, CodingKey {
            case alert
            case badge
            case sound
            case threadID = "thread-id"
            case category
        }
    }
}

// MARK: - Device Token Record

struct DeviceTokenRecord {
    let id: String
    let userID: String
    let deviceToken: String
    let platform: String // "iOS" or "watchOS"
    let appVersion: String
    let osVersion: String
    let environment: String // "development" or "production"
    let creationDate: Date
    let modificationDate: Date
    let isActive: Bool
}

// MARK: - APNS Manager Protocol is defined in Protocols/APNSManaging.swift

// MARK: - APNS Manager Implementation

class APNSManager: NSObject, APNSManaging {
    // MARK: - Published Properties

    private(set) var isRegistered: Bool = false
    private(set) var currentDeviceToken: String?
    private(set) var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Private Properties

    private let cloudKitManager: any CloudKitManaging
    private let notificationCenter = UNUserNotificationCenter.current()
    private let cloudKitContainer = CKContainer.default()
    private var notificationStore: (any NotificationStoring)?

    // MARK: - Constants

    private enum Constants {
        static let deviceTokenKey = "APNSDeviceToken"
        static let lastTokenUpdateKey = "APNSLastTokenUpdate"
        static let tokenExpirationDays = 30
    }

    // MARK: - Initialization

    init(cloudKitManager: any CloudKitManaging, notificationStore: (any NotificationStoring)? = nil) {
        self.cloudKitManager = cloudKitManager
        self.notificationStore = notificationStore
        super.init()

        // Set up notification center delegate
        notificationCenter.delegate = self

        // Check current authorization status
        Task {
            await checkAuthorizationStatus()
        }
    }

    // Set notification store after init if needed
    func setNotificationStore(_ store: any NotificationStoring) {
        notificationStore = store
    }

    // MARK: - Public Methods

    func requestNotificationPermissions() async throws -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound, .providesAppNotificationSettings]
            )

            await checkAuthorizationStatus()

            if granted {
                registerForRemoteNotifications()
            }

            return granted
        } catch {
            throw APNSError.permissionDenied
        }
    }

    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func handleDeviceToken(_ deviceToken: Data) async throws {
        // Convert token to string
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        // Check if token has changed
        if tokenString == currentDeviceToken {
            print("Device token unchanged, skipping registration")
            return
        }

        // Save token locally
        currentDeviceToken = tokenString
        UserDefaults.standard.set(tokenString, forKey: Constants.deviceTokenKey)
        UserDefaults.standard.set(Date(), forKey: Constants.lastTokenUpdateKey)

        // Register with CloudKit
        try await registerTokenWithCloudKit(tokenString)

        isRegistered = true
    }

    func handleRegistrationError(_ error: Error) {
        print("Failed to register for remote notifications: \(error)")
        isRegistered = false
        currentDeviceToken = nil
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo

        // Extract notification type and metadata
        guard let notificationType = userInfo["notificationType"] as? String else {
            print("No notification type in payload")
            return
        }

        // Handle different notification types
        switch notificationType {
        case "newFollower":
            await handleNewFollowerFameFitNotification(userInfo)
        case "workoutKudos":
            await handleWorkoutKudosFameFitNotification(userInfo)
        case "followRequest":
            await handleFollowRequestFameFitNotification(userInfo)
        case "workoutCompleted":
            await handleWorkoutCompletedFameFitNotification(userInfo)
        case "achievementUnlocked", "unlockAchieved":
            await handleAchievementFameFitNotification(userInfo)
        case "levelUp":
            await handleLevelUpFameFitNotification(userInfo)
        default:
            print("Unknown notification type: \(notificationType)")
        }

        // Update badge count
        await updateBadgeCount()
    }

    func updateBadgeCount(_ count: Int) async {
        do {
            try await UNUserNotificationCenter.current().setBadgeCount(count)
        } catch {
            print("Failed to update badge count: \(error)")
        }
    }

    func unregisterDevice() async throws {
        guard let token = currentDeviceToken else { return }

        // Remove from CloudKit
        try await removeTokenFromCloudKit(token)

        // Clear local storage
        currentDeviceToken = nil
        isRegistered = false
        UserDefaults.standard.removeObject(forKey: Constants.deviceTokenKey)
        UserDefaults.standard.removeObject(forKey: Constants.lastTokenUpdateKey)
    }

    // MARK: - Private Methods

    private func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        notificationAuthorizationStatus = settings.authorizationStatus
    }

    private func registerTokenWithCloudKit(_ token: String) async throws {
        guard let userID = cloudKitManager.currentUserID else {
            throw APNSError.tokenRegistrationFailed
        }

        // Create device token record
        let record = CKRecord(recordType: "DeviceTokens")
        record["userID"] = userID
        record["deviceToken"] = token
        record["platform"] = "iOS"
        record["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        record["osVersion"] = await MainActor.run { UIDevice.current.systemVersion }
        record["environment"] = getAPNSEnvironment()
        // modificationDate is managed by CloudKit automatically
        record["isActive"] = 1

        do {
            // Save to private database
            _ = try await cloudKitContainer.privateCloudDatabase.save(record)
            print("Successfully registered device token with CloudKit")
        } catch {
            throw APNSError.cloudKitSaveFailed(error)
        }
    }

    private func removeTokenFromCloudKit(_ token: String) async throws {
        // Query for existing token records
        let predicate = NSPredicate(format: "deviceToken == %@", token)
        let query = CKQuery(recordType: "DeviceTokens", predicate: predicate)

        do {
            let records = try await cloudKitContainer.privateCloudDatabase.records(matching: query)

            // Mark records as inactive instead of deleting
            for (recordID, _) in records.matchResults {
                if let record = try? await cloudKitContainer.privateCloudDatabase.record(for: recordID) {
                    record["isActive"] = 0
                    // modificationDate is managed by CloudKit automatically
                    try await cloudKitContainer.privateCloudDatabase.save(record)
                }
            }
        } catch {
            throw APNSError.cloudKitSaveFailed(error)
        }
    }

    private func getAPNSEnvironment() -> String {
        #if DEBUG
            return "development"
        #else
            return "production"
        #endif
    }

    private func updateBadgeCount() async {
        // Get unread count from notification store
        let unreadCount = notificationStore?.unreadCount ?? 0
        await updateBadgeCount(unreadCount)
    }

    // MARK: - Notification Handlers

    private func handleNewFollowerFameFitNotification(_: [AnyHashable: Any]) async {
        print("Handling new follower notification")
        // Navigate to followers list or profile
    }

    private func handleWorkoutKudosFameFitNotification(_: [AnyHashable: Any]) async {
        print("Handling workout kudos notification")
        // Navigate to workout details
    }

    private func handleFollowRequestFameFitNotification(_: [AnyHashable: Any]) async {
        print("Handling follow request notification")
        // Navigate to follow requests
    }

    private func handleWorkoutCompletedFameFitNotification(_: [AnyHashable: Any]) async {
        print("Handling workout completed notification")
        // Show workout summary
    }

    private func handleAchievementFameFitNotification(_: [AnyHashable: Any]) async {
        print("Handling achievement notification")
        // Show achievement details
    }

    private func handleLevelUpFameFitNotification(_: [AnyHashable: Any]) async {
        print("Handling level up notification")
        // Show level up celebration
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension APNSManager: UNUserNotificationCenterDelegate {
    // Called when notification is received while app is in foreground
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }

    // Called when user interacts with notification
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task {
            await handleNotificationResponse(response)
            completionHandler()
        }
    }
}

// MARK: - Notification Categories

extension APNSManager {
    static func registerNotificationCategories() {
        let kudosCategory = UNNotificationCategory(
            identifier: "WORKOUT_KUDOS",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_WORKOUT",
                    title: "View Workout",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "KUDOS_BACK",
                    title: "Kudos Back",
                    options: .authenticationRequired
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        let followCategory = UNNotificationCategory(
            identifier: "FOLLOW_REQUEST",
            actions: [
                UNNotificationAction(
                    identifier: "ACCEPT_FOLLOW",
                    title: "Accept",
                    options: .authenticationRequired
                ),
                UNNotificationAction(
                    identifier: "DECLINE_FOLLOW",
                    title: "Decline",
                    options: .destructive
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        let workoutCategory = UNNotificationCategory(
            identifier: "WORKOUT_COMPLETED",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_WORKOUT",
                    title: "View Details",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "SHARE_WORKOUT",
                    title: "Share",
                    options: .foreground
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        let categories: Set<UNNotificationCategory> = [kudosCategory, followCategory, workoutCategory]
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
}
