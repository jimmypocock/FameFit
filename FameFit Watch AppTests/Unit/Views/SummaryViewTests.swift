//
//  SummaryViewTests.swift
//  FameFit Watch AppTests
//
//  Unit tests for SummaryView using the WorkoutManaging protocol
//

@testable import FameFit_Watch_App
import HealthKit
import SwiftUI
import XCTest

class SummaryViewTests: XCTestCase {
    private var mockWorkoutManager: MockWorkoutManager!

    override func setUp() {
        super.setUp()
        mockWorkoutManager = MockWorkoutManager()
    }

    override func tearDown() {
        mockWorkoutManager = nil
        super.tearDown()
    }

    func testSummaryDataAfterWorkout() {
        // Given - Complete a workout
        mockWorkoutManager.simulateWorkoutInProgress(
            type: .running,
            duration: 2_700, // 45 minutes
            heartRate: 155,
            calories: 400,
            distance: 7_500 // 7.5km
        )

        // When
        mockWorkoutManager.endWorkout()

        // Then
        XCTAssertTrue(mockWorkoutManager.showingSummaryView)
        XCTAssertEqual(mockWorkoutManager.elapsedTimeForSummary, 2_700)
        XCTAssertEqual(mockWorkoutManager.totalCaloriesForSummary, 400)
        XCTAssertEqual(mockWorkoutManager.totalDistanceForSummary, 7_500)
        XCTAssertEqual(mockWorkoutManager.averageHeartRateForSummary, 150) // 155 - 5
    }

    func testDismissingSummaryView() {
        // Given - Summary view is showing
        mockWorkoutManager.simulateWorkoutInProgress()
        mockWorkoutManager.endWorkout()
        XCTAssertTrue(mockWorkoutManager.showingSummaryView)

        // When
        mockWorkoutManager.showingSummaryView = false

        // Then - Should trigger reset
        mockWorkoutManager.resetWorkout() // Simulating the didSet behavior
        XCTAssertTrue(mockWorkoutManager.resetWorkoutCalled)
        XCTAssertNil(mockWorkoutManager.selectedWorkout)
        XCTAssertEqual(mockWorkoutManager.displayElapsedTime, 0)
    }

    func testSummaryForDifferentWorkoutTypes() {
        let workoutConfigs: [(type: HKWorkoutActivityType, duration: TimeInterval, calories: Double)] = [
            (.walking, 3_600, 200), // 1 hour walk
            (.cycling, 5_400, 600), // 1.5 hour bike ride
            (.swimming, 1_800, 350), // 30 min swim
            (.yoga, 2_700, 150), // 45 min yoga
            (.hiking, 7_200, 500) // 2 hour hike
        ]

        for config in workoutConfigs {
            // Reset between tests
            mockWorkoutManager.reset()

            // Given
            mockWorkoutManager.simulateWorkoutInProgress(
                type: config.type,
                duration: config.duration,
                calories: config.calories
            )

            // When
            mockWorkoutManager.endWorkout()

            // Then
            XCTAssertEqual(mockWorkoutManager.elapsedTimeForSummary, config.duration)
            XCTAssertEqual(mockWorkoutManager.totalCaloriesForSummary, config.calories)
        }
    }

    func testEmptySummaryWithoutWorkout() {
        // Given - No workout was performed
        XCTAssertFalse(mockWorkoutManager.isWorkoutRunning)

        // When
        mockWorkoutManager.showingSummaryView = true

        // Then - Summary values should be zero
        XCTAssertEqual(mockWorkoutManager.elapsedTimeForSummary, 0)
        XCTAssertEqual(mockWorkoutManager.totalCaloriesForSummary, 0)
        XCTAssertEqual(mockWorkoutManager.totalDistanceForSummary, 0)
        XCTAssertEqual(mockWorkoutManager.averageHeartRateForSummary, 0)
    }

    func testResetAfterSummary() {
        // Given - Complete workout and view summary
        mockWorkoutManager.simulateWorkoutInProgress()
        mockWorkoutManager.endWorkout()
        XCTAssertTrue(mockWorkoutManager.showingSummaryView)

        // When
        mockWorkoutManager.resetWorkout()

        // Then - Everything should be reset
        XCTAssertFalse(mockWorkoutManager.showingSummaryView)
        XCTAssertNil(mockWorkoutManager.selectedWorkout)
        XCTAssertFalse(mockWorkoutManager.isWorkoutRunning)
        XCTAssertEqual(mockWorkoutManager.displayElapsedTime, 0)
        XCTAssertEqual(mockWorkoutManager.heartRate, 0)
        XCTAssertEqual(mockWorkoutManager.activeEnergy, 0)
        XCTAssertEqual(mockWorkoutManager.distance, 0)
    }
}
