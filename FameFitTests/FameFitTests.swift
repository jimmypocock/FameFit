//
//  FameFitTests.swift
//  FameFitTests
//
//  Created by Jimmy Pocock on 6/27/25.
//

import Testing
import AuthenticationServices
@testable import FameFit

// MARK: - Mock Managers for Testing
class MockCloudKitManager: CloudKitManager {
    var setupUserRecordCalled = false
    var checkAccountStatusCalled = false
    
    override func setupUserRecord(userID: String, displayName: String) {
        setupUserRecordCalled = true
        super.setupUserRecord(userID: userID, displayName: displayName)
    }
    
    override func checkAccountStatus() {
        checkAccountStatusCalled = true
        // Don't actually check CloudKit in tests
    }
}

class MockWorkoutObserver: WorkoutObserver {
    var startObservingCalled = false
    
    override func startObservingWorkouts() {
        startObservingCalled = true
        // Don't actually observe workouts in tests
    }
}

// MARK: - Authentication Manager Tests
struct AuthenticationManagerTests {
    var sut: AuthenticationManager
    var mockCloudKit: MockCloudKitManager
    
    init() {
        mockCloudKit = MockCloudKitManager()
        sut = AuthenticationManager(cloudKitManager: mockCloudKit)
        // Clean state
        sut.signOut()
    }
    
    @Test
    func testInitialState() {
        #expect(sut.isAuthenticated == false)
        #expect(sut.userID == nil)
        #expect(sut.userName == nil)
        #expect(sut.lastError == nil)
    }
    
    @Test
    func testSignOut() {
        // Set some values
        sut.userID = "test-user"
        sut.userName = "Test User"
        sut.isAuthenticated = true
        
        // Sign out
        sut.signOut()
        
        // Verify cleared
        #expect(sut.isAuthenticated == false)
        #expect(sut.userID == nil)
        #expect(sut.userName == nil)
    }
    
    @Test
    func testPersistenceLoading() {
        // Set values in UserDefaults
        let testID = "persistence-test-\(UUID().uuidString)"
        let testName = "Persistence Test"
        
        UserDefaults.standard.set(testID, forKey: "FameFitUserID")
        UserDefaults.standard.set(testName, forKey: "FameFitUserName")
        
        // Create new instance
        let newCloudKit = MockCloudKitManager()
        let newManager = AuthenticationManager(cloudKitManager: newCloudKit)
        
        // Should load persisted values
        #expect(newManager.isAuthenticated == true)
        #expect(newManager.userID == testID)
        #expect(newManager.userName == testName)
        #expect(newCloudKit.checkAccountStatusCalled == true)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "FameFitUserID")
        UserDefaults.standard.removeObject(forKey: "FameFitUserName")
    }
}

// MARK: - CloudKit Manager Tests
struct CloudKitManagerTests {
    var sut: CloudKitManager
    
    init() {
        sut = CloudKitManager()
    }
    
    @Test
    func testInitialState() {
        #expect(sut.followerCount == 0)
        #expect(sut.totalWorkouts == 0)
        #expect(sut.currentStreak == 0)
        #expect(sut.userName.isEmpty)
        #expect(sut.selectedCharacter == "chad")
    }
    
    @Test
    func testFollowerTitle() {
        // Test different follower counts
        sut.followerCount = 50
        #expect(sut.getFollowerTitle() == "Fitness Newbie")
        
        sut.followerCount = 500
        #expect(sut.getFollowerTitle() == "Micro-Influencer")
        
        sut.followerCount = 5_000
        #expect(sut.getFollowerTitle() == "Rising Star")
        
        sut.followerCount = 50_000
        #expect(sut.getFollowerTitle() == "Verified Influencer")
        
        sut.followerCount = 200_000
        #expect(sut.getFollowerTitle() == "FameFit Elite")
    }
    
    @Test
    func testAddFollowers() {
        sut.followerCount = 100
        sut.addFollowers(50)
        #expect(sut.followerCount == 150)
    }
}

// MARK: - Workout Observer Tests
struct WorkoutObserverTests {
    var sut: WorkoutObserver
    var mockCloudKit: MockCloudKitManager
    
    init() {
        mockCloudKit = MockCloudKitManager()
        sut = WorkoutObserver(cloudKitManager: mockCloudKit)
    }
    
    @Test
    func testInitialState() {
        #expect(sut.allWorkouts.isEmpty)
        #expect(sut.todaysWorkouts.isEmpty)
        #expect(sut.isAuthorized == false)
        #expect(sut.lastError == nil)
    }
}
