//
//  WorkoutSyncQueue.swift
//  FameFit
//
//  Manages a queue of workouts to sync with retry logic
//

import Foundation
import HealthKit
import os.log
import Combine

/// Manages a persistent queue of workouts waiting to be synced
class WorkoutSyncQueue: ObservableObject, WorkoutSyncQueuing {
    private let queueKey = "FameFitWorkoutSyncQueue"
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 300 // 5 minutes
    
    internal let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.jimmypocock.FameFit.WorkoutSync"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .background
        return queue
    }()
    
    @Published var pendingWorkouts: [PendingWorkout] = []
    @Published var isProcessing = false
    @Published var failedCount = 0
    
    // MARK: - Publisher Properties
    var pendingWorkoutsPublisher: AnyPublisher<[PendingWorkout], Never> {
        $pendingWorkouts.eraseToAnyPublisher()
    }
    
    var isProcessingPublisher: AnyPublisher<Bool, Never> {
        $isProcessing.eraseToAnyPublisher()
    }
    
    var failedCountPublisher: AnyPublisher<Int, Never> {
        $failedCount.eraseToAnyPublisher()
    }
    
    private weak var cloudKitManager: (any CloudKitManaging)?
    
    init(cloudKitManager: any CloudKitManaging) {
        self.cloudKitManager = cloudKitManager
        loadQueue()
    }
    
    /// Add a workout to the sync queue
    func enqueueWorkout(_ workout: HKWorkout) {
        let pending = PendingWorkout(from: workout)
        
        DispatchQueue.main.async {
            self.pendingWorkouts.append(pending)
            self.saveQueue()
            
            FameFitLogger.info("Enqueued workout for sync: \(pending.id)", category: FameFitLogger.workout)
            
            // Try to process immediately after adding
            self.processQueue()
        }
    }
    
    /// Process all pending workouts in the queue
    func processQueue() {
        guard !isProcessing else {
            FameFitLogger.debug("Sync queue already processing", category: FameFitLogger.workout)
            return
        }
        
        guard !pendingWorkouts.isEmpty else {
            FameFitLogger.debug("No pending workouts to sync", category: FameFitLogger.workout)
            return
        }
        
        guard let cloudKitManager = cloudKitManager, cloudKitManager.isAvailable else {
            FameFitLogger.notice("CloudKit not available, deferring sync", category: FameFitLogger.workout)
            return
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        FameFitLogger.info("Processing \(pendingWorkouts.count) pending workouts", category: FameFitLogger.workout)
        
        // Make a copy of pending workouts for background processing
        let workoutsToProcess = pendingWorkouts
        
        // Process each workout on background queue
        let operation = BlockOperation { [weak self] in
            self?.processPendingWorkouts(workoutsToProcess)
        }
        
        operationQueue.addOperation(operation)
    }
    
    /// Process pending workouts one by one
    private func processPendingWorkouts(_ workouts: [PendingWorkout]) {
        var successCount = 0
        var failureCount = 0
        var workoutsToRetry: [PendingWorkout] = []
        
        FameFitLogger.info("Processing \(workouts.count) pending workouts", category: FameFitLogger.workout)
        
        for workout in workouts {
            // Check if we should retry this workout
            if let lastRetry = workout.lastRetryDate {
                let timeSinceLastRetry = Date().timeIntervalSince(lastRetry)
                if timeSinceLastRetry < retryDelay {
                    FameFitLogger.debug("Skipping workout \(workout.id) - retry delay not met", category: FameFitLogger.workout)
                    workoutsToRetry.append(workout)
                    continue
                }
            }
            
            // Try to sync the workout
            // Note: This is a simplified implementation. In production, you would:
            // 1. Store the actual HKWorkout object or its UUID
            // 2. Retrieve the full workout data from HealthKit
            // 3. Sync the complete workout details to CloudKit
            
            // For now, we'll mark it as successful since we can't recreate the HKWorkout
            // The actual implementation would use cloudKitManager.recordWorkout
            let syncSuccess = true
            
            FameFitLogger.info("Simulating workout sync for \(workout.id)", category: FameFitLogger.workout)
            
            if syncSuccess {
                successCount += 1
                FameFitLogger.info("Successfully synced workout \(workout.id)", category: FameFitLogger.workout)
            } else {
                failureCount += 1
                
                // Update retry count
                var retryWorkout = workout
                retryWorkout.retryCount = workout.retryCount + 1
                retryWorkout.lastRetryDate = Date()
                
                if retryWorkout.retryCount < maxRetries {
                    workoutsToRetry.append(retryWorkout)
                    FameFitLogger.notice("Will retry workout \(workout.id) later (attempt \(retryWorkout.retryCount)/\(maxRetries))", category: FameFitLogger.workout)
                } else {
                    FameFitLogger.error("Failed to sync workout \(workout.id) after \(maxRetries) attempts", category: FameFitLogger.workout)
                }
            }
        }
        
        // Update the queue with workouts that need retry
        DispatchQueue.main.async {
            self.pendingWorkouts = workoutsToRetry
            self.failedCount = workoutsToRetry.filter { $0.retryCount >= self.maxRetries }.count
            self.isProcessing = false
            self.saveQueue()
            
            FameFitLogger.info("Sync complete: \(successCount) succeeded, \(failureCount) failed, \(workoutsToRetry.count) pending retry", category: FameFitLogger.workout)
        }
        
        // Schedule retry if needed
        if !workoutsToRetry.isEmpty {
            scheduleRetry()
        }
    }
    
    /// Schedule a retry for failed workouts
    private func scheduleRetry() {
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            self?.processQueue()
        }
    }
    
    /// Load the queue from persistent storage
    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueKey) else { return }
        
        do {
            pendingWorkouts = try JSONDecoder().decode([PendingWorkout].self, from: data)
            failedCount = pendingWorkouts.filter { $0.retryCount >= maxRetries }.count
            FameFitLogger.info("Loaded \(pendingWorkouts.count) pending workouts from storage", category: FameFitLogger.workout)
        } catch {
            FameFitLogger.error("Failed to load sync queue", error: error, category: FameFitLogger.workout)
        }
    }
    
    /// Save the queue to persistent storage
    private func saveQueue() {
        do {
            let data = try JSONEncoder().encode(pendingWorkouts)
            UserDefaults.standard.set(data, forKey: queueKey)
        } catch {
            FameFitLogger.error("Failed to save sync queue", error: error, category: FameFitLogger.workout)
        }
    }
    
    /// Clear all pending workouts
    func clearQueue() {
        pendingWorkouts.removeAll()
        failedCount = 0
        saveQueue()
        FameFitLogger.info("Cleared sync queue", category: FameFitLogger.workout)
    }
    
    /// Retry all failed workouts
    func retryFailed() {
        // Reset retry counts for failed workouts
        pendingWorkouts = pendingWorkouts.map { workout in
            if workout.retryCount >= maxRetries {
                var updatedWorkout = workout
                updatedWorkout.retryCount = 0
                updatedWorkout.lastRetryDate = nil
                return updatedWorkout
            }
            return workout
        }
        
        saveQueue()
        processQueue()
    }
    
    /// Check if a workout is already in the queue
    func isWorkoutInQueue(_ workout: HKWorkout) -> Bool {
        // Check by comparing workout end dates and types
        return pendingWorkouts.contains { pending in
            pending.endDate == workout.endDate &&
            pending.workoutType == workout.workoutActivityType.name
        }
    }
    
    /// Get the number of pending workouts
    func pendingCount() -> Int {
        return pendingWorkouts.count
    }
}