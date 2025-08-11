//
//  WorkoutSyncService.swift
//  FameFit
//
//  Manages reliable workout synchronization using HKAnchoredObjectQuery
//

import Foundation
import HealthKit
import CloudKit
import os.log
import UserNotifications

/// Key for storing the sync anchor in UserDefaults
private let kWorkoutSyncAnchorKey = "FameFitWorkoutSyncAnchor"

/// Manages workout synchronization with HealthKit using anchored queries for reliability
@MainActor
class WorkoutSyncService: ObservableObject {
    // MARK: - Properties
    
    private let healthKitService: HealthKitProtocol
    private weak var cloudKitManager: CloudKitService?
    weak var notificationStore: (any NotificationStoringProtocol)?
    weak var notificationManager: (any NotificationProtocol)?
    private var anchoredQuery: HKAnchoredObjectQuery?
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: FameFitError?
    
    // MARK: - Initialization
    
    init(cloudKitManager: CloudKitService, healthKitService: HealthKitProtocol) {
        self.cloudKitManager = cloudKitManager
        self.healthKitService = healthKitService
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring workouts using HKAnchoredObjectQuery for reliable incremental updates
    func startReliableSync() {
        FameFitLogger.info("🏃 Starting WorkoutSyncService reliable sync", category: FameFitLogger.workout)
        
        // Request notification permissions
        requestNotificationPermissions()
        
        Task {
            await startReliableSyncAsync()
        }
    }
    
    /// Stop monitoring workouts
    func stopSync() {
        if let query = anchoredQuery {
            healthKitService.stop(query)
            anchoredQuery = nil
            FameFitLogger.info("Stopped workout sync", category: FameFitLogger.workout)
        }
    }
    
    /// Force a manual sync
    func performManualSync() async {
        FameFitLogger.info("Performing manual workout sync", category: FameFitLogger.workout)
        
        isSyncing = true
        syncError = nil
        
        do {
            // Get recent workouts
            let workouts = try await fetchRecentWorkouts()
            
            if !workouts.isEmpty {
                FameFitLogger.info("Found \(workouts.count) workouts to sync", category: FameFitLogger.workout)
                await processWorkouts(workouts)
            } else {
                FameFitLogger.info("No new workouts to sync", category: FameFitLogger.workout)
            }
            
            lastSyncDate = Date()
            isSyncing = false
        } catch {
            FameFitLogger.error("Manual sync failed", error: error, category: FameFitLogger.workout)
            syncError = error.fameFitError
            isSyncing = false
        }
    }
    
    // MARK: - Private Methods
    
    private func startReliableSyncAsync() async {
        guard healthKitService.isHealthDataAvailable else {
            FameFitLogger.error("HealthKit not available", category: FameFitLogger.workout)
            syncError = .healthKitNotAvailable
            return
        }
        
        // Check if we have authorization
        let workoutType = HKObjectType.workoutType()
        let authStatus = healthKitService.authorizationStatus(for: workoutType)
        
        switch authStatus {
        case .notDetermined:
            FameFitLogger.info("🔐 HealthKit authorization not determined, requesting...", category: FameFitLogger.workout)
            
            do {
                let success = try await requestHealthKitAuthorization()
                if success {
                    FameFitLogger.info("✅ HealthKit authorization granted", category: FameFitLogger.workout)
                    await startReliableSyncAsync() // Retry after authorization
                } else {
                    FameFitLogger.error("❌ HealthKit authorization denied", category: FameFitLogger.workout)
                    syncError = .healthKitAuthorizationDenied
                }
            } catch {
                FameFitLogger.error("❌ HealthKit authorization failed", error: error, category: FameFitLogger.workout)
                syncError = .healthKitAuthorizationDenied
            }
            
        case .sharingAuthorized:
            // We have authorization, proceed with sync
            await setupAnchoredQuery()
            
        default:
            // Only log as error if user has completed onboarding
            // During onboarding, this is expected
            if authStatus == .notDetermined {
                FameFitLogger.info("HealthKit authorization not determined yet", category: FameFitLogger.workout)
            } else {
                FameFitLogger.error("❌ HealthKit not authorized (status: \(authStatus.rawValue))", category: FameFitLogger.workout)
            }
            syncError = .healthKitAuthorizationDenied
        }
    }
    
    private func requestHealthKitAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            healthKitService.requestAuthorization { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    private func setupAnchoredQuery() async {
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
            initialHandler: { [weak self] _, samples, deletedObjects, newAnchor, error in
                Task { @MainActor [weak self] in
                    await self?.handleInitialResults(
                        samples: samples,
                        deletedObjects: deletedObjects,
                        anchor: newAnchor,
                        error: error
                    )
                }
            },
            updateHandler: { [weak self] _, samples, deletedObjects, newAnchor, error in
                Task { @MainActor [weak self] in
                    await self?.handleIncrementalResults(
                        samples: samples,
                        deletedObjects: deletedObjects,
                        anchor: newAnchor,
                        error: error
                    )
                }
            }
        )
        
        FameFitLogger.info("Started reliable workout sync with HKAnchoredObjectQuery", category: FameFitLogger.workout)
    }
    
    /// Handle initial query results
    private func handleInitialResults(
        samples: [HKSample]?,
        deletedObjects _: [HKDeletedObject]?,
        anchor: HKQueryAnchor?,
        error: Error?
    ) async {
        isSyncing = true
        
        if let error {
            FameFitLogger.error("Initial sync error", error: error, category: FameFitLogger.workout)
            syncError = error.fameFitError
            isSyncing = false
            return
        }
        
        guard let workouts = samples as? [HKWorkout] else {
            isSyncing = false
            return
        }
        
        FameFitLogger.info("🏋️ Initial sync found \(workouts.count) workouts", category: FameFitLogger.workout)
        
        // Process workouts
        await processWorkouts(workouts)
        
        // Save the anchor
        if let anchor {
            saveAnchor(anchor)
        }
        
        lastSyncDate = Date()
        isSyncing = false
    }
    
    /// Handle incremental updates from the anchored query
    private func handleIncrementalResults(
        samples: [HKSample]?,
        deletedObjects _: [HKDeletedObject]?,
        anchor: HKQueryAnchor?,
        error: Error?
    ) async {
        if let error {
            FameFitLogger.error("Incremental sync error", error: error, category: FameFitLogger.workout)
            syncError = error.fameFitError
            return
        }
        
        guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
            return
        }
        
        FameFitLogger.info("🔄 Incremental sync found \(workouts.count) new workout(s)", category: FameFitLogger.workout)
        
        isSyncing = true
        
        // Process new workouts
        await processWorkouts(workouts)
        
        // Save the new anchor
        if let anchor {
            saveAnchor(anchor)
        }
        
        lastSyncDate = Date()
        isSyncing = false
    }
    
