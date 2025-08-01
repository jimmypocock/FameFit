//
//  DependencyFactory.swift
//  FameFit
//
//  Protocol-based factory for dependency injection
//

import Foundation
import HealthKit

// MARK: - Dependency Factory Protocol

protocol DependencyFactory {
    // MARK: - Core Services
    func createCloudKitManager() -> CloudKitManager
    func createAuthenticationManager(cloudKitManager: CloudKitManager) -> AuthenticationManager
    func createHealthKitService() -> HealthKitService
    func createNotificationStore() -> NotificationStore
    func createUnlockStorageService() -> UnlockStorageService
    
    // MARK: - Workflow Services
    func createWorkoutObserver(
        cloudKitManager: CloudKitManager,
        healthKitService: HealthKitService
    ) -> WorkoutObserver
    
    func createWorkoutSyncManager(
        cloudKitManager: CloudKitManager,
        healthKitService: HealthKitService
    ) -> WorkoutSyncManager
    
    func createWorkoutSyncQueue(cloudKitManager: CloudKitManager) -> WorkoutSyncQueue
    
    // MARK: - Social Services
    func createUserProfileService(cloudKitManager: CloudKitManager) -> UserProfileServicing
    func createRateLimitingService() -> RateLimitingServicing
    func createSocialFollowingService(
        cloudKitManager: CloudKitManager,
        rateLimiter: RateLimitingServicing,
        profileService: UserProfileServicing
    ) -> SocialFollowingServicing
    
    func createActivityFeedService(
        cloudKitManager: CloudKitManager,
        privacySettings: WorkoutPrivacySettings
    ) -> ActivityFeedServicing
    
    func createWorkoutKudosService(
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging,
        rateLimiter: RateLimitingServicing
    ) -> WorkoutKudosServicing
    
    func createGroupWorkoutService(
        cloudKitManager: CloudKitManager,
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging,
        rateLimiter: RateLimitingServicing
    ) -> GroupWorkoutServicing
    
    func createWorkoutChallengesService(
        cloudKitManager: CloudKitManager,
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging,
        rateLimiter: RateLimitingServicing
    ) -> WorkoutChallengesServicing
    
    func createActivityCommentsService(
        cloudKitManager: CloudKitManager,
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging,
        rateLimiter: RateLimitingServicing
    ) -> ActivityFeedCommentsServicing
    
    // MARK: - Notification Services
    func createNotificationScheduler() -> NotificationScheduling
    func createNotificationManager(
        notificationStore: NotificationStore,
        scheduler: NotificationScheduling
    ) -> NotificationManaging
    
    func createUnlockNotificationService(
        notificationStore: NotificationStore,
        unlockStorage: UnlockStorageService
    ) -> UnlockNotificationService
    
    func createAPNSManager() -> APNSManaging
    
    // MARK: - Advanced Services
    func createSubscriptionManager(cloudKitManager: CloudKitManager) -> CloudKitSubscriptionManaging
    func createRealTimeSyncCoordinator() -> RealTimeSyncCoordinating
    func createBulkPrivacyUpdateService(
        cloudKitManager: CloudKitManager,
        activityFeedService: ActivityFeedServicing
    ) -> BulkPrivacyUpdateServicing
    
    func createActivitySharingSettingsService(cloudKitManager: CloudKitManager) -> ActivityFeedSettingsServicing
    func createWorkoutAutoShareService(
        activityFeedService: ActivityFeedServicing,
        settingsService: ActivityFeedSettingsServicing,
        notificationManager: NotificationManaging
    ) -> WorkoutAutoShareServicing
    
    func createXPTransactionService() -> XPTransactionService
    func createGroupWorkoutSchedulingService(
        cloudKitManager: CloudKitManager
    ) -> GroupWorkoutSchedulingServicing
    
    // MARK: - Utilities
    func createMessageProvider() -> MessageProviding
    func createLogger() -> Logging
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
    
    func createNotificationStore() -> NotificationStore {
        NotificationStore()
    }
    
    func createUnlockStorageService() -> UnlockStorageService {
        UnlockStorageService()
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
        WorkoutSyncManager(
            cloudKitManager: cloudKitManager,
            healthKitService: healthKitService
        )
    }
    
    func createWorkoutSyncQueue(cloudKitManager: CloudKitManager) -> WorkoutSyncQueue {
        WorkoutSyncQueue(cloudKitManager: cloudKitManager)
    }
    
