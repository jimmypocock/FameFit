import AuthenticationServices
import CloudKit
import Combine
import Foundation
import HealthKit
import os.log

class CloudKitManager: NSObject, ObservableObject, CloudKitManaging {
    let container = CKContainer(identifier: "iCloud.com.jimmypocock.FameFit")
    private let privateDatabase: CKDatabase
    private let schemaManager: CloudKitSchemaManager
    
    // Recalculation tracking
    private let recalculationIntervalKey = "FameFitLastStatsRecalculation"
    private let recalculationInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    @Published var isSignedIn = false
    @Published var userRecord: CKRecord?
    @Published var totalXP: Int = 0
    @Published var userName: String = ""
    @Published var currentStreak: Int = 0
    @Published var totalWorkouts: Int = 0
    @Published var lastWorkoutTimestamp: Date?
    @Published var joinTimestamp: Date?
    @Published var lastError: FameFitError?

    weak var authenticationManager: AuthenticationManager?
    weak var unlockNotificationService: UnlockNotificationServiceProtocol?
    var xpTransactionService: XPTransactionService?

    var isAvailable: Bool {
        isSignedIn
    }

    var currentUserID: String? {
        userRecord?.recordID.recordName
    }

    var currentUserXP: Int {
        totalXP
    }

    // MARK: - Publisher Properties

    var isAvailablePublisher: AnyPublisher<Bool, Never> {
        $isSignedIn.eraseToAnyPublisher()
    }

    var totalXPPublisher: AnyPublisher<Int, Never> {
        $totalXP.eraseToAnyPublisher()
    }

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

    var lastErrorPublisher: AnyPublisher<FameFitError?, Never> {
        $lastError.eraseToAnyPublisher()
    }

    override init() {
        privateDatabase = container.privateCloudDatabase
        schemaManager = CloudKitSchemaManager(container: container)
        super.init()

        checkAccountStatus()
    }

