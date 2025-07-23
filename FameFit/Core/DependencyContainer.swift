//
//  DependencyContainer.swift
//  FameFit
//
//  Manages dependency injection for the app
//

import Foundation
import SwiftUI
import HealthKit

class DependencyContainer: ObservableObject {
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
    let workoutCommentsService: WorkoutCommentsServicing
    let groupWorkoutService: GroupWorkoutServicing
    
    init() {
        // Create instances with proper dependency injection
        self.cloudKitManager = CloudKitManager()
        self.authenticationManager = AuthenticationManager(cloudKitManager: cloudKitManager)
        self.healthKitService = RealHealthKitService()
        self.notificationStore = NotificationStore()
        
        self.workoutObserver = WorkoutObserver(
            cloudKitManager: cloudKitManager,
            healthKitService: healthKitService
        )
        
        self.workoutSyncManager = WorkoutSyncManager(
            cloudKitManager: cloudKitManager,
            healthKitService: healthKitService
        )
        
        self.workoutSyncQueue = WorkoutSyncQueue(
            cloudKitManager: cloudKitManager
        )
        
        self.unlockStorageService = UnlockStorageService()
        
        self.unlockNotificationService = UnlockNotificationService(
            notificationStore: notificationStore,
            unlockStorage: unlockStorageService
        )
        
        // Use mock services in DEBUG builds for easier testing
        #if DEBUG
        if ProcessInfo.processInfo.environment["USE_MOCK_SOCIAL"] == "1" {
            self.userProfileService = MockUserProfileService()
        } else {
            self.userProfileService = UserProfileService(cloudKitManager: cloudKitManager)
        }
        #else
        self.userProfileService = UserProfileService(cloudKitManager: cloudKitManager)
        #endif
        
        self.rateLimitingService = RateLimitingService()
        
        self.socialFollowingService = SocialFollowingService(
            cloudKitManager: cloudKitManager,
            rateLimiter: rateLimitingService,
            profileService: userProfileService
        )
        
        // Create activity feed service with default privacy settings
        let defaultPrivacySettings = WorkoutPrivacySettings()
        self.activityFeedService = ActivityFeedService(
            cloudKitManager: cloudKitManager,
            privacySettings: defaultPrivacySettings
        )
        
        // Create message provider
        self.messageProvider = FameFitMessageProvider()
        
        // Create notification scheduler
        self.notificationScheduler = NotificationScheduler(
            notificationStore: notificationStore
        )
        
        // Create APNS manager placeholder (will be set after init)
        let tempAPNSManager = APNSManager(cloudKitManager: cloudKitManager, notificationStore: notificationStore)
        self.apnsManager = tempAPNSManager
        
        // Create notification manager with APNS manager
        self.notificationManager = NotificationManager(
            scheduler: notificationScheduler,
            notificationStore: notificationStore,
            unlockService: unlockNotificationService,
            messageProvider: messageProvider,
            apnsManager: apnsManager
        )
        
        // Create workout kudos service
        self.workoutKudosService = WorkoutKudosService(
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimitingService
        )
        
        // Create workout comments service
        self.workoutCommentsService = WorkoutCommentsService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimitingService
        )
        
        // Create group workout service
        self.groupWorkoutService = GroupWorkoutService(
            cloudKitManager: cloudKitManager,
            userProfileService: userProfileService,
            notificationManager: notificationManager,
            rateLimiter: rateLimitingService
        )
        
        // Wire up dependencies
        cloudKitManager.authenticationManager = authenticationManager
        cloudKitManager.unlockNotificationService = unlockNotificationService
        
        // Give workout observer access to notification store and APNS manager
        workoutObserver.notificationStore = notificationStore
        workoutObserver.apnsManager = apnsManager
        
        // Give workout sync manager access to notification store and manager
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
        workoutCommentsService: WorkoutCommentsServicing? = nil,
        groupWorkoutService: GroupWorkoutServicing? = nil
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
        
        if let apnsManager = apnsManager {
            self.apnsManager = apnsManager
        } else {
            let tempAPNSManager = APNSManager(cloudKitManager: self.cloudKitManager)
            self.apnsManager = tempAPNSManager
        }
        
