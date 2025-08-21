//
//  DependencyContainer+Init.swift
//  FameFit
//
//  Production initialization for DependencyContainer
//

import Foundation
import CloudKit
import HealthKit
import Combine

// MARK: - Production Initialization

extension DependencyContainer {
    /// Create a container with a dependency factory
    /// - Parameters:
    ///   - factory: Factory to create dependencies (defaults to production)
    ///   - skipInitialization: Skip CloudKit initialization (for default/fallback containers)
    /// - Returns: A fully configured DependencyContainer
    @MainActor
    static func create(factory: DependencyFactory = ProductionDependencyFactory(), skipInitialization: Bool = false) -> DependencyContainer {
        // Phase 1: Core Services
        let cloudKitManager = factory.createCloudKitService()
        let watchConnectivityManager = factory.createWatchConnectivityManager()
        let authenticationManager = factory.createAuthenticationService(cloudKitManager: cloudKitManager, watchConnectivityManager: watchConnectivityManager)
        let healthKitService = factory.createHealthKitService()
        let notificationStore = factory.createNotificationStore()
        let unlockStorageService = factory.createUnlockStorageService()
        
        // Phase 2: Workout Services
        let workoutSyncManager = WorkoutSyncService(
            cloudKitManager: cloudKitManager,
            healthKitService: healthKitService
        )
        
        // Phase 3: Notification Services
        let unlockNotificationService = factory.createUnlockNotificationService(
            notificationStore: notificationStore,
            unlockStorage: unlockStorageService
        )
        
        let messageProvider = factory.createMessageProvider()
        let notificationScheduler = factory.createNotificationScheduler()
        let apnsManager = factory.createAPNSService(cloudKitManager: cloudKitManager)
        
        let notificationManager = factory.createNotificationService(
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
        
        let workoutChallengeLinksService = WorkoutChallengeLinksService(
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
        
        // Create WorkoutProcessor
        let workoutProcessor = WorkoutProcessor(
            cloudKitManager: cloudKitManager,
            xpTransactionService: xpTransactionService,
            activityFeedService: activityFeedService,
            notificationManager: notificationManager,
            userProfileService: userProfileService,
            workoutChallengesService: workoutChallengesService,
            workoutChallengeLinksService: workoutChallengeLinksService,
            activitySettingsService: activitySharingSettingsService
        )
        
        // Create WorkoutQueue for background processing
        let workoutQueue = WorkoutQueue(
            cloudKitManager: cloudKitManager,
            xpTransactionService: xpTransactionService,
            activityFeedService: activityFeedService,
            notificationManager: notificationManager
        )
        
        
        // Create verification service
        let countVerificationService = CountVerificationService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            xpTransactionService: xpTransactionService
        )
        
        // Create stats sync service
        let statsSyncService = StatsSyncService(
            container: cloudKitManager.container,
            operationQueue: CloudKitOperationQueue()
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
        
        // Wire up WorkoutProcessor to services that need it
        workoutSyncManager.workoutProcessor = workoutProcessor
        workoutSyncManager.notificationManager = notificationManager
        workoutSyncManager.userProfileService = userProfileService
        if let concreteGroupWorkoutService = groupWorkoutService as? GroupWorkoutService {
            concreteGroupWorkoutService.workoutProcessor = workoutProcessor
        }
        
        // Load and apply saved user privacy settings
        // Only do this for properly initialized containers, not fallback ones
        if !skipInitialization {
            Task {
                // Wait for CloudKit to be ready and user to be authenticated
                guard cloudKitManager.currentUserID != nil else {
                    FameFitLogger.info("Skipping privacy settings load - no user authenticated yet", category: FameFitLogger.social)
                    return
                }
                
                // Note: ActivityFeedSettings and UserSettings are different models
                // ActivityFeedSettings handles automatic sharing preferences
                // UserSettings handles privacy and notification preferences
                // For now, we'll use default UserSettings and let the ActivityFeedService
                // manage its own privacy settings separately
                let userSettings = UserSettings.defaultSettings(for: cloudKitManager.currentUserID ?? "unknown")
                if let concreteActivityFeedService = activityFeedService as? ActivityFeedService {
                    concreteActivityFeedService.updatePrivacySettings(userSettings)
                }
                FameFitLogger.info("✅ Initialized with default privacy settings", category: FameFitLogger.social)
            }
        }
        
        // Create container with all services
        let container = DependencyContainer(
            authenticationManager: authenticationManager,
            cloudKitManager: cloudKitManager,
            workoutProcessor: workoutProcessor,
            healthKitService: healthKitService,
            watchConnectivityManager: watchConnectivityManager,
            workoutSyncManager: workoutSyncManager,
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
            workoutChallengeLinksService: workoutChallengeLinksService,
            subscriptionManager: subscriptionManager,
            realTimeSyncCoordinator: realTimeSyncCoordinator,
            activityCommentsService: activityCommentsService,
            activitySharingSettingsService: activitySharingSettingsService,
            bulkPrivacyUpdateService: bulkPrivacyUpdateService,
            xpTransactionService: xpTransactionService,
            countVerificationService: countVerificationService,
            statsSyncService: statsSyncService,
            workoutQueue: workoutQueue
        )
        
        // Phase 11: Wire up circular dependencies (after all services are created)
        cloudKitManager.authenticationManager = authenticationManager
        cloudKitManager.xpTransactionService = xpTransactionService
        cloudKitManager.statsSyncService = statsSyncService
        
        // Since we're already on MainActor, we can set these directly
        workoutSyncManager.notificationStore = notificationStore
        workoutSyncManager.workoutProcessor = workoutProcessor
        workoutSyncManager.userProfileService = userProfileService
        
        // Start CloudKit initialization after all dependencies are wired up
        // Skip for default/fallback containers to avoid duplicate initialization
        if !skipInitialization {
            cloudKitManager.startInitialization()
        }
        
        return container
    }
    
}
