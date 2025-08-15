//
//  CloudKitService.swift
//  FameFit
//
//  Modern CloudKit manager using async/await and actors
//

import AuthenticationServices
import CloudKit
import Combine
import Foundation
import HealthKit
import os.log

final class CloudKitService: NSObject, ObservableObject, CloudKitProtocol {
    // MARK: - Properties
    
    let container = CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
    private let stateManager = CloudKitStateManager()
    private let operationQueue = CloudKitOperationQueue()
    private let schemaManager: CloudKitSchemaService
    private let retryExecutor = CloudKitRetryExecutor()
    private let retryQueue = Queue()
    
    // Recalculation tracking
    private let recalculationIntervalKey = "FameFitLastStatsRecalculation"
    private let recalculationInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // MARK: - Published Properties
    
    @Published var isSignedIn = false
    // @Published var userRecord: CKRecord? // DEPRECATED - We use UserProfile records now
    @Published var totalXP: Int = 0
    @Published var username: String = ""
    @Published var currentStreak: Int = 0
    @Published var totalWorkouts: Int = 0
    @Published var lastWorkoutTimestamp: Date?
    @Published var lastError: FameFitError?
    @Published private(set) var isInitialized = false
    @Published private(set) var currentUserRecordID: String?
    
    // Single initialization task to prevent race conditions
    private var initializationTask: Task<Void, Error>?
    
    // Services
    weak var authenticationManager: AuthenticationService?
    weak var unlockNotificationService: UnlockNotificationProtocol?
    var xpTransactionService: XPTransactionService?
    var statsSyncService: StatsSyncProtocol?
    
    // Computed properties for compatibility
    var isAvailable: Bool { isSignedIn }
    var currentUserID: String? { currentUserRecordID }
    var currentUserXP: Int { totalXP }
    
    // Databases
    var privateDatabase: CKDatabase { container.privateCloudDatabase }
    var publicDatabase: CKDatabase { container.publicCloudDatabase }
    var database: CKDatabase { privateDatabase } // Default for compatibility
    
    // MARK: - Publisher Properties
    
    var isAvailablePublisher: AnyPublisher<Bool, Never> {
        $isSignedIn.eraseToAnyPublisher()
    }
    
    var totalXPPublisher: AnyPublisher<Int, Never> {
        $totalXP.eraseToAnyPublisher()
    }
    
