//
//  CloudKitManager.swift
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

final class CloudKitManager: NSObject, ObservableObject, CloudKitManaging {
    // MARK: - Properties
    
    let container = CKContainer(identifier: "iCloud.com.jimmypocock.FameFit")
    private let stateManager = CloudKitStateManager()
    private let operationQueue = CloudKitOperationQueue()
    private let schemaManager: CloudKitSchemaManager
    
    // Recalculation tracking
    private let recalculationIntervalKey = "FameFitLastStatsRecalculation"
    private let recalculationInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // MARK: - Published Properties
    
    @Published var isSignedIn = false
    @Published var userRecord: CKRecord?
    @Published var totalXP: Int = 0
    @Published var userName: String = ""
    @Published var currentStreak: Int = 0
    @Published var totalWorkouts: Int = 0
    @Published var lastWorkoutTimestamp: Date?
    @Published var joinTimestamp: Date?
    @Published var lastError: FameFitError?
    @Published private(set) var isInitialized = false
    
    // Services
    weak var authenticationManager: AuthenticationManager?
    weak var unlockNotificationService: UnlockNotificationServiceProtocol?
    var xpTransactionService: XPTransactionService?
    
    // Computed properties for compatibility
    var isAvailable: Bool { isSignedIn }
    var currentUserID: String? { userRecord?.recordID.recordName }
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
        self.schemaManager = CloudKitSchemaManager(container: container)
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
        FameFitLogger.info("Initializing CloudKit manager", category: FameFitLogger.cloudKit)
        
        // Set up account change notifications
        setupAccountChangeNotifications()
        
        // Check initial account status
        await checkAccountStatusAsync()
        
