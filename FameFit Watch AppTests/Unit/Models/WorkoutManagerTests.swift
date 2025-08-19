@testable import FameFit_Watch_App
import HealthKit
import XCTest

class WorkoutManagerTests: XCTestCase {
    private var workoutManager: WorkoutManager!

    override func setUp() {
        super.setUp()
        workoutManager = WorkoutManager()
    }

    override func tearDown() {
        workoutManager = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        // Verify initial state
        XCTAssertNil(workoutManager.selectedWorkout)
        XCTAssertNil(workoutManager.session)
        XCTAssertNil(workoutManager.builder)
        XCTAssertNil(workoutManager.completedWorkout)
        XCTAssertFalse(workoutManager.isWorkoutRunning)
        XCTAssertFalse(workoutManager.isPaused)
        XCTAssertEqual(workoutManager.activeEnergy, 0)
        XCTAssertEqual(workoutManager.heartRate, 0)
        XCTAssertEqual(workoutManager.distance, 0)
        XCTAssertEqual(workoutManager.averageHeartRate, 0)
    }

    // MARK: - Workout Selection Tests

    func testWorkoutSelection() {
        // Given
        let workoutType = HKWorkoutActivityType.running

        // When
        workoutManager.selectedWorkout = workoutType

        // Then
        XCTAssertEqual(workoutManager.selectedWorkout, workoutType)
    }

    // MARK: - Pause/Resume Tests
    // Note: Actual pause/resume behavior cannot be tested without mocking HKWorkoutSession

    // MARK: - End Workout Tests

    func testEndWorkoutWithNoSession() {
        // Given no active session
        XCTAssertNil(workoutManager.session)

        // When endWorkout is called
        workoutManager.endWorkout()

        // Then should reset without crash
        XCTAssertNil(workoutManager.selectedWorkout)
        XCTAssertNil(workoutManager.session)
        XCTAssertNil(workoutManager.builder)
    }


    // MARK: - Reset Workout Tests

    func testResetWorkoutClearsAllState() {
        // Setup some state
        workoutManager.selectedWorkout = .running
        workoutManager.activeEnergy = 100
        workoutManager.heartRate = 150
        workoutManager.distance = 1_000
        workoutManager.averageHeartRate = 145
        workoutManager.isWorkoutRunning = true
        workoutManager.isPaused = false

        // When reset
        workoutManager.resetWorkout()

        // Then all state should be cleared
        XCTAssertNil(workoutManager.selectedWorkout)
        XCTAssertNil(workoutManager.session)
        XCTAssertNil(workoutManager.builder)
        XCTAssertNil(workoutManager.workout)
        XCTAssertEqual(workoutManager.activeEnergy, 0)
        XCTAssertEqual(workoutManager.heartRate, 0)
        XCTAssertEqual(workoutManager.distance, 0)
        XCTAssertEqual(workoutManager.averageHeartRate, 0)
        XCTAssertFalse(workoutManager.isWorkoutRunning)
        XCTAssertFalse(workoutManager.isPaused)
    }

    // MARK: - Summary View Tests


    // MARK: - Authorization Tests
    // Note: Cannot test actual HealthKit authorization without real HKHealthStore

    // MARK: - Metrics Update Tests

    func testMetricsStartAtZero() {
        XCTAssertEqual(workoutManager.activeEnergy, 0)
        XCTAssertEqual(workoutManager.heartRate, 0)
        XCTAssertEqual(workoutManager.distance, 0)
        XCTAssertEqual(workoutManager.averageHeartRate, 0)
    }

    // MARK: - Timer Tests

    func testDisplayElapsedTimeStartsAtZero() {
        XCTAssertEqual(workoutManager.displayElapsedTime, 0)
    }

    func testDisplayElapsedTimeCanBeSet() {
        // Given various elapsed times
        let testTimes: [TimeInterval] = [0, 30, 90, 3_665]

        for time in testTimes {
            workoutManager.displayElapsedTime = time
            XCTAssertEqual(
                workoutManager.displayElapsedTime,
                time,
                "Should be able to set elapsed time to \(time)"
            )
        }
    }

    // MARK: - Error State Tests

    func testWorkoutErrorStartsNil() {
        XCTAssertNil(workoutManager.workoutError)
    }

    // MARK: - Workout Type Tests

    func testSupportsMultipleWorkoutTypes() {
        let supportedTypes: [HKWorkoutActivityType] = [.running, .cycling, .walking]

        for type in supportedTypes {
            workoutManager.selectedWorkout = type
            XCTAssertEqual(workoutManager.selectedWorkout, type)
        }
    }
}
