import Foundation
import CloudKit
import AuthenticationServices
import os.log
import HealthKit
import Combine

class CloudKitManager: NSObject, ObservableObject, CloudKitManaging {
    private let container = CKContainer(identifier: "iCloud.com.jimmypocock.FameFit")
    private let privateDatabase: CKDatabase
    private let schemaManager: CloudKitSchemaManager
    
    @Published var isSignedIn = false
    @Published var userRecord: CKRecord?
    @Published var influencerXP: Int = 0
    @Published var userName: String = ""
    @Published var currentStreak: Int = 0
    @Published var totalWorkouts: Int = 0
    @Published var lastWorkoutTimestamp: Date?
    @Published var joinTimestamp: Date?
    @Published var lastError: FameFitError?
    
    
    weak var authenticationManager: AuthenticationManager?
    weak var unlockNotificationService: UnlockNotificationServiceProtocol?
    
    var isAvailable: Bool {
        isSignedIn
    }
    
    // MARK: - Publisher Properties
    var isAvailablePublisher: AnyPublisher<Bool, Never> {
        $isSignedIn.eraseToAnyPublisher()
    }
    
    
    var influencerXPPublisher: AnyPublisher<Int, Never> {
        $influencerXP.eraseToAnyPublisher()
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
        self.privateDatabase = container.privateCloudDatabase
        self.schemaManager = CloudKitSchemaManager(container: container)
        super.init()
        checkAccountStatus()
    }
    
    func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
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
    
