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

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FameFitLogger.info("App launched", category: FameFitLogger.app)

        // Don't create a new container here - wait for the one from FameFitApp
        // to be shared via onAppear

        // Register notification categories
        APNSManager.registerNotificationCategories()

        // Register background tasks
        registerBackgroundTasks()

        // Schedule background sync if needed
        scheduleBackgroundSync()
        
        // Initialize WatchConnectivity
        _ = WatchConnectivityManager.shared

        return true
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

        // The WorkoutSyncManager will handle sync automatically
    }

    func applicationDidEnterBackground(_: UIApplication) {
        FameFitLogger.info("App entered background", category: FameFitLogger.app)

        // Schedule background sync for later
        scheduleBackgroundSync()
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        // Register our background task identifier
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.jimmypocock.FameFit.sync",
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGProcessingTask)
        }

        FameFitLogger.info("Background tasks registered", category: FameFitLogger.app)
    }

    private func scheduleBackgroundSync() {
        // Skip background task scheduling in test environment
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            FameFitLogger.debug("Skipping background sync in test environment", category: FameFitLogger.app)
            return
        }

        let request = BGProcessingTaskRequest(identifier: "com.jimmypocock.FameFit.sync")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        // Try to run at least once per day
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3_600) // 1 hour from now

        do {
            try BGTaskScheduler.shared.submit(request)
            FameFitLogger.info("Background sync scheduled", category: FameFitLogger.app)
        } catch {
            FameFitLogger.error("Failed to schedule background sync", error: error, category: FameFitLogger.app)
        }
    }

    private func handleBackgroundSync(task: BGProcessingTask) {
        FameFitLogger.info("Background sync started", category: FameFitLogger.app)

        // Schedule the next sync
        scheduleBackgroundSync()

        // Create a background task to ensure we have time to complete
        let syncTask = Task {
            // Ensure we have a dependency container
            guard let container = self.dependencyContainer else {
                task.setTaskCompleted(success: false)
                return
            }

            // Process any queued workouts
            await withCheckedContinuation { continuation in
                container.workoutSyncQueue.processQueue()

                // Give it a few seconds to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    continuation.resume()
                }
            }

            task.setTaskCompleted(success: true)
            FameFitLogger.info("Background sync completed", category: FameFitLogger.app)
        }

        // Handle expiration
        task.expirationHandler = {
            syncTask.cancel()
            FameFitLogger.notice("Background sync expired", category: FameFitLogger.app)
        }
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