        // Initialize if account is available
        if isSignedIn {
            await performInitialization()
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
                await performInitialization()
            }
            
        } catch {
            FameFitLogger.error("Failed to check account status", error: error, category: FameFitLogger.cloudKit)
            await MainActor.run {
                self.isSignedIn = false
                self.lastError = error.fameFitError
            }
        }
    }
    
    /// Setup user record with display name
    func setupUserRecord(userID: String, displayName: String) {
        Task {
            await setupUserRecordAsync(userID: userID, displayName: displayName)
        }
    }
    
    private func setupUserRecordAsync(userID: String, displayName: String) async {
        guard await stateManager.startOperation(.userRecordCreate) else {
            FameFitLogger.debug("User record creation already in progress", category: FameFitLogger.cloudKit)
            return
        }
        
        defer {
            Task {
                await stateManager.completeOperation(.userRecordCreate)
            }
        }
        
        do {
            // Get the CloudKit user record ID
            let recordID = try await container.userRecordID()
            
            // Try to fetch existing record first
            let userRecord: CKRecord
            do {
                userRecord = try await privateDatabase.record(for: recordID)
                FameFitLogger.info("Found existing user record", category: FameFitLogger.cloudKit)
            } catch {
                // Create new record if not found
                userRecord = CKRecord(recordType: CloudKitConfiguration.RecordType.users, recordID: recordID)
                FameFitLogger.info("Creating new user record", category: FameFitLogger.cloudKit)
                
                // Set initial values for new record
                userRecord["totalXP"] = 0
                userRecord["influencerXP"] = 0 // Legacy
                userRecord["totalWorkouts"] = 0
                userRecord["currentStreak"] = 0
                userRecord["joinTimestamp"] = Date()
            }
            
            // Update display name
            userRecord["displayName"] = displayName
            
            // Save the record
            let savedRecord = try await operationQueue.enqueueSave(
                record: userRecord,
                database: privateDatabase,
                priority: .high
            )
            
            // Update local state
            await processUserRecord(savedRecord)
            
        } catch {
            FameFitLogger.error("Failed to setup user record", error: error, category: FameFitLogger.cloudKit)
            await MainActor.run {
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
    
    func addXPAsync(_ xp: Int) async {
        FameFitLogger.info("Adding \(xp) XP", category: FameFitLogger.cloudKit)
        
        guard let userRecord = userRecord else {
            FameFitLogger.warning("No user record available", category: FameFitLogger.cloudKit)
            await fetchUserRecordAsync()
            return
        }
        
        do {
            // Update XP
            let currentXP = userRecord["totalXP"] as? Int ?? 0
            userRecord["totalXP"] = currentXP + xp
            
            // Save the updated record
            let savedRecord = try await operationQueue.enqueueSave(
                record: userRecord,
                database: privateDatabase,
                priority: .high
            )
            
            // Update local state
            await processUserRecord(savedRecord)
            
            FameFitLogger.info("Successfully added \(xp) XP, new total: \(currentXP + xp)", category: FameFitLogger.cloudKit)
            
            // Unlock notifications if applicable
            // Note: showFollowerNotification was removed - using notification manager instead
            
            // Track XP transaction
            await trackXPTransaction(xp: xp)
            
        } catch {
            FameFitLogger.error("Failed to add XP", error: error, category: FameFitLogger.cloudKit)
            await MainActor.run {
                self.lastError = error.fameFitError
            }
        }
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
            let recordID = try await container.userRecordID()
            let record = try await operationQueue.enqueueFetch(
                recordID: recordID,
                database: privateDatabase,
                priority: .high
            )
            
            await processUserRecord(record)
            
            FameFitLogger.info("Successfully fetched user record", category: FameFitLogger.cloudKit)
            
        } catch {
            FameFitLogger.error("Failed to fetch user record", error: error, category: FameFitLogger.cloudKit)
            
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
    
    // MARK: - CloudKit Operations
    
    func save(_ record: CKRecord) async throws -> CKRecord {
        return try await operationQueue.enqueueSave(
            record: record,
            database: record.recordType == CloudKitConfiguration.RecordType.users ? privateDatabase : publicDatabase,
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
        return recordID.recordName
    }
    
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
    
    private func performInitialization() async {
        guard await stateManager.canStartInitialization() else {
            FameFitLogger.debug("Cannot start initialization at this time", category: FameFitLogger.cloudKit)
            return
        }
        
        await stateManager.setInitializationState(.inProgress)
        
        do {
            // Initialize schema if needed
            try await initializeSchemaWithRetry()
            
            // Fetch user record
            await fetchUserRecordAsync()
            
            // Check if stats recalculation is needed
            await checkAndRecalculateStatsIfNeeded()
            
            // Mark as initialized
            await stateManager.setInitializationState(.completed)
            await MainActor.run {
                self.isInitialized = true
            }
            
            FameFitLogger.info("CloudKit initialization completed successfully", category: FameFitLogger.cloudKit)
            
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
    
    private func processUserRecord(_ record: CKRecord) async {
        await MainActor.run {
            self.userRecord = record
            
            // Extract user data
            self.totalXP = record["totalXP"] as? Int ?? record["influencerXP"] as? Int ?? 0
            self.userName = record["displayName"] as? String ?? ""
            self.currentStreak = record["currentStreak"] as? Int ?? 0
            self.totalWorkouts = record["totalWorkouts"] as? Int ?? 0
            self.lastWorkoutTimestamp = record["lastWorkoutTimestamp"] as? Date
            self.joinTimestamp = record["joinTimestamp"] as? Date
            self.lastError = nil
        }
        
        FameFitLogger.info("""
            🔍 Fresh stats from Users record:
               Record ID: \(record.recordID.recordName)
               totalWorkouts: \(record["totalWorkouts"] as? Int ?? 0)
               totalXP: \(record["totalXP"] as? Int ?? 0)
               influencerXP: \(record["influencerXP"] as? Int ?? 0)
               Final values: workouts=\(self.totalWorkouts), XP=\(self.totalXP)
            """, category: FameFitLogger.cloudKit)
    }
    
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
            
            let workoutRecords = try await fetchRecords(
                ofType: "Workouts",
                predicate: predicate,
                sortDescriptors: sortDescriptors,
                limit: 1000
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
            
            FameFitLogger.info("""
                📈 Recalculated stats:
                   Total XP: \(totalXP)
                   Total Workouts: \(workoutRecords.count)
                   Current Streak: \(currentStreak)
                """, category: FameFitLogger.cloudKit)
            
            guard let userRecord = userRecord else { return }
            
            userRecord["totalXP"] = totalXP
            userRecord["totalWorkouts"] = workoutRecords.count
            userRecord["currentStreak"] = currentStreak
            
            if let lastWorkout = workoutRecords.first,
               let endDate = lastWorkout["endDate"] as? Date {
                userRecord["lastWorkoutTimestamp"] = endDate
            }
            
            let savedRecord = try await save(userRecord)
            await processUserRecord(savedRecord)
            
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
    
    func saveWorkout(_ workoutHistory: Workout) {
        // Legacy method - no longer used
        FameFitLogger.warning("saveWorkout called - this is a legacy method", category: FameFitLogger.cloudKit)
    }
    
    func fetchWorkouts(completion: @escaping (Result<[Workout], Error>) -> Void) {
        Task {
            do {
                let predicate = NSPredicate(value: true)
                let records = try await fetchRecords(
                    ofType: "Workouts",
                    predicate: predicate,
                    sortDescriptors: nil,
                    limit: 100
                )
                
                let workouts = records.compactMap { record -> Workout? in
                    guard let id = record["workoutId"] as? String,
                          let type = record["workoutType"] as? String,
                          let startDate = record["startDate"] as? Date,
                          let endDate = record["endDate"] as? Date else {
                        return nil
                    }
                    
                    // Extract individual fields to avoid type-checking timeout
                    let workoutId = UUID(uuidString: id) ?? UUID()
                    let duration = record["duration"] as? TimeInterval ?? 0
                    let totalEnergyBurned = record["totalEnergyBurned"] as? Double ?? 0
                    let totalDistance = record["totalDistance"] as? Double
                    let averageHeartRate = record["averageHeartRate"] as? Double
                    let followersEarned = record["followersEarned"] as? Int ?? 5
                    let xpEarned = record["xpEarned"] as? Int
                    let source = record["source"] as? String ?? "Unknown"
                    
                    return Workout(
                        id: workoutId,
                        workoutType: type,
                        startDate: startDate,
                        endDate: endDate,
                        duration: duration,
                        totalEnergyBurned: totalEnergyBurned,
                        totalDistance: totalDistance,
                        averageHeartRate: averageHeartRate,
                        followersEarned: followersEarned,
                        xpEarned: xpEarned,
                        source: source
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
        
        guard let userRecord = userRecord else {
            throw FameFitError.cloudKitNotAvailable
        }
        
        // Reset all stats to zero
        userRecord["totalXP"] = 0
        userRecord["totalWorkouts"] = 0
        userRecord["currentStreak"] = 0
        userRecord["lastWorkoutTimestamp"] = nil
        
        // Save the updated record
        let savedRecord = try await save(userRecord)
        await processUserRecord(savedRecord)
        
        FameFitLogger.info("Stats reset completed", category: FameFitLogger.cloudKit)
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
    
    var userNamePublisher: AnyPublisher<String, Never> {
        $userName.eraseToAnyPublisher()
    }
    
    var lastWorkoutTimestampPublisher: AnyPublisher<Date?, Never> {
        $lastWorkoutTimestamp.eraseToAnyPublisher()
    }
    
    var joinTimestampPublisher: AnyPublisher<Date?, Never> {
        $joinTimestamp.eraseToAnyPublisher()
    }
}