    /// Process workouts by saving to CloudKit and updating user stats
    private func processWorkouts(_ workouts: [HKWorkout]) async {
        guard let cloudKitManager = cloudKitManager else {
            FameFitLogger.error("CloudKitService not available", category: FameFitLogger.workout)
            return
        }
        
        var processedCount = 0
        
        for workout in workouts {
            // Skip future workouts (sometimes happens with manual entries)
            guard workout.endDate <= Date() else {
                FameFitLogger.warning("Skipping future workout", category: FameFitLogger.workout)
                continue
            }
            
            // Get app install date
            let appInstallDate = UserDefaults.standard.object(forKey: "AppInstallDate") as? Date ?? Date()
            
            FameFitLogger.info("📅 App install date: \(appInstallDate)", category: FameFitLogger.workout)
            FameFitLogger.info("📅 Current date: \(Date())", category: FameFitLogger.workout)
            
            // Only process workouts after app install
            guard workout.endDate >= appInstallDate else {
                FameFitLogger.info(
                    "⏩ Skipping pre-install workout from \(workout.endDate)",
                    category: FameFitLogger.workout
                )
                continue
            }
            
            // Check if workout already synced
            if isWorkoutAlreadySynced(workout) {
                FameFitLogger.debug("Workout already synced: \(workout.uuid)", category: FameFitLogger.workout)
                continue
            }
            
            // Calculate followers/XP earned (10 XP per workout)
            let xpEarned = 10
            
            // Save workout to CloudKit
            if await saveWorkoutToCloudKit(workout, xpEarned: xpEarned) {
                processedCount += 1
                
                // Add XP to user's total
                await cloudKitManager.addXPAsync(xpEarned)
                
                // Send local notification for XP milestone
                if let notificationManager = notificationManager {
                    await notificationManager.notifyXPMilestone(previousXP: cloudKitManager.totalXP - xpEarned, currentXP: cloudKitManager.totalXP)
                }
            }
        }
        
        if processedCount > 0 {
            FameFitLogger.info("✅ Processed \(processedCount) new workout(s)", category: FameFitLogger.workout)
        }
    }
    
