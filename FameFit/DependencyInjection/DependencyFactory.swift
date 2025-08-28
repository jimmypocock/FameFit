//
//  DependencyFactory.swift
//  FameFit
//
//  Factory pattern for creating app dependencies
//

import Foundation
import CloudKit
import Combine

// MARK: - Dependency Factory Protocol

protocol DependencyFactory: AnyObject {
    // Core Services
    func createCloudKitService() -> CloudKitService
    func createAuthenticationService(cloudKitManager: CloudKitService, watchConnectivityManager: WatchConnectivityProtocol?) -> AuthenticationService
    func createHealthKitService() -> HealthKitProtocol
    func createWatchConnectivityManager() -> WatchConnectivityProtocol
    func createNotificationStore() -> NotificationStore
    func createUnlockStorageService() -> UnlockStorageService
    func createUnlockNotificationService(notificationStore: NotificationStore, unlockStorage: UnlockStorageService) -> UnlockNotificationService
    func createNotificationScheduler() -> NotificationSchedulingProtocol
    func createAPNSService(cloudKitManager: CloudKitService) -> APNSProtocol
    
    // Workflow Services
    @MainActor func createWorkoutSyncService(cloudKitManager: CloudKitService, healthKitService: HealthKitProtocol) -> WorkoutSyncService
    
    // Social Services
    func createUserProfileService(cloudKitManager: CloudKitService) -> UserProfileProtocol
    func createRateLimitingService() -> RateLimitingService
    func createNotificationService(notificationStore: NotificationStore, scheduler: NotificationSchedulingProtocol) -> NotificationProtocol
    func createSocialFollowingService(cloudKitManager: CloudKitService, rateLimiter: RateLimitingProtocol, profileService: UserProfileProtocol) -> SocialFollowingProtocol
    func createBulkPrivacyUpdateService(cloudKitManager: CloudKitService, userProfileService: UserProfileProtocol) -> BulkPrivacyUpdateProtocol
    func createWorkoutChallengesService(cloudKitManager: CloudKitService) -> WorkoutChallengesProtocol
    func createActivityFeedService(cloudKitManager: CloudKitService) -> ActivityFeedProtocol
    func createActivityCommentsService(cloudKitManager: CloudKitService) -> ActivityFeedCommentsProtocol
    func createSubscriptionManager(cloudKitManager: CloudKitService) -> CloudKitSubscriptionProtocol
    func createPushNotificationService(cloudKitManager: CloudKitService, subscriptionManager: CloudKitSubscriptionProtocol) -> CloudKitPushNotificationService
    func createWorkoutKudosService(cloudKitManager: CloudKitService) -> WorkoutKudosProtocol
    func createActivitySharingSettingsService(cloudKitManager: CloudKitService) -> ActivityFeedSettingsProtocol
    func createXPTransactionService(container: CKContainer) -> XPTransactionService
    func createGroupWorkoutService(cloudKitManager: CloudKitService, userProfileService: UserProfileProtocol, notificationManager: NotificationProtocol) -> GroupWorkoutProtocol
    func createRealTimeSyncCoordinator(subscriptionManager: CloudKitSubscriptionProtocol, cloudKitManager: CloudKitService, socialFollowingService: SocialFollowingProtocol, userProfileService: UserProfileProtocol, workoutKudosService: WorkoutKudosProtocol, activityCommentsService: ActivityFeedCommentsProtocol, workoutChallengesService: WorkoutChallengesProtocol, groupWorkoutService: GroupWorkoutProtocol, activityFeedService: ActivityFeedProtocol) -> RealTimeSyncProtocol
    
    // Utilities
    func createMessageProvider() -> MessagingProtocol
}

// MARK: - Production Dependency Factory

class ProductionDependencyFactory: DependencyFactory {
    // MARK: - Core Services
    
    func createCloudKitService() -> CloudKitService {
        CloudKitService()
    }
    
    func createAuthenticationService(cloudKitManager: CloudKitService, watchConnectivityManager: WatchConnectivityProtocol?) -> AuthenticationService {
        AuthenticationService(cloudKitManager: cloudKitManager, watchConnectivityManager: watchConnectivityManager)
    }
    
    func createHealthKitService() -> HealthKitProtocol {
        HealthKitService()
    }
    
