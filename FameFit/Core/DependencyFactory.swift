//
//  DependencyFactory.swift
//  FameFit
//
//  Factory pattern for creating app dependencies
//

import Foundation
import CloudKit

// MARK: - Dependency Factory Protocol

protocol DependencyFactory: AnyObject {
    // Core Services
    func createCloudKitManager() -> CloudKitManager
    func createAuthenticationManager(cloudKitManager: CloudKitManager) -> AuthenticationManager
    func createHealthKitService() -> HealthKitService
    func createModernHealthKitService() -> ModernHealthKitServicing
    func createWatchConnectivityManager() -> WatchConnectivityManaging
    func createNotificationStore() -> NotificationStore
    func createUnlockStorageService() -> UnlockStorageService
    func createUnlockNotificationService(notificationStore: NotificationStore, unlockStorage: UnlockStorageService) -> UnlockNotificationService
    func createNotificationScheduler() -> NotificationScheduling
    func createAPNSManager(cloudKitManager: CloudKitManager) -> APNSManaging
    
    // Workflow Services
    func createWorkoutObserver(cloudKitManager: CloudKitManager, healthKitService: HealthKitService) -> WorkoutObserver
    func createWorkoutSyncManager(cloudKitManager: CloudKitManager, healthKitService: HealthKitService) -> WorkoutSyncManager
    func createWorkoutSyncQueue(cloudKitManager: CloudKitManager) -> WorkoutSyncQueue
    
    // Social Services
    func createUserProfileService(cloudKitManager: CloudKitManager) -> UserProfileServicing
    func createRateLimitingService() -> RateLimitingService
    func createNotificationManager(notificationStore: NotificationStore, scheduler: NotificationScheduling) -> NotificationManaging
    func createSocialFollowingService(cloudKitManager: CloudKitManager, rateLimiter: RateLimitingServicing, profileService: UserProfileServicing) -> SocialFollowingServicing
    func createBulkPrivacyUpdateService(cloudKitManager: CloudKitManager, userProfileService: UserProfileServicing) -> BulkPrivacyUpdateServicing
    func createWorkoutChallengesService(cloudKitManager: CloudKitManager) -> WorkoutChallengesServicing
    func createActivityFeedService(cloudKitManager: CloudKitManager) -> ActivityFeedServicing
    func createActivityCommentsService(cloudKitManager: CloudKitManager) -> ActivityFeedCommentsServicing
    func createSubscriptionManager(cloudKitManager: CloudKitManager) -> CloudKitSubscriptionManaging
    func createPushNotificationService(cloudKitManager: CloudKitManager, subscriptionManager: CloudKitSubscriptionManaging) -> CloudKitPushNotificationService
    func createWorkoutKudosService(cloudKitManager: CloudKitManager) -> WorkoutKudosServicing
    func createActivitySharingSettingsService(cloudKitManager: CloudKitManager) -> ActivityFeedSettingsServicing
    func createWorkoutAutoShareService(activityFeedService: ActivityFeedServicing, settingsService: ActivityFeedSettingsServicing, notificationManager: NotificationManaging) -> WorkoutAutoShareServicing
    func createXPTransactionService(container: CKContainer) -> XPTransactionService
    func createGroupWorkoutService(cloudKitManager: CloudKitManager, userProfileService: UserProfileServicing, notificationManager: NotificationManaging) -> GroupWorkoutServiceProtocol
    func createRealTimeSyncCoordinator(subscriptionManager: CloudKitSubscriptionManaging, cloudKitManager: CloudKitManager, socialFollowingService: SocialFollowingServicing, userProfileService: UserProfileServicing, workoutKudosService: WorkoutKudosServicing, activityCommentsService: ActivityFeedCommentsServicing, workoutChallengesService: WorkoutChallengesServicing, groupWorkoutService: GroupWorkoutServiceProtocol, activityFeedService: ActivityFeedServicing) -> RealTimeSyncCoordinating
    
    // Utilities
    func createMessageProvider() -> MessageProviding
}

// MARK: - Production Dependency Factory

class ProductionDependencyFactory: DependencyFactory {
    
    // MARK: - Core Services
    
