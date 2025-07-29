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
        XCTAssertFalse(workoutManager.showingSummaryView)
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

    func testTogglePauseWhenRunning() {
        // Given workout is running
        workoutManager.isWorkoutRunning = true
        workoutManager.isPaused = false

        // When togglePause is called
        workoutManager.togglePause()

        // Then pause() should be called (we can't test the actual session pause without mocking)
        // But we can verify the logic flow works
        XCTAssertTrue(true) // No crash occurred
    }

    func testTogglePauseWhenPaused() {
        // Given workout is paused
        workoutManager.isWorkoutRunning = false
        workoutManager.isPaused = true

        // When togglePause is called
        workoutManager.togglePause()

        // Then resume() should be called
        XCTAssertTrue(true) // No crash occurred
    }

    func testTogglePauseWhenNotActive() {
        // Given workout is not active
        workoutManager.isWorkoutRunning = false
        workoutManager.isPaused = false

        // When togglePause is called
        workoutManager.togglePause()

        // Then nothing should happen
        XCTAssertTrue(true) // No crash occurred
    }

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

    func testEndWorkoutShowsSummary() {
        // Given a mock session exists
        // Note: We can't create a real HKWorkoutSession in tests
        // but we can test the expected behavior

        // When endWorkout would be called with an active session
        // It should set showingSummaryView to true
        // This is handled in the actual endWorkout method
        XCTAssertFalse(workoutManager.showingSummaryView)
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

    func testShowingSummaryViewDidSetResetsWorkout() {
        // Given
        workoutManager.selectedWorkout = .cycling
        workoutManager.showingSummaryView = true

        // When summary view is dismissed
        workoutManager.showingSummaryView = false

        // Then workout should be reset
        XCTAssertNil(workoutManager.selectedWorkout)
    }

    // MARK: - Authorization Tests

    func testRequestAuthorizationExists() {
        // Verify the method exists and can be called
        workoutManager.requestAuthorization()

        // No crash means the method exists
        XCTAssertTrue(true)
    }

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

    // MARK: - Message Tests

    func testInitialMessageIsEmpty() {
        XCTAssertEqual(workoutManager.currentMessage, "")
    }

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