    func createWatchConnectivityManager() -> WatchConnectivityProtocol {
        // Create a new instance for proper dependency injection
        EnhancedWatchConnectivityManager()
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
    
    func createNotificationScheduler() -> NotificationSchedulingProtocol {
        NotificationScheduler(notificationStore: NotificationStore())
    }
    
    func createAPNSService(cloudKitManager: CloudKitService) -> APNSProtocol {
        APNSService(cloudKitManager: cloudKitManager)
    }
    
    // MARK: - Workflow Services
    
    @MainActor
    func createWorkoutSyncService(
        cloudKitManager: CloudKitService,
        healthKitService: HealthKitProtocol
    ) -> WorkoutSyncService {
        // WorkoutSyncService is @MainActor and must be created on MainActor
        // This is handled directly in DependencyContainer initialization
        // This method exists only for protocol conformance
        WorkoutSyncService(
            cloudKitManager: cloudKitManager,
            healthKitService: healthKitService
        )
    }
    
    // MARK: - Social Services
    
    func createUserProfileService(cloudKitManager: CloudKitService) -> UserProfileProtocol {
        UserProfileService(cloudKitManager: cloudKitManager)
    }
    
    func createRateLimitingService() -> RateLimitingService {
        RateLimitingService()
    }
    
    func createNotificationService(notificationStore: NotificationStore, scheduler: NotificationSchedulingProtocol) -> NotificationProtocol {
        let unlockService = createUnlockNotificationService(
            notificationStore: notificationStore,
            unlockStorage: createUnlockStorageService()
        )
        let messageProvider = createMessageProvider()
        
        return NotificationService(
            scheduler: scheduler,
            notificationStore: notificationStore,
            unlockService: unlockService,
            messageProvider: messageProvider
        )
    }
    
    func createSocialFollowingService(
        cloudKitManager: CloudKitService, 
        rateLimiter: RateLimitingProtocol, 
        profileService: UserProfileProtocol
    ) -> SocialFollowingProtocol {
        let notificationStore = createNotificationStore()
        let scheduler = createNotificationScheduler()
        let notificationManager = createNotificationService(notificationStore: notificationStore, scheduler: scheduler)
        
        return CachedSocialFollowingService(
            cloudKitManager: cloudKitManager,
            rateLimiter: rateLimiter,
            profileService: profileService,
            notificationManager: notificationManager
        )
    }
    
    func createBulkPrivacyUpdateService(
        cloudKitManager: CloudKitService,
        userProfileService: UserProfileProtocol
    ) -> BulkPrivacyUpdateProtocol {
        // First need to create ActivityFeedService for BulkPrivacyUpdateService
        let activityFeedService = createActivityFeedService(cloudKitManager: cloudKitManager)
        return BulkPrivacyUpdateService(
            cloudKitManager: cloudKitManager,
            activityFeedService: activityFeedService
        )
    }
    
    func createWorkoutChallengesService(cloudKitManager: CloudKitService) -> WorkoutChallengesProtocol {
        let userProfileService = createUserProfileService(cloudKitManager: cloudKitManager)
        let notificationStore = createNotificationStore()
        let scheduler = createNotificationScheduler()
        let notificationManager = createNotificationService(notificationStore: notificationStore, scheduler: scheduler)
        let rateLimiter = createRateLimitingService()
        let workoutChallengeLinksService = WorkoutChallengeLinksService(cloudKitManager: cloudKitManager)
        return WorkoutChallengesService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimiter,
            workoutChallengeLinksService: workoutChallengeLinksService
        )
    }
    
    func createActivityFeedService(cloudKitManager: CloudKitService) -> ActivityFeedProtocol {
        let userSettings = UserSettings.defaultSettings(for: cloudKitManager.currentUserID ?? "unknown")
        let userProfileService = createUserProfileService(cloudKitManager: cloudKitManager)
        return ActivityFeedService(
            cloudKitManager: cloudKitManager,
            userSettings: userSettings,
            userProfileService: userProfileService
        )
    }
    
    func createActivityCommentsService(cloudKitManager: CloudKitService) -> ActivityFeedCommentsProtocol {
        let userProfileService = createUserProfileService(cloudKitManager: cloudKitManager)
        let notificationStore = createNotificationStore()
        let scheduler = createNotificationScheduler()
        let notificationManager = createNotificationService(notificationStore: notificationStore, scheduler: scheduler)
        let rateLimiter = createRateLimitingService()
        return ActivityFeedCommentsService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimiter
        )
    }
    
    func createSubscriptionManager(cloudKitManager: CloudKitService) -> CloudKitSubscriptionProtocol {
        CloudKitSubscriptionService()
    }
    
    func createPushNotificationService(
        cloudKitManager: CloudKitService,
        subscriptionManager: CloudKitSubscriptionProtocol
    ) -> CloudKitPushNotificationService {
        CloudKitPushNotificationService()
    }
    
    func createWorkoutKudosService(cloudKitManager: CloudKitService) -> WorkoutKudosProtocol {
        let userProfileService = createUserProfileService(cloudKitManager: cloudKitManager)
        let notificationStore = createNotificationStore()
        let scheduler = createNotificationScheduler()
        let notificationManager = createNotificationService(notificationStore: notificationStore, scheduler: scheduler)
        let rateLimiter = createRateLimitingService()
        return WorkoutKudosService(
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimiter
        )
    }
    
    func createActivitySharingSettingsService(cloudKitManager: CloudKitService) -> ActivityFeedSettingsProtocol {
        ActivityFeedSettingsService(cloudKitManager: cloudKitManager)
    }
    
    func createXPTransactionService(container: CKContainer) -> XPTransactionService {
        XPTransactionService(container: container)
    }
    
    func createGroupWorkoutService(
        cloudKitManager: CloudKitService,
        userProfileService: UserProfileProtocol,
        notificationManager: NotificationProtocol
    ) -> GroupWorkoutProtocol {
        let rateLimiter = createRateLimitingService()
        return GroupWorkoutService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimiter
        )
    }
    
    func createRealTimeSyncCoordinator(
        subscriptionManager: CloudKitSubscriptionProtocol,
        cloudKitManager: CloudKitService,
        socialFollowingService: SocialFollowingProtocol,
        userProfileService: UserProfileProtocol,
        workoutKudosService: WorkoutKudosProtocol,
        activityCommentsService: ActivityFeedCommentsProtocol,
        workoutChallengesService: WorkoutChallengesProtocol,
        groupWorkoutService: GroupWorkoutProtocol,
        activityFeedService: ActivityFeedProtocol
    ) -> RealTimeSyncProtocol {
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
    
    func createMessageProvider() -> MessagingProtocol {
        return FameFitMessageProvider()
    }
}
