//
//  DependencyContainer.swift
//  FameFit
//
//  Manages dependency injection for the app using modern Swift patterns
//

import Foundation
import CloudKit
import HealthKit
import SwiftUI

/// Main dependency container following modern Swift patterns and security best practices
/// The container is split into extensions for better maintainability:
/// - DependencyContainer+Init.swift: Production initialization
/// - DependencyContainer+TestSupport.swift: Test initialization
/// - DependencyContainer+Environment.swift: SwiftUI environment integration
final class DependencyContainer: ObservableObject {
    
    // MARK: - Core Services

    let authenticationManager: AuthenticationService
    let cloudKitManager: CloudKitService
    let healthKitService: HealthKitProtocol
    let watchConnectivityManager: WatchConnectivityProtocol
    
    // MARK: - Workout Services
    
    let workoutObserver: WorkoutObserver
    let workoutProcessor: WorkoutProcessor
    let workoutSyncManager: WorkoutSyncService
    let workoutSyncQueue: WorkoutSyncQueue
    
    // MARK: - Notification Services
    
    let notificationStore: NotificationStore
    let unlockNotificationService: UnlockNotificationService
    let unlockStorageService: UnlockStorageService
    let notificationScheduler: NotificationSchedulingProtocol
    let notificationManager: NotificationProtocol
    let messageProvider: MessagingProtocol
    let apnsManager: APNSProtocol
    
    // MARK: - Social & Profile Services
    
    let userProfileService: UserProfileProtocol
    let rateLimitingService: RateLimitingProtocol
    let socialFollowingService: SocialFollowingProtocol
    
    // MARK: - Activity Feed Services
    
    let activityFeedService: ActivityFeedProtocol
    let activityCommentsService: ActivityFeedCommentsProtocol
    let workoutKudosService: WorkoutKudosProtocol
    let activitySharingSettingsService: ActivityFeedSettingsProtocol
    let workoutAutoShareService: WorkoutAutoShareProtocol
    
    // MARK: - Privacy & Settings Services
    
    let bulkPrivacyUpdateService: BulkPrivacyUpdateProtocol
    
    // MARK: - Challenge & Group Services
    
    let workoutChallengesService: WorkoutChallengesProtocol
    let workoutChallengeLinksService: WorkoutChallengeLinksProtocol
    let groupWorkoutService: GroupWorkoutProtocol
    
    // MARK: - Sync & Real-time Services
    
    let subscriptionManager: CloudKitSubscriptionProtocol
    let realTimeSyncCoordinator: RealTimeSyncProtocol
    
    // MARK: - Transaction Services
    
    let xpTransactionService: XPTransactionService
    
    // MARK: - Verification Services
    
    let countVerificationService: CountVerificationProtocol
    
    // MARK: - Sync Services
    
    let statsSyncService: StatsSyncProtocol
    
    // MARK: - Base Initializer
    
