import CloudKit
import Combine
@testable import FameFit
import Foundation
import HealthKit

/// Mock CloudKitService for unit testing
class MockCloudKitService: ObservableObject, CloudKitProtocol {
    // MARK: - CloudKitProtocol Properties
    
    @Published var isAvailable: Bool = true
    @Published var currentUserID: String? = "mock-user-id"
    @Published var totalXP: Int = 100
    @Published var totalWorkouts: Int = 20
    @Published var currentStreak: Int = 5
    @Published var username: String = "Test User"
    @Published var lastWorkoutTimestamp: Date? = Date().addingTimeInterval(-24 * 60 * 60)
    @Published var lastError: FameFitError?
    
    // Publishers
    var isAvailablePublisher: AnyPublisher<Bool, Never> {
        $isAvailable.eraseToAnyPublisher()
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
    
    var usernamePublisher: AnyPublisher<String, Never> {
        $username.eraseToAnyPublisher()
    }
    
    var lastWorkoutTimestampPublisher: AnyPublisher<Date?, Never> {
        $lastWorkoutTimestamp.eraseToAnyPublisher()
    }
    
    var lastErrorPublisher: AnyPublisher<FameFitError?, Never> {
        $lastError.eraseToAnyPublisher()
    }
    
    // CloudKit databases
    var database: CKDatabase { 
        CKContainer(identifier: CloudKitConfiguration.containerIdentifier).privateCloudDatabase 
    }
    var publicDatabase: CKDatabase { 
        CKContainer(identifier: CloudKitConfiguration.containerIdentifier).publicCloudDatabase 
    }
    var privateDatabase: CKDatabase { 
        CKContainer(identifier: CloudKitConfiguration.containerIdentifier).privateCloudDatabase 
    }
    
    // MARK: - Mock Properties
    
    var mockPublicDatabase: MockCKDatabase!
    var mockPrivateDatabase: MockCKDatabase!
    
    // Track method calls
    var addFollowersCalled = false
    var addFollowersCallCount = 0
    var lastAddedFollowerCount = 0
    var addXPCalled = false
    var addXPCallCount = 0
    var lastAddedXPCount = 0
    var fetchUserRecordCalled = false
    var recordWorkoutCalled = false
    var addFollowersCalls: [(count: Int, date: Date)] = []
    var addXPCalls: [(xp: Int, date: Date)] = []
    var saveCallCount = 0
    var mockRecords: [CKRecord] = []
    var mockRecordsByID: [String: CKRecord] = [:]
    var mockQueryResults: [CKRecord] = []
    var savedRecords: [CKRecord] = []
    
    // Control test behavior
    var shouldFail = false
    var shouldFailAddFollowers = false
    var shouldFailAddXP = false
    var shouldFailFetchUserRecord = false
    var mockIsAvailable = true
    var mockCurrentUserID: String? = "mock-user-id"
    
    // Additional mock properties
    var isSignedIn = true
    var userRecord: CKRecord?
    var workoutHistory: [Workout] = []
    
    // MARK: - Initialization
    
    init() {
        // Initialize mock databases
        mockPublicDatabase = MockCKDatabase()
        mockPrivateDatabase = MockCKDatabase()
    }
    
    // MARK: - CloudKitProtocol Methods
    
    func checkAccountStatus() {
        // Mock is always signed in and ready
        isSignedIn = true
    }
    
    func fetchUserRecord() {
        fetchUserRecordCalled = true
        
        if shouldFailFetchUserRecord {
            lastError = .cloudKitUserNotFound
        } else {
            // Simulate successful fetch with no changes
            lastError = nil
        }
    }
    
    func addXP(_ xp: Int) {
        addXPCalled = true
        addXPCallCount += 1
        lastAddedXPCount = xp
        addXPCalls.append((xp: xp, date: Date()))
        
        if !shouldFailAddXP {
            // Update values synchronously
            let newXP = totalXP + xp
            let newWorkoutCount = totalWorkouts + 1
            
            totalXP = newXP
            totalWorkouts = newWorkoutCount
            lastWorkoutTimestamp = Date()
            lastError = nil
        } else {
            lastError = .cloudKitSyncFailed(NSError(domain: "MockError", code: 1))
        }
    }
    
    func recordWorkout(_ workout: HKWorkout, completion: @escaping (Bool) -> Void) {
        recordWorkoutCalled = true
        
        DispatchQueue.main.async {
            completion(!self.shouldFailAddFollowers)
        }
    }
    
    func getXPTitle() -> String {
        switch totalXP {
        case 0 ..< 100:
            return "Fitness Newbie"
        case 100 ..< 1_000:
            return "Micro-Influencer"
        case 1_000 ..< 10_000:
            return "Rising Star"
        case 10_000 ..< 100_000:
            return "Verified Influencer"
        default:
            return "FameFit Elite"
        }
    }
    
    func saveWorkout(_ workout: Workout) async throws {
        if shouldFail {
            throw FameFitError.cloudKitSyncFailed(NSError(domain: "MockError", code: 1))
        }
        workoutHistory.append(workout)
    }
    
    func fetchWorkouts(completion: @escaping (Result<[Workout], Error>) -> Void) {
        // Sort by endDate descending to match CloudKit implementation
        let sortedHistory = workoutHistory.sorted { $0.endDate > $1.endDate }
        completion(.success(sortedHistory))
    }
    
    func recalculateStatsIfNeeded() async throws {
        // Mock implementation - no-op for tests
    }
    
    func recalculateUserStats() async throws {
        // Mock implementation - no-op for tests
    }
    
    func clearAllWorkoutsAndResetStats() async throws {
        // Mock implementation - reset all stats
        totalXP = 0
        totalWorkouts = 0
        currentStreak = 0
        lastWorkoutTimestamp = nil
        workoutHistory = []
    }
    
    func debugCloudKitEnvironment() async throws {
        // Mock implementation - no-op for tests
    }
    
    func forceResetStats() async throws {
        // Mock implementation - reset all stats
        totalXP = 0
        totalWorkouts = 0
        currentStreak = 0
        lastWorkoutTimestamp = nil
    }
    
    // CloudKit operations
    func fetchRecords(withQuery query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?) async throws -> [CKRecord] {
        if shouldFail {
            throw FameFitError.cloudKitSyncFailed(NSError(domain: "MockError", code: 1))
        }
        return mockQueryResults
    }
    
    func fetchRecords(ofType recordType: String, predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?, limit: Int?) async throws -> [CKRecord] {
        if shouldFail {
            throw FameFitError.cloudKitSyncFailed(NSError(domain: "MockError", code: 1))
        }
        return mockRecords
    }
    
    func save(_ record: CKRecord) async throws -> CKRecord {
        saveCallCount += 1
        mockRecords.append(record)
        mockRecordsByID[record.recordID.recordName] = record
        savedRecords.append(record)
        if shouldFail {
            throw FameFitError.cloudKitSyncFailed(NSError(domain: "MockError", code: 1))
        }
        return record
    }
    
    func delete(withRecordID recordID: CKRecord.ID) async throws {
        if shouldFail {
            throw FameFitError.cloudKitSyncFailed(NSError(domain: "MockError", code: 1))
        }
        mockRecordsByID.removeValue(forKey: recordID.recordName)
        mockRecords.removeAll { $0.recordID == recordID }
    }
    
    func getCurrentUserID() async throws -> String {
        guard let userID = currentUserID else {
            throw FameFitError.cloudKitUserNotFound
        }
        return userID
    }
    
    // MARK: - Test Helper Methods
    
    func addFollowers(_ count: Int) {
        addFollowersCalled = true
        addFollowersCallCount += 1
        lastAddedFollowerCount = count
        addFollowersCalls.append((count: count, date: Date()))
        
        // Match the real implementation - addFollowers calls addXP
        addXP(count)
    }
    
    func reset() {
        addFollowersCalled = false
        addFollowersCallCount = 0
        lastAddedFollowerCount = 0
        addXPCalled = false
        addXPCallCount = 0
        lastAddedXPCount = 0
        fetchUserRecordCalled = false
        recordWorkoutCalled = false
        addFollowersCalls.removeAll()
        addXPCalls.removeAll()
        
        totalXP = 100
        totalWorkouts = 20
        currentStreak = 5
        lastWorkoutTimestamp = Date().addingTimeInterval(-24 * 60 * 60)
        lastError = nil
    }
    
    func simulateUserSignOut() {
        isSignedIn = false
        userRecord = nil
        totalXP = 0
        username = ""
        currentStreak = 0
        totalWorkouts = 0
        lastWorkoutTimestamp = nil
    }
    
    func resetUserStats() {
        totalXP = 0
        totalWorkouts = 0
        currentStreak = 0
        lastWorkoutTimestamp = nil
    }
    
    func checkAvailability() async {
        // Mock is always available
        isSignedIn = true
    }
}