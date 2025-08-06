//
//  DependencyContainer+Init.swift
//  FameFit
//
//  Production initialization for DependencyContainer
//

import Foundation

// MARK: - Production Initialization

extension DependencyContainer {
    /// Initialize container with a dependency factory
    /// - Parameter factory: Factory to create dependencies (defaults to production)
    @MainActor
    convenience init(factory: DependencyFactory = ProductionDependencyFactory()) {
        // Phase 1: Core Services
        let cloudKitManager = factory.createCloudKitManager()
        let authenticationManager = factory.createAuthenticationManager(cloudKitManager: cloudKitManager)
        let healthKitService = factory.createHealthKitService()
        let modernHealthKitService = factory.createModernHealthKitService()
        let watchConnectivityManager = factory.createWatchConnectivityManager()
        let notificationStore = factory.createNotificationStore()
        let unlockStorageService = factory.createUnlockStorageService()
        
        // Phase 2: Workout Services
        let workoutObserver = factory.createWorkoutObserver(
            cloudKitManager: cloudKitManager,
            healthKitService: healthKitService
        )
        
        let workoutSyncManager = WorkoutSyncManager(
            cloudKitManager: cloudKitManager,
            healthKitService: healthKitService
        )
        
        let workoutSyncQueue = factory.createWorkoutSyncQueue(
            cloudKitManager: cloudKitManager
        )
        
        // Phase 3: Notification Services
        let unlockNotificationService = factory.createUnlockNotificationService(
            notificationStore: notificationStore,
            unlockStorage: unlockStorageService
        )
        
        let messageProvider = factory.createMessageProvider()
        let notificationScheduler = factory.createNotificationScheduler()
        let apnsManager = factory.createAPNSManager(cloudKitManager: cloudKitManager)
        
        let notificationManager = factory.createNotificationManager(
            notificationStore: notificationStore,
            scheduler: notificationScheduler
        )
        
        // Phase 4: User & Social Services
        let userProfileService = factory.createUserProfileService(
            cloudKitManager: cloudKitManager
        )
        
        let rateLimitingService = factory.createRateLimitingService()
        
        let socialFollowingService = factory.createSocialFollowingService(
            cloudKitManager: cloudKitManager,
            rateLimiter: rateLimitingService,
            profileService: userProfileService
        )
        
        // Phase 5: Activity Feed Services
        let activityFeedService = factory.createActivityFeedService(
            cloudKitManager: cloudKitManager
        )
        
        let activityCommentsService = factory.createActivityCommentsService(
            cloudKitManager: cloudKitManager
        )
        
        let workoutKudosService = factory.createWorkoutKudosService(
            cloudKitManager: cloudKitManager
        )
        
        // Phase 6: Privacy & Settings Services
        let bulkPrivacyUpdateService = factory.createBulkPrivacyUpdateService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService
        )
        
        let activitySharingSettingsService = factory.createActivitySharingSettingsService(
            cloudKitManager: cloudKitManager
        )
        
        // Phase 7: Challenge & Group Workout Services
        let workoutChallengesService = factory.createWorkoutChallengesService(
            cloudKitManager: cloudKitManager
        )
        
        let groupWorkoutService = factory.createGroupWorkoutService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager
        )
        
        // Phase 8: Subscription & Real-time Services
        let subscriptionManager = factory.createSubscriptionManager(
            cloudKitManager: cloudKitManager
        )
        
        _ = factory.createPushNotificationService(
            cloudKitManager: cloudKitManager,
            subscriptionManager: subscriptionManager
        )
        
        // Phase 9: Transaction & Auto-share Services
        let xpTransactionService = factory.createXPTransactionService(
            container: cloudKitManager.container
        )
        
        let workoutAutoShareService = factory.createWorkoutAutoShareService(
            activityFeedService: activityFeedService,
            settingsService: activitySharingSettingsService,
            notificationManager: notificationManager
        )
        
        // Phase 10: Real-time Sync Coordinator
        let realTimeSyncCoordinator = factory.createRealTimeSyncCoordinator(
            subscriptionManager: subscriptionManager,
            cloudKitManager: cloudKitManager,
            socialFollowingService: socialFollowingService,
            userProfileService: userProfileService,
            workoutKudosService: workoutKudosService,
            activityCommentsService: activityCommentsService,
            workoutChallengesService: workoutChallengesService,
            groupWorkoutService: groupWorkoutService,
            activityFeedService: activityFeedService
        )
        
        // Initialize with all services
        self.init(
            authenticationManager: authenticationManager,
            cloudKitManager: cloudKitManager,
            workoutObserver: workoutObserver,
            healthKitService: healthKitService,
            modernHealthKitService: modernHealthKitService,
            watchConnectivityManager: watchConnectivityManager,
            workoutSyncManager: workoutSyncManager,
            workoutSyncQueue: workoutSyncQueue,
            notificationStore: notificationStore,
            unlockNotificationService: unlockNotificationService,
            unlockStorageService: unlockStorageService,
            userProfileService: userProfileService,
            rateLimitingService: rateLimitingService,
            socialFollowingService: socialFollowingService,
            activityFeedService: activityFeedService,
            notificationScheduler: notificationScheduler,
            notificationManager: notificationManager,
            messageProvider: messageProvider,
            workoutKudosService: workoutKudosService,
            apnsManager: apnsManager,
            groupWorkoutService: groupWorkoutService,
            workoutChallengesService: workoutChallengesService,
            subscriptionManager: subscriptionManager,
            realTimeSyncCoordinator: realTimeSyncCoordinator,
            activityCommentsService: activityCommentsService,
            activitySharingSettingsService: activitySharingSettingsService,
            bulkPrivacyUpdateService: bulkPrivacyUpdateService,
            workoutAutoShareService: workoutAutoShareService,
            xpTransactionService: xpTransactionService
        )
        
        // Phase 11: Wire up circular dependencies (after all services are created)
        cloudKitManager.authenticationManager = authenticationManager
        cloudKitManager.xpTransactionService = xpTransactionService
        workoutObserver.cloudKitManager = cloudKitManager
        
        // Since we're already on MainActor, we can set these directly
        workoutSyncManager.notificationStore = notificationStore
        workoutSyncManager.notificationManager = notificationManager
        
        // Start CloudKit initialization after all dependencies are wired up
        cloudKitManager.startInitialization()
    }
}