    // MARK: - Social Services
    
    func createUserProfileService(cloudKitManager: CloudKitManager) -> UserProfileServicing {
        UserProfileService(cloudKitManager: cloudKitManager)
    }
    
    func createRateLimitingService() -> RateLimitingServicing {
        RateLimitingService()
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
    
    func createActivityFeedService(
        cloudKitManager: CloudKitManager,
        privacySettings: WorkoutPrivacySettings
    ) -> ActivityFeedServicing {
        ActivityFeedService(
            cloudKitManager: cloudKitManager,
            privacySettings: privacySettings
        )
    }
    
    func createWorkoutKudosService(
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging,
        rateLimiter: RateLimitingServicing
    ) -> WorkoutKudosServicing {
        WorkoutKudosService(
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimiter
        )
    }
    
    func createGroupWorkoutService(
        cloudKitManager: CloudKitManager,
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging,
        rateLimiter: RateLimitingServicing
    ) -> GroupWorkoutServicing {
        GroupWorkoutService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimiter
        )
    }
    
    func createWorkoutChallengesService(
        cloudKitManager: CloudKitManager,
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging,
        rateLimiter: RateLimitingServicing
    ) -> WorkoutChallengesServicing {
        WorkoutChallengesService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimiter
        )
    }
    
    func createActivityCommentsService(
        cloudKitManager: CloudKitManager,
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging,
        rateLimiter: RateLimitingServicing
    ) -> ActivityFeedCommentsServicing {
        ActivityFeedCommentsService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimiter
        )
    }
    
    // MARK: - Notification Services
    
    func createNotificationScheduler() -> NotificationScheduling {
        NotificationScheduler()
    }
    
    func createNotificationManager(
        notificationStore: NotificationStore,
        scheduler: NotificationScheduling
    ) -> NotificationManaging {
        NotificationManager(
            notificationStore: notificationStore,
            scheduler: scheduler
        )
    }
    
    func createUnlockNotificationService(
        notificationStore: NotificationStore,
        unlockStorage: UnlockStorageService
    ) -> UnlockNotificationService {
        UnlockNotificationService(
            notificationStore: notificationStore,
            unlockStorage: unlockStorage
        )
    }
    
    func createAPNSManager() -> APNSManaging {
        APNSManager()
    }
    
    // MARK: - Advanced Services
    
    func createSubscriptionManager(cloudKitManager: CloudKitManager) -> CloudKitSubscriptionManaging {
        CloudKitSubscriptionManager(cloudKitManager: cloudKitManager)
    }
    
    func createRealTimeSyncCoordinator() -> RealTimeSyncCoordinating {
        RealTimeSyncCoordinator()
    }
    
    func createBulkPrivacyUpdateService(
        cloudKitManager: CloudKitManager,
        activityFeedService: ActivityFeedServicing
    ) -> BulkPrivacyUpdateServicing {
        BulkPrivacyUpdateService(
            cloudKitManager: cloudKitManager,
            activityFeedService: activityFeedService
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
        WorkoutAutoShareService(
            activityFeedService: activityFeedService,
            settingsService: settingsService,
            notificationManager: notificationManager
        )
    }
    
    func createXPTransactionService() -> XPTransactionService {
        XPTransactionService()
    }
    
    func createGroupWorkoutSchedulingService(
        cloudKitManager: CloudKitManager
    ) -> GroupWorkoutSchedulingServicing {
        GroupWorkoutSchedulingService(cloudKitManager: cloudKitManager)
    }
    
    // MARK: - Utilities
    
    func createMessageProvider() -> MessageProviding {
        FameFitMessageProvider()
    }
    
    func createLogger() -> Logging {
        FameFitLogger()
    }
}

// MARK: - Test Dependency Factory

class TestDependencyFactory: DependencyFactory {
    
    // MARK: - Core Services
    
    func createCloudKitManager() -> CloudKitManager {
        MockCloudKitManager()
    }
    
    func createAuthenticationManager(cloudKitManager: CloudKitManager) -> AuthenticationManager {
        MockAuthenticationManager()
    }
    
    func createHealthKitService() -> HealthKitService {
        MockHealthKitService()
    }
    
    func createNotificationStore() -> NotificationStore {
        MockNotificationStore()
    }
    
    func createUnlockStorageService() -> UnlockStorageService {
        MockUnlockStorageService()
    }
    
