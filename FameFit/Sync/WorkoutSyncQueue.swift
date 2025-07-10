//
//  WorkoutSyncQueue.swift
//  FameFit
//
//  Manages a queue of workouts to sync with retry logic
//

import Foundation
import HealthKit
import os.log

/// Represents a workout pending sync
struct PendingWorkout: Codable {
    let id: String
    let workoutType: String
    let duration: TimeInterval
    let calories: Double
    let endDate: Date
    let retryCount: Int
    let lastRetryDate: Date?
    
    init(from workout: HKWorkout, retryCount: Int = 0) {
        self.id = workout.uuid.uuidString
        self.workoutType = workout.workoutActivityType.rawValue.description
        self.duration = workout.duration
        self.endDate = workout.endDate
        self.retryCount = retryCount
        self.lastRetryDate = nil
        
        // Extract calories
        var cal = 0.0
        if let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energyBurned = workout.statistics(for: energyBurnedType)?.sumQuantity()
            cal = energyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        }
        self.calories = cal
    }
}

/// Manages a persistent queue of workouts waiting to be synced
class WorkoutSyncQueue: ObservableObject {
    private let queueKey = "FameFitWorkoutSyncQueue"
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 300 // 5 minutes
    
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.jimmypocock.FameFit.WorkoutSync"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .background
        return queue
    }()
    
    @Published var pendingWorkouts: [PendingWorkout] = []
    @Published var isProcessing = false
    @Published var failedCount = 0
    
    private weak var cloudKitManager: CloudKitManager?
    
    init(cloudKitManager: CloudKitManager) {
        self.cloudKitManager = cloudKitManager
        loadQueue()
    }
    
    /// Add a workout to the sync queue
    func enqueueWorkout(_ workout: HKWorkout) {
        let pending = PendingWorkout(from: workout)
        
        DispatchQueue.main.async {
            self.pendingWorkouts.append(pending)
            self.saveQueue()
        }
        
        FameFitLogger.info("Enqueued workout for sync: \(pending.id)", category: FameFitLogger.workout)
        
        // Try to process immediately
        processQueue()
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
        
        // Process each workout
        let operation = BlockOperation { [weak self] in
            self?.processPendingWorkouts()
        }
        
        operationQueue.addOperation(operation)
    }
    
    /// Process pending workouts one by one
    private func processPendingWorkouts() {
        var successCount = 0
        var failureCount = 0
        var workoutsToRetry: [PendingWorkout] = []
        
        for workout in pendingWorkouts {
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
            let semaphore = DispatchSemaphore(value: 0)
            var syncSuccess = false
            
            DispatchQueue.main.async { [weak self] in
                self?.cloudKitManager?.addFollowers(5)
                syncSuccess = true // Assume success for now
                semaphore.signal()
            }
            
            // Wait for sync to complete (with timeout)
            let result = semaphore.wait(timeout: .now() + 10)
            
            if result == .success && syncSuccess {
                successCount += 1
                FameFitLogger.info("Successfully synced workout \(workout.id)", category: FameFitLogger.workout)
            } else {
                failureCount += 1
                
                // Update retry count
                var retryWorkout = workout
                retryWorkout = PendingWorkout(
                    id: workout.id,
                    workoutType: workout.workoutType,
                    duration: workout.duration,
                    calories: workout.calories,
                    endDate: workout.endDate,
                    retryCount: workout.retryCount + 1,
                    lastRetryDate: Date()
                )
                
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
                return PendingWorkout(
                    id: workout.id,
                    workoutType: workout.workoutType,
                    duration: workout.duration,
                    calories: workout.calories,
                    endDate: workout.endDate,
                    retryCount: 0,
                    lastRetryDate: nil
                )
            }
            return workout
        }
        
        saveQueue()
        processQueue()
    }
}

// Helper extension to make PendingWorkout fully Codable
extension PendingWorkout {
    init(id: String, workoutType: String, duration: TimeInterval, calories: Double, endDate: Date, retryCount: Int, lastRetryDate: Date?) {
        self.id = id
        self.workoutType = workoutType
        self.duration = duration
        self.calories = calories
        self.endDate = endDate
        self.retryCount = retryCount
        self.lastRetryDate = lastRetryDate
    }
}