//
//  DependencyContainer.swift
//  FameFit
//
//  Manages dependency injection for the app
//

import Foundation
import HealthKit
import SwiftUI

class DependencyContainer: ObservableObject {
    // MARK: - Factory Methods

    private struct CoreServices {
        let cloudKitManager: CloudKitManager
        let authenticationManager: AuthenticationManager
        let healthKitService: HealthKitService
        let notificationStore: NotificationStore
        let unlockStorageService: UnlockStorageService
    }

    private static func createCoreServices() -> CoreServices {
        let cloudKitManager = CloudKitManager()
        let authenticationManager = AuthenticationManager(cloudKitManager: cloudKitManager)
        let healthKitService = RealHealthKitService()
        let notificationStore = NotificationStore()
        let unlockStorageService = UnlockStorageService()

        return CoreServices(
            cloudKitManager: cloudKitManager,
            authenticationManager: authenticationManager,
            healthKitService: healthKitService,
            notificationStore: notificationStore,
            unlockStorageService: unlockStorageService
        )
    }

    private struct WorkoutServices {
        let workoutObserver: WorkoutObserver
        let workoutSyncManager: WorkoutSyncManager
        let workoutSyncQueue: WorkoutSyncQueue
    }

    private static func createWorkoutServices(
        cloudKitManager: CloudKitManager,
        healthKitService: HealthKitService
    ) -> WorkoutServices {
        let workoutObserver = WorkoutObserver(
            cloudKitManager: cloudKitManager,
            healthKitService: healthKitService
        )

        let workoutSyncManager = WorkoutSyncManager(
            cloudKitManager: cloudKitManager,
            healthKitService: healthKitService
        )

        let workoutSyncQueue = WorkoutSyncQueue(
            cloudKitManager: cloudKitManager
        )

        return WorkoutServices(
            workoutObserver: workoutObserver,
            workoutSyncManager: workoutSyncManager,
            workoutSyncQueue: workoutSyncQueue
        )
    }

    let authenticationManager: AuthenticationManager
    let cloudKitManager: CloudKitManager
    let workoutObserver: WorkoutObserver
    let healthKitService: HealthKitService
    let workoutSyncManager: WorkoutSyncManager
    let workoutSyncQueue: WorkoutSyncQueue
    let notificationStore: NotificationStore
    let unlockNotificationService: UnlockNotificationService
    let unlockStorageService: UnlockStorageService
    let userProfileService: UserProfileServicing
    let rateLimitingService: RateLimitingServicing
    let socialFollowingService: SocialFollowingServicing
    let activityFeedService: ActivityFeedServicing
    let notificationScheduler: NotificationScheduling
    let notificationManager: NotificationManaging
    let messageProvider: MessageProviding
    let workoutKudosService: WorkoutKudosServicing
    let apnsManager: APNSManaging
    let groupWorkoutService: GroupWorkoutServicing
    let workoutChallengesService: WorkoutChallengesServicing
    let subscriptionManager: CloudKitSubscriptionManaging
    let realTimeSyncCoordinator: RealTimeSyncCoordinating
    let activityCommentsService: ActivityFeedCommentsServicing
    let activitySharingSettingsService: ActivityFeedSettingsServicing
    let xpTransactionService: XPTransactionService

    init() {
        // Initialize core services
        let core = Self.createCoreServices()
        cloudKitManager = core.cloudKitManager
        authenticationManager = core.authenticationManager
        healthKitService = core.healthKitService
        notificationStore = core.notificationStore
        unlockStorageService = core.unlockStorageService

        // Initialize workout services
        let workout = Self.createWorkoutServices(
            cloudKitManager: cloudKitManager,
            healthKitService: healthKitService
        )
        workoutObserver = workout.workoutObserver
        workoutSyncManager = workout.workoutSyncManager
        workoutSyncQueue = workout.workoutSyncQueue

        // Initialize notification services (before social services that depend on them)
        unlockNotificationService = UnlockNotificationService(
            notificationStore: notificationStore,
            unlockStorage: unlockStorageService
        )

        messageProvider = FameFitMessageProvider()

        notificationScheduler = NotificationScheduler(
            notificationStore: notificationStore
        )

        let tempAPNSManager = APNSManager(cloudKitManager: cloudKitManager, notificationStore: notificationStore)
        apnsManager = tempAPNSManager

        notificationManager = NotificationManager(
            scheduler: notificationScheduler,
            notificationStore: notificationStore,
            unlockService: unlockNotificationService,
            messageProvider: messageProvider,
            apnsManager: apnsManager
        )

        // Initialize social services
        userProfileService = UserProfileService(cloudKitManager: cloudKitManager)

        rateLimitingService = RateLimitingService()

        socialFollowingService = SocialFollowingService(
            cloudKitManager: cloudKitManager,
            rateLimiter: rateLimitingService,
            profileService: userProfileService
        )

        let defaultPrivacySettings = WorkoutPrivacySettings()
        activityFeedService = ActivityFeedService(
            cloudKitManager: cloudKitManager,
            privacySettings: defaultPrivacySettings
        )

        // Create social services
        workoutKudosService = WorkoutKudosService(
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimitingService
        )


        groupWorkoutService = GroupWorkoutService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimitingService
        )