    /// Base initializer that accepts all dependencies
    /// Used by both production and test initializers
    @MainActor
    init(
        authenticationManager: AuthenticationService,
        cloudKitManager: CloudKitService,
        workoutObserver: WorkoutObserver,
        workoutProcessor: WorkoutProcessor,
        healthKitService: HealthKitProtocol,
        watchConnectivityManager: WatchConnectivityProtocol,
        workoutSyncManager: WorkoutSyncService,
        workoutSyncQueue: WorkoutSyncQueue,
        notificationStore: NotificationStore,
        unlockNotificationService: UnlockNotificationService,
        unlockStorageService: UnlockStorageService,
        userProfileService: UserProfileProtocol,
        rateLimitingService: RateLimitingProtocol,
        socialFollowingService: SocialFollowingProtocol,
        activityFeedService: ActivityFeedProtocol,
        notificationScheduler: NotificationSchedulingProtocol,
        notificationManager: NotificationProtocol,
        messageProvider: MessagingProtocol,
        workoutKudosService: WorkoutKudosProtocol,
        apnsManager: APNSProtocol,
        groupWorkoutService: GroupWorkoutProtocol,
        workoutChallengesService: WorkoutChallengesProtocol,
        workoutChallengeLinksService: WorkoutChallengeLinksProtocol,
        subscriptionManager: CloudKitSubscriptionProtocol,
        realTimeSyncCoordinator: RealTimeSyncProtocol,
        activityCommentsService: ActivityFeedCommentsProtocol,
        activitySharingSettingsService: ActivityFeedSettingsProtocol,
        bulkPrivacyUpdateService: BulkPrivacyUpdateProtocol,
        workoutAutoShareService: WorkoutAutoShareProtocol,
        xpTransactionService: XPTransactionService,
        countVerificationService: CountVerificationProtocol,
        statsSyncService: StatsSyncProtocol
    ) {
        self.authenticationManager = authenticationManager
        self.cloudKitManager = cloudKitManager
        self.workoutObserver = workoutObserver
        self.workoutProcessor = workoutProcessor
        self.healthKitService = healthKitService
        self.watchConnectivityManager = watchConnectivityManager
        self.workoutSyncManager = workoutSyncManager
        self.workoutSyncQueue = workoutSyncQueue
        self.notificationStore = notificationStore
        self.unlockNotificationService = unlockNotificationService
        self.unlockStorageService = unlockStorageService
        self.userProfileService = userProfileService
        self.rateLimitingService = rateLimitingService
        self.socialFollowingService = socialFollowingService
        self.activityFeedService = activityFeedService
        self.notificationScheduler = notificationScheduler
        self.notificationManager = notificationManager
        self.messageProvider = messageProvider
        self.workoutKudosService = workoutKudosService
        self.apnsManager = apnsManager
        self.groupWorkoutService = groupWorkoutService
        self.workoutChallengesService = workoutChallengesService
        self.workoutChallengeLinksService = workoutChallengeLinksService
        self.subscriptionManager = subscriptionManager
        self.realTimeSyncCoordinator = realTimeSyncCoordinator
        self.activityCommentsService = activityCommentsService
        self.activitySharingSettingsService = activitySharingSettingsService
        self.bulkPrivacyUpdateService = bulkPrivacyUpdateService
        self.workoutAutoShareService = workoutAutoShareService
        self.xpTransactionService = xpTransactionService
        self.countVerificationService = countVerificationService
        self.statsSyncService = statsSyncService
    }
    
    /// Convenience initializer using factory pattern
    /// - Parameters:
    ///   - factory: Factory to create dependencies (defaults to production)
    ///   - skipInitialization: Skip CloudKit initialization (for default/fallback containers)
    @MainActor
    convenience init(factory: DependencyFactory = ProductionDependencyFactory(), skipInitialization: Bool = false) {
        let container = DependencyContainer.create(factory: factory, skipInitialization: skipInitialization)
        self.init(
            authenticationManager: container.authenticationManager,
            cloudKitManager: container.cloudKitManager,
            workoutObserver: container.workoutObserver,
            workoutProcessor: container.workoutProcessor,
            healthKitService: container.healthKitService,
            watchConnectivityManager: container.watchConnectivityManager,
            workoutSyncManager: container.workoutSyncManager,
            workoutSyncQueue: container.workoutSyncQueue,
            notificationStore: container.notificationStore,
            unlockNotificationService: container.unlockNotificationService,
            unlockStorageService: container.unlockStorageService,
            userProfileService: container.userProfileService,
            rateLimitingService: container.rateLimitingService,
            socialFollowingService: container.socialFollowingService,
            activityFeedService: container.activityFeedService,
            notificationScheduler: container.notificationScheduler,
            notificationManager: container.notificationManager,
            messageProvider: container.messageProvider,
            workoutKudosService: container.workoutKudosService,
            apnsManager: container.apnsManager,
            groupWorkoutService: container.groupWorkoutService,
            workoutChallengesService: container.workoutChallengesService,
            workoutChallengeLinksService: container.workoutChallengeLinksService,
            subscriptionManager: container.subscriptionManager,
            realTimeSyncCoordinator: container.realTimeSyncCoordinator,
            activityCommentsService: container.activityCommentsService,
            activitySharingSettingsService: container.activitySharingSettingsService,
            bulkPrivacyUpdateService: container.bulkPrivacyUpdateService,
            workoutAutoShareService: container.workoutAutoShareService,
            xpTransactionService: container.xpTransactionService,
            countVerificationService: container.countVerificationService,
            statsSyncService: container.statsSyncService
        )
    }
}

// MARK: - Security & Best Practices Notes
// 1. All services are created through a factory pattern for testability
// 2. Dependencies are explicitly declared and injected
// 3. No singletons are used directly - everything goes through DI
// 4. Circular dependencies are wired up after initialization
// 5. Test initializer allows for easy mocking
// 6. Container is immutable after initialization (all properties are let)
// 7. Modern Swift concurrency patterns are supported throughout
