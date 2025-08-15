//
//  DependencyContainer+TestSupport.swift
//  FameFit
//
//  Test support initialization for DependencyContainer
//  Only available in DEBUG builds to prevent test code from shipping to production
//

#if DEBUG

import Foundation
import CloudKit
import WatchConnectivity
import Combine
import HealthKit

// MARK: - Simple Test Mocks

private class TestMockMessageProvider: MessagingProtocol {
    var personality = MessagePersonality.default
    
    func getMessage(for context: MessageContext) -> String { "Test message" }
    func getMessage(for category: MessageCategory, context: MessageContext) -> String { "Test message" }
    func getTimeAwareMessage(at time: Date) -> String { "Test message" }
    func getMotivationalMessage() -> String { "Test message" }
    func getRoastMessage(for workoutType: HKWorkoutActivityType?) -> String { "Test roast" }
    func getCatchphrase() -> String { "Test catchphrase" }
    func updatePersonality(_ newPersonality: MessagePersonality) { personality = newPersonality }
    func shouldIncludeCategory(_ category: MessageCategory) -> Bool { true }
    
    // Notification methods
    func getWorkoutEndMessage(workoutType: String, duration: Int, calories: Int, xpEarned: Int) -> String {
        "Workout complete"
    }
    func getStreakMessage(streak: Int, isAtRisk: Bool) -> String {
        "Streak: \(streak) days"
    }
    func getXPMilestoneMessage(level: Int, title: String) -> String {
        "Level \(level): \(title)"
    }
    func getFollowerMessage(username: String, displayName: String, action: String) -> String {
        "\(displayName) \(action)"
    }
}

// MARK: - Test Support Initialization

