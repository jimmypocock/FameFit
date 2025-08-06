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
        BackgroundWorkoutProcessor.shared.scheduleNextBackgroundTask()
    }
    
    private func scheduleBackgroundSync() {
        // Skip in test environment
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            FameFitLogger.debug("Skipping background sync in test environment", category: FameFitLogger.app)
            return
        }
        
        let request = BGProcessingTaskRequest(identifier: syncTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        
        do {
            try BGTaskScheduler.shared.submit(request)
            FameFitLogger.info("Background sync scheduled", category: FameFitLogger.app)
        } catch {
            FameFitLogger.error("Failed to schedule background sync: \(error)", category: FameFitLogger.app)
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
                
                // Process any queued workouts
                container.workoutSyncQueue.processQueue()
                
                // Wait a moment for processing to complete
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                FameFitLogger.info("Background sync completed successfully", category: FameFitLogger.app)
                task.setTaskCompleted(success: true)
            } catch {
                FameFitLogger.error("Background sync failed: \(error)", category: FameFitLogger.app)
                task.setTaskCompleted(success: false)
            }
        }
    }
}