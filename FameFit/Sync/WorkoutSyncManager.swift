//
//  WorkoutSyncManager.swift
//  FameFit
//
//  Manages reliable workout synchronization using HKAnchoredObjectQuery
//

import Foundation
import HealthKit
import UserNotifications
import os.log

/// Key for storing the sync anchor in UserDefaults
private let kWorkoutSyncAnchorKey = "FameFitWorkoutSyncAnchor"

/// Manages workout synchronization with HealthKit using anchored queries for reliability
class WorkoutSyncManager: ObservableObject {
    private let healthKitService: HealthKitService
    private weak var cloudKitManager: CloudKitManager?
    private var anchoredQuery: HKAnchoredObjectQuery?
    private let healthStore = HKHealthStore() // Needed for anchored query
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: FameFitError?
    
    init(cloudKitManager: CloudKitManager, healthKitService: HealthKitService? = nil) {
        self.cloudKitManager = cloudKitManager
        self.healthKitService = healthKitService ?? RealHealthKitService()
    }
    
    /// Start monitoring workouts using HKAnchoredObjectQuery for reliable incremental updates
    func startReliableSync() {
        guard healthKitService.isHealthDataAvailable else {
            FameFitLogger.error("HealthKit not available", category: FameFitLogger.workout)
            DispatchQueue.main.async {
                self.syncError = .healthKitNotAvailable
            }
            return
        }
        
        // Get the last anchor from UserDefaults
        var anchor: HKQueryAnchor?
        if let anchorData = UserDefaults.standard.data(forKey: kWorkoutSyncAnchorKey) {
            do {
                anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: anchorData)
                FameFitLogger.info("Resuming sync from saved anchor", category: FameFitLogger.workout)
            } catch {
                FameFitLogger.error("Failed to decode anchor", error: error, category: FameFitLogger.workout)
            }
        }
        
        // Create the anchored object query
        let workoutType = HKObjectType.workoutType()
        
        anchoredQuery = HKAnchoredObjectQuery(
            type: workoutType,
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, newAnchor, error in
            self?.handleInitialResults(
                samples: samples,
                deletedObjects: deletedObjects,
                anchor: newAnchor,
                error: error
            )
        }
        
        // Set up the update handler for ongoing changes
        anchoredQuery?.updateHandler = { [weak self] query, samples, deletedObjects, newAnchor, error in
            self?.handleIncrementalResults(
                samples: samples,
                deletedObjects: deletedObjects,
                anchor: newAnchor,
                error: error
            )
        }
        
        // Execute the query
        healthStore.execute(anchoredQuery!)
        