    var lastErrorPublisher: AnyPublisher<FameFitError?, Never> {
        $lastError.eraseToAnyPublisher()
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    override init() {
        self.schemaManager = CloudKitSchemaService(container: container)
        super.init()
        
    }
    
    
    /// Start CloudKit initialization (should be called after DependencyContainer is ready)
    func startInitialization() {
        Task {
            await initialize()
        }
    }
    
    // MARK: - Public Methods
    
    /// Initialize CloudKit and set up account monitoring
    private func initialize() async {
        // Set up account change notifications
        setupAccountChangeNotifications()
        
        // Check initial account status
        await checkAccountStatusAsync()
        
        // Initialize if account is available
        if isSignedIn {
            let currentState = await stateManager.getInitializationState()
            if case .completed = currentState {
                await MainActor.run {
                    self.isInitialized = true
                }
                FameFitLogger.debug("CloudKit already initialized", category: FameFitLogger.cloudKit)
            } else if case .inProgress = currentState {
                FameFitLogger.debug("CloudKit initialization already in progress", category: FameFitLogger.cloudKit)
            } else {
                FameFitLogger.info("Initializing CloudKit manager", category: FameFitLogger.cloudKit)
                await performInitialization()
            }
        }
    }
    
    /// Check account status (protocol requirement)
    func checkAccountStatus() {
        Task {
            await checkAccountStatusAsync()
        }
    }
    
    /// Check account status async
    private func checkAccountStatusAsync() async {
        guard await stateManager.shouldCheckAccountStatus() else {
            return
        }
        
        do {
            let status = try await container.accountStatus()
            await stateManager.updateAccountStatus(status)
            
            await MainActor.run {
                self.isSignedIn = (status == .available)
                
                if !self.isSignedIn {
                    self.lastError = .cloudKitNotAvailable
                }
            }
            
            FameFitLogger.info("CloudKit account status: \(String(describing: status))", category: FameFitLogger.cloudKit)
            
            // Initialize if newly available
            if status == .available && !isInitialized {
                await ensureInitialized()
            }
        } catch {
            FameFitLogger.error("Failed to check account status", error: error, category: FameFitLogger.cloudKit)
            await MainActor.run {
                self.isSignedIn = false
                self.lastError = error.fameFitError
            }
        }
    }
    
    /// Add followers (legacy method)
    func addFollowers(_ count: Int = 5) {
        Task {
            await addXPAsync(count)
        }
    }
    
    /// Add XP to user's total
    func addXP(_ xp: Int) {
        Task {
            await addXPAsync(xp)
        }
    }
    
    /// Complete a workout - increments both XP and workout count
    func completeWorkout(xpEarned: Int) async {
        FameFitLogger.info("Completing workout with \(xpEarned) XP", category: FameFitLogger.cloudKit)
        
        // We no longer use the legacy Users record - just update local state and sync to UserProfile
        let newTotalXP = totalXP + xpEarned
        let newTotalWorkouts = totalWorkouts + 1
        
        // Update local state immediately
        await MainActor.run {
            self.totalXP = newTotalXP
            self.totalWorkouts = newTotalWorkouts
        }
        
        FameFitLogger.info("Successfully completed workout: +\(xpEarned) XP, workout #\(newTotalWorkouts)", category: FameFitLogger.cloudKit)
        
        // Sync updated stats to UserProfiles (the real source of truth)
        await syncStatsToUserProfile(totalWorkouts: newTotalWorkouts, totalXP: newTotalXP)
        
        // Track XP transaction
        await trackXPTransaction(xp: xpEarned)
    }
    
    func addXPAsync(_ xp: Int) async {
        FameFitLogger.info("Adding \(xp) XP", category: FameFitLogger.cloudKit)
        
        // We no longer use the legacy Users record - just update local state and sync to UserProfile
        let newTotalXP = totalXP + xp
        
        // Update local state immediately
        await MainActor.run {
            self.totalXP = newTotalXP
        }
        
        FameFitLogger.info("Successfully added \(xp) XP, new total: \(newTotalXP)", category: FameFitLogger.cloudKit)
        
        // Sync updated XP to UserProfiles (keep workout count as-is)
        await syncStatsToUserProfile(totalWorkouts: totalWorkouts, totalXP: newTotalXP)
        
        // Track XP transaction
        await trackXPTransaction(xp: xp)
    }
    
    // MARK: - Fetch Methods
    
    func fetchUserRecord() {
        Task {
            await fetchUserRecordAsync()
        }
    }
    
    private func fetchUserRecordAsync() async {
        guard await stateManager.startOperation(.userRecordFetch) else {
            return
        }
        
        defer {
            Task {
                await stateManager.completeOperation(.userRecordFetch)
            }
        }
        
        do {
            // We no longer use the legacy Users record system
            // Just get the CloudKit user ID and cache it
            let actualUserID = try await container.userRecordID().recordName
            
            // Store the user ID
            await MainActor.run {
                self.currentUserRecordID = actualUserID // Store the actual CloudKit user ID
                // Post notification from main thread
                NotificationCenter.default.post(name: Notification.Name("CloudKitUserIDAvailable"), object: nil)
            }
            
            FameFitLogger.info("Successfully obtained CloudKit user ID: \(actualUserID)", category: FameFitLogger.cloudKit)
        } catch {
            FameFitLogger.error("Failed to get CloudKit user ID", error: error, category: FameFitLogger.cloudKit)
            
            if await stateManager.shouldRetryOperation(.userRecordFetch, error: error) {
                let delay = await stateManager.getRetryDelay(for: .userRecordFetch)
                
                Task {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    await fetchUserRecordAsync()
                }
            } else {
                await MainActor.run {
                    lastError = error.fameFitError
                }
            }
        }
    }
    
    // MARK: - Account Deletion Support
    
    /// Clear all local caches after account deletion
    func clearAllCaches() async {
        await MainActor.run {
            // Clear CloudKit state
            self.currentUserRecordID = nil
            self.totalXP = 0
            self.username = ""
            self.currentStreak = 0
            self.totalWorkouts = 0
            self.lastWorkoutTimestamp = nil
            self.isInitialized = false
            
            // Clear initialization task
            self.initializationTask = nil
        }
        
        FameFitLogger.info("Cleared all CloudKit caches", category: FameFitLogger.cloudKit)
    }
    
    // MARK: - CloudKit Operations
    
    func save(_ record: CKRecord) async throws -> CKRecord {
        return try await operationQueue.enqueueSave(
            record: record,
            database: publicDatabase, // All user data now in public database via UserProfile
            priority: .medium
        )
    }
    
    func fetchRecords(ofType recordType: String, predicate: NSPredicate, sortDescriptors: [NSSortDescriptor]?, limit: Int) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        if let sortDescriptors = sortDescriptors {
            query.sortDescriptors = sortDescriptors
        }
        
        return try await operationQueue.enqueueQuery(
            query: query,
            database: publicDatabase,
            limit: limit,
            priority: .medium
        )
    }
    