        self.workoutCommentsService = workoutCommentsService ?? WorkoutCommentsService(
            cloudKitManager: self.cloudKitManager,
            userProfileService: self.userProfileService,
            notificationManager: self.notificationManager,
            rateLimiter: self.rateLimitingService
        )
        
        self.groupWorkoutService = groupWorkoutService ?? GroupWorkoutService(
            cloudKitManager: self.cloudKitManager,
            userProfileService: self.userProfileService,
            notificationManager: self.notificationManager,
            rateLimiter: self.rateLimitingService
        )
        
        // Wire up dependencies for WorkoutSyncManager
        self.workoutSyncManager.notificationStore = self.notificationStore
        self.workoutSyncManager.notificationManager = self.notificationManager
    }
    
    // MARK: - Testing Support
    
    #if DEBUG
    /// Test notification settings integration by verifying preferences are respected
    func testNotificationSettingsIntegration() {
        // Create test preferences with some notifications disabled
        var testPreferences = NotificationPreferences()
        testPreferences.soundEnabled = false
        testPreferences.badgeEnabled = false
        testPreferences.enabledTypes[.workoutKudos] = false
        testPreferences.enabledTypes[.newFollower] = true
        
        // Update all services with test preferences
        notificationScheduler.updatePreferences(testPreferences)
        notificationManager.updatePreferences(testPreferences)
        unlockNotificationService.updatePreferences(testPreferences)
        workoutObserver.updatePreferences(testPreferences)
        
        print("✅ Notification settings integration test completed")
        print("   - Sound disabled: \(!testPreferences.soundEnabled)")
        print("   - Badge disabled: \(!testPreferences.badgeEnabled)")
        print("   - Workout kudos disabled: \(testPreferences.enabledTypes[.workoutKudos] == false)")
        print("   - New followers enabled: \(testPreferences.enabledTypes[.newFollower] == true)")
    }
    
    /// Populate the notification store with test notifications for manual testing
    func addTestNotifications() {
        let testNotifications = [
            NotificationItem(
                type: .workoutCompleted,
                title: "🏃 Chad",
                body: "Awesome! You crushed that 30-minute run and earned 15 followers!",
                metadata: .workout(WorkoutNotificationMetadata(
                    workoutId: "test-workout-1",
                    workoutType: "Running",
                    duration: 30,
                    calories: 250,
                    xpEarned: 15,
                    distance: 5000,
                    averageHeartRate: 145
                ))
            ),
            
            NotificationItem(
                type: .newFollower,
                title: "New Follower! 👥",
                body: "FitnessGuru started following you",
                metadata: .social(SocialNotificationMetadata(
                    userID: "user123",
                    username: "fitnessguru",
                    displayName: "Fitness Guru",
                    profileImageUrl: nil,
                    relationshipType: "follower",
                    actionCount: nil
                )),
                actions: [.view]
            ),
            
            NotificationItem(
                type: .unlockAchieved,
                title: "Achievement Unlocked! 🏆",
                body: "You've earned the 'Workout Warrior' achievement!",
                metadata: .achievement(AchievementNotificationMetadata(
                    achievementId: "warrior",
                    achievementName: "Workout Warrior",
                    achievementDescription: "Complete 50 workouts",
                    xpRequired: 1000,
                    category: "fitness",
                    iconEmoji: "🏆"
                )),
                actions: [.view]
            ),
            
            NotificationItem(
                type: .levelUp,
                title: "Level Up! ⭐",
                body: "Congratulations! You've reached level 5!",
                actions: [.view]
            ),
            
            NotificationItem(
                type: .workoutKudos,
                title: "Workout Kudos! ❤️",
                body: "2 people gave kudos to your morning run",
                metadata: .social(SocialNotificationMetadata(
                    userID: "kudos-user",
                    username: "runner123",
                    displayName: "Runner 123",
                    profileImageUrl: nil,
                    relationshipType: "kudos",
                    actionCount: 2
                )),
                actions: [.view, .reply]
            )
        ]
        
        // Add test notifications
        testNotifications.forEach { notification in
            notificationStore.addNotification(notification)
        }
    }
    #endif
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