        workoutChallengesService = WorkoutChallengesService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimitingService
        )

        // Initialize activity services
        activityCommentsService = ActivityFeedCommentsService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimitingService
        )
        
        activitySharingSettingsService = ActivityFeedSettingsService(
            cloudKitManager: cloudKitManager
        )
        
        // Initialize XP transaction service
        xpTransactionService = XPTransactionService(container: cloudKitManager.container)
        
        // Initialize sync coordinator
        subscriptionManager = CloudKitSubscriptionManager()

        // Capture all dependencies before the closure to avoid self capture
        let capturedSubscriptionManager = subscriptionManager
        let capturedCloudKitManager = cloudKitManager
        let capturedSocialFollowingService = socialFollowingService
        let capturedUserProfileService = userProfileService
        let capturedWorkoutKudosService = workoutKudosService
        let capturedActivityCommentsService = activityCommentsService
        let capturedWorkoutChallengesService = workoutChallengesService
        let capturedGroupWorkoutService = groupWorkoutService
        let capturedActivityFeedService = activityFeedService

        realTimeSyncCoordinator = MainActor.assumeIsolated {
            RealTimeSyncCoordinator(
                subscriptionManager: capturedSubscriptionManager,
                cloudKitManager: capturedCloudKitManager,
                socialFollowingService: capturedSocialFollowingService,
                userProfileService: capturedUserProfileService,
                workoutKudosService: capturedWorkoutKudosService,
                activityCommentsService: capturedActivityCommentsService,
                workoutChallengesService: capturedWorkoutChallengesService,
                groupWorkoutService: capturedGroupWorkoutService,
                activityFeedService: capturedActivityFeedService
            )
        }

        // Wire up dependencies
        cloudKitManager.authenticationManager = authenticationManager
        cloudKitManager.unlockNotificationService = unlockNotificationService
        cloudKitManager.xpTransactionService = xpTransactionService

        workoutObserver.notificationStore = notificationStore
        workoutObserver.apnsManager = apnsManager

        workoutSyncManager.notificationStore = notificationStore
        workoutSyncManager.notificationManager = notificationManager
    }

    // For testing, allow injection of mock managers
    init(
        authenticationManager: AuthenticationManager,
        cloudKitManager: CloudKitManager,
        workoutObserver: WorkoutObserver,
        healthKitService: HealthKitService? = nil,
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
        xpTransactionService: XPTransactionService? = nil
    ) {
        self.authenticationManager = authenticationManager
        self.cloudKitManager = cloudKitManager
        self.workoutObserver = workoutObserver
        self.healthKitService = healthKitService ?? RealHealthKitService()
        self.workoutSyncManager = workoutSyncManager ?? WorkoutSyncManager(
            cloudKitManager: cloudKitManager,
            healthKitService: self.healthKitService
        )
        self.workoutSyncQueue = workoutSyncQueue ?? WorkoutSyncQueue(
            cloudKitManager: cloudKitManager
        )
        self.notificationStore = notificationStore ?? NotificationStore()
        self.unlockStorageService = unlockStorageService ?? UnlockStorageService()
        self.unlockNotificationService = unlockNotificationService ?? UnlockNotificationService(
            notificationStore: self.notificationStore,
            unlockStorage: self.unlockStorageService
        )
        self.userProfileService = userProfileService ?? UserProfileService(
            cloudKitManager: cloudKitManager
        )
        self.rateLimitingService = rateLimitingService ?? RateLimitingService()
        self.socialFollowingService = socialFollowingService ?? SocialFollowingService(
            cloudKitManager: cloudKitManager,
            rateLimiter: self.rateLimitingService,
            profileService: self.userProfileService
        )

        let defaultPrivacySettings = WorkoutPrivacySettings()
        self.activityFeedService = activityFeedService ?? ActivityFeedService(
            cloudKitManager: cloudKitManager,
            privacySettings: defaultPrivacySettings
        )

        self.messageProvider = messageProvider ?? FameFitMessageProvider()

        self.notificationScheduler = notificationScheduler ?? NotificationScheduler(
            notificationStore: self.notificationStore
        )

        self.notificationManager = notificationManager ?? NotificationManager(
            scheduler: self.notificationScheduler,
            notificationStore: self.notificationStore,
            unlockService: self.unlockNotificationService,
            messageProvider: self.messageProvider
        )

        self.workoutKudosService = workoutKudosService ?? WorkoutKudosService(
            userProfileService: self.userProfileService,
            notificationManager: self.notificationManager,
            rateLimiter: self.rateLimitingService
        )

        if let apnsManager {
            self.apnsManager = apnsManager
        } else {
            let tempAPNSManager = APNSManager(cloudKitManager: self.cloudKitManager)
            self.apnsManager = tempAPNSManager
        }


        self.groupWorkoutService = groupWorkoutService ?? GroupWorkoutService(
            cloudKitManager: self.cloudKitManager,
            userProfileService: self.userProfileService,
            notificationManager: self.notificationManager,
            rateLimiter: self.rateLimitingService
        )

        self.workoutChallengesService = workoutChallengesService ?? WorkoutChallengesService(
            cloudKitManager: self.cloudKitManager,
            userProfileService: self.userProfileService,
            notificationManager: self.notificationManager,
            rateLimiter: self.rateLimitingService
        )

        self.subscriptionManager = subscriptionManager ?? CloudKitSubscriptionManager()
        
        self.activityCommentsService = activityCommentsService ?? ActivityFeedCommentsService(
            cloudKitManager: self.cloudKitManager,
            userProfileService: self.userProfileService,
            notificationManager: self.notificationManager,
            rateLimiter: self.rateLimitingService
        )
        
        self.activitySharingSettingsService = activitySharingSettingsService ?? ActivityFeedSettingsService(
            cloudKitManager: self.cloudKitManager
        )
        
        self.xpTransactionService = xpTransactionService ?? XPTransactionService(container: self.cloudKitManager.container)

        if let realTimeSyncCoordinator {
            self.realTimeSyncCoordinator = realTimeSyncCoordinator
        } else {
            // Capture all dependencies before the closure to avoid self capture
            let capturedSubscriptionManager = self.subscriptionManager
            let capturedCloudKitManager = self.cloudKitManager
            let capturedSocialFollowingService = self.socialFollowingService
            let capturedUserProfileService = self.userProfileService
            let capturedWorkoutKudosService = self.workoutKudosService
            let capturedActivityCommentsService = self.activityCommentsService
            let capturedWorkoutChallengesService = self.workoutChallengesService
            let capturedGroupWorkoutService = self.groupWorkoutService
            let capturedActivityFeedService = self.activityFeedService

            let coordinator = MainActor.assumeIsolated {
                RealTimeSyncCoordinator(
                    subscriptionManager: capturedSubscriptionManager,
                    cloudKitManager: capturedCloudKitManager,
                    socialFollowingService: capturedSocialFollowingService,
                    userProfileService: capturedUserProfileService,
                    workoutKudosService: capturedWorkoutKudosService,
                    activityCommentsService: capturedActivityCommentsService,
                    workoutChallengesService: capturedWorkoutChallengesService,
                    groupWorkoutService: capturedGroupWorkoutService,
                    activityFeedService: capturedActivityFeedService
                )
            }
            self.realTimeSyncCoordinator = coordinator
        }

        // Wire up dependencies for WorkoutSyncManager
        self.workoutSyncManager.notificationStore = self.notificationStore
        self.workoutSyncManager.notificationManager = self.notificationManager
    }
}

// MARK: - Environment Key

struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer()
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