    func delete(withRecordID recordID: CKRecord.ID) async throws {
        await operationQueue.enqueue(
            priority: .medium,
            description: "Delete record \(recordID.recordName)"
        ) {
            _ = try await self.publicDatabase.deleteRecord(withID: recordID)
        }
    }
    
    func deleteRecords(withIDs recordIDs: [CKRecord.ID]) async throws {
        await operationQueue.enqueue(
            priority: .medium,
            description: "Delete \(recordIDs.count) records"
        ) {
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
            self.publicDatabase.add(operation)
        }
    }
    
    func getCurrentUserID() async throws -> String {
        if let currentUserID = currentUserID {
            return currentUserID
        }
        
        let recordID = try await container.userRecordID()
        let recordName = recordID.recordName
        
        // Cache the user record ID for future use
        await MainActor.run {
            self.currentUserRecordID = recordName
        }
        
        return recordName
    }
    
    // DEPRECATED: We no longer use the legacy Users record system
    // All user data is now stored in UserProfile records
    /*
    /// Get or create the Users record for the current user
    func getCurrentUser() async throws -> CKRecord {
        // This method is deprecated - we use UserProfile records exclusively
        throw FameFitError.deprecated("Users record system is deprecated. Use UserProfile instead.")
    }
    */
    
    // MARK: - Private Methods
    