        FameFitLogger.info("Started reliable workout sync with HKAnchoredObjectQuery", category: FameFitLogger.workout)
    }
    
    /// Stop monitoring workouts
    func stopSync() {
        if let query = anchoredQuery {
            healthStore.stop(query)
            anchoredQuery = nil
            FameFitLogger.info("Stopped workout sync", category: FameFitLogger.workout)
        }
    }
    
    /// Handle initial query results
    private func handleInitialResults(
        samples: [HKSample]?,
        deletedObjects: [HKDeletedObject]?,
        anchor: HKQueryAnchor?,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isSyncing = true
        }
        
        if let error = error {
            FameFitLogger.error("Initial sync error", error: error, category: FameFitLogger.workout)
            DispatchQueue.main.async {
                self.syncError = error.fameFitError
                self.isSyncing = false
            }
            return
        }
        
        guard let workouts = samples as? [HKWorkout] else {
            DispatchQueue.main.async {
                self.isSyncing = false
            }
            return
        }
        
        FameFitLogger.info("Initial sync found \(workouts.count) workouts", category: FameFitLogger.workout)
        
        // Process workouts
        processWorkouts(workouts, isInitialSync: true)
        
        // Save the anchor
        if let anchor = anchor {
            saveAnchor(anchor)
        }
        
        DispatchQueue.main.async {
            self.isSyncing = false
            self.lastSyncDate = Date()
            self.syncError = nil
        }
    }
    
    /// Handle incremental updates
    private func handleIncrementalResults(
        samples: [HKSample]?,
        deletedObjects: [HKDeletedObject]?,
        anchor: HKQueryAnchor?,
        error: Error?
    ) {
        if let error = error {
            FameFitLogger.error("Incremental sync error", error: error, category: FameFitLogger.workout)
            DispatchQueue.main.async {
                self.syncError = error.fameFitError
            }
            return
        }
        
        guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
            return
        }
        
        FameFitLogger.info("Incremental sync found \(workouts.count) new workout(s)", category: FameFitLogger.workout)
        
        // Process new workouts
        processWorkouts(workouts, isInitialSync: false)
        
        // Save the new anchor
        if let anchor = anchor {
            saveAnchor(anchor)
        }
        
        DispatchQueue.main.async {
            self.lastSyncDate = Date()
            self.syncError = nil
        }
    }
    
    /// Process workouts and update follower count
    private func processWorkouts(_ workouts: [HKWorkout], isInitialSync: Bool) {
        // Get app install date to avoid counting pre-install workouts
        let appInstallDateKey = UserDefaultsKeys.appInstallDate
        if UserDefaults.standard.object(forKey: appInstallDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: appInstallDateKey)
        }
        let appInstallDate = UserDefaults.standard.object(forKey: appInstallDateKey) as? Date ?? Date()
        
        for workout in workouts {
            // Skip workouts before app install
            guard workout.endDate > appInstallDate else {
                FameFitLogger.debug("Skipping pre-install workout", category: FameFitLogger.workout)
                continue
            }
            
            // Validate workout data
            guard workout.duration > 0,
                  workout.duration < 86400, // Less than 24 hours
                  workout.endDate > workout.startDate else {
                FameFitLogger.notice("Invalid workout data detected, skipping", category: FameFitLogger.workout)
                continue
            }
            
            // Log workout info
            let duration = workout.duration / 60
            FameFitLogger.info("Processing workout: \(workout.workoutActivityType.name) - Duration: \(Int(duration)) min", category: FameFitLogger.workout)
            
            // For initial sync, we might want to batch process
            // For incremental updates, process immediately
            if !isInitialSync {
                // Add followers for the workout
                cloudKitManager?.addFollowers(5)
                
                // Send notification
                sendWorkoutNotification(for: workout)
            }
        }
        
        // For initial sync, we might want to calculate total followers differently
        if isInitialSync && !workouts.isEmpty {
            FameFitLogger.info("Initial sync complete. Found \(workouts.count) workouts since install", category: FameFitLogger.workout)
            // You might want to batch update followers here instead of per-workout
        }
    }
    
    /// Save the sync anchor to UserDefaults
    private func saveAnchor(_ anchor: HKQueryAnchor) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: kWorkoutSyncAnchorKey)
            FameFitLogger.debug("Saved sync anchor", category: FameFitLogger.workout)
        } catch {
            FameFitLogger.error("Failed to save anchor", error: error, category: FameFitLogger.workout)
        }
    }
    
    /// Send notification for completed workout
    private func sendWorkoutNotification(for workout: HKWorkout) {
        let character = FameFitCharacter.characterForWorkoutType(workout.workoutActivityType)
        let duration = Int(workout.duration / 60)
        
        // Get calories if available
        var calories = 0
        if let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energyBurned = workout.statistics(for: energyBurnedType)?.sumQuantity()
            calories = Int(energyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
        }
        
        let content = UNMutableNotificationContent()
        content.title = "\(character.emoji) \(character.fullName)"
        content.body = character.workoutCompletionMessage(followers: 5)
        content.sound = .default
        content.badge = NSNumber(value: cloudKitManager?.followerCount ?? 0)
        
        content.userInfo = [
            "character": character.rawValue,
            "duration": duration,
            "calories": calories,
            "newFollowers": 5
        ]
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                FameFitLogger.error("Failed to send notification", error: error, category: FameFitLogger.workout)
            }
        }
    }
}