    func createCloudKitManager() -> CloudKitManager {
        CloudKitManager()
    }
    
    func createAuthenticationManager(cloudKitManager: CloudKitManager) -> AuthenticationManager {
        AuthenticationManager(cloudKitManager: cloudKitManager)
    }
    
    func createHealthKitService() -> HealthKitService {
        RealHealthKitService()
    }
    
    func createModernHealthKitService() -> ModernHealthKitServicing {
        ModernHealthKitService()
    }
    
    func createWatchConnectivityManager() -> WatchConnectivityManaging {
        // WatchConnectivity should be a singleton since WCSession is a singleton
        // We still return it through the factory for consistency and testability
        return WatchConnectivitySingleton.shared
    }
    
    func createNotificationStore() -> NotificationStore {
        NotificationStore()
    }
    
    func createUnlockStorageService() -> UnlockStorageService {
        UnlockStorageService()
    }
    
    func createUnlockNotificationService(notificationStore: NotificationStore, unlockStorage: UnlockStorageService) -> UnlockNotificationService {
        UnlockNotificationService(
            notificationStore: notificationStore,
            unlockStorage: unlockStorage
        )
    }
    
    func createNotificationScheduler() -> NotificationScheduling {
        NotificationScheduler(notificationStore: NotificationStore())
    }
    
    func createAPNSManager(cloudKitManager: CloudKitManager) -> APNSManaging {
        APNSManager(cloudKitManager: cloudKitManager)
    }
    
    // MARK: - Workflow Services
    
    func createWorkoutObserver(
        cloudKitManager: CloudKitManager,
        healthKitService: HealthKitService
    ) -> WorkoutObserver {
        WorkoutObserver(
            cloudKitManager: cloudKitManager,
            healthKitService: healthKitService
        )
    }
    
    func createWorkoutSyncManager(
        cloudKitManager: CloudKitManager,
        healthKitService: HealthKitService
    ) -> WorkoutSyncManager {
        // Note: WorkoutSyncManager is @MainActor, so it must be created on the main actor
        // This factory method is not used anymore - WorkoutSyncManager is created directly in DependencyContainer+Init
        fatalError("WorkoutSyncManager must be created on MainActor. Use DependencyContainer init instead.")
    }
    
    func createWorkoutSyncQueue(cloudKitManager: CloudKitManager) -> WorkoutSyncQueue {
        WorkoutSyncQueue(cloudKitManager: cloudKitManager)
    }
    
    // MARK: - Social Services
    
    func createUserProfileService(cloudKitManager: CloudKitManager) -> UserProfileServicing {
        UserProfileService(cloudKitManager: cloudKitManager)
    }
    
    func createRateLimitingService() -> RateLimitingService {
        RateLimitingService()
    }
    
    func createNotificationManager(notificationStore: NotificationStore, scheduler: NotificationScheduling) -> NotificationManaging {
        let unlockService = createUnlockNotificationService(
            notificationStore: notificationStore,
            unlockStorage: createUnlockStorageService()
        )
        let messageProvider = createMessageProvider()
        
        return NotificationManager(
            scheduler: scheduler,
            notificationStore: notificationStore,
            unlockService: unlockService,
            messageProvider: messageProvider
        )
    }
    
    func createSocialFollowingService(
        cloudKitManager: CloudKitManager, 
        rateLimiter: RateLimitingServicing, 
        profileService: UserProfileServicing
    ) -> SocialFollowingServicing {
        CachedSocialFollowingService(
            cloudKitManager: cloudKitManager,
            rateLimiter: rateLimiter,
            profileService: profileService
        )
    }
    
    func createBulkPrivacyUpdateService(
        cloudKitManager: CloudKitManager,
        userProfileService: UserProfileServicing
    ) -> BulkPrivacyUpdateServicing {
        // First need to create ActivityFeedService for BulkPrivacyUpdateService
        let activityFeedService = createActivityFeedService(cloudKitManager: cloudKitManager)
        return BulkPrivacyUpdateService(
            cloudKitManager: cloudKitManager,
            activityFeedService: activityFeedService
        )
    }
    
