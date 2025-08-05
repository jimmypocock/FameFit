//
//  RealTimeSyncCoordinator.swift
//  FameFit
//
//  Coordinates real-time synchronization across services using CloudKit subscriptions
//

import CloudKit
import Combine
import Foundation

// MARK: - Protocol

protocol RealTimeSyncCoordinating {
    func startRealTimeSync() async
    func stopRealTimeSync() async
    func handleRemoteChange(_ notification: CloudKitNotificationInfo) async
}

// MARK: - Implementation

final class RealTimeSyncCoordinator: RealTimeSyncCoordinating {
    // MARK: - Properties

    private let subscriptionManager: CloudKitSubscriptionManaging
    private let cloudKitManager: any CloudKitManaging
    private let socialFollowingService: SocialFollowingServicing?
    private let userProfileService: UserProfileServicing?
    private let workoutKudosService: WorkoutKudosServicing?
    private let activityCommentsService: ActivityFeedCommentsServicing?
    private let workoutChallengesService: WorkoutChallengesServicing?
    private let groupWorkoutService: GroupWorkoutServiceProtocol?
    private let activityFeedService: ActivityFeedServicing?

    private var cancellables = Set<AnyCancellable>()
    private var isRunning = false

    // Publishers for UI updates
    let profileUpdatePublisher = PassthroughSubject<String, Never>() // userId
    let feedUpdatePublisher = PassthroughSubject<Void, Never>()
    let challengeUpdatePublisher = PassthroughSubject<String, Never>() // challengeId
    let kudosUpdatePublisher = PassthroughSubject<String, Never>() // workoutId
    let commentUpdatePublisher = PassthroughSubject<String, Never>() // workoutId

    // MARK: - Initialization

    init(
        subscriptionManager: CloudKitSubscriptionManaging,
        cloudKitManager: any CloudKitManaging,
        socialFollowingService: SocialFollowingServicing? = nil,
        userProfileService: UserProfileServicing? = nil,
        workoutKudosService: WorkoutKudosServicing? = nil,
        activityCommentsService: ActivityFeedCommentsServicing? = nil,
        workoutChallengesService: WorkoutChallengesServicing? = nil,
        groupWorkoutService: GroupWorkoutServiceProtocol? = nil,
        activityFeedService: ActivityFeedServicing? = nil
    ) {
        self.subscriptionManager = subscriptionManager
        self.cloudKitManager = cloudKitManager
        self.socialFollowingService = socialFollowingService
        self.userProfileService = userProfileService
        self.workoutKudosService = workoutKudosService
        self.activityCommentsService = activityCommentsService
        self.workoutChallengesService = workoutChallengesService
        self.groupWorkoutService = groupWorkoutService
        self.activityFeedService = activityFeedService
    }

    // MARK: - Real-Time Sync

    func startRealTimeSync() async {
        guard !isRunning else { return }
        isRunning = true

        // Set up CloudKit subscriptions
        do {
            try await subscriptionManager.setupSubscriptions()
        } catch {
            print("Failed to setup subscriptions: \(error)")
        }

        // Listen for CloudKit notifications
        subscriptionManager.notificationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                Task { [weak self] in
                    await self?.handleRemoteChange(notification)
                }
            }
            .store(in: &cancellables)

        print("Real-time sync started")
    }

    func stopRealTimeSync() async {
        isRunning = false
        cancellables.removeAll()
        print("Real-time sync stopped")
    }

    // MARK: - Handle Remote Changes

    func handleRemoteChange(_ notification: CloudKitNotificationInfo) async {
        print("Handling remote change for \(notification.recordType): \(notification.changeType)")

        switch notification.recordType {
        case SubscriptionType.userProfile.recordType:
            await handleUserProfileChange(notification)

        case SubscriptionType.socialFollowing.recordType:
            await handleSocialFollowingChange(notification)

        case SubscriptionType.workoutKudos.recordType:
            await handleWorkoutKudosChange(notification)

        case SubscriptionType.workoutComments.recordType:
            await handleWorkoutCommentsChange(notification)

        case SubscriptionType.workoutChallenges.recordType:
            await handleWorkoutChallengeChange(notification)

        case SubscriptionType.groupWorkouts.recordType:
            await handleGroupWorkoutChange(notification)

        case SubscriptionType.activityFeed.recordType:
            await handleActivityFeedChange(notification)

        case SubscriptionType.workoutHistory.recordType:
            // Workout history changes trigger feed updates
            feedUpdatePublisher.send()

        default:
            print("Unknown record type: \(notification.recordType)")
        }
    }

    // MARK: - Specific Change Handlers

    private func handleUserProfileChange(_ notification: CloudKitNotificationInfo) async {
        let userId = notification.recordID.recordName
        print("DEBUG: handleUserProfileChange called for userId: \(userId)")

        // Clear cache for this user
        if let service = userProfileService {
            print("DEBUG: Calling clearCache for userId: \(userId)")
            service.clearCache(for: userId)
            print("DEBUG: clearCache called successfully")
        } else {
            print("DEBUG: userProfileService is nil!")
        }

        // Notify UI
        profileUpdatePublisher.send(userId)
    }

    private func handleSocialFollowingChange(_ notification: CloudKitNotificationInfo) async {
        // Extract follower and following IDs
        if let followerID = notification.userInfo["followerID"] as? String {
            profileUpdatePublisher.send(followerID)
        }

        if let followingID = notification.userInfo["followingID"] as? String {
            profileUpdatePublisher.send(followingID)
        }

        // Trigger feed refresh
        feedUpdatePublisher.send()
    }

    private func handleWorkoutKudosChange(_ notification: CloudKitNotificationInfo) async {
        if let workoutId = notification.userInfo["workoutId"] as? String {
            kudosUpdatePublisher.send(workoutId)
        }
    }

    private func handleWorkoutCommentsChange(_ notification: CloudKitNotificationInfo) async {
        if let workoutId = notification.userInfo["workoutId"] as? String {
            commentUpdatePublisher.send(workoutId)
        }
    }

    private func handleWorkoutChallengeChange(_ notification: CloudKitNotificationInfo) async {
        let challengeId = notification.recordID.recordName

        // Handle different challenge status changes
        if let status = notification.userInfo["status"] as? String {
            switch status {
            case "active":
                // Challenge started - refresh challenges view
                challengeUpdatePublisher.send(challengeId)

            case "completed":
                // Challenge completed - refresh and potentially show notification
                challengeUpdatePublisher.send(challengeId)

            default:
                challengeUpdatePublisher.send(challengeId)
            }
        } else {
            // General update
            challengeUpdatePublisher.send(challengeId)
        }
    }

    private func handleGroupWorkoutChange(_: CloudKitNotificationInfo) async {
        // Trigger feed refresh for group workout updates
        feedUpdatePublisher.send()
    }

    private func handleActivityFeedChange(_: CloudKitNotificationInfo) async {
        // New activity added - refresh feed
        feedUpdatePublisher.send()
    }
}

// MARK: - Sync State

enum SyncState {
    case idle
    case syncing
    case error(Error)

    var isActive: Bool {
        if case .syncing = self {
            return true
        }
        return false
    }
}

// MARK: - Connection Monitor

final class ConnectionMonitor: ObservableObject {
    @Published var isConnected = true
    @Published var syncState: SyncState = .idle

    private var monitor: NSObject? // Would use NWPathMonitor in real implementation

    func startMonitoring() {
        // Monitor network connectivity
        // This is a simplified version - real implementation would use Network framework
        isConnected = true
    }

    func stopMonitoring() {
        monitor = nil
    }
}
