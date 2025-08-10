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

// MARK: - Test Support Initialization

extension DependencyContainer {
    /// Initialize container with mock services for testing
    /// All parameters are optional to allow partial mocking
    @MainActor
    convenience init(
        authenticationManager: AuthenticationService,
        cloudKitManager: CloudKitService,
        workoutObserver: WorkoutObserver,
        healthKitService: HealthKitProtocol? = nil,
        watchConnectivityManager: WatchConnectivityProtocol? = nil,
        workoutSyncManager: WorkoutSyncService? = nil,
        workoutSyncQueue: WorkoutSyncQueue? = nil,
        notificationStore: NotificationStore? = nil,
        unlockNotificationService: UnlockNotificationService? = nil,
        unlockStorageService: UnlockStorageService? = nil,
        userProfileService: UserProfileProtocol? = nil,
        rateLimitingService: RateLimitingProtocol? = nil,
        socialFollowingService: SocialFollowingProtocol? = nil,
        activityFeedService: ActivityFeedProtocol? = nil,
        notificationScheduler: NotificationSchedulingProtocol? = nil,
        notificationManager: NotificationProtocol? = nil,
        messageProvider: MessageProvidingProtocol? = nil,
        workoutKudosService: WorkoutKudosProtocol? = nil,
        apnsManager: APNSProtocol? = nil,
        groupWorkoutService: GroupWorkoutProtocol? = nil,
        workoutChallengesService: WorkoutChallengesProtocol? = nil,
        subscriptionManager: CloudKitSubscriptionProtocol? = nil,
        realTimeSyncCoordinator: (any RealTimeSyncCoordinatorProtocol)? = nil,
        activityCommentsService: ActivityFeedCommentsProtocol? = nil,
        activitySharingSettingsService: ActivityFeedSettingsProtocol? = nil,
        bulkPrivacyUpdateService: BulkPrivacyUpdateProtocol? = nil,
        workoutAutoShareService: WorkoutAutoShareProtocol? = nil,
        xpTransactionService: XPTransactionService? = nil,
        countVerificationService: CountVerificationProtocol? = nil,
        statsSyncService: StatsSyncProtocol? = nil
    ) {
        // Create default instances for optional dependencies
        let resolvedHealthKitService = healthKitService ?? HealthKitService()
        let resolvedWatchConnectivityManager: WatchConnectivityProtocol = watchConnectivityManager ?? WatchConnectivitySingleton.shared
        let resolvedNotificationStore = notificationStore ?? NotificationStore()
        let resolvedUnlockStorageService = unlockStorageService ?? UnlockStorageService()
        let resolvedMessageProvider = messageProvider ?? FameFitMessageProvider()
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
        
        let resolvedWorkoutSyncQueue = workoutSyncQueue ?? WorkoutSyncQueue(
            cloudKitManager: cloudKitManager
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
        let privacySettings = WorkoutPrivacySettings()
        let resolvedActivityFeedService = activityFeedService ?? ActivityFeedService(
            cloudKitManager: cloudKitManager,
            privacySettings: privacySettings
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
        
        let resolvedWorkoutAutoShareService = workoutAutoShareService ?? WorkoutAutoShareService(
            workoutObserver: workoutObserver,
            activityFeedService: resolvedActivityFeedService,
            activityFeedSettingsService: resolvedActivitySharingSettingsService,
            notificationManager: resolvedNotificationService,
            notificationStore: resolvedNotificationStore
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
        
        // Call designated initializer
        self.init(
            authenticationManager: authenticationManager,
            cloudKitManager: cloudKitManager,
            workoutObserver: workoutObserver,
            workoutProcessor: resolvedWorkoutProcessor,
            healthKitService: resolvedHealthKitService,
            watchConnectivityManager: resolvedWatchConnectivityManager,
            workoutSyncManager: resolvedWorkoutSyncService,
            workoutSyncQueue: resolvedWorkoutSyncQueue,
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
            workoutAutoShareService: resolvedWorkoutAutoShareService,
            xpTransactionService: resolvedXpTransactionService,
            countVerificationService: resolvedCountVerificationService,
            statsSyncService: resolvedStatsSyncService
        )
    }
}

#endif // DEBUG
