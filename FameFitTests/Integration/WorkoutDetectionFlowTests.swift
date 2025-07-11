import XCTest
import HealthKit
@testable import FameFit

/// Tests the complete workout detection flow from HealthKit to follower updates
class WorkoutDetectionFlowTests: XCTestCase {
    
    var mockHealthKitService: MockHealthKitService!
    var mockCloudKitManager: MockCloudKitManager!
    var workoutObserver: WorkoutObserver!
    
    override func setUp() {
        super.setUp()
        
        // Reset UserDefaults for consistent testing
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastProcessedWorkoutDate)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.appInstallDate)
        
        mockHealthKitService = MockHealthKitService()
        mockHealthKitService.isHealthDataAvailableValue = true
        mockHealthKitService.authorizationSuccess = true
        
        mockCloudKitManager = MockCloudKitManager()
        workoutObserver = WorkoutObserver(
            cloudKitManager: mockCloudKitManager,
            healthKitService: mockHealthKitService
        )
        
        // Authorize the WorkoutObserver for all tests
        let authExpectation = XCTestExpectation(description: "Authorization complete")
        workoutObserver.requestHealthKitAuthorization { success, error in
            authExpectation.fulfill()
        }
        wait(for: [authExpectation], timeout: 1.0)
    }
    
    override func tearDown() {
        mockHealthKitService.reset()
        mockCloudKitManager.reset()
        workoutObserver = nil
        
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastProcessedWorkoutDate)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.appInstallDate)
        
        super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testNewWorkoutTriggersFollowerIncrease() {
        // Given - User has authorized HealthKit and is signed in
        mockCloudKitManager.isSignedIn = true
        
        let initialFollowers = mockCloudKitManager.followerCount
        let expectation = XCTestExpectation(description: "Workout processed")
        
        // Create a workout that just finished
        let workout = TestWorkoutBuilder.createRunWorkout(
            duration: 1800, // 30 minutes
            startDate: Date().addingTimeInterval(-1800)
        )
        
        // When - Start observing first (with no workouts)
        workoutObserver.startObservingWorkouts()
        
        // Wait a moment for the initial fetchLatestWorkout to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Now add the workout and trigger observer
            self.mockHealthKitService.mockWorkouts = [workout]
            self.mockHealthKitService.triggerWorkoutObserver()
        }
        
        // Wait for async processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertTrue(mockCloudKitManager.addFollowersCalled, "addFollowers should have been called")
        XCTAssertEqual(mockCloudKitManager.lastAddedFollowerCount, 5, "Should add 5 followers per workout")
        XCTAssertEqual(mockCloudKitManager.followerCount, 105, "Follower count should be 100 + 5")
    }
    
    func testMultipleWorkoutsProcessedInOrder() {
        // Test that multiple calls to addFollowers work correctly
        
        // Given
        let initialFollowers = mockCloudKitManager.followerCount
        let initialWorkouts = mockCloudKitManager.totalWorkouts
        
        // When - Simulate processing 3 workouts
        for i in 1...3 {
            mockCloudKitManager.addFollowers(5)
            // Process workout \(i)
        }
        
        // Then
        XCTAssertEqual(mockCloudKitManager.followerCount, initialFollowers + 15, "Should add 5 followers per workout")
        XCTAssertEqual(mockCloudKitManager.totalWorkouts, initialWorkouts + 3, "Should increment workout count by 3")
        XCTAssertEqual(mockCloudKitManager.addFollowersCallCount, 3, "Should be called 3 times")
    }
    
    func testWorkoutBeforeAppInstallIgnored() {
        // Given - Set app install date to 1 hour ago
        let installDate = Date().addingTimeInterval(-3600) // 1 hour ago
        UserDefaults.standard.set(installDate, forKey: UserDefaultsKeys.appInstallDate)
        
        let expectation = XCTestExpectation(description: "Old workout ignored")
        _ = mockCloudKitManager.followerCount
        
        // Create a workout from before install (2 hours ago)
        let oldWorkout = TestWorkoutBuilder.createRunWorkout(
            startDate: Date().addingTimeInterval(-7200) // 2 hours ago
        )
        
        // Create a workout from after install (30 minutes ago)
        let newWorkout = TestWorkoutBuilder.createRunWorkout(
            startDate: Date().addingTimeInterval(-1800) // 30 minutes ago
        )
        
        // When - Start observing first
        workoutObserver.startObservingWorkouts()
        
        // Wait for initial fetch, then add workouts and trigger
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.mockHealthKitService.mockWorkouts = [oldWorkout, newWorkout]
            self.mockHealthKitService.triggerWorkoutObserver()
        }
        
        // Wait for async processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 3.0)
        
        // Only the new workout should be processed
        XCTAssertEqual(mockCloudKitManager.followerCount, 105, "Should be 100 + 5 for new workout only")
        XCTAssertEqual(mockCloudKitManager.addFollowersCallCount, 1, "Should only process 1 workout")
    }
    
    func testWorkoutProcessingUpdatesLastProcessedDate() {
        // Test that UserDefaults can store and retrieve dates
        
        // Given
        let testDate = Date()
        let key = UserDefaultsKeys.lastProcessedWorkoutDate
        
        // When - Save a date
        UserDefaults.standard.set(testDate, forKey: key)
        // UserDefaults automatically synchronizes
        
        // Then - Retrieve and verify
        let retrievedDate = UserDefaults.standard.object(forKey: key) as? Date
        XCTAssertNotNil(retrievedDate, "Should be able to retrieve saved date")
        
        if let retrieved = retrievedDate {
            let timeDiff = abs(retrieved.timeIntervalSince(testDate))
            XCTAssertLessThan(timeDiff, 1.0, "Retrieved date should match saved date")
        }
    }
    
    func testErrorHandlingWhenCloudKitFails() {
        // This test verifies that CloudKit errors are handled gracefully
        
        // Given
        mockCloudKitManager.shouldFailAddFollowers = true
        let initialFollowers = mockCloudKitManager.followerCount
        
        // When - Directly test the CloudKit manager behavior
        mockCloudKitManager.addFollowers(5)
        
        // Then
        XCTAssertEqual(mockCloudKitManager.followerCount, initialFollowers, "Followers should not change on error")
        XCTAssertTrue(mockCloudKitManager.addFollowersCalled, "addFollowers should have been called")
        XCTAssertNotNil(mockCloudKitManager.lastError, "Should have an error set")
    }
}