//
//  AppDelegate.swift
//  FameFit
//
//  Handles app lifecycle and background tasks
//

import UIKit
import BackgroundTasks
import os.log

class AppDelegate: NSObject, UIApplicationDelegate {
    var dependencyContainer: DependencyContainer?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FameFitLogger.info("App launched", category: FameFitLogger.app)
        
        // Don't create a new container here - wait for the one from FameFitApp
        // to be shared via onAppear
        
        // Register background tasks
        registerBackgroundTasks()
        
        // Schedule background sync if needed
        scheduleBackgroundSync()
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        FameFitLogger.info("App became active", category: FameFitLogger.app)
        
        // The WorkoutSyncManager will handle sync automatically
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
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
}
