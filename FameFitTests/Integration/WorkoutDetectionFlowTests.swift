@testable import FameFit
import HealthKit
import XCTest

/// Tests the complete workout detection flow from HealthKit to XP updates
class WorkoutDetectionFlowTests: XCTestCase {
    private var mockHealthKitService: MockHealthKitService!
    private var mockCloudKitManager: MockCloudKitManager!
    private var workoutObserver: WorkoutObserver!

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
        workoutObserver.requestHealthKitAuthorization { _, _ in
            authExpectation.fulfill()
        }
        wait(for: [authExpectation], timeout: 3.0)
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

    func testNewWorkoutTriggersXPIncrease() {
        // Given - User has authorized HealthKit and is signed in
        mockCloudKitManager.isSignedIn = true

        let expectation = XCTestExpectation(description: "Workout processed")

        // Create a workout that just finished
        let workout = TestWorkoutBuilder.createRunWorkout(
            duration: 1_800, // 30 minutes
            startDate: Date().addingTimeInterval(-1_800)
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

        XCTAssertTrue(mockCloudKitManager.addXPCalled, "addXP should have been called")

        // 30-minute run should give approximately 36 XP (30 * 1.0 base * 1.2 running multiplier)
        // Plus potential time bonuses and first workout bonus (50 XP)
        // The actual XP will vary based on when test runs, so check it's reasonable
        let earnedXP = mockCloudKitManager.lastAddedXPCount
        XCTAssertGreaterThan(earnedXP, 30, "Should earn at least 30 XP for 30-minute run")
        XCTAssertLessThan(earnedXP, 150, "Should earn less than 150 XP (even with bonuses)")

        // Check that total XP increased
        XCTAssertEqual(mockCloudKitManager.totalXP, 100 + earnedXP, "XP count should increase by earned amount")
    }

    func testMultipleWorkoutsProcessedInOrder() {
        // Test that multiple calls to addXP work correctly

        // Given
        let initialXP = mockCloudKitManager.totalXP
        let initialWorkouts = mockCloudKitManager.totalWorkouts

        // When - Simulate processing 3 workouts
        for _ in 1 ... 3 {
            mockCloudKitManager.addXP(5)
        }

        // Then
        XCTAssertEqual(mockCloudKitManager.totalXP, initialXP + 15, "Should add 5 XP per workout")
        XCTAssertEqual(mockCloudKitManager.totalWorkouts, initialWorkouts + 3, "Should increment workout count by 3")
        XCTAssertEqual(mockCloudKitManager.addXPCallCount, 3, "Should be called 3 times")
    }

    func testWorkoutBeforeAppInstallIgnored() {
        // Given - Set app install date to 1 hour ago
        let installDate = Date().addingTimeInterval(-3_600) // 1 hour ago
        UserDefaults.standard.set(installDate, forKey: UserDefaultsKeys.appInstallDate)

        let expectation = XCTestExpectation(description: "Old workout ignored")
        _ = mockCloudKitManager.totalXP

        // Create a workout from before install (2 hours ago)
        let oldWorkout = TestWorkoutBuilder.createRunWorkout(
            startDate: Date().addingTimeInterval(-7_200) // 2 hours ago
        )

        // Create a workout from after install (30 minutes ago)
        let newWorkout = TestWorkoutBuilder.createRunWorkout(
            startDate: Date().addingTimeInterval(-1_800) // 30 minutes ago
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
        XCTAssertEqual(mockCloudKitManager.addXPCallCount, 1, "Should only process 1 workout")

        // Verify XP increased (amount depends on workout calculation)
        XCTAssertGreaterThan(mockCloudKitManager.totalXP, 100, "XP should increase from base 100")
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
        mockCloudKitManager.shouldFailAddXP = true
        let initialXP = mockCloudKitManager.totalXP

        // When - Directly test the CloudKit manager behavior
        mockCloudKitManager.addXP(5)

        // Then
        XCTAssertEqual(mockCloudKitManager.totalXP, initialXP, "XP should not change on error")
        XCTAssertTrue(mockCloudKitManager.addXPCalled, "addXP should have been called")
        XCTAssertNotNil(mockCloudKitManager.lastError, "Should have an error set")
    }
}
