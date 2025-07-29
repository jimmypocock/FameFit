import CloudKit
import Combine
@testable import FameFit
import Foundation
import HealthKit

/// Mock CloudKitManager for unit testing
class MockCloudKitManager: CloudKitManager {
    // MARK: - Database Mocking

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
    var saveCallCount = 0 // Add this property
    var mockRecords: [String: CKRecord] = [:] // Add this property
    var mockQueryResults: [CKRecord] = [] // Add this property

    // Control test behavior
    var shouldFailAddFollowers = false
    var shouldFailAddXP = false
    var shouldFailFetchUserRecord = false
    var mockIsAvailable = true
    var mockCurrentUserID: String? = "mock-user-id"

    // Override parent properties to set initial values
    override init() {
        // Initialize mock databases first
        mockPublicDatabase = MockCKDatabase()
        mockPrivateDatabase = MockCKDatabase()

        super.init()

        // Set initial test values
        isSignedIn = true
        totalXP = 100
        userName = "Test User"
        currentStreak = 5
        totalWorkouts = 20
        joinTimestamp = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        lastWorkoutTimestamp = Date().addingTimeInterval(-24 * 60 * 60)
    }

    // Note: We can't expose publicDatabase/privateDatabase as CKDatabase
    // because MockCKDatabase can't inherit from CKDatabase (no public init)

    // Publishers
    override var isAvailablePublisher: AnyPublisher<Bool, Never> {
        Just(isAvailable).eraseToAnyPublisher()
    }

    override var totalXPPublisher: AnyPublisher<Int, Never> {
        $totalXP.eraseToAnyPublisher()
    }

    override var totalWorkoutsPublisher: AnyPublisher<Int, Never> {
        $totalWorkouts.eraseToAnyPublisher()
    }

    override var currentStreakPublisher: AnyPublisher<Int, Never> {
        $currentStreak.eraseToAnyPublisher()
    }

    override var userNamePublisher: AnyPublisher<String, Never> {
        $userName.eraseToAnyPublisher()
    }

    override var lastWorkoutTimestampPublisher: AnyPublisher<Date?, Never> {
        $lastWorkoutTimestamp.eraseToAnyPublisher()
    }

    override var joinTimestampPublisher: AnyPublisher<Date?, Never> {
        $joinTimestamp.eraseToAnyPublisher()
    }

    override var lastErrorPublisher: AnyPublisher<FameFitError?, Never> {
        $lastError.eraseToAnyPublisher()
    }

    // Override CloudKit availability
    override var isAvailable: Bool {
        mockIsAvailable
    }

    override var currentUserID: String? {
        get { mockCurrentUserID }
        set { mockCurrentUserID = newValue }
    }

    override func checkAccountStatus() {
        // Mock is always signed in and ready
        isSignedIn = true
    }

    func checkAvailability() async {
        // Mock is always available
        isSignedIn = true
    }

    // Mock CloudKit database access
    func save(_ record: CKRecord) async throws -> CKRecord {
        saveCallCount += 1
        mockRecords[record.recordID.recordName] = record
        return record
    }

    func query(_: CKQuery, in _: CKDatabase? = nil) async throws -> [CKRecord] {
        mockQueryResults
    }

    override func addFollowers(_ count: Int) {
        addFollowersCalled = true
        addFollowersCallCount += 1
        lastAddedFollowerCount = count
        addFollowersCalls.append((count: count, date: Date()))

        // Match the real implementation - addFollowers calls addXP
        addXP(count)
    }

    override func addXP(_ xp: Int) {
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

    override func setupUserRecord(userID: String, displayName: String) {
        // Mock implementation - just update the properties
        mockCurrentUserID = userID
        userName = displayName
    }

    override func fetchUserRecord() {
        fetchUserRecordCalled = true

        if shouldFailFetchUserRecord {
            lastError = .cloudKitUserNotFound
        } else {
            // Simulate successful fetch with no changes
            lastError = nil
        }
    }

    override func recordWorkout(_: HKWorkout, completion: @escaping (Bool) -> Void) {
        recordWorkoutCalled = true

        DispatchQueue.main.async {
            completion(!self.shouldFailAddFollowers)
        }
    }

    // Test helper methods
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
        joinTimestamp = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        lastWorkoutTimestamp = Date().addingTimeInterval(-24 * 60 * 60)
        lastError = nil
    }

    func simulateUserSignOut() {
        isSignedIn = false
        userRecord = nil
        totalXP = 0
        userName = ""
        currentStreak = 0
        totalWorkouts = 0
        joinTimestamp = nil
        lastWorkoutTimestamp = nil
    }

    // MARK: - Workout History

    private var workoutHistory: [WorkoutHistoryItem] = []

    override func saveWorkoutHistory(_ workoutHistory: WorkoutHistoryItem) {
        self.workoutHistory.append(workoutHistory)
    }

    override func fetchWorkoutHistory(completion: @escaping (Result<[WorkoutHistoryItem], Error>) -> Void) {
        // Sort by endDate descending to match CloudKit implementation
        let sortedHistory = workoutHistory.sorted { $0.endDate > $1.endDate }
        completion(.success(sortedHistory))
    }

    // Override the new XP title method
    override func getXPTitle() -> String {
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
}
