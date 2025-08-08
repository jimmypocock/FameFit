//
//  DependencyContainer.swift
//  FameFit
//
//  Manages dependency injection for the app using modern Swift patterns
//

import Foundation
import HealthKit
import SwiftUI

/// Main dependency container following modern Swift patterns and security best practices
/// The container is split into extensions for better maintainability:
/// - DependencyContainer+Init.swift: Production initialization
/// - DependencyContainer+Test.swift: Test initialization
/// - DependencyContainer+Environment.swift: SwiftUI environment integration
final class DependencyContainer: ObservableObject {
    // MARK: - Core Services
    
    let authenticationManager: AuthenticationManager
    let cloudKitManager: CloudKitManager
    let healthKitService: HealthKitService
    let modernHealthKitService: ModernHealthKitServicing
    let watchConnectivityManager: WatchConnectivityManaging
    
    // MARK: - Workout Services
    
    let workoutObserver: WorkoutObserver
    let workoutProcessor: WorkoutProcessor
    let workoutSyncManager: WorkoutSyncManager
    let workoutSyncQueue: WorkoutSyncQueue
    
    // MARK: - Notification Services
    
    let notificationStore: NotificationStore
    let unlockNotificationService: UnlockNotificationService
    let unlockStorageService: UnlockStorageService
    let notificationScheduler: NotificationScheduling
    let notificationManager: NotificationManaging
    let messageProvider: MessageProviding
    let apnsManager: APNSManaging
    
    // MARK: - Social & Profile Services
    
    let userProfileService: UserProfileServicing
    let rateLimitingService: RateLimitingServicing
    let socialFollowingService: SocialFollowingServicing
    
    // MARK: - Activity Feed Services
    
    let activityFeedService: ActivityFeedServicing
    let activityCommentsService: ActivityFeedCommentsServicing
    let workoutKudosService: WorkoutKudosServicing
    let activitySharingSettingsService: ActivityFeedSettingsServicing
    let workoutAutoShareService: WorkoutAutoShareServicing
    
    // MARK: - Privacy & Settings Services
    
    let bulkPrivacyUpdateService: BulkPrivacyUpdateServicing
    
    // MARK: - Challenge & Group Services
    
    let workoutChallengesService: WorkoutChallengesServicing
    let workoutChallengeLinksService: WorkoutChallengeLinksServicing
    let groupWorkoutService: GroupWorkoutServiceProtocol
    
    // MARK: - Sync & Real-time Services
    
    let subscriptionManager: CloudKitSubscriptionManaging
    let realTimeSyncCoordinator: RealTimeSyncCoordinating
    
    // MARK: - Transaction Services
    
    let xpTransactionService: XPTransactionService
    
    // MARK: - Verification Services
    
    let countVerificationService: CountVerificationServicing
    
    // MARK: - Sync Services
    
    let statsSyncService: StatsSyncServicing
    
    // MARK: - Base Initializer
    
    /// Base initializer that accepts all dependencies
    /// Used by both production and test initializers
    init(
        authenticationManager: AuthenticationManager,
        cloudKitManager: CloudKitManager,
        workoutObserver: WorkoutObserver,
        workoutProcessor: WorkoutProcessor,
        healthKitService: HealthKitService,
        modernHealthKitService: ModernHealthKitServicing,
        watchConnectivityManager: WatchConnectivityManaging,
        workoutSyncManager: WorkoutSyncManager,
        workoutSyncQueue: WorkoutSyncQueue,
        notificationStore: NotificationStore,
        unlockNotificationService: UnlockNotificationService,
        unlockStorageService: UnlockStorageService,
        userProfileService: UserProfileServicing,
        rateLimitingService: RateLimitingServicing,
        socialFollowingService: SocialFollowingServicing,
        activityFeedService: ActivityFeedServicing,
        notificationScheduler: NotificationScheduling,
        notificationManager: NotificationManaging,
        messageProvider: MessageProviding,
        workoutKudosService: WorkoutKudosServicing,
        apnsManager: APNSManaging,
        groupWorkoutService: GroupWorkoutServiceProtocol,
        workoutChallengesService: WorkoutChallengesServicing,
        workoutChallengeLinksService: WorkoutChallengeLinksServicing,
        subscriptionManager: CloudKitSubscriptionManaging,
        realTimeSyncCoordinator: RealTimeSyncCoordinating,
        activityCommentsService: ActivityFeedCommentsServicing,
        activitySharingSettingsService: ActivityFeedSettingsServicing,
        bulkPrivacyUpdateService: BulkPrivacyUpdateServicing,
        workoutAutoShareService: WorkoutAutoShareServicing,
        xpTransactionService: XPTransactionService,
        countVerificationService: CountVerificationServicing,
        statsSyncService: StatsSyncServicing
    ) {
        self.authenticationManager = authenticationManager
        self.cloudKitManager = cloudKitManager
        self.workoutObserver = workoutObserver
        self.workoutProcessor = workoutProcessor
        self.healthKitService = healthKitService
        self.modernHealthKitService = modernHealthKitService
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
}

// MARK: - Security & Best Practices Notes
// 1. All services are created through a factory pattern for testability
// 2. Dependencies are explicitly declared and injected
// 3. No singletons are used directly - everything goes through DI
// 4. Circular dependencies are wired up after initialization
// 5. Test initializer allows for easy mocking
// 6. Container is immutable after initialization (all properties are let)
// 7. Modern Swift concurrency patterns are supported throughout
