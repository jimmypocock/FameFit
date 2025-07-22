import Foundation
import CloudKit
import HealthKit
@testable import FameFit

/// Mock CloudKitManager for unit testing
class MockCloudKitManager: CloudKitManager {
    
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
    
    // Control test behavior
    var shouldFailAddFollowers = false
    var shouldFailAddXP = false
    var shouldFailFetchUserRecord = false
    var mockIsAvailable = true
    
    // Override CloudKit availability
    override var isAvailable: Bool {
        return mockIsAvailable
    }
    
    override var currentUserID: String? {
        return "mock-user-id"
    }
    
    override init() {
        super.init()
        // Set initial test values
        self.isSignedIn = true
        self.totalXP = 100
        self.userName = "Test User"
        self.currentStreak = 5
        self.totalWorkouts = 20
        self.joinTimestamp = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
        self.lastWorkoutTimestamp = Date().addingTimeInterval(-24 * 60 * 60) // 1 day ago
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
            let newXP = self.totalXP + xp
            let newWorkoutCount = self.totalWorkouts + 1
            
            self.totalXP = newXP
            self.totalWorkouts = newWorkoutCount
            self.lastWorkoutTimestamp = Date()
            self.lastError = nil
        } else {
            self.lastError = .cloudKitSyncFailed(NSError(domain: "MockError", code: 1))
        }
    }
    
    override func fetchUserRecord() {
        fetchUserRecordCalled = true
        
        if shouldFailFetchUserRecord {
            self.lastError = .cloudKitUserNotFound
        } else {
            // Simulate successful fetch with no changes
            self.lastError = nil
        }
    }
    
    override func recordWorkout(_ workout: HKWorkout, completion: @escaping (Bool) -> Void) {
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
}