    // MARK: - Workflow Services
    
    func createWorkoutObserver(
        cloudKitManager: CloudKitManager,
        healthKitService: HealthKitService
    ) -> WorkoutObserver {
        MockWorkoutObserver()
    }
    
    func createWorkoutSyncManager(
        cloudKitManager: CloudKitManager,
        healthKitService: HealthKitService
    ) -> WorkoutSyncManager {
        MockWorkoutSyncManager()
    }
    
    func createWorkoutSyncQueue(cloudKitManager: CloudKitManager) -> WorkoutSyncQueue {
        MockWorkoutSyncQueue()
    }
    
    // MARK: - Social Services
    
    func createUserProfileService(cloudKitManager: CloudKitManager) -> UserProfileServicing {
        MockUserProfileService()
    }
    
    func createRateLimitingService() -> RateLimitingServicing {
        MockRateLimitingService()
    }
    
    func createSocialFollowingService(
        cloudKitManager: CloudKitManager,
        rateLimiter: RateLimitingServicing,
        profileService: UserProfileServicing
    ) -> SocialFollowingServicing {
        MockSocialFollowingService()
    }
    
    func createActivityFeedService(
        cloudKitManager: CloudKitManager,
        privacySettings: WorkoutPrivacySettings
    ) -> ActivityFeedServicing {
        MockActivityFeedService()
    }
    
    func createWorkoutKudosService(
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging,
        rateLimiter: RateLimitingServicing
    ) -> WorkoutKudosServicing {
        MockWorkoutKudosService()
    }
    
    func createGroupWorkoutService(
        cloudKitManager: CloudKitManager,
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging,
        rateLimiter: RateLimitingServicing
    ) -> GroupWorkoutServicing {
        MockGroupWorkoutService()
    }
    
    func createWorkoutChallengesService(
        cloudKitManager: CloudKitManager,
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging,
        rateLimiter: RateLimitingServicing
    ) -> WorkoutChallengesServicing {
        MockWorkoutChallengesService()
    }
    
    func createActivityCommentsService(
        cloudKitManager: CloudKitManager,
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging,
        rateLimiter: RateLimitingServicing
    ) -> ActivityFeedCommentsServicing {
        MockActivityCommentsService()
    }
    
    // MARK: - Notification Services
    
    func createNotificationScheduler() -> NotificationScheduling {
        MockNotificationScheduler()
    }
    
    func createNotificationManager(
        notificationStore: NotificationStore,
        scheduler: NotificationScheduling
    ) -> NotificationManaging {
        MockNotificationManager()
    }
    
    func createUnlockNotificationService(
        notificationStore: NotificationStore,
        unlockStorage: UnlockStorageService
    ) -> UnlockNotificationService {
        MockUnlockNotificationService()
    }
    
    func createAPNSManager() -> APNSManaging {
        MockAPNSManager()
    }
    
    // MARK: - Advanced Services
    
    func createSubscriptionManager(cloudKitManager: CloudKitManager) -> CloudKitSubscriptionManaging {
        MockSubscriptionManager()
    }
    
    func createRealTimeSyncCoordinator() -> RealTimeSyncCoordinating {
        MockRealTimeSyncCoordinator()
    }
    
    func createBulkPrivacyUpdateService(
        cloudKitManager: CloudKitManager,
        activityFeedService: ActivityFeedServicing
    ) -> BulkPrivacyUpdateServicing {
        MockBulkPrivacyUpdateService()
    }
    
    func createActivitySharingSettingsService(cloudKitManager: CloudKitManager) -> ActivityFeedSettingsServicing {
        MockActivitySharingSettingsService()
    }
    
    func createWorkoutAutoShareService(
        activityFeedService: ActivityFeedServicing,
        settingsService: ActivityFeedSettingsServicing,
        notificationManager: NotificationManaging
    ) -> WorkoutAutoShareServicing {
        MockWorkoutAutoShareService()
    }
    
    func createXPTransactionService() -> XPTransactionService {
        MockXPTransactionService()
    }
    
    func createGroupWorkoutSchedulingService(
        cloudKitManager: CloudKitManager
    ) -> GroupWorkoutSchedulingServicing {
        MockGroupWorkoutSchedulingService()
    }
    
    // MARK: - Utilities
    
    func createMessageProvider() -> MessageProviding {
        MockMessageProvider()
    }
    
    func createLogger() -> Logging {
        MockLogger()
    }
}