extension DependencyContainer {
    /// Initialize container with mock services for testing
    /// All parameters are optional to allow partial mocking
    @MainActor
    convenience init(
        authenticationManager: AuthenticationService,
        cloudKitManager: CloudKitService,
        healthKitService: HealthKitProtocol? = nil,
        watchConnectivityManager: WatchConnectivityProtocol? = nil,
        workoutSyncManager: WorkoutSyncService? = nil,
        notificationStore: NotificationStore? = nil,
        unlockNotificationService: UnlockNotificationService? = nil,
        unlockStorageService: UnlockStorageService? = nil,
        userProfileService: UserProfileProtocol? = nil,
        rateLimitingService: RateLimitingProtocol? = nil,
        socialFollowingService: SocialFollowingProtocol? = nil,
        activityFeedService: ActivityFeedProtocol? = nil,
        notificationScheduler: NotificationSchedulingProtocol? = nil,
        notificationManager: NotificationProtocol? = nil,
        messageProvider: MessagingProtocol? = nil,
        workoutKudosService: WorkoutKudosProtocol? = nil,
        apnsManager: APNSProtocol? = nil,
        groupWorkoutService: GroupWorkoutProtocol? = nil,
        workoutChallengesService: WorkoutChallengesProtocol? = nil,
        subscriptionManager: CloudKitSubscriptionProtocol? = nil,
        realTimeSyncCoordinator: (any RealTimeSyncProtocol)? = nil,
        activityCommentsService: ActivityFeedCommentsProtocol? = nil,
        activitySharingSettingsService: ActivityFeedSettingsProtocol? = nil,
        bulkPrivacyUpdateService: BulkPrivacyUpdateProtocol? = nil,
        xpTransactionService: XPTransactionService? = nil,
        countVerificationService: CountVerificationProtocol? = nil,
        statsSyncService: StatsSyncProtocol? = nil,
        workoutQueue: WorkoutQueue? = nil
    ) {
        // Create default instances for optional dependencies
        let resolvedHealthKitService = healthKitService ?? HealthKitService()
        let resolvedWatchConnectivityManager: WatchConnectivityProtocol = watchConnectivityManager ?? EnhancedWatchConnectivityManager()
        let resolvedNotificationStore = notificationStore ?? NotificationStore()
        let resolvedUnlockStorageService = unlockStorageService ?? UnlockStorageService()
        let resolvedMessageProvider: MessagingProtocol = messageProvider ?? TestMockMessageProvider()
        let resolvedNotificationScheduler = notificationScheduler ?? NotificationScheduler(
            notificationStore: resolvedNotificationStore
        )
        let resolvedApnsManager = apnsManager ?? APNSService(cloudKitManager: cloudKitManager)
        
        let resolvedUnlockNotificationService = unlockNotificationService ?? UnlockNotificationService(
            notificationStore: resolvedNotificationStore,
            unlockStorage: resolvedUnlockStorageService
        )
        
        let resolvedNotificationService = notificationManager ?? NotificationService(
            scheduler: resolvedNotificationScheduler,
            notificationStore: resolvedNotificationStore,
            unlockService: resolvedUnlockNotificationService,
            messageProvider: resolvedMessageProvider
        )
        
        let resolvedWorkoutSyncService = workoutSyncManager ?? WorkoutSyncService(
            cloudKitManager: cloudKitManager,
            healthKitService: resolvedHealthKitService
        )
        
        // Create user and social services
        let resolvedUserProfileService = userProfileService ?? UserProfileService(
            cloudKitManager: cloudKitManager
        )
        let resolvedRateLimitingService = rateLimitingService ?? RateLimitingService()
        let resolvedSocialFollowingService = socialFollowingService ?? CachedSocialFollowingService(
            cloudKitManager: cloudKitManager,
            rateLimiter: resolvedRateLimitingService,
            profileService: resolvedUserProfileService,
            notificationManager: resolvedNotificationService
        )
        
        // Create activity feed services
        let userSettings = UserSettings.defaultSettings(for: cloudKitManager.currentUserID ?? "test-user")
        let resolvedActivityFeedService = activityFeedService ?? ActivityFeedService(
            cloudKitManager: cloudKitManager,
            userSettings: userSettings
        )
        
        let resolvedActivityCommentsService = activityCommentsService ?? ActivityFeedCommentsService(
            cloudKitManager: cloudKitManager,
            userProfileService: resolvedUserProfileService,
            notificationManager: resolvedNotificationService,
            rateLimiter: resolvedRateLimitingService
        )
        
        let resolvedWorkoutKudosService = workoutKudosService ?? WorkoutKudosService(
            userProfileService: resolvedUserProfileService,
            notificationManager: resolvedNotificationService,
            rateLimiter: resolvedRateLimitingService
        )
        
        // Create bulk privacy and settings services
        let resolvedBulkPrivacyUpdateService = bulkPrivacyUpdateService ?? BulkPrivacyUpdateService(
            cloudKitManager: cloudKitManager,
            activityFeedService: resolvedActivityFeedService
        )
        
        let resolvedActivitySharingSettingsService = activitySharingSettingsService ?? ActivityFeedSettingsService(
            cloudKitManager: cloudKitManager
        )
        
        // Create WorkoutChallengeLinksService first
        let workoutChallengeLinksService = WorkoutChallengeLinksService(
            cloudKitManager: cloudKitManager
        )
        
        // Create challenge and group workout services
        let resolvedWorkoutChallengesService = workoutChallengesService ?? WorkoutChallengesService(
            cloudKitManager: cloudKitManager,
            userProfileService: resolvedUserProfileService,
            notificationManager: resolvedNotificationService,
            rateLimiter: resolvedRateLimitingService,
            workoutChallengeLinksService: workoutChallengeLinksService
        )
        
        let resolvedGroupWorkoutService = groupWorkoutService ?? GroupWorkoutService(
            cloudKitManager: cloudKitManager,
            userProfileService: resolvedUserProfileService,
            notificationManager: resolvedNotificationService,
            rateLimiter: resolvedRateLimitingService
        )
        
        // Create subscription and push notification services
        let resolvedSubscriptionManager = subscriptionManager ?? CloudKitSubscriptionService()
        
        // Create transaction and auto-share services
        let resolvedXpTransactionService = xpTransactionService ?? XPTransactionService(
            container: cloudKitManager.container
        )
        
        
        // Create real-time sync coordinator
        let resolvedRealTimeSyncCoordinator = realTimeSyncCoordinator ?? RealTimeSyncCoordinator(
            subscriptionManager: resolvedSubscriptionManager,
            cloudKitManager: cloudKitManager,
            socialFollowingService: resolvedSocialFollowingService,
            userProfileService: resolvedUserProfileService,
            workoutKudosService: resolvedWorkoutKudosService,
            activityCommentsService: resolvedActivityCommentsService,
            workoutChallengesService: resolvedWorkoutChallengesService,
            groupWorkoutService: resolvedGroupWorkoutService,
            activityFeedService: resolvedActivityFeedService
        )
        
        // Create WorkoutProcessor for testing
        let resolvedWorkoutProcessor = WorkoutProcessor(
            cloudKitManager: cloudKitManager,
            xpTransactionService: resolvedXpTransactionService,
            activityFeedService: resolvedActivityFeedService,
            notificationManager: resolvedNotificationService,
            userProfileService: resolvedUserProfileService,
            workoutChallengesService: resolvedWorkoutChallengesService,
            workoutChallengeLinksService: workoutChallengeLinksService,
            activitySettingsService: resolvedActivitySharingSettingsService
        )
        
        // Create verification service
        let resolvedCountVerificationService = countVerificationService ?? CountVerificationService(
            cloudKitManager: cloudKitManager,
            userProfileService: resolvedUserProfileService,
            xpTransactionService: resolvedXpTransactionService
        )
        
        // Create stats sync service
        let resolvedStatsSyncService = statsSyncService ?? StatsSyncService(
            container: cloudKitManager.container,
            operationQueue: CloudKitOperationQueue()
        )
        
        // Create workout queue
        let resolvedWorkoutQueue = workoutQueue ?? WorkoutQueue(
            cloudKitManager: cloudKitManager,
            xpTransactionService: resolvedXpTransactionService,
            activityFeedService: resolvedActivityFeedService,
            notificationManager: resolvedNotificationService
        )
        
        // Call designated initializer
        self.init(
            authenticationManager: authenticationManager,
            cloudKitManager: cloudKitManager,
            workoutProcessor: resolvedWorkoutProcessor,
            healthKitService: resolvedHealthKitService,
            watchConnectivityManager: resolvedWatchConnectivityManager,
            workoutSyncManager: resolvedWorkoutSyncService,
            notificationStore: resolvedNotificationStore,
            unlockNotificationService: resolvedUnlockNotificationService,
            unlockStorageService: resolvedUnlockStorageService,
            userProfileService: resolvedUserProfileService,
            rateLimitingService: resolvedRateLimitingService,
            socialFollowingService: resolvedSocialFollowingService,
            activityFeedService: resolvedActivityFeedService,
            notificationScheduler: resolvedNotificationScheduler,
            notificationManager: resolvedNotificationService,
            messageProvider: resolvedMessageProvider,
            workoutKudosService: resolvedWorkoutKudosService,
            apnsManager: resolvedApnsManager,
            groupWorkoutService: resolvedGroupWorkoutService,
            workoutChallengesService: resolvedWorkoutChallengesService,
            workoutChallengeLinksService: workoutChallengeLinksService,
            subscriptionManager: resolvedSubscriptionManager,
            realTimeSyncCoordinator: resolvedRealTimeSyncCoordinator,
            activityCommentsService: resolvedActivityCommentsService,
            activitySharingSettingsService: resolvedActivitySharingSettingsService,
            bulkPrivacyUpdateService: resolvedBulkPrivacyUpdateService,
            xpTransactionService: resolvedXpTransactionService,
            countVerificationService: resolvedCountVerificationService,
            statsSyncService: resolvedStatsSyncService,
            workoutQueue: resolvedWorkoutQueue
        )
    }
}

#endif // DEBUG