    func createWorkoutChallengesService(cloudKitManager: CloudKitManager) -> WorkoutChallengesServicing {
        let userProfileService = createUserProfileService(cloudKitManager: cloudKitManager)
        let notificationStore = createNotificationStore()
        let scheduler = createNotificationScheduler()
        let notificationManager = createNotificationManager(notificationStore: notificationStore, scheduler: scheduler)
        let rateLimiter = createRateLimitingService()
        return WorkoutChallengesService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimiter
        )
    }
    
    func createActivityFeedService(cloudKitManager: CloudKitManager) -> ActivityFeedServicing {
        let privacySettings = WorkoutPrivacySettings()
        return ActivityFeedService(cloudKitManager: cloudKitManager, privacySettings: privacySettings)
    }
    
    func createActivityCommentsService(cloudKitManager: CloudKitManager) -> ActivityFeedCommentsServicing {
        let userProfileService = createUserProfileService(cloudKitManager: cloudKitManager)
        let notificationStore = createNotificationStore()
        let scheduler = createNotificationScheduler()
        let notificationManager = createNotificationManager(notificationStore: notificationStore, scheduler: scheduler)
        let rateLimiter = createRateLimitingService()
        return ActivityFeedCommentsService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimiter
        )
    }
    
    func createSubscriptionManager(cloudKitManager: CloudKitManager) -> CloudKitSubscriptionManaging {
        CloudKitSubscriptionManager()
    }
    
    func createPushNotificationService(
        cloudKitManager: CloudKitManager,
        subscriptionManager: CloudKitSubscriptionManaging
    ) -> CloudKitPushNotificationService {
        CloudKitPushNotificationService()
    }
    
    func createWorkoutKudosService(cloudKitManager: CloudKitManager) -> WorkoutKudosServicing {
        let userProfileService = createUserProfileService(cloudKitManager: cloudKitManager)
        let notificationStore = createNotificationStore()
        let scheduler = createNotificationScheduler()
        let notificationManager = createNotificationManager(notificationStore: notificationStore, scheduler: scheduler)
        let rateLimiter = createRateLimitingService()
        return WorkoutKudosService(
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimiter
        )
    }
    
    func createActivitySharingSettingsService(cloudKitManager: CloudKitManager) -> ActivityFeedSettingsServicing {
        ActivityFeedSettingsService(cloudKitManager: cloudKitManager)
    }
    
    func createWorkoutAutoShareService(
        activityFeedService: ActivityFeedServicing,
        settingsService: ActivityFeedSettingsServicing,
        notificationManager: NotificationManaging
    ) -> WorkoutAutoShareServicing {
        let workoutObserver = createWorkoutObserver(cloudKitManager: CloudKitManager(), healthKitService: RealHealthKitService())
        let notificationStore = NotificationStore()
        return WorkoutAutoShareService(
            workoutObserver: workoutObserver,
            activityFeedService: activityFeedService,
            activityFeedSettingsService: settingsService,
            notificationManager: notificationManager,
            notificationStore: notificationStore
        )
    }
    
    func createXPTransactionService(container: CKContainer) -> XPTransactionService {
        XPTransactionService(container: container)
    }
    
    func createGroupWorkoutService(
        cloudKitManager: CloudKitManager,
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging
    ) -> GroupWorkoutServiceProtocol {
        let rateLimiter = createRateLimitingService()
        return GroupWorkoutService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimiter
        )
    }
    
    func createRealTimeSyncCoordinator(
        subscriptionManager: CloudKitSubscriptionManaging,
        cloudKitManager: CloudKitManager,
        socialFollowingService: SocialFollowingServicing,
        userProfileService: UserProfileServicing,
        workoutKudosService: WorkoutKudosServicing,
        activityCommentsService: ActivityFeedCommentsServicing,
        workoutChallengesService: WorkoutChallengesServicing,
        groupWorkoutService: GroupWorkoutServiceProtocol,
        activityFeedService: ActivityFeedServicing
    ) -> RealTimeSyncCoordinating {
        RealTimeSyncCoordinator(
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
    }
    
    // MARK: - Utilities
    
    func createMessageProvider() -> MessageProviding {
        FameFitMessageProvider()
    }
}