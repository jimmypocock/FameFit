//
//  CloudKitSubscriptionManager.swift
//  FameFit
//
//  Manages CloudKit subscriptions for real-time updates
//

import CloudKit
import Combine
import Foundation

// MARK: - Subscription Types

enum SubscriptionType: String, CaseIterable {
    case workoutHistory = "WorkoutHistory"
    case userProfile = "UserProfile"
    case socialFollowing = "SocialFollowing"
    case workoutKudos = "WorkoutKudos"
    case workoutComments = "WorkoutComments"
    case workoutChallenges = "WorkoutChallenges"
    case groupWorkouts = "GroupWorkouts"
    case activityFeed = "ActivityFeed"

    var recordType: String {
        rawValue
    }

    var subscriptionID: String {
        switch self {
        case .workoutHistory:
            "workout-history-subscription"
        case .userProfile:
            "user-profile-subscription"
        case .socialFollowing:
            "social-following-subscription"
        case .workoutKudos:
            "workout-kudos-subscription"
        case .workoutComments:
            "workout-comments-subscription"
        case .workoutChallenges:
            "workout-challenges-subscription"
        case .groupWorkouts:
            "group-workouts-subscription"
        case .activityFeed:
            "activity-feed-subscription"
        }
    }
}

// MARK: - Notification Info

struct CloudKitNotificationInfo {
    let recordType: String
    let recordID: CKRecord.ID
    let changeType: String
    let userInfo: [String: Any]
}

// MARK: - Protocol

protocol CloudKitSubscriptionManaging {
    func setupSubscriptions() async throws
    func removeAllSubscriptions() async throws
    func handleFameFitNotification(_ notification: CKQueryNotification) async

    var notificationPublisher: AnyPublisher<CloudKitNotificationInfo, Never> { get }
}

// MARK: - Implementation

final class CloudKitSubscriptionManager: CloudKitSubscriptionManaging {
    // MARK: - Properties

    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase

    private let notificationSubject = PassthroughSubject<CloudKitNotificationInfo, Never>()
    var notificationPublisher: AnyPublisher<CloudKitNotificationInfo, Never> {
        notificationSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(container: CKContainer = CKContainer.default()) {
        self.container = container
        publicDatabase = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase
    }

    // MARK: - Setup Subscriptions

    func setupSubscriptions() async throws {
        // Check if user is authenticated
        let status = try await container.accountStatus()
        guard status == .available else {
            print("CloudKit account not available for subscriptions")
            return
        }

        // Set up subscriptions for each type
        for subscriptionType in SubscriptionType.allCases {
            do {
                try await setupSubscription(for: subscriptionType)
            } catch {
                print("Failed to setup subscription for \(subscriptionType): \(error)")
            }
        }
    }

    private func setupSubscription(for type: SubscriptionType) async throws {
        let subscriptionID = type.subscriptionID
        let database = databaseForSubscriptionType(type)

        // Check if subscription already exists
        do {
            _ = try await database.subscription(for: CKQuerySubscription.ID(subscriptionID))
            print("Subscription \(subscriptionID) already exists")
            return
        } catch {
            // Subscription doesn't exist, create it
        }

        // Create subscription based on type
        let subscription = createSubscription(for: type)

        // Configure notification
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldBadge = false // We handle badging ourselves
        notificationInfo.shouldSendContentAvailable = true // For silent push

        // Add custom keys based on subscription type
        switch type {
        case .workoutHistory:
            notificationInfo.desiredKeys = ["workoutType", "startDate", "xpEarned"]
        case .userProfile:
            notificationInfo.desiredKeys = ["displayName", "totalXP", "currentLevel"]
        case .socialFollowing:
            notificationInfo.desiredKeys = ["followerID", "followingID", "status"]
        case .workoutKudos:
            notificationInfo.desiredKeys = ["workoutID", "userID", "timestamp"]
        case .workoutComments:
            notificationInfo.desiredKeys = ["workoutID", "userID", "content", "parentCommentID"]
        case .workoutChallenges:
            notificationInfo.desiredKeys = ["status", "participants", "type", "targetValue"]
        case .groupWorkouts:
            notificationInfo.desiredKeys = ["name", "startTime", "participantIDs", "status"]
        case .activityFeed:
            notificationInfo.desiredKeys = ["userID", "activityType", "timestamp", "isPublic"]
        }

        subscription.notificationInfo = notificationInfo

        // Save subscription
        do {
            _ = try await database.save(subscription)
            print("Successfully created subscription: \(subscriptionID)")
        } catch {
            throw SubscriptionError.failedToCreate(type: type, error: error)
        }
    }

    private func createSubscription(for type: SubscriptionType) -> CKQuerySubscription {
        let predicate: NSPredicate
        let options: CKQuerySubscription.Options

        switch type {
        case .workoutHistory:
            // Subscribe to all new workout records
            predicate = NSPredicate(value: true)
            options = [.firesOnRecordCreation]

        case .userProfile:
            // Subscribe to profile updates
            predicate = NSPredicate(value: true)
            options = [.firesOnRecordUpdate]

        case .socialFollowing:
            // Subscribe to following relationship changes
            predicate = NSPredicate(value: true)
            options = [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]

        case .workoutKudos:
            // Subscribe to kudos changes
            predicate = NSPredicate(value: true)
            options = [.firesOnRecordCreation, .firesOnRecordDeletion]

        case .workoutComments:
            // Subscribe to new comments
            predicate = NSPredicate(value: true)
            options = [.firesOnRecordCreation, .firesOnRecordUpdate]

        case .workoutChallenges:
            // Subscribe to challenge updates
            predicate = NSPredicate(value: true)
            options = [.firesOnRecordCreation, .firesOnRecordUpdate]

        case .groupWorkouts:
            // Subscribe to group workout changes
            predicate = NSPredicate(value: true)
            options = [.firesOnRecordCreation, .firesOnRecordUpdate]

        case .activityFeed:
            // Subscribe to new activities
            predicate = NSPredicate(format: "isPublic == %@", NSNumber(value: true))
            options = [.firesOnRecordCreation]
        }

        return CKQuerySubscription(
            recordType: type.recordType,
            predicate: predicate,
            subscriptionID: type.subscriptionID,
            options: options
        )
    }

    private func databaseForSubscriptionType(_ type: SubscriptionType) -> CKDatabase {
        switch type {
        case .workoutHistory:
            privateDatabase
        case .userProfile, .socialFollowing, .workoutKudos, .workoutComments,
             .workoutChallenges, .groupWorkouts, .activityFeed:
            publicDatabase
        }
    }

    // MARK: - Remove Subscriptions

    func removeAllSubscriptions() async throws {
        for subscriptionType in SubscriptionType.allCases {
            let database = databaseForSubscriptionType(subscriptionType)
            let subscriptionID = subscriptionType.subscriptionID

            do {
                try await database.deleteSubscription(withID: CKQuerySubscription.ID(subscriptionID))
                print("Removed subscription: \(subscriptionID)")
            } catch {
                print("Failed to remove subscription \(subscriptionID): \(error)")
            }
        }
    }

    // MARK: - Handle Notifications

    func handleFameFitNotification(_ notification: CKQueryNotification) async {
        guard let recordID = notification.recordID else { return }

        let recordType = notification.recordFields?["recordType"] as? String ?? ""
        let changeType = notification.queryNotificationReason

        // Extract user info
        var userInfo: [String: Any] = [:]
        if let recordFields = notification.recordFields {
            userInfo = recordFields
        }

        // Create notification info
        let notificationInfo = CloudKitNotificationInfo(
            recordType: recordType,
            recordID: recordID,
            changeType: changeTypeKey(for: changeType),
            userInfo: userInfo
        )

        // Publish notification
        notificationSubject.send(notificationInfo)

        // Mark notification as read
        if let notificationID = notification.notificationID {
            do {
                try await container.markNotificationRead(notificationID)
            } catch {
                print("Failed to mark notification as read: \(error)")
            }
        }
    }

    private func changeTypeKey(for reason: CKQueryNotification.Reason) -> String {
        switch reason {
        case .recordCreated:
            return "recordCreated"
        case .recordUpdated:
            return "recordUpdated"
        case .recordDeleted:
            return "recordDeleted"
        @unknown default:
            return "unknown"
        }
    }
}

// MARK: - Container Extension

extension CKContainer {
    func markNotificationRead(_: CKNotification.ID) async throws {
        // Note: CKMarkNotificationsReadOperation is deprecated
        // Consider using CKDatabaseSubscription, CKFetchDatabaseChangesOperation,
        // and CKFetchRecordZoneChangesOperation as recommended by Apple
        print("Notification read marking is no longer supported by CloudKit")
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case failedToCreate(type: SubscriptionType, error: Error)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case let .failedToCreate(type, error):
            "Failed to create subscription for \(type.rawValue): \(error.localizedDescription)"
        case .notAuthenticated:
            "User is not authenticated with CloudKit"
        }
    }
}
