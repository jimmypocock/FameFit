//
//  ControlsViewTests.swift
//  FameFit Watch AppTests
//
//  Unit tests for ControlsView using the WorkoutManaging protocol
//

@testable import FameFit_Watch_App
import SwiftUI
import XCTest

class ControlsViewTests: XCTestCase {
    private var mockWorkoutManager: MockWorkoutManager!

    override func setUp() {
        super.setUp()
        mockWorkoutManager = MockWorkoutManager()
    }

    override func tearDown() {
        mockWorkoutManager = nil
        super.tearDown()
    }

    func testPauseWorkout() {
        // Given
        mockWorkoutManager.simulateWorkoutInProgress()
        XCTAssertTrue(mockWorkoutManager.isWorkoutRunning)
        XCTAssertFalse(mockWorkoutManager.isPaused)

        // When
        mockWorkoutManager.pause()

        // Then
        XCTAssertTrue(mockWorkoutManager.pauseCalled)
        XCTAssertTrue(mockWorkoutManager.isPaused)
        XCTAssertTrue(mockWorkoutManager.isWorkoutRunning)
    }

    func testResumeWorkout() {
        // Given
        mockWorkoutManager.simulateWorkoutInProgress()
        mockWorkoutManager.pause()
        XCTAssertTrue(mockWorkoutManager.isPaused)

        // When
        mockWorkoutManager.resume()

        // Then
        XCTAssertTrue(mockWorkoutManager.resumeCalled)
        XCTAssertFalse(mockWorkoutManager.isPaused)
        XCTAssertTrue(mockWorkoutManager.isWorkoutRunning)
    }

    func testTogglePause() {
        // Given
        mockWorkoutManager.simulateWorkoutInProgress()
        let initialPauseState = mockWorkoutManager.isPaused

        // When
        mockWorkoutManager.togglePause()

        // Then
        XCTAssertTrue(mockWorkoutManager.togglePauseCalled)
        XCTAssertNotEqual(mockWorkoutManager.isPaused, initialPauseState)

        // When - Toggle again
        mockWorkoutManager.togglePause()

        // Then - Should be back to initial state
        XCTAssertEqual(mockWorkoutManager.isPaused, initialPauseState)
    }

    func testEndWorkout() {
        // Given
        mockWorkoutManager.simulateWorkoutInProgress(
            type: .running,
            duration: 1_800, // 30 minutes
            heartRate: 145,
            calories: 250,
            distance: 5_000 // 5km
        )

        // When
        mockWorkoutManager.endWorkout()

        // Then
        XCTAssertTrue(mockWorkoutManager.endWorkoutCalled)
        XCTAssertFalse(mockWorkoutManager.isWorkoutRunning)
        XCTAssertFalse(mockWorkoutManager.isPaused)
        XCTAssertTrue(mockWorkoutManager.showingSummaryView)

        // Verify summary data was transferred
        XCTAssertEqual(mockWorkoutManager.elapsedTimeForSummary, 1_800)
        XCTAssertEqual(mockWorkoutManager.totalCaloriesForSummary, 250)
        XCTAssertEqual(mockWorkoutManager.totalDistanceForSummary, 5_000)
        XCTAssertEqual(mockWorkoutManager.averageHeartRateForSummary, 140) // 145 - 5
    }

}