    /// Check if a workout has already been synced
    private func isWorkoutAlreadySynced(_ workout: HKWorkout) -> Bool {
        let syncedWorkoutIDs = UserDefaults.standard.array(forKey: "SyncedWorkoutIDs") as? [String] ?? []
        return syncedWorkoutIDs.contains(workout.uuid.uuidString)
    }
    
    /// Save workout to CloudKit
    private func saveWorkoutToCloudKit(_ workout: HKWorkout, xpEarned: Int) async -> Bool {
        guard let cloudKitManager = cloudKitManager else { return false }
        
        do {
            // Create workout record
            let record = CKRecord(recordType: "Workouts")
            record["id"] = workout.uuid.uuidString
            record["workoutType"] = workout.workoutActivityType.storageKey
            record["startDate"] = workout.startDate
            record["endDate"] = workout.endDate
            record["duration"] = workout.duration
            let energyBurnedQuantity = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()
            record["totalEnergyBurned"] = energyBurnedQuantity?.doubleValue(for: .kilocalorie()) ?? 0
            record["totalDistance"] = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
            record["averageHeartRate"] = 0 // Would need to fetch from samples
            record["followersEarned"] = xpEarned // Legacy field
            record["xpEarned"] = xpEarned
            record["source"] = workout.sourceRevision.source.name
            
            // Save to CloudKit
            _ = try await cloudKitManager.save(record)
            
            // Mark as synced
            var syncedIDs = UserDefaults.standard.array(forKey: "SyncedWorkoutIDs") as? [String] ?? []
            syncedIDs.append(workout.uuid.uuidString)
            
            // Keep only last 1000 IDs to prevent unbounded growth
            if syncedIDs.count > 1_000 {
                syncedIDs = Array(syncedIDs.suffix(1_000))
            }
            
            UserDefaults.standard.set(syncedIDs, forKey: "SyncedWorkoutIDs")
            
            FameFitLogger.info(
                "💾 Saved workout: \(workout.workoutActivityType.storageKey) +\(xpEarned) XP",
                category: FameFitLogger.workout
            )
            
            return true
        } catch {
            FameFitLogger.error("Failed to save workout to CloudKit", error: error, category: FameFitLogger.workout)
            return false
        }
    }
    
    /// Save anchor to UserDefaults
    private func saveAnchor(_ anchor: HKQueryAnchor) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: kWorkoutSyncAnchorKey)
            FameFitLogger.debug("Saved sync anchor", category: FameFitLogger.workout)
        } catch {
            FameFitLogger.error("Failed to save sync anchor", error: error, category: FameFitLogger.workout)
        }
    }
    
    /// Fetch recent workouts (for manual sync)
    private func fetchRecentWorkouts() async throws -> [HKWorkout] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            healthKitService.fetchWorkoutsWithPredicate(
                predicate,
                limit: 100,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let workouts = (samples as? [HKWorkout]) ?? []
                    continuation.resume(returning: workouts)
                }
            }
        }
    }
    
    /// Request notification permissions
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if granted {
                        FameFitLogger.info("Notification permissions granted", category: FameFitLogger.notifications)
                    } else if let error {
                        FameFitLogger.error("Notification permissions error", error: error, category: FameFitLogger.notifications)
                    }
                }
            } else if settings.authorizationStatus == .authorized {
                FameFitLogger.info("Notification permissions already granted", category: FameFitLogger.notifications)
            }
        }
    }
}

// MARK: - CloudKit Extensions

private extension CKRecord {
    convenience init(recordType: String) {
        self.init(recordType: recordType, recordID: CKRecord.ID(recordName: UUID().uuidString))
    }
}
