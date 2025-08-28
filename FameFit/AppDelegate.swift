//
//  AppDelegate.swift
//  FameFit
//
//  Handles app lifecycle and background tasks
//

import BackgroundTasks
import os.log
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    var dependencyContainer: DependencyContainer?
    var appInitializer: AppInitializer?

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FameFitLogger.info("App launched", category: FameFitLogger.app)

        // Register notification categories
        APNSService.registerNotificationCategories()

        // Register background tasks BEFORE didFinishLaunching returns (iOS requirement)
        registerBackgroundTasks()

        return true
    }
    
    /// Configure the AppDelegate with dependencies from SwiftUI app
    func configure(with container: DependencyContainer) {
        FameFitLogger.info("Configure AppDelegate with Dependency Container and Initializer",
                           category: FameFitLogger.app)
        self.dependencyContainer = container
        self.appInitializer = AppInitializer(dependencyContainer: container)
        
        // Perform initial app setup
        appInitializer?.performInitialSetup()
    }

    func applicationDidBecomeActive(_: UIApplication) {
        FameFitLogger.info("App became active", category: FameFitLogger.app)

        // Update badge count to reflect current notification state
        Task {
            if let container = dependencyContainer {
                let unreadCount = container.notificationStore.unreadCount
                await container.apnsManager.updateBadgeCount(unreadCount)
            }
        }

        // The WorkoutSyncService will handle sync automatically
        
        // Sync user profile to Watch when app becomes active
        Task { @MainActor in
            if let container = dependencyContainer,
               let profileService = container.userProfileService as? UserProfileService,
               let currentProfile = profileService.currentProfile,
               let watchManager = container.watchConnectivityManager as? EnhancedWatchConnectivityManager {
                FameFitLogger.info("📱⌚ Syncing profile to Watch on app activation", category: FameFitLogger.connectivity)
                watchManager.syncUserProfile(currentProfile)
            } else if let container = dependencyContainer,
                      let watchManager = container.watchConnectivityManager as? EnhancedWatchConnectivityManager {
                // Try to fetch profile if not loaded
                do {
                    let profile = try await container.userProfileService.fetchCurrentUserProfile()
                    FameFitLogger.info("📱⌚ Fetched and syncing profile to Watch on app activation", category: FameFitLogger.connectivity)
                    watchManager.syncUserProfile(profile)
                } catch {
                    FameFitLogger.warning("📱⌚ Could not fetch profile for Watch sync: \(error)", category: FameFitLogger.connectivity)
                }
            }
        }
    }

    func applicationDidEnterBackground(_: UIApplication) {
        FameFitLogger.info("App entered background", category: FameFitLogger.app)

        // Smart trigger: Check for pending items and schedule immediate sync if needed
        Task {
            if let workoutQueue = dependencyContainer?.workoutQueue {
                let stats = await workoutQueue.getQueueStats()
                
                if stats.pending > 0 || stats.failed > 0 {
                    FameFitLogger.info("⚡ \(stats.pending) pending items detected - triggering immediate background sync", category: FameFitLogger.app)
                    BackgroundTaskManager.shared.scheduleImmediateSync()
                } else {
                    // Normal background task scheduling
                    BackgroundTaskManager.shared.scheduleBackgroundTasks()
                }
            } else {
                // Fallback to normal scheduling
                BackgroundTaskManager.shared.scheduleBackgroundTasks()
            }
        }
    }

    // MARK: - Background Tasks
    
    private func registerBackgroundTasks() {
        // Register sync task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.jimmypocock.FameFit.sync",
            using: nil
        ) { task in
            BackgroundTaskManager.shared.handleBackgroundSyncTask(task as! BGProcessingTask)
        }
        
        // Register workout processing task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.jimmypocock.FameFit.workout-processing",
            using: nil
        ) { task in
            Task {
                // Process workout retry queue
                if let workoutQueue = self.dependencyContainer?.workoutQueue {
                    await workoutQueue.processAll()
                }
                // Trigger workout sync
                if let workoutSyncService = self.dependencyContainer?.workoutSyncManager {
                    await workoutSyncService.performManualSync()
                }
                task.setTaskCompleted(success: true)
            }
        }
        
        FameFitLogger.info("Background tasks registered", category: FameFitLogger.app)
    }

    // MARK: - Push Notifications

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        FameFitLogger.info("Successfully registered for push notifications", category: FameFitLogger.app)

        // Handle the device token
        Task {
            do {
                try await dependencyContainer?.apnsManager.handleDeviceToken(deviceToken)
                FameFitLogger.info("Device token registered with CloudKit", category: FameFitLogger.app)
            } catch {
                FameFitLogger.error("Failed to register device token", error: error, category: FameFitLogger.app)
            }
        }
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        FameFitLogger.error("Failed to register for push notifications", error: error, category: FameFitLogger.app)
        dependencyContainer?.apnsManager.handleRegistrationError(error)
    }

    func application(
        _: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        FameFitLogger.info("Received remote notification", category: FameFitLogger.app)

        // Process the notification
        Task {
            // Check if this is a silent notification for background updates
            if let aps = userInfo["aps"] as? [String: Any],
               let contentAvailable = aps["content-available"] as? Int,
               contentAvailable == 1 {
                // Handle background update
                FameFitLogger.info("Processing silent notification", category: FameFitLogger.app)

                // Process retry queue if needed
                if let workoutQueue = dependencyContainer?.workoutQueue {
                    Task {
                        await workoutQueue.processAll()
                    }
                }

                completionHandler(.newData)
            } else {
                // Regular notification - will be handled by UNUserNotificationCenterDelegate
                completionHandler(.noData)
            }
        }
    }
}
