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
        authenticationManager: AuthenticationManager,
        cloudKitManager: CloudKitManager,
        workoutObserver: WorkoutObserver,
        healthKitService: HealthKitService? = nil,
        modernHealthKitService: ModernHealthKitServicing? = nil,
        watchConnectivityManager: WatchConnectivityManaging? = nil,
        workoutSyncManager: WorkoutSyncManager? = nil,
        workoutSyncQueue: WorkoutSyncQueue? = nil,
        notificationStore: NotificationStore? = nil,
        unlockNotificationService: UnlockNotificationService? = nil,
        unlockStorageService: UnlockStorageService? = nil,
        userProfileService: UserProfileServicing? = nil,
        rateLimitingService: RateLimitingServicing? = nil,
        socialFollowingService: SocialFollowingServicing? = nil,
        activityFeedService: ActivityFeedServicing? = nil,
        notificationScheduler: NotificationScheduling? = nil,
        notificationManager: NotificationManaging? = nil,
        messageProvider: MessageProviding? = nil,
        workoutKudosService: WorkoutKudosServicing? = nil,
        apnsManager: APNSManaging? = nil,
        groupWorkoutService: GroupWorkoutServiceProtocol? = nil,
        workoutChallengesService: WorkoutChallengesServicing? = nil,
        subscriptionManager: CloudKitSubscriptionManaging? = nil,
        realTimeSyncCoordinator: (any RealTimeSyncCoordinating)? = nil,
        activityCommentsService: ActivityFeedCommentsServicing? = nil,
        activitySharingSettingsService: ActivityFeedSettingsServicing? = nil,
        bulkPrivacyUpdateService: BulkPrivacyUpdateServicing? = nil,
        workoutAutoShareService: WorkoutAutoShareServicing? = nil,
        xpTransactionService: XPTransactionService? = nil,
        countVerificationService: CountVerificationServicing? = nil,
        statsSyncService: StatsSyncServicing? = nil
    ) {
        // Create default instances for optional dependencies
        let resolvedHealthKitService = healthKitService ?? RealHealthKitService()
        let resolvedModernHealthKitService = modernHealthKitService ?? ModernHealthKitService()
        let resolvedWatchConnectivityManager: WatchConnectivityManaging = watchConnectivityManager ?? WatchConnectivitySingleton.shared
        let resolvedNotificationStore = notificationStore ?? NotificationStore()
        let resolvedUnlockStorageService = unlockStorageService ?? UnlockStorageService()
        let resolvedMessageProvider = messageProvider ?? FameFitMessageProvider()
        let resolvedNotificationScheduler = notificationScheduler ?? NotificationScheduler(
            notificationStore: resolvedNotificationStore
        )
        let resolvedApnsManager = apnsManager ?? APNSManager(cloudKitManager: cloudKitManager)
        
        let resolvedUnlockNotificationService = unlockNotificationService ?? UnlockNotificationService(
            notificationStore: resolvedNotificationStore,
            unlockStorage: resolvedUnlockStorageService
        )
        
        let resolvedNotificationManager = notificationManager ?? NotificationManager(
            scheduler: resolvedNotificationScheduler,
            notificationStore: resolvedNotificationStore,
            unlockService: resolvedUnlockNotificationService,
            messageProvider: resolvedMessageProvider
        )
        
        let resolvedWorkoutSyncManager = workoutSyncManager ?? WorkoutSyncManager(
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
            notificationManager: resolvedNotificationManager
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
            notificationManager: resolvedNotificationManager,
            rateLimiter: resolvedRateLimitingService
        )
        
        let resolvedWorkoutKudosService = workoutKudosService ?? WorkoutKudosService(
            userProfileService: resolvedUserProfileService,
            notificationManager: resolvedNotificationManager,
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
            notificationManager: resolvedNotificationManager,
            rateLimiter: resolvedRateLimitingService,
            workoutChallengeLinksService: workoutChallengeLinksService
        )
        
        let resolvedGroupWorkoutService = groupWorkoutService ?? GroupWorkoutService(
            cloudKitManager: cloudKitManager,
            userProfileService: resolvedUserProfileService,
            notificationManager: resolvedNotificationManager,
            rateLimiter: resolvedRateLimitingService
        )
        
        // Create subscription and push notification services
        let resolvedSubscriptionManager = subscriptionManager ?? CloudKitSubscriptionManager()
        
        // Create transaction and auto-share services
        let resolvedXpTransactionService = xpTransactionService ?? XPTransactionService(
            container: cloudKitManager.container
        )
        
        let resolvedWorkoutAutoShareService = workoutAutoShareService ?? WorkoutAutoShareService(
            workoutObserver: workoutObserver,
            activityFeedService: resolvedActivityFeedService,
            activityFeedSettingsService: resolvedActivitySharingSettingsService,
            notificationManager: resolvedNotificationManager,
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
            notificationManager: resolvedNotificationManager,
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
            modernHealthKitService: resolvedModernHealthKitService,
            watchConnectivityManager: resolvedWatchConnectivityManager,
            workoutSyncManager: resolvedWorkoutSyncManager,
            workoutSyncQueue: resolvedWorkoutSyncQueue,
            notificationStore: resolvedNotificationStore,
            unlockNotificationService: resolvedUnlockNotificationService,
            unlockStorageService: resolvedUnlockStorageService,
            userProfileService: resolvedUserProfileService,
            rateLimitingService: resolvedRateLimitingService,
            socialFollowingService: resolvedSocialFollowingService,
            activityFeedService: resolvedActivityFeedService,
            notificationScheduler: resolvedNotificationScheduler,
            notificationManager: resolvedNotificationManager,
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
