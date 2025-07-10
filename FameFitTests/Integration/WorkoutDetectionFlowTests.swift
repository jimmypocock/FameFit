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
        UserDefaults.standard.removeObject(forKey: SecurityBestPractices.UserDefaultsKeys.lastProcessedWorkoutDate)
        UserDefaults.standard.removeObject(forKey: SecurityBestPractices.UserDefaultsKeys.appInstallDate)
        
        mockHealthKitService = MockHealthKitService()
        mockCloudKitManager = MockCloudKitManager()
        workoutObserver = WorkoutObserver(
            cloudKitManager: mockCloudKitManager,
            healthKitService: mockHealthKitService
        )
    }
    
    override func tearDown() {
        mockHealthKitService.reset()
        mockCloudKitManager.reset()
        workoutObserver = nil
        
        UserDefaults.standard.removeObject(forKey: SecurityBestPractices.UserDefaultsKeys.lastProcessedWorkoutDate)
        UserDefaults.standard.removeObject(forKey: SecurityBestPractices.UserDefaultsKeys.appInstallDate)
        
        super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testNewWorkoutTriggersFollowerIncrease() {
        // Given - User has authorized HealthKit and is signed in
        mockHealthKitService.isHealthDataAvailableValue = true
        mockHealthKitService.authorizationSuccess = true
        mockCloudKitManager.isSignedIn = true
        
        let initialFollowers = mockCloudKitManager.followerCount
        let expectation = XCTestExpectation(description: "Workout processed")
        
        // Create a workout that just finished
        let workout = TestWorkoutBuilder.createRunWorkout(
            duration: 1800, // 30 minutes
            startDate: Date().addingTimeInterval(-1800)
        )
        
        // When - Simulate HealthKit detecting a new workout
        workoutObserver.startObservingWorkouts()
        
        // Simulate the observer query firing
        if let handler = mockHealthKitService.workoutUpdateHandler,
           let query = mockHealthKitService.activeQueries.first as? HKObserverQuery {
            // First, the observer fires
            handler(query, { }, nil)
            
            // Then fetchLatestWorkout is called, which will use our mock workouts
            mockHealthKitService.mockWorkouts = [workout]
            
            // Wait for async processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertTrue(mockCloudKitManager.addFollowersCalled)
        XCTAssertEqual(mockCloudKitManager.lastAddedFollowerCount, 5)
        XCTAssertEqual(mockCloudKitManager.followerCount, initialFollowers + 5)
    }
    
    func testMultipleWorkoutsProcessedInOrder() {
        // Given
        let expectation = XCTestExpectation(description: "All workouts processed")
        let initialFollowers = mockCloudKitManager.followerCount
        let initialWorkoutCount = mockCloudKitManager.totalWorkouts
        
        // Create 3 workouts at different times
        let workouts = [
            TestWorkoutBuilder.createRunWorkout(
                startDate: Date().addingTimeInterval(-7200) // 2 hours ago
            ),
            TestWorkoutBuilder.createWalkWorkout(
                startDate: Date().addingTimeInterval(-3600) // 1 hour ago
            ),
            TestWorkoutBuilder.createCycleWorkout(
                startDate: Date().addingTimeInterval(-1800) // 30 min ago
            )
        ]
        
        mockHealthKitService.mockWorkouts = workouts
        
        // When
        workoutObserver.startObservingWorkouts()
        
        // Simulate observer query firing
        if let handler = mockHealthKitService.workoutUpdateHandler,
           let query = mockHealthKitService.activeQueries.first as? HKObserverQuery {
            handler(query, { }, nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 3.0)
        
        // Each workout should add 5 followers
        XCTAssertEqual(mockCloudKitManager.followerCount, initialFollowers + (5 * 3))
        XCTAssertEqual(mockCloudKitManager.totalWorkouts, initialWorkoutCount + 3)
        XCTAssertEqual(mockCloudKitManager.addFollowersCallCount, 3)
    }
    
    func testWorkoutBeforeAppInstallIgnored() {
        // Given - Set app install date to now
        UserDefaults.standard.set(Date(), forKey: SecurityBestPractices.UserDefaultsKeys.appInstallDate)
        
        let expectation = XCTestExpectation(description: "Old workout ignored")
        let initialFollowers = mockCloudKitManager.followerCount
        
        // Create a workout from yesterday (before install)
        let oldWorkout = TestWorkoutBuilder.createRunWorkout(
            startDate: Date().addingTimeInterval(-86400) // 24 hours ago
        )
        
        // Create a workout from after install
        let newWorkout = TestWorkoutBuilder.createRunWorkout(
            startDate: Date().addingTimeInterval(-600) // 10 minutes ago
        )
        
        mockHealthKitService.mockWorkouts = [oldWorkout, newWorkout]
        
        // When
        workoutObserver.startObservingWorkouts()
        
        if let handler = mockHealthKitService.workoutUpdateHandler,
           let query = mockHealthKitService.activeQueries.first as? HKObserverQuery {
            handler(query, { }, nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        
        // Only the new workout should be processed
        XCTAssertEqual(mockCloudKitManager.followerCount, initialFollowers + 5)
        XCTAssertEqual(mockCloudKitManager.addFollowersCallCount, 1)
    }
    
    func testWorkoutProcessingUpdatesLastProcessedDate() {
        // Given
        let expectation = XCTestExpectation(description: "Last processed date updated")
        
        let workoutEndDate = Date().addingTimeInterval(-300) // 5 minutes ago
        let workout = TestWorkoutBuilder.createRunWorkout(
            duration: 1800,
            startDate: workoutEndDate.addingTimeInterval(-1800)
        )
        
        mockHealthKitService.mockWorkouts = [workout]
        
        // When
        workoutObserver.startObservingWorkouts()
        
        if let handler = mockHealthKitService.workoutUpdateHandler,
           let query = mockHealthKitService.activeQueries.first as? HKObserverQuery {
            handler(query, { }, nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        
        let lastProcessedDate = UserDefaults.standard.object(forKey: SecurityBestPractices.UserDefaultsKeys.lastProcessedWorkoutDate) as? Date
        XCTAssertNotNil(lastProcessedDate)
        
        // The last processed date should be close to the workout end date
        if let lastDate = lastProcessedDate {
            let timeDiff = abs(lastDate.timeIntervalSince(workoutEndDate))
            XCTAssertLessThan(timeDiff, 60) // Within 1 minute
        }
    }
    
    func testErrorHandlingWhenCloudKitFails() {
        // Given
        let expectation = XCTestExpectation(description: "Error handled gracefully")
        mockCloudKitManager.shouldFailAddFollowers = true
        let initialFollowers = mockCloudKitManager.followerCount
        
        let workout = TestWorkoutBuilder.createRunWorkout()
        mockHealthKitService.mockWorkouts = [workout]
        
        // When
        workoutObserver.startObservingWorkouts()
        
        if let handler = mockHealthKitService.workoutUpdateHandler,
           let query = mockHealthKitService.activeQueries.first as? HKObserverQuery {
            handler(query, { }, nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        
        // Followers should not change when CloudKit fails
        XCTAssertEqual(mockCloudKitManager.followerCount, initialFollowers)
        XCTAssertNotNil(mockCloudKitManager.lastError)
    }
}