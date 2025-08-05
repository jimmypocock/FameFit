//
//  DependencyContainer+Test.swift
//  FameFit
//
//  Test initialization for DependencyContainer
//

import Foundation
import CloudKit

// MARK: - Test Initialization

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
        groupWorkoutService: GroupWorkoutServicing? = nil,
        workoutChallengesService: WorkoutChallengesServicing? = nil,
        subscriptionManager: CloudKitSubscriptionManaging? = nil,
        realTimeSyncCoordinator: (any RealTimeSyncCoordinating)? = nil,
        activityCommentsService: ActivityFeedCommentsServicing? = nil,
        activitySharingSettingsService: ActivityFeedSettingsServicing? = nil,
        bulkPrivacyUpdateService: BulkPrivacyUpdateServicing? = nil,
        workoutAutoShareService: WorkoutAutoShareServicing? = nil,
        xpTransactionService: XPTransactionService? = nil,
        groupWorkoutSchedulingService: GroupWorkoutSchedulingServicing? = nil
    ) {
        // Create default instances for optional dependencies
        let finalHealthKitService = healthKitService ?? RealHealthKitService()
        let finalModernHealthKitService = modernHealthKitService ?? ModernHealthKitService()
        let finalWatchConnectivityManager: WatchConnectivityManaging = watchConnectivityManager ?? WatchConnectivitySingleton.shared
        let finalNotificationStore = notificationStore ?? NotificationStore()
        let finalUnlockStorageService = unlockStorageService ?? UnlockStorageService()
        let finalMessageProvider = messageProvider ?? FameFitMessageProvider()
        let finalNotificationScheduler = notificationScheduler ?? NotificationScheduler(
            notificationStore: finalNotificationStore
        )
        let finalApnsManager = apnsManager ?? APNSManager(cloudKitManager: cloudKitManager)
        
        let finalUnlockNotificationService = unlockNotificationService ?? UnlockNotificationService(
            notificationStore: finalNotificationStore,
            unlockStorage: finalUnlockStorageService
        )
        
        let finalNotificationManager = notificationManager ?? NotificationManager(
            scheduler: finalNotificationScheduler,
            notificationStore: finalNotificationStore,
            unlockService: finalUnlockNotificationService,
            messageProvider: finalMessageProvider
        )
        
        let finalWorkoutSyncManager = workoutSyncManager ?? WorkoutSyncManager(
            cloudKitManager: cloudKitManager,
            healthKitService: finalHealthKitService
        )
        
        let finalWorkoutSyncQueue = workoutSyncQueue ?? WorkoutSyncQueue(
            cloudKitManager: cloudKitManager
        )
        
        // Create user and social services
        let finalUserProfileService = userProfileService ?? UserProfileService(
            cloudKitManager: cloudKitManager
        )
        let finalRateLimitingService = rateLimitingService ?? RateLimitingService()
        let finalSocialFollowingService = socialFollowingService ?? CachedSocialFollowingService(
            cloudKitManager: cloudKitManager,
            rateLimiter: finalRateLimitingService,
            profileService: finalUserProfileService
        )
        
        // Create activity feed services
        let privacySettings = WorkoutPrivacySettings()
        let finalActivityFeedService = activityFeedService ?? ActivityFeedService(
            cloudKitManager: cloudKitManager,
            privacySettings: privacySettings
        )
        
        let finalActivityCommentsService = activityCommentsService ?? ActivityFeedCommentsService(
            cloudKitManager: cloudKitManager,
            userProfileService: finalUserProfileService,
            notificationManager: finalNotificationManager,
            rateLimiter: finalRateLimitingService
        )
        
        let finalWorkoutKudosService = workoutKudosService ?? WorkoutKudosService(
            userProfileService: finalUserProfileService,
            notificationManager: finalNotificationManager,
            rateLimiter: finalRateLimitingService
        )
        
        // Create bulk privacy and settings services
        let finalBulkPrivacyUpdateService = bulkPrivacyUpdateService ?? BulkPrivacyUpdateService(
            cloudKitManager: cloudKitManager,
            activityFeedService: finalActivityFeedService
        )
        
        let finalActivitySharingSettingsService = activitySharingSettingsService ?? ActivityFeedSettingsService(
            cloudKitManager: cloudKitManager
        )
        
        // Create challenge and group workout services
        let finalWorkoutChallengesService = workoutChallengesService ?? WorkoutChallengesService(
            cloudKitManager: cloudKitManager,
            userProfileService: finalUserProfileService,
            notificationManager: finalNotificationManager,
            rateLimiter: finalRateLimitingService
        )
        
        let finalGroupWorkoutService = groupWorkoutService ?? GroupWorkoutService(
            cloudKitManager: cloudKitManager,
            userProfileService: finalUserProfileService,
            notificationManager: finalNotificationManager,
            rateLimiter: finalRateLimitingService
        )
        
        let finalGroupWorkoutSchedulingService = groupWorkoutSchedulingService ?? GroupWorkoutSchedulingService(
            cloudKitManager: cloudKitManager,
            userProfileService: finalUserProfileService,
            notificationManager: finalNotificationManager
        )
        
        // Create subscription and push notification services
        let finalSubscriptionManager = subscriptionManager ?? CloudKitSubscriptionManager()
        
        // Create transaction and auto-share services
        let finalXpTransactionService = xpTransactionService ?? XPTransactionService(
            container: cloudKitManager.container
        )
        
        let finalWorkoutAutoShareService = workoutAutoShareService ?? WorkoutAutoShareService(
            workoutObserver: workoutObserver,
            activityFeedService: finalActivityFeedService,
            activityFeedSettingsService: finalActivitySharingSettingsService,
            notificationManager: finalNotificationManager,
            notificationStore: finalNotificationStore
        )
        
        // Create real-time sync coordinator
        let finalRealTimeSyncCoordinator = realTimeSyncCoordinator ?? RealTimeSyncCoordinator(
            subscriptionManager: finalSubscriptionManager,
            cloudKitManager: cloudKitManager,
            socialFollowingService: finalSocialFollowingService,
            userProfileService: finalUserProfileService,
            workoutKudosService: finalWorkoutKudosService,
            activityCommentsService: finalActivityCommentsService,
            workoutChallengesService: finalWorkoutChallengesService,
            groupWorkoutService: finalGroupWorkoutService,
            activityFeedService: finalActivityFeedService
        )
        
        // Call designated initializer
        self.init(
            authenticationManager: authenticationManager,
            cloudKitManager: cloudKitManager,
            workoutObserver: workoutObserver,
            healthKitService: finalHealthKitService,
            modernHealthKitService: finalModernHealthKitService,
            watchConnectivityManager: finalWatchConnectivityManager,
            workoutSyncManager: finalWorkoutSyncManager,
            workoutSyncQueue: finalWorkoutSyncQueue,
            notificationStore: finalNotificationStore,
            unlockNotificationService: finalUnlockNotificationService,
            unlockStorageService: finalUnlockStorageService,
            userProfileService: finalUserProfileService,
            rateLimitingService: finalRateLimitingService,
            socialFollowingService: finalSocialFollowingService,
            activityFeedService: finalActivityFeedService,
            notificationScheduler: finalNotificationScheduler,
            notificationManager: finalNotificationManager,
            messageProvider: finalMessageProvider,
            workoutKudosService: finalWorkoutKudosService,
            apnsManager: finalApnsManager,
            groupWorkoutService: finalGroupWorkoutService,
            workoutChallengesService: finalWorkoutChallengesService,
            subscriptionManager: finalSubscriptionManager,
            realTimeSyncCoordinator: finalRealTimeSyncCoordinator,
            activityCommentsService: finalActivityCommentsService,
            activitySharingSettingsService: finalActivitySharingSettingsService,
            bulkPrivacyUpdateService: finalBulkPrivacyUpdateService,
            workoutAutoShareService: finalWorkoutAutoShareService,
            xpTransactionService: finalXpTransactionService,
            groupWorkoutSchedulingService: finalGroupWorkoutSchedulingService
        )
    }
}