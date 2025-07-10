import Foundation
import CloudKit
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
    }
    
    override func addFollowers(_ count: Int) {
        addFollowersCalled = true
        addFollowersCallCount += 1
        lastAddedFollowerCount = count
        
        if !shouldFailAddFollowers {
            self.followerCount += count
            self.totalWorkouts += 1
            self.lastError = nil
            
            print("[MockCloudKitManager] Added \(count) followers. Total: \(followerCount)")
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
        fetchUserRecordCalled = false
        recordWorkoutCalled = false
        
        followerCount = 100
        totalWorkouts = 20
        currentStreak = 5
        lastError = nil
    }
    
    func simulateUserSignOut() {
        isSignedIn = false
        userRecord = nil
        followerCount = 0
        userName = ""
        currentStreak = 0
        totalWorkouts = 0
    }
}