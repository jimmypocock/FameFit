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
        
        // Configure background processor
        BackgroundWorkoutProcessor.shared.configure(with: container)
        
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
    }

    func applicationDidEnterBackground(_: UIApplication) {
        FameFitLogger.info("App entered background", category: FameFitLogger.app)

        // Background tasks are now handled by BackgroundTaskManager
        BackgroundTaskManager.shared.scheduleBackgroundTasks()
        
        // Trigger background workout processing
        BackgroundWorkoutProcessor.shared.triggerBackgroundProcessing()
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
            BackgroundWorkoutProcessor.shared.handleBackgroundTask(task)
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

                // Trigger a sync if needed
                if let container = dependencyContainer {
                    container.workoutSyncQueue.processQueue()
                }

                completionHandler(.newData)
            } else {
                // Regular notification - will be handled by UNUserNotificationCenterDelegate
                completionHandler(.noData)
            }
        }
    }
}
