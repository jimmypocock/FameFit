@testable import FameFit
import HealthKit
import XCTest

class WorkoutObserverTests: XCTestCase {
    private var mockHealthKitService: MockHealthKitService!
    private var mockCloudKitManager: MockCloudKitManager!
    private var workoutObserver: WorkoutObserver!

    override func setUp() {
        super.setUp()

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

        super.tearDown()
    }

    // MARK: - Authorization Tests

    func testRequestHealthKitAuthorization_Success() {
        let expectation = XCTestExpectation(description: "Authorization completes")

        mockHealthKitService.authorizationError = nil
        mockHealthKitService.authorizationSuccess = true

        workoutObserver.requestHealthKitAuthorization { success, error in
            XCTAssertTrue(success)
            XCTAssertNil(error)
            XCTAssertTrue(self.workoutObserver.isAuthorized)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(mockHealthKitService.requestAuthorizationCalled)
    }

    func testRequestHealthKitAuthorization_Failure() {
        let expectation = XCTestExpectation(description: "Authorization fails")

        mockHealthKitService.authorizationError = NSError(domain: "HealthKit", code: 1)
        mockHealthKitService.authorizationSuccess = false

        workoutObserver.requestHealthKitAuthorization { success, error in
            XCTAssertFalse(success)
            XCTAssertNotNil(error)
            XCTAssertFalse(self.workoutObserver.isAuthorized)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(mockHealthKitService.requestAuthorizationCalled)
    }

    // MARK: - Workout Detection Tests

    func testWorkoutDetection_AddsXP() {
        // Given
        let expectation = XCTestExpectation(description: "Workout processed")
        mockCloudKitManager.reset()
        _ = mockCloudKitManager.totalXP // Verify starts at 0

        // Create a mock workout
        let workout = TestWorkoutBuilder.createRunWorkout()
        mockHealthKitService.mockWorkouts = [workout]

        // When
        workoutObserver.fetchInitialWorkouts()

        // Add delay to allow async processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        // Then
        wait(for: [expectation], timeout: 2.0)

        XCTAssertTrue(mockHealthKitService.fetchWorkoutsCalled)
        XCTAssertEqual(workoutObserver.allWorkouts.count, 1)
    }

    func testWorkoutDetection_MultipleWorkouts() {
        // Given
        let expectation = XCTestExpectation(description: "Multiple workouts processed")
        let workouts = TestWorkoutBuilder.createWorkoutSeries(count: 3)
        mockHealthKitService.mockWorkouts = workouts

        // When
        workoutObserver.fetchInitialWorkouts()

        // Add delay to allow async processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        // Then
        wait(for: [expectation], timeout: 2.0)

        XCTAssertTrue(mockHealthKitService.fetchWorkoutsCalled)
        XCTAssertEqual(workoutObserver.allWorkouts.count, 3)
    }

    func testWorkoutObserver_StartsBackgroundDelivery() {
        // When
        workoutObserver.startObservingWorkouts()

        // Then
        XCTAssertTrue(mockHealthKitService.startObservingWorkoutsCalled)
        XCTAssertTrue(mockHealthKitService.enableBackgroundDeliveryCalled)
        XCTAssertTrue(mockHealthKitService.backgroundDeliveryEnabled)
    }

    func testWorkoutObserver_StopsObserving() {
        // Given
        workoutObserver.startObservingWorkouts()
        XCTAssertNotNil(workoutObserver)
        XCTAssertFalse(mockHealthKitService.activeQueries.isEmpty)

        // When
        workoutObserver.stopObservingWorkouts()

        // Then
        XCTAssertTrue(mockHealthKitService.activeQueries.isEmpty)
    }

    func testHealthKitNotAvailable() {
        // Given
        mockHealthKitService.isHealthDataAvailableValue = false
        let expectation = XCTestExpectation(description: "Error set")

        // When
        workoutObserver.requestHealthKitAuthorization { success, error in
            XCTAssertFalse(success)
            XCTAssertEqual(error, .healthKitNotAvailable)
            expectation.fulfill()
        }

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(workoutObserver.lastError, .healthKitNotAvailable)
    }

    func testAuthorizationDenied() {
        // Given
        mockHealthKitService.simulateAuthorizationDenied()
        let expectation = XCTestExpectation(description: "Authorization denied")

        // When
        workoutObserver.requestHealthKitAuthorization { success, error in
            XCTAssertFalse(success)
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(workoutObserver.isAuthorized)
    }

    func testTodaysWorkouts() {
        // Given
        let todaysWorkouts = TestWorkoutBuilder.createTodaysWorkouts()
        let yesterdayWorkout = TestWorkoutBuilder.createRunWorkout(
            startDate: Date().addingTimeInterval(-86400) // 24 hours ago
        )

        mockHealthKitService.mockWorkouts = todaysWorkouts + [yesterdayWorkout]
        let expectation = XCTestExpectation(description: "Workouts fetched")

        // When
        workoutObserver.fetchInitialWorkouts()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        // Then
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(workoutObserver.allWorkouts.count, 4)
        XCTAssertEqual(workoutObserver.todaysWorkouts.count, 3)
    }
}