    func setupUserRecord(userID: String, displayName: String) {
        // Use CloudKit's user record ID instead of Apple Sign In ID
        container.fetchUserRecordID { [weak self] recordID, error in
            guard let recordID = recordID else { return }
            
            self?.privateDatabase.fetch(withRecordID: recordID) { existingRecord, fetchError in
                let userRecord = existingRecord ?? CKRecord(recordType: "UserProfiles", recordID: recordID)
        
                // Only update if this is a new record
                if existingRecord == nil {
                    userRecord["displayName"] = displayName
                    userRecord["influencerXP"] = 0
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
                        if let error = error {
                            self?.lastError = error.fameFitError
                            return
                        }
                        
                        if let record = record {
                            self?.userRecord = record
                            self?.influencerXP = record["influencerXP"] as? Int ?? 0
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
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = error.fameFitError
                }
                return
            }
            
            guard let recordID = recordID else {
                DispatchQueue.main.async {
                    self?.lastError = .cloudKitUserNotFound
                }
                return
            }
            
            self?.privateDatabase.fetch(withRecordID: recordID) { record, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.lastError = error.fameFitError
                        return
                    }
                    
                    if let record = record {
                        self?.userRecord = record
                        
                        // Read XP field
                        self?.influencerXP = record["influencerXP"] as? Int ?? 0
                        
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
        
        guard let userRecord = userRecord else {
            FameFitLogger.notice("No user record found - fetching...", category: FameFitLogger.cloudKit)
            fetchUserRecord()
            return
        }
        
        let currentXP = userRecord["influencerXP"] as? Int ?? 0
        let currentTotal = userRecord["totalWorkouts"] as? Int ?? 0
        
        FameFitLogger.debug("Current XP: \(currentXP), workouts: \(currentTotal)", category: FameFitLogger.cloudKit)
        
        userRecord["influencerXP"] = currentXP + xp
        userRecord["totalWorkouts"] = currentTotal + 1
        userRecord["lastWorkoutTimestamp"] = Date()
        
        FameFitLogger.debug("New XP: \(currentXP + xp), workouts: \(currentTotal + 1)", category: FameFitLogger.cloudKit)
        
        updateStreakIfNeeded(userRecord)
        
        // Store previous XP for unlock checking
        let previousXP = currentXP
        
        privateDatabase.save(userRecord) { [weak self] record, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = error.fameFitError
                    return
                }
                
                if let record = record {
                    self?.userRecord = record
                    
                    // Update XP
                    self?.influencerXP = record["influencerXP"] as? Int ?? 0
                    
                    // Check for new unlocks
                    if let newXP = record["influencerXP"] as? Int {
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
        let daysSinceLastWorkout = calendar.dateComponents([.day], from: lastWorkoutTimestamp, to: Date()).day ?? 0
        
        if daysSinceLastWorkout <= 1 {
            record["currentStreak"] = currentStreak + 1
        } else {
            record["currentStreak"] = 1
        }
    }
    
    
    func getXPTitle() -> String {
        switch influencerXP {
        case 0..<100:
            return "Fitness Newbie"
        case 100..<1_000:
            return "Micro-Influencer"
        case 1_000..<10_000:
            return "Rising Star"
        case 10_000..<100_000:
            return "Verified Influencer"
        default:
            return "FameFit Elite"
        }
    }
    
    
    func recordWorkout(_ workout: HKWorkout, completion: @escaping (Bool) -> Void) {
        // For now, just increase followers when a workout is recorded
        addFollowers(5)
        completion(true)
    }
    
    // MARK: - Workout History
    
    func saveWorkoutHistory(_ workoutHistory: WorkoutHistoryItem) {
        guard isSignedIn else {
            FameFitLogger.error("Cannot save workout history - not signed in", category: FameFitLogger.cloudKit)
            return
        }
        
        FameFitLogger.info("📝 Attempting to save workout history to CloudKit:", category: FameFitLogger.cloudKit)
        FameFitLogger.info("   - Type: \(workoutHistory.workoutType)", category: FameFitLogger.cloudKit)
        FameFitLogger.info("   - Date: \(workoutHistory.endDate)", category: FameFitLogger.cloudKit)
        FameFitLogger.info("   - Duration: \(Int(workoutHistory.duration/60)) minutes", category: FameFitLogger.cloudKit)
        FameFitLogger.info("   - XP: \(workoutHistory.effectiveXPEarned)", category: FameFitLogger.cloudKit)
        
        let record = CKRecord(recordType: "WorkoutHistory")
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
        
        privateDatabase.save(record) { savedRecord, error in
            if let error = error {
                FameFitLogger.error("❌ Failed to save workout history", error: error, category: FameFitLogger.cloudKit)
                FameFitLogger.error("   Error details: \(error.localizedDescription)", category: FameFitLogger.cloudKit)
            } else {
                FameFitLogger.info("✅ Workout history saved successfully!", category: FameFitLogger.cloudKit)
                FameFitLogger.info("   - Record ID: \(savedRecord?.recordID.recordName ?? "unknown")", category: FameFitLogger.cloudKit)
                FameFitLogger.info("   - Workout: \(workoutHistory.workoutType) on \(workoutHistory.endDate)", category: FameFitLogger.cloudKit)
            }
        }
    }
    
    func fetchWorkoutHistory(completion: @escaping (Result<[WorkoutHistoryItem], Error>) -> Void) {
        guard isSignedIn else {
            FameFitLogger.error("❌ Cannot fetch workout history - not signed in", category: FameFitLogger.cloudKit)
            completion(.failure(FameFitError.cloudKitNotAvailable))
            return
        }
        
        FameFitLogger.info("🔍 Starting workout history fetch from CloudKit", category: FameFitLogger.cloudKit)
        FameFitLogger.info("   - User signed in: \(isSignedIn)", category: FameFitLogger.cloudKit)
        FameFitLogger.info("   - Using private database", category: FameFitLogger.cloudKit)
        
        // Alternative approach: Use CKFetchRecordsOperation without a query
        // First, we need to get all record IDs, but since we can't query...
        // Let's use a different strategy: fetch recent records using a zone-based approach
        
        // For now, let's try a very simple predicate that CloudKit should accept
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "WorkoutHistory", predicate: predicate)
        
        // Add explicit sort descriptor to avoid CloudKit using recordName
        query.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: false)]
        
        // Use the older API that might be more forgiving
        var workoutHistoryItems: [WorkoutHistoryItem] = []
        
        privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { [weak self] result in
            switch result {
            case .failure(let error):
                FameFitLogger.error("Fetch failed", error: error, category: FameFitLogger.cloudKit)
                
                // If we get any query error, just return empty for now
                if error.localizedDescription.contains("marked queryable") ||
                   error.localizedDescription.contains("Did not find record type") {
                    FameFitLogger.info("Query not supported or record type missing - returning empty", category: FameFitLogger.cloudKit)
                    completion(.success([]))
                    return
                }
                
                completion(.failure(error))
                
            case .success((let matchResults, _)):
                FameFitLogger.info("✅ Query successful! Found \(matchResults.count) workout records", category: FameFitLogger.cloudKit)
                
                for (_, recordResult) in matchResults {
                    switch recordResult {
                    case .success(let record):
                        if let historyItem = self?.workoutHistoryItem(from: record) {
                            workoutHistoryItems.append(historyItem)
                            FameFitLogger.info("📊 Parsed workout: \(historyItem.workoutType) from \(historyItem.endDate)", category: FameFitLogger.cloudKit)
                        }
                    case .failure(let error):
                        FameFitLogger.error("Failed to fetch individual record", error: error, category: FameFitLogger.cloudKit)
                    }
                }
                
                // Sort by endDate descending
                workoutHistoryItems.sort { $0.endDate > $1.endDate }
                completion(.success(workoutHistoryItems))
            }
        }
    }
    
    private func workoutHistoryItem(from record: CKRecord) -> WorkoutHistoryItem? {
        guard let workoutId = record["workoutId"] as? String,
              let workoutType = record["workoutType"] as? String,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date,
              let duration = record["duration"] as? TimeInterval,
              let totalEnergyBurned = record["totalEnergyBurned"] as? Double,
              let source = record["source"] as? String,
              let id = UUID(uuidString: workoutId) else {
            return nil
        }
        
        // Read XP - required field
        let xp = record["xpEarned"] as? Int ?? 0
        
        return WorkoutHistoryItem(
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
}
