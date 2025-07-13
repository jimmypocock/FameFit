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
    var fetchUserRecordCalled = false
    var recordWorkoutCalled = false
    
    // Control test behavior
    var shouldFailAddFollowers = false
    var shouldFailFetchUserRecord = false
    
    // Override CloudKit availability
    override var isAvailable: Bool {
        return true
    }
    
    override init() {
        super.init()
        // Set initial test values
        self.isSignedIn = true
        self.followerCount = 100
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
        
        // Track call for testing
        
        if !shouldFailAddFollowers {
            // Update values synchronously to ensure Combine publishers fire correctly
            let newFollowerCount = self.followerCount + count
            let newWorkoutCount = self.totalWorkouts + 1
            
            // Update both at once
            self.followerCount = newFollowerCount
            self.totalWorkouts = newWorkoutCount
            self.lastWorkoutTimestamp = Date()
            self.lastError = nil
            
            // State updated
        } else {
            self.lastError = .cloudKitSyncFailed(NSError(domain: "MockError", code: 1))
            // Simulating failure
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
        fetchUserRecordCalled = false
        recordWorkoutCalled = false
        
        followerCount = 100
        totalWorkouts = 20
        currentStreak = 5
        joinTimestamp = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        lastWorkoutTimestamp = Date().addingTimeInterval(-24 * 60 * 60)
        lastError = nil
    }
    
    func simulateUserSignOut() {
        isSignedIn = false
        userRecord = nil
        followerCount = 0
        userName = ""
        currentStreak = 0
        totalWorkouts = 0
        joinTimestamp = nil
        lastWorkoutTimestamp = nil
    }
}