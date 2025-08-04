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
        registerBackgroundTasks()
        scheduleBackgroundTasks()
    }
    
    private func registerBackgroundTasks() {
        // Register sync task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: syncTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundSync(task: task as! BGProcessingTask)
        }
        
        // Register workout processing task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: workoutTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self = self else { return }
            BackgroundWorkoutProcessor.shared.handleBackgroundTask(task)
        }
        
        FameFitLogger.info("Background tasks registered", category: FameFitLogger.app)
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
    
    private func handleBackgroundSync(task: BGProcessingTask) {
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
                
                let syncManager = container.syncManager
                try await syncManager.performSync()
                
                FameFitLogger.info("Background sync completed successfully", category: FameFitLogger.app)
                task.setTaskCompleted(success: true)
            } catch {
                FameFitLogger.error("Background sync failed: \(error)", category: FameFitLogger.app)
                task.setTaskCompleted(success: false)
            }
        }
    }
}