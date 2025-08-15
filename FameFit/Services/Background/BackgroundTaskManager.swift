import Foundation
import BackgroundTasks
import CloudKit

@MainActor
final class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    private let syncTaskIdentifier = "com.jimmypocock.FameFit.sync"
    private let workoutTaskIdentifier = "com.jimmypocock.FameFit.workout-processing"
    
    private var dependencyContainer: DependencyContainer?
    
    private init() {}
    
    func configure(with container: DependencyContainer) {
        self.dependencyContainer = container
        // Registration happens in AppDelegate to meet iOS requirements
        // Just schedule the tasks here
        scheduleBackgroundTasks()
    }
    
    func scheduleBackgroundTasks() {
        scheduleBackgroundSync()
        scheduleWorkoutProcessing()
    }
    
    private func scheduleBackgroundSync() {
        // Skip in test environment
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            FameFitLogger.debug("Skipping background sync in test environment", category: FameFitLogger.app)
            return
        }
        
        Task {
            await scheduleAdaptiveBackgroundSync()
        }
    }
    
    private func scheduleAdaptiveBackgroundSync() async {
        let request = BGProcessingTaskRequest(identifier: syncTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        // Adaptive scheduling based on queue state
        var interval: TimeInterval = 60 * 60 // Default: 1 hour
        
        if let container = dependencyContainer {
            let stats = await container.workoutQueue.getQueueStats()
            
            if stats.pending > 0 || stats.failed > 0 {
                // High priority: Items waiting to be processed
                interval = 15 * 60 // 15 minutes
                FameFitLogger.info("📊 Adaptive sync: \(stats.pending) pending, \(stats.failed) failed - scheduling in 15 min", category: FameFitLogger.app)
            } else {
                // Low priority: No pending items
                interval = 2 * 60 * 60 // 2 hours
                FameFitLogger.debug("📊 Adaptive sync: Queue empty - scheduling in 2 hours", category: FameFitLogger.app)
            }
        }
        
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            FameFitLogger.info("Background sync scheduled for \(interval/60) minutes", category: FameFitLogger.app)
        } catch {
            FameFitLogger.error("Failed to schedule background sync: \(error)", category: FameFitLogger.app)
        }
    }
    
    /// Schedule immediate sync when critical items are pending
    func scheduleImmediateSync() {
        let request = BGProcessingTaskRequest(identifier: syncTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // 30 seconds
        
        do {
            try BGTaskScheduler.shared.submit(request)
            FameFitLogger.info("⚡ Immediate background sync scheduled", category: FameFitLogger.app)
        } catch {
            FameFitLogger.error("Failed to schedule immediate sync: \(error)", category: FameFitLogger.app)
        }
    }
    
    func handleBackgroundSyncTask(_ task: BGProcessingTask) {
        // Schedule next sync
        scheduleBackgroundSync()
        
        task.expirationHandler = {
            FameFitLogger.info("Background sync expired", category: FameFitLogger.app)
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                guard let container = dependencyContainer else {
                    throw NSError(domain: "BackgroundSync", code: 0, userInfo: [NSLocalizedDescriptionKey: "No dependency container"])
                }
                
                // Process workout queue
                await container.workoutQueue.processAll()
                
                // Trigger workout sync
                await container.workoutSyncManager.performManualSync()
                
                FameFitLogger.info("Background sync completed successfully", category: FameFitLogger.app)
                task.setTaskCompleted(success: true)
            } catch {
                FameFitLogger.error("Background sync failed: \(error)", category: FameFitLogger.app)
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func scheduleWorkoutProcessing() {
        // Skip in test environment
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            FameFitLogger.debug("Skipping workout processing in test environment", category: FameFitLogger.app)
            return
        }
        
        let request = BGProcessingTaskRequest(identifier: workoutTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            FameFitLogger.info("Workout processing scheduled", category: FameFitLogger.app)
        } catch {
            FameFitLogger.error("Failed to schedule workout processing: \(error)", category: FameFitLogger.app)
        }
    }
}