    func checkAccountStatus() {
        container.accountStatus { [weak self] status, _ in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.isSignedIn = true
                    self?.schemaManager.initializeSchemaIfNeeded()
                    self?.fetchUserRecord()
                case .noAccount:
                    self?.isSignedIn = false
                default:
                    self?.isSignedIn = false
                }
            }
        }
    }

    func setupUserRecord(userID _: String, displayName: String) {
        // Use CloudKit's user record ID instead of Apple Sign In ID
        container.fetchUserRecordID { [weak self] recordID, error in
            guard let recordID else { return }

            self?.privateDatabase.fetch(withRecordID: recordID) { existingRecord, _ in
                let userRecord = existingRecord ?? CKRecord(recordType: "Users", recordID: recordID)

                // Only update if this is a new record
                if existingRecord == nil {
                    userRecord["displayName"] = displayName
                    userRecord["totalXP"] = 0
                    userRecord["influencerXP"] = 0 // Keep for backward compatibility
                    userRecord["totalWorkouts"] = 0
                    userRecord["currentStreak"] = 0
                    userRecord["joinTimestamp"] = Date()
                    userRecord["lastWorkoutTimestamp"] = Date()
                } else {
                    // Update display name if changed
                    userRecord["displayName"] = displayName
                }

                self?.privateDatabase.save(userRecord) { [weak self] record, error in
                    DispatchQueue.main.async {
                        if let error {
                            self?.lastError = error.fameFitError
                            return
                        }

                        if let record {
                            self?.userRecord = record
                            // Try new field first, fall back to old field for compatibility
                            self?.totalXP = record["totalXP"] as? Int ?? record["influencerXP"] as? Int ?? 0
                            self?.userName = record["displayName"] as? String ?? ""
                            self?.currentStreak = record["currentStreak"] as? Int ?? 0
                            self?.totalWorkouts = record["totalWorkouts"] as? Int ?? 0
                            self?.lastWorkoutTimestamp = record["lastWorkoutTimestamp"] as? Date
                            self?.joinTimestamp = record["joinTimestamp"] as? Date
                            self?.lastError = nil
                        }
                    }
                }
            }
        }
    }

    func fetchUserRecord() {
        container.fetchUserRecordID { [weak self] recordID, error in
            if let error {
                DispatchQueue.main.async {
                    self?.lastError = error.fameFitError
                }
                return
            }

            guard let recordID else {
                DispatchQueue.main.async {
                    self?.lastError = .cloudKitUserNotFound
                }
                return
            }

            self?.privateDatabase.fetch(withRecordID: recordID) { record, error in
                DispatchQueue.main.async {
                    if let error {
                        self?.lastError = error.fameFitError
                        return
                    }

                    if let record {
                        self?.userRecord = record

                        // Read XP field
                        // Try new field first, fall back to old field
                        self?.totalXP = record["totalXP"] as? Int ?? record["influencerXP"] as? Int ?? 0

                        self?.userName = record["displayName"] as? String ?? ""
                        self?.currentStreak = record["currentStreak"] as? Int ?? 0
                        self?.totalWorkouts = record["totalWorkouts"] as? Int ?? 0
                        self?.lastWorkoutTimestamp = record["lastWorkoutTimestamp"] as? Date
                        self?.joinTimestamp = record["joinTimestamp"] as? Date
                        self?.lastError = nil
                    }
                }
            }
        }
    }

    func addFollowers(_ count: Int = 5) {
        // Legacy method - just adds the count as XP
        addXP(count)
    }

    func addXP(_ xp: Int) {
        FameFitLogger.info("addXP called with amount: \(xp)", category: FameFitLogger.cloudKit)

        guard let userRecord else {
            FameFitLogger.notice("No user record found - fetching...", category: FameFitLogger.cloudKit)
            fetchUserRecord()
            return
        }

        // Try new field first, fall back to old field
        let currentXP = userRecord["totalXP"] as? Int ?? userRecord["influencerXP"] as? Int ?? 0
        let currentTotal = userRecord["totalWorkouts"] as? Int ?? 0

        FameFitLogger.debug(
            "Current XP: \(currentXP), workouts: \(currentTotal)", category: FameFitLogger.cloudKit
        )

        userRecord["totalXP"] = currentXP + xp
        userRecord["influencerXP"] = currentXP + xp // Keep both fields in sync
        userRecord["totalWorkouts"] = currentTotal + 1
        userRecord["lastWorkoutTimestamp"] = Date()

        FameFitLogger.info(
            "📊 Updating Users record - New XP: \(currentXP + xp), New workout count: \(currentTotal + 1)", category: FameFitLogger.cloudKit
        )

        updateStreakIfNeeded(userRecord)

        // Store previous XP for unlock checking
        let previousXP = currentXP

        privateDatabase.save(userRecord) { [weak self] record, error in
            DispatchQueue.main.async {
                if let error {
                    self?.lastError = error.fameFitError
                    return
                }

                if let record {
                    self?.userRecord = record

                    // Update cached values
                    self?.totalXP = record["totalXP"] as? Int ?? 0
                    self?.totalWorkouts = record["totalWorkouts"] as? Int ?? 0
                    
                    FameFitLogger.info(
                        "✅ Users record saved - XP: \(self?.totalXP ?? 0), Workouts: \(self?.totalWorkouts ?? 0)",
                        category: FameFitLogger.cloudKit
                    )

                    // Check for new unlocks
                    // Check for new XP value from either field
                    let newXP = record["totalXP"] as? Int ?? record["influencerXP"] as? Int
                    if let newXP {
                        Task {
                            await self?.unlockNotificationService?.checkForNewUnlocks(
                                previousXP: previousXP,
                                currentXP: newXP
                            )
                        }
                    }

                    self?.totalWorkouts = record["totalWorkouts"] as? Int ?? 0
                    self?.currentStreak = record["currentStreak"] as? Int ?? 0
                    self?.lastWorkoutTimestamp = record["lastWorkoutTimestamp"] as? Date
                    self?.joinTimestamp = record["joinTimestamp"] as? Date
                    self?.lastError = nil
                }
            }
        }
    }

    private func updateStreakIfNeeded(_ record: CKRecord) {
        let lastWorkoutTimestamp = record["lastWorkoutTimestamp"] as? Date ?? Date()
        let currentStreak = record["currentStreak"] as? Int ?? 0

        let calendar = Calendar.current
        let daysSinceLastWorkout =
            calendar.dateComponents([.day], from: lastWorkoutTimestamp, to: Date()).day ?? 0

        if daysSinceLastWorkout <= 1 {
            record["currentStreak"] = currentStreak + 1
        } else {
            record["currentStreak"] = 1
        }
    }

    func getXPTitle() -> String {
        switch totalXP {
        case 0 ..< 100:
            "Fitness Newbie"
        case 100 ..< 1_000:
            "Micro-Influencer"
        case 1_000 ..< 10_000:
            "Rising Star"
        case 10_000 ..< 100_000:
            "Verified Influencer"
        default:
            "FameFit Elite"
        }
    }

    func recordWorkout(_: HKWorkout, completion: @escaping (Bool) -> Void) {
        // For now, just increase followers when a workout is recorded
        addFollowers(5)
        completion(true)
    }

    // MARK: - Stats Recalculation
    
    /// Checks if stats recalculation is needed based on time interval
    func shouldRecalculateStats() -> Bool {
        guard let lastRecalculation = UserDefaults.standard.object(forKey: recalculationIntervalKey) as? Date else {
            // Never recalculated
            return true
        }
        
        return Date().timeIntervalSince(lastRecalculation) > recalculationInterval
    }
    
    /// Performs recalculation if needed
    func recalculateStatsIfNeeded() async throws {
        guard shouldRecalculateStats() else {
            FameFitLogger.info("⏰ Stats recalculation not needed yet", category: FameFitLogger.cloudKit)
            return
        }
        
        try await recalculateUserStats()
        UserDefaults.standard.set(Date(), forKey: recalculationIntervalKey)
    }
    
    /// Recalculates user stats from workout records for data integrity
    func recalculateUserStats() async throws {
        guard let userRecord else {
            throw FameFitError.cloudKitUserNotFound
        }
        
        FameFitLogger.info("🔄 Starting user stats recalculation", category: FameFitLogger.cloudKit)
        FameFitLogger.info("📦 CloudKit Container: \(container.containerIdentifier ?? "unknown")", category: FameFitLogger.cloudKit)
        FameFitLogger.info("👤 Current User Record ID: \(userRecord.recordID.recordName)", category: FameFitLogger.cloudKit)
        
        // Log current state
        let currentWorkoutCount = userRecord["totalWorkouts"] as? Int ?? 0
        let currentXP = userRecord["totalXP"] as? Int ?? 0
        FameFitLogger.info("📊 Current Users record stats: \(currentWorkoutCount) workouts, \(currentXP) XP", category: FameFitLogger.cloudKit)
        
        // Fetch all workouts from CloudKit
        let workouts = try await fetchAllWorkouts()
        
        // Log workout details
        if workouts.isEmpty {
            FameFitLogger.info("⚠️ No workout records found in Workouts table", category: FameFitLogger.cloudKit)
        } else {
            FameFitLogger.info("📱 Found \(workouts.count) workout records", category: FameFitLogger.cloudKit)
            for (index, workout) in workouts.prefix(5).enumerated() {
                FameFitLogger.info("  Workout \(index + 1): \(workout.workoutType), XP: \(workout.effectiveXPEarned), Date: \(workout.endDate)", category: FameFitLogger.cloudKit)
            }
        }
        
        // Calculate totals from actual workout records
        let totalWorkoutCount = workouts.count
        let totalXPFromWorkouts = workouts.reduce(0) { $0 + $1.effectiveXPEarned }
        
        // Check for drift
        let workoutDrift = abs(totalWorkoutCount - currentWorkoutCount)
        let xpDrift = abs(totalXPFromWorkouts - currentXP)
        
        FameFitLogger.info(
            """
            📊 Stats comparison:
               Workouts - Record: \(currentWorkoutCount), Actual: \(totalWorkoutCount), Drift: \(workoutDrift)
               XP - Record: \(currentXP), Actual: \(totalXPFromWorkouts), Drift: \(xpDrift)
            """,
            category: FameFitLogger.cloudKit
        )
        
        // Always update if current values are incorrect (force reset to actual values)
        if currentWorkoutCount != totalWorkoutCount || currentXP != totalXPFromWorkouts {
            userRecord["totalWorkouts"] = totalWorkoutCount
            userRecord["totalXP"] = totalXPFromWorkouts
            userRecord["influencerXP"] = totalXPFromWorkouts // Keep both fields in sync
            userRecord["lastRecalculationDate"] = Date()
            
            FameFitLogger.info("📝 Updating Users record with correct values...", category: FameFitLogger.cloudKit)
            
            try await privateDatabase.save(userRecord)
            
            // Update local cached values
            await MainActor.run {
                self.totalWorkouts = totalWorkoutCount
                self.totalXP = totalXPFromWorkouts
            }
            
            FameFitLogger.info(
                "✅ User stats recalculated and saved. Set to \(totalWorkoutCount) workouts and \(totalXPFromWorkouts) XP",
                category: FameFitLogger.cloudKit
            )
        } else {
            FameFitLogger.info("✅ User stats are accurate, no recalculation needed", category: FameFitLogger.cloudKit)
        }
    }
    
    /// Updates user stats immediately after a workout is saved (incremental update)
    private func updateUserStatsAfterWorkout(_ workout: Workout) async throws {
        guard let userRecord else {
            throw FameFitError.cloudKitUserNotFound
        }
        
        FameFitLogger.info("⚡ Updating user stats after workout save", category: FameFitLogger.cloudKit)
        
        // Get current cached stats
        let currentWorkoutCount = userRecord["totalWorkouts"] as? Int ?? 0
        let currentXP = userRecord["totalXP"] as? Int ?? 0
        
        // Increment by the new workout
        let newWorkoutCount = currentWorkoutCount + 1
        let newTotalXP = currentXP + workout.effectiveXPEarned
        
        FameFitLogger.info("📊 Updating stats: \(currentWorkoutCount) → \(newWorkoutCount) workouts, \(currentXP) → \(newTotalXP) XP", category: FameFitLogger.cloudKit)
        
        // Update the record
        userRecord["totalWorkouts"] = newWorkoutCount
        userRecord["totalXP"] = newTotalXP
        
        // Save to CloudKit
        try await privateDatabase.save(userRecord)
        
        // Update local cached values immediately
        await MainActor.run {
            self.totalWorkouts = newWorkoutCount
            self.totalXP = newTotalXP
        }
        
        FameFitLogger.info("✅ User stats updated: \(newWorkoutCount) workouts, \(newTotalXP) XP", category: FameFitLogger.cloudKit)
    }
    
    /// Fetches all workouts for the current user
    private func fetchAllWorkouts() async throws -> [Workout] {
        guard isSignedIn else {
            throw FameFitError.cloudKitUserNotFound
        }
        
        var allWorkouts: [Workout] = []
        var cursor: CKQueryOperation.Cursor?
        var batchCount = 0
        
        FameFitLogger.info("🔄 Starting fetchAllWorkouts...", category: FameFitLogger.cloudKit)
        
        repeat {
            batchCount += 1
            FameFitLogger.info("📦 Fetching batch #\(batchCount)", category: FameFitLogger.cloudKit)
            let (workouts, nextCursor) = try await fetchWorkoutsBatch(cursor: cursor)
            FameFitLogger.info("📦 Batch #\(batchCount) returned \(workouts.count) workouts", category: FameFitLogger.cloudKit)
            allWorkouts.append(contentsOf: workouts)
            cursor = nextCursor
            
            if cursor != nil {
                FameFitLogger.info("📦 More workouts available, fetching next batch...", category: FameFitLogger.cloudKit)
            }
        } while cursor != nil
        
        FameFitLogger.info("📱 Fetched \(allWorkouts.count) total workouts across \(batchCount) batch(es)", category: FameFitLogger.cloudKit)
        return allWorkouts
    }
    
    /// Fetches a batch of workouts with pagination support
    private func fetchWorkoutsBatch(cursor: CKQueryOperation.Cursor?) async throws -> ([Workout], CKQueryOperation.Cursor?) {
        if let cursor = cursor {
            // Continue from cursor
            let (results, nextCursor) = try await privateDatabase.records(continuingMatchFrom: cursor)
            let workouts = results.compactMap { _, result in
                if let record = try? result.get() {
                    // Enhanced logging for debugging
                    FameFitLogger.info("===== WORKOUT RECORD DETAILS =====", category: FameFitLogger.cloudKit)
                    FameFitLogger.info("Record ID: \(record.recordID.recordName)", category: FameFitLogger.cloudKit)
                    FameFitLogger.info("Zone ID: \(record.recordID.zoneID.zoneName)", category: FameFitLogger.cloudKit)
                    FameFitLogger.info("Created by: \(record.creatorUserRecordID?.recordName ?? "unknown")", category: FameFitLogger.cloudKit)
                    FameFitLogger.info("Created at: \(record.creationDate ?? Date())", category: FameFitLogger.cloudKit)
                    FameFitLogger.info("Modified at: \(record.modificationDate ?? Date())", category: FameFitLogger.cloudKit)
                    
                    // Log all fields
                    FameFitLogger.info("Fields in record:", category: FameFitLogger.cloudKit)
                    for key in record.allKeys() {
                        if let value = record[key] {
                            FameFitLogger.info("  \(key): \(value)", category: FameFitLogger.cloudKit)
                        }
                    }
                    FameFitLogger.info("=================================", category: FameFitLogger.cloudKit)
                    return record
                }
                return nil
            }.compactMap { workout(from: $0) }
            
            return (workouts, nextCursor)
        } else {
            // Initial query
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "Workouts", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: false)]
            
            FameFitLogger.info("🔍 Querying Workouts table in private database", category: FameFitLogger.cloudKit)
            
            let (results, cursor) = try await privateDatabase.records(
                matching: query,
                resultsLimit: 100
            )
            
            FameFitLogger.info("📊 Query returned \(results.count) results", category: FameFitLogger.cloudKit)
            
            var recordIndex = 0
            let workouts = results.compactMap { _, result in
                if let record = try? result.get() {
                    // Log first 3 records in detail for debugging
                    if recordIndex < 3 {
                        FameFitLogger.info("===== WORKOUT RECORD #\(recordIndex + 1) =====", category: FameFitLogger.cloudKit)
                        FameFitLogger.info("Record ID: \(record.recordID.recordName)", category: FameFitLogger.cloudKit)
                        FameFitLogger.info("Zone ID: \(record.recordID.zoneID.zoneName)", category: FameFitLogger.cloudKit)
                        FameFitLogger.info("Created by: \(record.creatorUserRecordID?.recordName ?? "unknown")", category: FameFitLogger.cloudKit)
                        FameFitLogger.info("Created at: \(record.creationDate ?? Date())", category: FameFitLogger.cloudKit)
                        
                        // Log specific workout fields
                        if let workoutType = record["workoutType"] {
                            FameFitLogger.info("Workout Type: \(workoutType)", category: FameFitLogger.cloudKit)
                        }
                        if let source = record["source"] {
                            FameFitLogger.info("Source: \(source)", category: FameFitLogger.cloudKit)
                        }
                        if let endDate = record["endDate"] {
                            FameFitLogger.info("End Date: \(endDate)", category: FameFitLogger.cloudKit)
                        }
                        FameFitLogger.info("================================", category: FameFitLogger.cloudKit)
                    }
                    recordIndex += 1
                    return record
                }
                return nil
            }.compactMap { workout(from: $0) }
            
            return (workouts, cursor)
        }
    }
    
    // MARK: - Workout History

    func saveWorkout(_ workoutHistory: Workout) {
        guard isSignedIn else {
            FameFitLogger.error(
                "Cannot save workout history - not signed in", category: FameFitLogger.cloudKit
            )
            return
        }

        FameFitLogger.info(
            "📝 Attempting to save workout history to CloudKit:", category: FameFitLogger.cloudKit
        )
        FameFitLogger.info("   - Type: \(workoutHistory.workoutType)", category: FameFitLogger.cloudKit)
        FameFitLogger.info("   - Date: \(workoutHistory.endDate)", category: FameFitLogger.cloudKit)
        FameFitLogger.info(
            "   - Duration: \(Int(workoutHistory.duration / 60)) minutes", category: FameFitLogger.cloudKit
        )
        FameFitLogger.info(
            "   - XP: \(workoutHistory.effectiveXPEarned)", category: FameFitLogger.cloudKit
        )

        let record = CKRecord(recordType: "Workouts")
        record["workoutId"] = workoutHistory.id.uuidString
        record["workoutType"] = workoutHistory.workoutType
        record["startDate"] = workoutHistory.startDate
        record["endDate"] = workoutHistory.endDate
        record["duration"] = workoutHistory.duration
        record["totalEnergyBurned"] = workoutHistory.totalEnergyBurned
        record["totalDistance"] = workoutHistory.totalDistance
        record["averageHeartRate"] = workoutHistory.averageHeartRate
        record["xpEarned"] = workoutHistory.effectiveXPEarned
        record["source"] = workoutHistory.source

        privateDatabase.save(record) { [weak self] savedRecord, error in
            if let error {
                FameFitLogger.error(
                    "❌ Failed to save workout history", error: error, category: FameFitLogger.cloudKit
                )
                FameFitLogger.error(
                    "   Error details: \(error.localizedDescription)", category: FameFitLogger.cloudKit
                )
            } else if let savedRecord {
                FameFitLogger.info(
                    "✅ Workout history saved successfully!", category: FameFitLogger.cloudKit
                )
                FameFitLogger.info(
                    "   - Record ID: \(savedRecord.recordID.recordName)",
                    category: FameFitLogger.cloudKit
                )
                FameFitLogger.info(
                    "   - Workout: \(workoutHistory.workoutType) on \(workoutHistory.endDate)",
                    category: FameFitLogger.cloudKit
                )
                
                // Create XP transaction for audit trail
                Task { [weak self] in
                    await self?.createXPTransaction(for: workoutHistory, workoutRecordID: savedRecord.recordID.recordName)
                }
                
                // Update user stats immediately for data consistency
                Task { [weak self] in
                    do {
                        try await self?.updateUserStatsAfterWorkout(workoutHistory)
                        FameFitLogger.info("✅ User stats updated after workout save", category: FameFitLogger.cloudKit)
                    } catch {
                        FameFitLogger.error("❌ Failed to update user stats after workout", error: error, category: FameFitLogger.cloudKit)
                    }
                }
            }
        }
    }

    func fetchWorkouts(completion: @escaping (Result<[Workout], Error>) -> Void) {
        guard isSignedIn else {
            FameFitLogger.error(
                "❌ Cannot fetch workout history - not signed in", category: FameFitLogger.cloudKit
            )
            completion(.failure(FameFitError.cloudKitNotAvailable))
            return
        }

        FameFitLogger.info(
            "🔍 Starting workout history fetch from CloudKit", category: FameFitLogger.cloudKit
        )
        FameFitLogger.info("   - User signed in: \(isSignedIn)", category: FameFitLogger.cloudKit)
        FameFitLogger.info("   - Using private database", category: FameFitLogger.cloudKit)

        // Alternative approach: Use CKFetchRecordsOperation without a query
        // First, we need to get all record IDs, but since we can't query...
        // Let's use a different strategy: fetch recent records using a zone-based approach

        // For now, let's try a very simple predicate that CloudKit should accept
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Workouts", predicate: predicate)

        // Add explicit sort descriptor to avoid CloudKit using recordName
        query.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: false)]

        // Use the older API that might be more forgiving
        var workouts: [Workout] = []

        privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) {
            [weak self] result in
            switch result {
            case let .failure(error):
                FameFitLogger.error("Fetch failed", error: error, category: FameFitLogger.cloudKit)

                // If we get any query error, just return empty for now
                if error.localizedDescription.contains("marked queryable")
                    || error.localizedDescription.contains("Did not find record type") {
                    FameFitLogger.info(
                        "Query not supported or record type missing - returning empty",
                        category: FameFitLogger.cloudKit
                    )
                    completion(.success([]))
                    return
                }

                completion(.failure(error))

            case let .success((matchResults, _)):
                FameFitLogger.info(
                    "✅ Query successful! Found \(matchResults.count) workout records",
                    category: FameFitLogger.cloudKit
                )

                for (_, recordResult) in matchResults {
                    switch recordResult {
                    case let .success(record):
                        if let historyItem = self?.workout(from: record) {
                            workouts.append(historyItem)
                            FameFitLogger.info(
                                "📊 Parsed workout: \(historyItem.workoutType) from \(historyItem.endDate)",
                                category: FameFitLogger.cloudKit
                            )
                        }
                    case let .failure(error):
                        FameFitLogger.error(
                            "Failed to fetch individual record", error: error, category: FameFitLogger.cloudKit
                        )
                    }
                }

                // Sort by endDate descending
                workouts.sort { $0.endDate > $1.endDate }
                completion(.success(workouts))
            }
        }
    }

    private func workout(from record: CKRecord) -> Workout? {
        guard let workoutId = record["workoutId"] as? String,
              let workoutType = record["workoutType"] as? String,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date,
              let duration = record["duration"] as? TimeInterval,
              let totalEnergyBurned = record["totalEnergyBurned"] as? Double,
              let source = record["source"] as? String,
              let id = UUID(uuidString: workoutId)
        else {
            return nil
        }

        // Read XP - required field
        let xp = record["xpEarned"] as? Int ?? 0

        return Workout(
            id: id,
            workoutType: workoutType,
            startDate: startDate,
            endDate: endDate,
            duration: duration,
            totalEnergyBurned: totalEnergyBurned,
            totalDistance: record["totalDistance"] as? Double,
            averageHeartRate: record["averageHeartRate"] as? Double,
            followersEarned: xp, // Deprecated field
            xpEarned: xp,
            source: source
        )
    }

    // MARK: - Debug Methods
    
    /// Force reset stats to zero (bypass workout query)
    func forceResetStats() async throws {
        guard let userRecord else {
            throw FameFitError.cloudKitUserNotFound
        }
        
        FameFitLogger.info("🔧 Force resetting stats to zero", category: FameFitLogger.cloudKit)
        
        // Reset user stats
        userRecord["totalWorkouts"] = 0
        userRecord["totalXP"] = 0
        userRecord["influencerXP"] = 0
        userRecord["currentStreak"] = 0
        userRecord["lastWorkoutTimestamp"] = nil
        userRecord["lastRecalculationDate"] = Date()
        
        try await privateDatabase.save(userRecord)
        
        // Update local cached values
        await MainActor.run {
            self.totalWorkouts = 0
            self.totalXP = 0
            self.currentStreak = 0
            self.lastWorkoutTimestamp = nil
        }
        
        // Clear the recalculation timestamp to force recalc next time
        UserDefaults.standard.removeObject(forKey: recalculationIntervalKey)
        
        FameFitLogger.info("✅ Stats force reset to zero", category: FameFitLogger.cloudKit)
    }
    
    /// Checks CloudKit environment and database state
    func debugCloudKitEnvironment() async throws {
        FameFitLogger.info("===== CLOUDKIT ENVIRONMENT DEBUG =====", category: FameFitLogger.cloudKit)
        FameFitLogger.info("Container ID: \(container.containerIdentifier ?? "unknown")", category: FameFitLogger.cloudKit)
        
        // Check account status
        let status = try await container.accountStatus()
        FameFitLogger.info("Account Status: \(status)", category: FameFitLogger.cloudKit)
        
        // Fetch user record ID
        if let userRecordID = try? await container.userRecordID() {
            FameFitLogger.info("User Record ID: \(userRecordID.recordName)", category: FameFitLogger.cloudKit)
        }
        
        // Check what record types exist - get actual count, not just 1
        FameFitLogger.info("Checking Workouts table...", category: FameFitLogger.cloudKit)
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Workouts", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: false)]
        
        // Get total count
        var totalCount = 0
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            let (results, nextCursor) = try await privateDatabase.records(
                matching: query,
                resultsLimit: 100
            )
            totalCount += results.count
            cursor = nextCursor
        } while cursor != nil
        
        FameFitLogger.info("Found \(totalCount) TOTAL workout record(s) in Workouts table", category: FameFitLogger.cloudKit)
        
        // Show first few workout details
        if totalCount > 0 {
            FameFitLogger.info("Getting details of first few workouts...", category: FameFitLogger.cloudKit)
            let detailQuery = CKQuery(recordType: "Workouts", predicate: predicate)
            detailQuery.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: false)]
            
            let (detailResults, _) = try await privateDatabase.records(
                matching: detailQuery,
                resultsLimit: 3
            )
            
            for (index, (_, result)) in detailResults.enumerated() {
                if let record = try? result.get() {
                    FameFitLogger.info("Workout #\(index + 1):", category: FameFitLogger.cloudKit)
                    FameFitLogger.info("  ID: \(record.recordID.recordName)", category: FameFitLogger.cloudKit)
                    FameFitLogger.info("  Type: \(record["workoutType"] ?? "unknown")", category: FameFitLogger.cloudKit)
                    FameFitLogger.info("  Date: \(record["endDate"] ?? "unknown")", category: FameFitLogger.cloudKit)
                    FameFitLogger.info("  Source: \(record["source"] ?? "unknown")", category: FameFitLogger.cloudKit)
                }
            }
        }
        
        // Check workout history table (old schema)
        let historyQuery = CKQuery(recordType: "WorkoutHistory", predicate: predicate)
        do {
            let (historyResults, _) = try await privateDatabase.records(
                matching: historyQuery,
                resultsLimit: 1
            )
            FameFitLogger.info("Found \(historyResults.count) WorkoutHistory record(s) (old schema)", category: FameFitLogger.cloudKit)
        } catch {
            FameFitLogger.info("WorkoutHistory table not found or accessible", category: FameFitLogger.cloudKit)
        }
        
        FameFitLogger.info("=====================================", category: FameFitLogger.cloudKit)
    }
    
    /// Clears all workout records and resets user stats (DEBUG ONLY)
    func clearAllWorkoutsAndResetStats() async throws {
        guard let userRecord else {
            throw FameFitError.cloudKitUserNotFound
        }
        
        FameFitLogger.info("🗑️ Starting complete workout cleanup", category: FameFitLogger.cloudKit)
        
        // First, fetch all workouts to delete them
        let allWorkouts = try await fetchAllWorkouts()
        FameFitLogger.info("🗑️ Found \(allWorkouts.count) workouts to delete", category: FameFitLogger.cloudKit)
        
        // Delete all workout records
        if !allWorkouts.isEmpty {
            // Since we can't easily get record IDs from Workout, let's query and delete
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "Workouts", predicate: predicate)
            
            var allRecordIDs: [CKRecord.ID] = []
            var cursor: CKQueryOperation.Cursor?
            
            repeat {
                let (results, nextCursor) = try await privateDatabase.records(
                    matching: query,
                    desiredKeys: nil,
                    resultsLimit: 100
                )
                
                for (recordID, _) in results {
                    allRecordIDs.append(recordID)
                }
                
                cursor = nextCursor
            } while cursor != nil
            
            FameFitLogger.info("🗑️ Deleting \(allRecordIDs.count) workout records", category: FameFitLogger.cloudKit)
            
            // Delete in batches
            for i in stride(from: 0, to: allRecordIDs.count, by: 100) {
                let batch = Array(allRecordIDs[i..<min(i + 100, allRecordIDs.count)])
                _ = try await privateDatabase.modifyRecords(saving: [], deleting: batch)
                FameFitLogger.info("🗑️ Deleted batch of \(batch.count) records", category: FameFitLogger.cloudKit)
            }
        }
        
        // Reset user stats
        userRecord["totalWorkouts"] = 0
        userRecord["totalXP"] = 0
        userRecord["influencerXP"] = 0
        userRecord["currentStreak"] = 0
        userRecord["lastWorkoutTimestamp"] = nil
        userRecord["lastRecalculationDate"] = Date()
        
        try await privateDatabase.save(userRecord)
        
        // Update local cached values
        await MainActor.run {
            self.totalWorkouts = 0
            self.totalXP = 0
            self.currentStreak = 0
            self.lastWorkoutTimestamp = nil
        }
        
        FameFitLogger.info("✅ All workouts cleared and stats reset to zero", category: FameFitLogger.cloudKit)
    }
    
    // MARK: - Profile Sync

    /// Syncs user stats from the private Users table to the public UserProfiles table
    func syncUserProfile(profile: UserProfile, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userRecord else {
            completion(.failure(CKError(.internalError)))
            return
        }

        // Create updated profile with current stats from Users table
        let updatedProfile = UserProfile(
            id: profile.id,
            userID: userRecord.recordID.recordName,
            username: profile.username,
            bio: profile.bio,
            workoutCount: totalWorkouts,
            totalXP: totalXP,
            createdTimestamp: profile.createdTimestamp,
            modifiedTimestamp: Date(),
            isVerified: profile.isVerified,
            privacyLevel: profile.privacyLevel,
            profileImageURL: profile.profileImageURL,
            headerImageURL: profile.headerImageURL
        )

        // Convert to CloudKit record
        let recordID = CKRecord.ID(recordName: profile.id)
        let profileRecord = updatedProfile.toCKRecord(recordID: recordID)

        // Save to public database
        let publicDatabase = CKContainer.default().publicCloudDatabase
        publicDatabase.save(profileRecord) { _, error in
            if let error {
                FameFitLogger.error(
                    "Failed to sync profile", error: error, category: FameFitLogger.cloudKit
                )
                completion(.failure(error))
            } else {
                FameFitLogger.info(
                    "✅ Successfully synced profile to public database", category: FameFitLogger.cloudKit
                )
                completion(.success(()))
            }
        }
    }
    
    // MARK: - XP Transaction Creation
    
    private func createXPTransaction(for workout: Workout, workoutRecordID: String) async {
        guard let currentUserID = currentUserID,
              let xpTransactionService = xpTransactionService else {
            FameFitLogger.error(
                "Cannot create XP transaction - missing user ID or service",
                category: FameFitLogger.cloudKit
            )
            return
        }
        
        // Calculate XP with detailed factors
        let userStats = UserStats(
            totalWorkouts: totalWorkouts,
            currentStreak: currentStreak,
            recentWorkouts: [], // Would need to fetch recent workouts for full implementation
            totalXP: totalXP
        )
        
        let result = XPCalculator.calculateXP(for: workout, userStats: userStats)
        
        do {
            let transaction = try await xpTransactionService.createTransaction(
                userRecordID: currentUserID,
                workoutRecordID: workoutRecordID,
                baseXP: result.baseXP,
                finalXP: result.finalXP,
                factors: result.factors
            )
            
            FameFitLogger.info(
                "✅ XP Transaction created: \(transaction.id.uuidString)",
                category: FameFitLogger.cloudKit
            )
            FameFitLogger.info(
                "   - Base XP: \(result.baseXP), Final XP: \(result.finalXP)",
                category: FameFitLogger.cloudKit
            )
            FameFitLogger.info(
                "   - Multiplier: \(result.factors.totalMultiplier)x",
                category: FameFitLogger.cloudKit
            )
        } catch {
            FameFitLogger.error(
                "❌ Failed to create XP transaction",
                error: error,
                category: FameFitLogger.cloudKit
            )
        }
    }
}
