//
//  WorkoutSyncService.swift
//  FameFit
//
//  Manages reliable workout synchronization using HKAnchoredObjectQuery
//  This is the SINGLE source of truth for HealthKit workout syncing
//

import Foundation
import HealthKit
import CloudKit
import os.log
import UserNotifications
import Combine

/// Key for storing the sync anchor in UserDefaults
private let kWorkoutSyncAnchorKey = "FameFitWorkoutSyncAnchor"

/// Manages workout synchronization with HealthKit using anchored queries for reliability
/// This service handles ALL workout syncing - there should be no other workout observers
@MainActor
class WorkoutSyncService: ObservableObject {
    // MARK: - Properties
    
    private let healthKitService: HealthKitProtocol
    private weak var cloudKitManager: CloudKitService?
    weak var notificationStore: (any NotificationStoringProtocol)?
    weak var notificationManager: (any NotificationProtocol)?
    weak var workoutProcessor: WorkoutProcessor?
    private var anchoredQuery: HKAnchoredObjectQuery?
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: FameFitError?
    @Published var isAuthorized = false
    
    // Publisher for workout completion events (for sharing prompt)
    private let workoutCompletedSubject = PassthroughSubject<Workout, Never>()
    var workoutCompletedPublisher: AnyPublisher<Workout, Never> {
        workoutCompletedSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init(cloudKitManager: CloudKitService, healthKitService: HealthKitProtocol) {
        self.cloudKitManager = cloudKitManager
        self.healthKitService = healthKitService
        
        // Listen for Watch workout completions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchWorkoutCompletion),
            name: Notification.Name("WatchWorkoutCompleted"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
    
    @objc private func handleWatchWorkoutCompletion(_ notification: Notification) {
        guard let workoutID = notification.userInfo?["workoutID"] as? String else { return }
        
        FameFitLogger.info("📱 Received Watch workout completion: \(workoutID), triggering immediate sync", category: FameFitLogger.workout)
        
        // Trigger immediate sync
        Task {
            await performManualSync()
        }
    }
    
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
    
    /// Process workouts using WorkoutProcessor for consistent handling
    private func processWorkouts(_ workouts: [HKWorkout]) async {
        guard workoutProcessor != nil else {
            FameFitLogger.error("WorkoutProcessor not available - falling back to basic save", category: FameFitLogger.workout)
            // Fall back to basic CloudKit save if processor not available
            await processWorkoutsBasic(workouts)
            return
        }
        
        var processedCount = 0
        var failedWorkouts: [(workout: HKWorkout, error: Error)] = []
        
        // Process workouts with controlled concurrency
        await withTaskGroup(of: ProcessResult.self) { group in
            let maxConcurrent = 3
            var activeCount = 0
            
            for workout in workouts {
                // Skip future workouts (sometimes happens with manual entries)
                guard workout.endDate <= Date() else {
                    FameFitLogger.warning("Skipping future workout", category: FameFitLogger.workout)
                    continue
                }
                
                // Get app install date
                let appInstallDate = UserDefaults.standard.object(forKey: "AppInstallDate") as? Date ?? Date()
                
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
                
                // Wait if we've hit concurrency limit
                if activeCount >= maxConcurrent {
                    if let result = await group.next() {
                        handleProcessResult(result, &processedCount, &failedWorkouts)
                        activeCount -= 1
                    }
                }
                
                group.addTask {
                    await self.processWorkout(workout)
                }
                activeCount += 1
            }
            
            // Collect remaining results
            for await result in group {
                handleProcessResult(result, &processedCount, &failedWorkouts)
            }
        }
        
        // Handle failed workouts
        for (workout, error) in failedWorkouts {
            if let ckError = error as? CKError, ckError.isRetryable {
                await queueWorkoutForRetry(workout)
            }
        }
        
        if processedCount > 0 {
            FameFitLogger.info("✅ Processed \(processedCount) new workout(s) via WorkoutProcessor", category: FameFitLogger.workout)
        }
        
        if !failedWorkouts.isEmpty {
            FameFitLogger.warning("⚠️ \(failedWorkouts.count) workout(s) failed and queued for retry", category: FameFitLogger.workout)
        }
    }
    
    private struct ProcessResult {
        let workout: HKWorkout
        let success: Bool
        let error: Error?
    }
    
    private func processWorkout(_ workout: HKWorkout) async -> ProcessResult {
        do {
            // Use WorkoutProcessor for ALL business logic
            // This handles: XP calculation, CloudKit save, activity feed, challenges, notifications
            try await workoutProcessor?.processHealthKitWorkout(workout)
            
            // Mark as synced AFTER successful processing
            markWorkoutAsSynced(workout)
            
            // Publish workout completion for sharing prompt (only for recent workouts)
            let workoutAge = Date().timeIntervalSince(workout.endDate)
            if workoutAge < 3_600 { // Only prompt for workouts completed within the last hour
                let workoutItem = Workout(from: workout, followersEarned: 0)
                await MainActor.run {
                    self.workoutCompletedSubject.send(workoutItem)
                }
            }
            
            return ProcessResult(workout: workout, success: true, error: nil)
        } catch {
            FameFitLogger.error("Failed to process workout \(workout.uuid)", error: error, category: FameFitLogger.workout)
            return ProcessResult(workout: workout, success: false, error: error)
        }
    }
    
    private func handleProcessResult(
        _ result: ProcessResult,
        _ processedCount: inout Int,
        _ failedWorkouts: inout [(workout: HKWorkout, error: Error)]
    ) {
        if result.success {
            processedCount += 1
        } else if let error = result.error {
            failedWorkouts.append((workout: result.workout, error: error))
        }
    }
    
    private func queueWorkoutForRetry(_ workout: HKWorkout) async {
        guard let cloudKitManager = cloudKitManager else { return }
        
        let workoutItem = Workout(from: workout, followersEarned: 0)
        if let data = try? JSONEncoder().encode(workoutItem) {
            await cloudKitManager.queueForRetry(
                type: .workoutSave,
                data: data,
                priority: .high
            )
            FameFitLogger.info("📋 Queued workout \(workout.uuid) for background retry", category: FameFitLogger.workout)
        }
    }
    
    /// Fallback method for basic workout saving when WorkoutProcessor is not available
    private func processWorkoutsBasic(_ workouts: [HKWorkout]) async {
        guard let cloudKitManager = cloudKitManager else {
            FameFitLogger.error("CloudKitService not available", category: FameFitLogger.workout)
            return
        }
        
        for workout in workouts {
            // Skip checks (same as above)
            guard workout.endDate <= Date() else { continue }
            let appInstallDate = UserDefaults.standard.object(forKey: "AppInstallDate") as? Date ?? Date()
            guard workout.endDate >= appInstallDate else { continue }
            if isWorkoutAlreadySynced(workout) { continue }
            
            // Basic save with fixed XP
            let workoutItem = Workout(from: workout, followersEarned: 10)
            cloudKitManager.saveWorkout(workoutItem)
            markWorkoutAsSynced(workout)
            
            FameFitLogger.info("💾 Saved workout via basic fallback: \(workout.uuid)", category: FameFitLogger.workout)
        }
    }
    
    /// Check if a workout has already been synced
    private func isWorkoutAlreadySynced(_ workout: HKWorkout) -> Bool {
        let syncedWorkoutIDs = UserDefaults.standard.array(forKey: "SyncedWorkoutIDs") as? [String] ?? []
        return syncedWorkoutIDs.contains(workout.uuid.uuidString)
    }
    
    /// Mark a workout as synced to prevent duplicate processing
    private func markWorkoutAsSynced(_ workout: HKWorkout) {
        var syncedIDs = UserDefaults.standard.array(forKey: "SyncedWorkoutIDs") as? [String] ?? []
        syncedIDs.append(workout.uuid.uuidString)
        
        // Keep only last 1000 IDs to prevent unbounded growth
        if syncedIDs.count > 1_000 {
            syncedIDs = Array(syncedIDs.suffix(1_000))
        }
        
        UserDefaults.standard.set(syncedIDs, forKey: "SyncedWorkoutIDs")
        FameFitLogger.debug("Marked workout as synced: \(workout.uuid.uuidString)", category: FameFitLogger.workout)
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
    
    /// Check HealthKit authorization status (from WorkoutObserver)
    func checkHealthKitAuthorization() -> Bool {
        guard healthKitService.isHealthDataAvailable else {
            return false
        }
        
        // We can't actually check if we have READ permission for HealthKit
        // Apple doesn't allow this for privacy reasons
        // Return the isAuthorized state we track
        return isAuthorized
    }
    
    /// Request HealthKit authorization with comprehensive permissions
    func requestHealthKitAuthorization(completion: @escaping (Bool, FameFitError?) -> Void) {
        guard healthKitService.isHealthDataAvailable else {
            DispatchQueue.main.async {
                self.syncError = .healthKitNotAvailable
                completion(false, .healthKitNotAvailable)
            }
            return
        }

        var typesToRead: Set<HKObjectType> = [.workoutType()]

        if let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            typesToRead.insert(activeEnergyType)
        }
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            typesToRead.insert(heartRateType)
        }
        if let walkingRunningType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            typesToRead.insert(walkingRunningType)
        }
        if let cyclingType = HKObjectType.quantityType(forIdentifier: .distanceCycling) {
            typesToRead.insert(cyclingType)
        }

        healthKitService.requestAuthorization { [weak self] success, error in
            DispatchQueue.main.async {
                if let error {
                    self?.syncError = error.fameFitError
                    completion(false, error.fameFitError)
                } else if !success {
                    self?.syncError = .healthKitAuthorizationDenied
                    completion(false, .healthKitAuthorizationDenied)
                } else {
                    // We can't know for sure if READ permission was granted
                    // but the request completed successfully
                    self?.isAuthorized = true
                    self?.syncError = nil
                    completion(true, nil)
                    // Don't automatically start observing - let onboarding control this
                }
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