    private func setupAccountChangeNotifications() {
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.checkAccountStatusAsync()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Ensures CloudKit is initialized, using a single shared task to prevent race conditions
    private func ensureInitialized() async {
        // If already initialized, return immediately
        if isInitialized {
            return
        }
        
        // If there's an existing initialization task, wait for it
        if let existingTask = initializationTask {
            FameFitLogger.debug("Waiting for existing initialization task", category: FameFitLogger.cloudKit)
            do {
                try await existingTask.value
            } catch {
                FameFitLogger.error("Initialization task failed", error: error, category: FameFitLogger.cloudKit)
            }
            return
        }
        
        // Create a new initialization task
        initializationTask = Task {
            await performInitialization()
        }
        
        // Wait for it to complete
        do {
            try await initializationTask?.value
        } catch {
            FameFitLogger.error("Failed to initialize CloudKit", error: error, category: FameFitLogger.cloudKit)
        }
    }
    
    private func performInitialization() async {
        let initStart = Date()
        
        guard await stateManager.canStartInitialization() else {
            FameFitLogger.debug("Cannot start initialization at this time", category: FameFitLogger.cloudKit)
            return
        }
        
        await stateManager.setInitializationState(.inProgress)
        
        do {
            // Initialize schema if needed
            let schemaStart = Date()
            try await initializeSchemaWithRetry()
            let schemaDuration = Date().timeIntervalSince(schemaStart)
            FameFitLogger.info("Schema check completed in \(String(format: "%.2f", schemaDuration))s", category: FameFitLogger.cloudKit)
            
            // Only fetch user record if authentication manager indicates user has completed onboarding
            if let authManager = authenticationManager, authManager.hasCompletedOnboarding {
                // Fetch user record
                let userRecordStart = Date()
                await fetchUserRecordAsync()
                let userRecordDuration = Date().timeIntervalSince(userRecordStart)
                FameFitLogger.info("User record fetch completed in \(String(format: "%.2f", userRecordDuration))s", category: FameFitLogger.cloudKit)
                
                // Check if stats recalculation is needed
                await checkAndRecalculateStatsIfNeeded()
            } else {
                FameFitLogger.debug("Skipping user record fetch - user not authenticated or onboarding incomplete", category: FameFitLogger.cloudKit)
            }
            
            // Mark as initialized
            await stateManager.setInitializationState(.completed)
            await MainActor.run {
                self.isInitialized = true
                // Clear the initialization task reference
                self.initializationTask = nil
            }
            
            let totalDuration = Date().timeIntervalSince(initStart)
            FameFitLogger.info("✅ CloudKit initialization completed successfully in \(String(format: "%.2f", totalDuration))s", category: FameFitLogger.cloudKit)
        } catch {
            FameFitLogger.error("CloudKit initialization failed", error: error, category: FameFitLogger.cloudKit)
            await stateManager.setInitializationState(.failed(error))
            
            // Schedule retry if appropriate
            if await stateManager.shouldRetryOperation(.schemaInitialization, error: error) {
                let delay = await stateManager.getRetryDelay(for: .schemaInitialization)
                
                Task {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    await performInitialization()
                }
            }
        }
    }
    
    private func initializeSchemaWithRetry() async throws {
        // For now, we'll skip schema initialization if CloudKit isn't ready
        // The schema will be created automatically when records are first saved
        do {
            // Quick check if CloudKit is accessible
            _ = try await container.privateCloudDatabase.recordZone(for: .default)
            FameFitLogger.info("CloudKit is accessible, schema will be created on demand", category: FameFitLogger.cloudKit)
        } catch {
            if error.localizedDescription.contains("Can't query system types") {
                FameFitLogger.info("CloudKit not ready for schema check, will initialize on first use", category: FameFitLogger.cloudKit)
                return
            }
            throw error
        }
    }
    
    // DEPRECATED: We no longer use the legacy Users record system
    /*
    private func processUserRecord(_ record: CKRecord) async {
        // This method is deprecated - we use UserProfile records exclusively
    }
    */
    
    private func trackXPTransaction(xp: Int) async {
        // TODO: Update to use new XPTransactionService API
        // xpTransactionService?.createTransaction(...)
    }
    
    // MARK: - Stats Recalculation
    
    func checkAndRecalculateStatsIfNeeded() async {
        let lastRecalculation = UserDefaults.standard.object(forKey: recalculationIntervalKey) as? Date
        let now = Date()
        
        if let lastDate = lastRecalculation {
            let timeSince = now.timeIntervalSince(lastDate)
            if timeSince < recalculationInterval {
                FameFitLogger.info("⏰ Stats recalculation not needed yet", category: FameFitLogger.cloudKit)
                return
            }
        }
        
        FameFitLogger.info("♻️ Starting stats recalculation", category: FameFitLogger.cloudKit)
        await recalculateStatsFromWorkouts()
        UserDefaults.standard.set(now, forKey: recalculationIntervalKey)
    }
    
    private func recalculateStatsFromWorkouts() async {
        do {
            let predicate = NSPredicate(value: true)
            let sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: false)]
            
            // Fetch from PRIVATE database where workouts are stored
            let query = CKQuery(recordType: "Workouts", predicate: predicate)
            query.sortDescriptors = sortDescriptors
            
            let workoutRecords = try await operationQueue.enqueueQuery(
                query: query,
                database: privateDatabase,
                limit: 1_000,
                priority: .medium
            )
            
            FameFitLogger.info("📊 Found \(workoutRecords.count) workouts to analyze", category: FameFitLogger.cloudKit)
            
            var totalXP = 0
            var workoutsByDate: [Date: Int] = [:]
            
            for record in workoutRecords {
                if let xpEarned = record["xpEarned"] as? Int {
                    totalXP += xpEarned
                }
                
                if let endDate = record["endDate"] as? Date {
                    let calendar = Calendar.current
                    let dayStart = calendar.startOfDay(for: endDate)
                    workoutsByDate[dayStart] = (workoutsByDate[dayStart] ?? 0) + 1
                }
            }
            
            let currentStreak = calculateCurrentStreak(from: workoutsByDate)
            
            // Capture final values as constants for use in async closure
            let finalXP = totalXP
            let finalWorkoutCount = workoutRecords.count
            let finalStreak = currentStreak
            
            FameFitLogger.info("""
                📈 Recalculated stats:
                   Total XP: \(finalXP)
                   Total Workouts: \(finalWorkoutCount)
                   Current Streak: \(finalStreak)
                """, category: FameFitLogger.cloudKit)
            
            // Update local state with recalculated values
            await MainActor.run {
                self.totalXP = finalXP
                self.totalWorkouts = finalWorkoutCount
                self.currentStreak = finalStreak
                
                if let lastWorkout = workoutRecords.first,
                   let endDate = lastWorkout["endDate"] as? Date {
                    self.lastWorkoutTimestamp = endDate
                }
            }
            
            // Sync to UserProfiles record (the real source of truth)
            await syncStatsToUserProfile(totalWorkouts: finalWorkoutCount, totalXP: finalXP)
        } catch {
            FameFitLogger.error("❌ Failed to recalculate stats", error: error, category: FameFitLogger.cloudKit)
        }
    }
    
    private func calculateCurrentStreak(from workoutsByDate: [Date: Int]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        while true {
            if workoutsByDate[currentDate] != nil {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else if streak > 0 {
                break
            } else {
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
                if calendar.dateComponents([.day], from: currentDate, to: Date()).day! > 30 {
                    break
                }
            }
        }
        
        return streak
    }
    
    // MARK: - Legacy Protocol Methods
    
    func saveWorkout(_ workout: Workout) {
        Task {
            do {
                // Create the workout record
                let record = CKRecord(recordType: "Workouts")
                record["workoutID"] = workout.id
                record["workoutType"] = workout.workoutType
                record["startDate"] = workout.startDate
                record["endDate"] = workout.endDate
                record["duration"] = workout.duration
                record["totalEnergyBurned"] = workout.totalEnergyBurned
                record["totalDistance"] = workout.totalDistance
                record["averageHeartRate"] = workout.averageHeartRate
                record["followersEarned"] = workout.followersEarned
                record["xpEarned"] = workout.xpEarned
                record["source"] = workout.source
                
                // Save to CloudKit
                _ = try await privateDatabase.save(record)
                
                FameFitLogger.info("✅ Saved workout to CloudKit: \(workout.workoutType)", category: FameFitLogger.cloudKit)
            } catch {
                FameFitLogger.error("Failed to save workout to CloudKit", error: error, category: FameFitLogger.cloudKit)
            }
        }
    }
    
    func fetchWorkouts(completion: @escaping (Result<[Workout], Error>) -> Void) {
        Task {
            do {
                let predicate = NSPredicate(value: true)
                let query = CKQuery(recordType: "Workouts", predicate: predicate)
                query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
                
                // Fetch from PRIVATE database
                let records = try await operationQueue.enqueueQuery(
                    query: query,
                    database: privateDatabase,
                    limit: 100,
                    priority: .medium
                )
                
                FameFitLogger.info("📊 Fetched \(records.count) workout records from CloudKit", category: FameFitLogger.cloudKit)
                
                let workouts = records.compactMap { record -> Workout? in
                    guard let id = record["workoutID"] as? String,
                          let type = record["workoutType"] as? String,
                          let startDate = record["startDate"] as? Date,
                          let endDate = record["endDate"] as? Date else {
                        FameFitLogger.warning("⚠️ Skipping workout record with missing required fields", category: FameFitLogger.cloudKit)
                        return nil
                    }
                    
                    // Extract individual fields to avoid type-checking timeout
                    let workoutID = id
                    let duration = record["duration"] as? TimeInterval ?? 0
                    let totalEnergyBurned = record["totalEnergyBurned"] as? Double ?? 0
                    let totalDistance = record["totalDistance"] as? Double
                    let averageHeartRate = record["averageHeartRate"] as? Double
                    let followersEarned = record["followersEarned"] as? Int ?? 5
                    let xpEarned = record["xpEarned"] as? Int
                    let source = record["source"] as? String ?? "Unknown"
                    let groupWorkoutID = record["groupWorkoutID"] as? String
                    
                    return Workout(
                        id: workoutID,
                        workoutType: type,
                        startDate: startDate,
                        endDate: endDate,
                        duration: duration,
                        totalEnergyBurned: totalEnergyBurned,
                        totalDistance: totalDistance,
                        averageHeartRate: averageHeartRate,
                        followersEarned: followersEarned,
                        xpEarned: xpEarned,
                        source: source,
                        groupWorkoutID: groupWorkoutID
                    )
                }
                
                completion(.success(workouts))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func recordWorkout(_ workout: HKWorkout, completion: @escaping (Bool) -> Void) {
        // Legacy method - no longer used
        FameFitLogger.warning("recordWorkout called - this is a legacy method", category: FameFitLogger.cloudKit)
        completion(true)
    }
    
    func getXPTitle() -> String {
        let levelInfo = XPCalculator.getLevel(for: totalXP)
        return levelInfo.title
    }
    
    func recalculateStatsIfNeeded() async throws {
        await checkAndRecalculateStatsIfNeeded()
    }
    
    func recalculateUserStats() async throws {
        await recalculateStatsFromWorkouts()
    }
    
    func clearAllWorkoutsAndResetStats() async throws {
        // Implementation for clearing all workouts
        FameFitLogger.warning("clearAllWorkoutsAndResetStats - not implemented", category: FameFitLogger.cloudKit)
    }
    
    func debugCloudKitEnvironment() async throws {
        FameFitLogger.info("""
            CloudKit Debug Info:
            - Container: \(container.containerIdentifier ?? "Unknown")
            - Is Signed In: \(isSignedIn)
            - User ID: \(currentUserID ?? "None")
            - Total XP: \(totalXP)
            - Total Workouts: \(totalWorkouts)
            """, category: FameFitLogger.cloudKit)
    }
    
    func forceResetStats() async throws {
        FameFitLogger.warning("Forcing stats reset to zero", category: FameFitLogger.cloudKit)
        
        // Reset local state to zero
        await MainActor.run {
            self.totalXP = 0
            self.totalWorkouts = 0
            self.currentStreak = 0
            self.lastWorkoutTimestamp = nil
        }
        
        // Sync zeroed stats to UserProfiles (the real source of truth)
        await syncStatsToUserProfile(totalWorkouts: 0, totalXP: 0)
        
        FameFitLogger.info("Stats reset completed", category: FameFitLogger.cloudKit)
    }
    
    func updateUserStats(totalWorkouts: Int, totalXP: Int) async throws {
        FameFitLogger.info("Updating user stats - Workouts: \(totalWorkouts), XP: \(totalXP)", category: FameFitLogger.cloudKit)
        
        // Update local state
        await MainActor.run {
            self.totalWorkouts = totalWorkouts
            self.totalXP = totalXP
        }
        
        FameFitLogger.info("User stats updated successfully", category: FameFitLogger.cloudKit)
        
        // Sync to UserProfiles record (the real source of truth)
        await syncStatsToUserProfile(totalWorkouts: totalWorkouts, totalXP: totalXP)
    }
    
    private func syncStatsToUserProfile(totalWorkouts: Int, totalXP: Int) async {
        guard let userID = currentUserID else {
            FameFitLogger.warning("Cannot sync to profile - no user ID", category: FameFitLogger.cloudKit)
            return
        }
        
        // Use centralized sync service if available
        if let syncService = statsSyncService {
            let stats = UserStatsSnapshot(
                userID: userID,
                totalWorkouts: totalWorkouts,
                totalXP: totalXP,
                currentStreak: currentStreak,
                lastWorkoutDate: lastWorkoutTimestamp
            )
            
            // Queue for batch sync (more efficient)
            syncService.queueStatsSync(stats)
        } else {
            // Fallback to direct sync if service not available
            await performDirectStatsSync(totalWorkouts: totalWorkouts, totalXP: totalXP)
        }
    }
    
    private func performDirectStatsSync(totalWorkouts: Int, totalXP: Int) async {
        // Original implementation as fallback
        guard let userID = currentUserID else { return }
        
        do {
            let predicate = NSPredicate(format: "userID == %@", userID)
            let query = CKQuery(recordType: "UserProfiles", predicate: predicate)
            let results = try await publicDatabase.records(matching: query)
            
            guard let (_, profileResult) = results.matchResults.first,
                  let profileRecord = try? profileResult.get() else {
                FameFitLogger.warning("No UserProfile found to sync stats", category: FameFitLogger.cloudKit)
                return
            }
            
            profileRecord["workoutCount"] = totalWorkouts
            profileRecord["totalXP"] = totalXP
            // modificationDate is managed by CloudKit automatically
            
            _ = try await publicDatabase.save(profileRecord)
            FameFitLogger.info("Successfully synced stats to UserProfile", category: FameFitLogger.cloudKit)
        } catch {
            FameFitLogger.error("Failed to sync stats to UserProfile", error: error, category: FameFitLogger.cloudKit)
        }
    }
    
    // MARK: - Additional CloudKit Operations
    
    func fetchRecords(withQuery query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?) async throws -> [CKRecord] {
        let database = zoneID != nil ? privateDatabase : publicDatabase
        let results = try await database.records(matching: query)
        return results.matchResults.compactMap { try? $0.1.get() }
    }
    
    func fetchRecords(ofType recordType: String, predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?, limit: Int?) async throws -> [CKRecord] {
        let predicate = predicate ?? NSPredicate(value: true)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors
        
        return try await operationQueue.enqueueQuery(
            query: query,
            database: publicDatabase,
            limit: limit ?? 100,
            priority: .medium
        )
    }
    
    // MARK: - Missing Publishers
    
    var totalWorkoutsPublisher: AnyPublisher<Int, Never> {
        $totalWorkouts.eraseToAnyPublisher()
    }
    
    var currentStreakPublisher: AnyPublisher<Int, Never> {
        $currentStreak.eraseToAnyPublisher()
    }
    
    var usernamePublisher: AnyPublisher<String, Never> {
        $username.eraseToAnyPublisher()
    }
    
    var lastWorkoutTimestampPublisher: AnyPublisher<Date?, Never> {
        $lastWorkoutTimestamp.eraseToAnyPublisher()
    }
    
    // MARK: - Account Deletion
    
    /// Delete all user data from CloudKit
    func deleteAllUserData() async throws {
        guard let userID = currentUserID else {
            throw FameFitError.userNotAuthenticated
        }
        
        FameFitLogger.info("Starting account deletion for user: \(userID)", category: FameFitLogger.cloudKit)
        
        // Track deletion progress
        var deletedRecords = 0
        var errors: [Error] = []
        
        // Record types to delete from private database
        let privateRecordTypes = [
            "Workouts",
            "XPTransactions",
            "WorkoutHistory",
            "WorkoutMetrics",
            "GroupWorkoutInvites",
            "Notifications",
            "NotificationHistory",
            "WorkoutChallengeLinks",
            "UserSettings",
            "ActivityFeedSettings",
            "DeviceTokens"
        ]
        
        // Record types to delete from public database
        let publicRecordTypes = [
            "UserProfiles",
            "UserRelationships",
            "ActivityFeed",
            "WorkoutKudos",
            "ActivityFeedComments"
        ]
        
        // Delete from private database
        for recordType in privateRecordTypes {
            do {
                // Only query for records with our userID field, not system fields
                let predicate = NSPredicate(format: "userID == %@ OR hostID == %@", userID, userID)
                let query = CKQuery(recordType: recordType, predicate: predicate)
                let records = try await privateDatabase.records(matching: query)
                
                let recordIDs = records.matchResults.compactMap { result -> CKRecord.ID? in
                    guard let record = try? result.1.get() else { return nil }
                    return record.recordID
                }
                
                if !recordIDs.isEmpty {
                    try await deleteRecords(withIDs: recordIDs)
                    deletedRecords += recordIDs.count
                    FameFitLogger.info("Deleted \(recordIDs.count) \(recordType) records", category: FameFitLogger.cloudKit)
                }
            } catch {
                FameFitLogger.error("Failed to delete \(recordType) records", error: error, category: FameFitLogger.cloudKit)
                errors.append(error)
            }
        }
        
        // Delete from public database
        for recordType in publicRecordTypes {
            do {
                let predicate = NSPredicate(format: "userID == %@ OR followerID == %@ OR followingID == %@", userID, userID, userID)
                let query = CKQuery(recordType: recordType, predicate: predicate)
                let records = try await publicDatabase.records(matching: query)
                
                let recordIDs = records.matchResults.compactMap { result -> CKRecord.ID? in
                    guard let record = try? result.1.get() else { return nil }
                    return record.recordID
                }
                
                if !recordIDs.isEmpty {
                    // Delete from public database
                    for recordID in recordIDs {
                        _ = try await publicDatabase.deleteRecord(withID: recordID)
                    }
                    deletedRecords += recordIDs.count
                    FameFitLogger.info("Deleted \(recordIDs.count) public \(recordType) records", category: FameFitLogger.cloudKit)
                }
            } catch {
                FameFitLogger.error("Failed to delete public \(recordType) records", error: error, category: FameFitLogger.cloudKit)
                errors.append(error)
            }
        }
        
        // Delete any group workouts the user created
        do {
            let predicate = NSPredicate(format: "hostID == %@", userID)
            let query = CKQuery(recordType: "GroupWorkouts", predicate: predicate)
            let records = try await publicDatabase.records(matching: query)
            
            for result in records.matchResults {
                if let record = try? result.1.get() {
                    _ = try await publicDatabase.deleteRecord(withID: record.recordID)
                    deletedRecords += 1
                }
            }
        } catch {
            FameFitLogger.error("Failed to delete group workouts", error: error, category: FameFitLogger.cloudKit)
            errors.append(error)
        }
        
        // Clear local cache and state
        clearLocalData()
        
        FameFitLogger.info("Account deletion completed. Deleted \(deletedRecords) records with \(errors.count) errors", category: FameFitLogger.cloudKit)
        
        // If there were critical errors, throw
        if !errors.isEmpty && deletedRecords == 0 {
            throw FameFitError.cloudKitSyncFailed(errors.first ?? FameFitError.unknownError(NSError(domain: "CloudKit", code: -1)))
        }
    }
    
    private func clearLocalData() {
        // Clear all local state
        totalXP = 0
        totalWorkouts = 0
        currentStreak = 0
        lastWorkoutTimestamp = nil
        username = "FameFit User"
        currentUserRecordID = nil
        // userRecord = nil // DEPRECATED - We use UserProfile records now
        isSignedIn = false
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "CloudKit_TotalXP")
        UserDefaults.standard.removeObject(forKey: "CloudKit_TotalWorkouts")
        UserDefaults.standard.removeObject(forKey: "CloudKit_CurrentStreak")
        UserDefaults.standard.removeObject(forKey: "CloudKit_LastWorkoutDate")
        UserDefaults.standard.removeObject(forKey: "CloudKit_JoinDate")
        UserDefaults.standard.removeObject(forKey: "CloudKit_UserName")
        UserDefaults.standard.synchronize()
        
        FameFitLogger.info("Cleared all local CloudKit data", category: FameFitLogger.cloudKit)
    }
    
    // MARK: - Retry Infrastructure
    
    /// Save a record with automatic retry logic
    func saveWithRetry(
        _ record: CKRecord,
        database: CKDatabase? = nil,
        configuration: RetryConfiguration = .default
    ) async throws -> CKRecord {
        let db = database ?? privateDatabase
        let operationName = "Save \(record.recordType) record"
        
        return try await retryExecutor.execute(
            operation: {
                try await db.save(record)
            },
            configuration: configuration,
            operationName: operationName
        )
    }
    
    /// Fetch a record with automatic retry logic
    func fetchWithRetry(
        recordID: CKRecord.ID,
        database: CKDatabase? = nil,
        configuration: RetryConfiguration = .default
    ) async throws -> CKRecord {
        let db = database ?? privateDatabase
        let operationName = "Fetch record \(recordID.recordName)"
        
        return try await retryExecutor.execute(
            operation: {
                try await db.record(for: recordID)
            },
            configuration: configuration,
            operationName: operationName
        )
    }
    
    /// Delete a record with automatic retry logic
    func deleteWithRetry(
        recordID: CKRecord.ID,
        database: CKDatabase? = nil,
        configuration: RetryConfiguration = .default
    ) async throws {
        let db = database ?? privateDatabase
        let operationName = "Delete record \(recordID.recordName)"
        
        _ = try await retryExecutor.execute(
            operation: {
                try await db.deleteRecord(withID: recordID)
            },
            configuration: configuration,
            operationName: operationName
        )
    }
    
    /// Execute a query with automatic retry logic
    func queryWithRetry(
        _ query: CKQuery,
        database: CKDatabase? = nil,
        limit: Int = CKQueryOperation.maximumResults,
        configuration: RetryConfiguration = .default
    ) async throws -> [CKRecord] {
        let db = database ?? privateDatabase
        let operationName = "Query \(query.recordType)"
        
        return try await retryExecutor.execute(
            operation: {
                let (results, _) = try await db.records(matching: query, resultsLimit: limit)
                return results.compactMap { _, result in
                    try? result.get()
                }
            },
            configuration: configuration,
            operationName: operationName
        )
    }
    
    /// Queue an operation for retry if it fails
    func queueForRetry(
        type: QueueItem.ItemType,
        data: Data,
        priority: QueueItem.Priority = .medium
    ) async {
        let item = QueueItem(
            type: type,
            data: data,
            priority: priority
        )
        
        await retryQueue.enqueue(item)
    }
    
}
