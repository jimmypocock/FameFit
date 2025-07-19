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
    weak var notificationStore: (any NotificationStoring)?
    private var anchoredQuery: HKAnchoredObjectQuery?
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: FameFitError?
    
    init(cloudKitManager: CloudKitManager, healthKitService: HealthKitService? = nil) {
        self.cloudKitManager = cloudKitManager
        self.healthKitService = healthKitService ?? RealHealthKitService()
    }
    
    /// Start monitoring workouts using HKAnchoredObjectQuery for reliable incremental updates
    func startReliableSync() {
        FameFitLogger.info("🏃 Starting WorkoutSyncManager reliable sync", category: FameFitLogger.workout)
        
        guard healthKitService.isHealthDataAvailable else {
            FameFitLogger.error("HealthKit not available", category: FameFitLogger.workout)
            DispatchQueue.main.async {
                self.syncError = .healthKitNotAvailable
            }
            return
        }
        
        // Check if we have authorization
        let workoutType = HKObjectType.workoutType()
        let authStatus = healthKitService.authorizationStatus(for: workoutType)
        
        if authStatus == .notDetermined {
            FameFitLogger.info("🔐 HealthKit authorization not determined, requesting...", category: FameFitLogger.workout)
            healthKitService.requestAuthorization { [weak self] success, error in
                if success {
                    FameFitLogger.info("✅ HealthKit authorization granted", category: FameFitLogger.workout)
                    self?.startReliableSync() // Retry after authorization
                } else {
                    FameFitLogger.error("❌ HealthKit authorization failed", error: error, category: FameFitLogger.workout)
                    DispatchQueue.main.async {
                        self?.syncError = .healthKitAuthorizationDenied
                    }
                }
            }
            return
        } else if authStatus != .sharingAuthorized {
            FameFitLogger.error("❌ HealthKit not authorized (status: \(authStatus.rawValue))", category: FameFitLogger.workout)
            DispatchQueue.main.async {
                self.syncError = .healthKitAuthorizationDenied
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
        
        // Create and execute the anchored object query using the service
        anchoredQuery = healthKitService.executeAnchoredQuery(
            anchor: anchor,
            initialHandler: { [weak self] query, samples, deletedObjects, newAnchor, error in
                self?.handleInitialResults(
                    samples: samples,
                    deletedObjects: deletedObjects,
                    anchor: newAnchor,
                    error: error
                )
            },
            updateHandler: { [weak self] query, samples, deletedObjects, newAnchor, error in
                self?.handleIncrementalResults(
                    samples: samples,
                    deletedObjects: deletedObjects,
                    anchor: newAnchor,
                    error: error
                )
            }
        )
        
        FameFitLogger.info("Started reliable workout sync with HKAnchoredObjectQuery", category: FameFitLogger.workout)
    }
    
    /// Stop monitoring workouts
    func stopSync() {
        if let query = anchoredQuery {
            healthKitService.stop(query)
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
        
        FameFitLogger.info("🏋️ Initial sync found \(workouts.count) workouts", category: FameFitLogger.workout)
        
        // Log details about each workout found
        for workout in workouts {
            let duration = Int(workout.duration / 60)
            FameFitLogger.info("📊 Found workout: \(workout.workoutActivityType.name) - Duration: \(duration) min - Date: \(workout.endDate)", category: FameFitLogger.workout)
        }
        
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
        
        FameFitLogger.info("🆕 Incremental sync found \(workouts.count) new workout(s)", category: FameFitLogger.workout)
        
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
        
        FameFitLogger.info("📅 App install date: \(appInstallDate)", category: FameFitLogger.workout)
        FameFitLogger.info("📅 Current date: \(Date())", category: FameFitLogger.workout)
        
        var workoutHistoryItems: [WorkoutHistoryItem] = []
        
        for workout in workouts {
            // Skip workouts before app install
            guard workout.endDate > appInstallDate else {
                FameFitLogger.info("⏭️ Skipping pre-install workout: \(workout.workoutActivityType.name) - Date: \(workout.endDate)", category: FameFitLogger.workout)
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
            FameFitLogger.info("🔄 Processing workout: \(workout.workoutActivityType.name) - Duration: \(Int(duration)) min - Date: \(workout.endDate)", category: FameFitLogger.workout)
            FameFitLogger.info("📍 Workout source: \(workout.sourceRevision.source.name) - Bundle: \(workout.sourceRevision.source.bundleIdentifier)", category: FameFitLogger.workout)
            
            // Calculate XP for this workout
            let calculatedXP = XPCalculator.calculateXP(
                for: WorkoutHistoryItem(from: workout, followersEarned: 0, xpEarned: 0),
                currentStreak: cloudKitManager?.currentStreak ?? 0
            )
            
            // Check for special bonuses
            let workoutNumber = cloudKitManager?.totalWorkouts ?? 0 + 1
            let specialBonus = XPCalculator.calculateSpecialBonus(
                workoutNumber: workoutNumber,
                isPersonalRecord: false // TODO: Implement PR detection
            )
            
            let totalXP = calculatedXP + specialBonus
            
            FameFitLogger.info("🎯 Calculated XP: \(calculatedXP) + bonus: \(specialBonus) = \(totalXP) total", category: FameFitLogger.workout)
            
            // Create workout history item with calculated XP
            let historyItem = WorkoutHistoryItem(from: workout, followersEarned: totalXP, xpEarned: totalXP)
            workoutHistoryItems.append(historyItem)
            
            // For initial sync, we might want to batch process
            // For incremental updates, process immediately
            if !isInitialSync {
                // Add XP for the workout
                cloudKitManager?.addXP(totalXP)
                
                // Save workout history to CloudKit
                FameFitLogger.info("💾 Saving workout to CloudKit: \(historyItem.workoutType) with \(totalXP) XP", category: FameFitLogger.workout)
                cloudKitManager?.saveWorkoutHistory(historyItem)
                
                // Send notification
                sendWorkoutNotification(for: workout)
            }
        }
        
        // For initial sync, we might want to calculate total followers differently
        if isInitialSync && !workouts.isEmpty {
            FameFitLogger.info("Initial sync complete. Found \(workouts.count) workouts since install", category: FameFitLogger.workout)
            // Batch save workout history for initial sync
            for historyItem in workoutHistoryItems {
                cloudKitManager?.saveWorkoutHistory(historyItem)
            }
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
        
        // Fallback for test workouts - use statistics API
        if calories == 0 {
            // Try active energy burned statistics one more time with a different approach
            if let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
               let statistics = workout.statistics(for: energyBurnedType),
               let sumQuantity = statistics.sumQuantity() {
                calories = Int(sumQuantity.doubleValue(for: .kilocalorie()))
            }
        }
        
        let title = "\(character.emoji) \(character.fullName)"
        
        // Calculate XP for notification
        let calculatedXP = XPCalculator.calculateXP(
            for: WorkoutHistoryItem(from: workout, followersEarned: 0, xpEarned: 0),
            currentStreak: cloudKitManager?.currentStreak ?? 0
        )
        
        let body = character.workoutCompletionMessage(followers: calculatedXP)
        
        // Add to notification store
        let notificationItem = NotificationItem(
            title: title,
            body: body,
            character: character,
            workoutDuration: duration,
            calories: calories,
            followersEarned: calculatedXP
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.notificationStore?.addNotification(notificationItem)
        }
        
        // Also send push notification
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: notificationStore?.unreadCount ?? 0)
        
        content.userInfo = [
            "character": character.rawValue,
            "duration": duration,
            "calories": calories,
            "newFollowers": 5
        ]
        
        // Use workout-specific identifier to prevent duplicates
        let notificationId = "workout-\(character.rawValue)-\(workout.endDate.timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                FameFitLogger.error("Failed to send notification", error: error, category: FameFitLogger.workout)
            } else {
                FameFitLogger.debug("Push notification sent successfully", category: FameFitLogger.workout)
            }
        }
    }
}