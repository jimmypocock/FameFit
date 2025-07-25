//
//  WatchStartViewTests.swift
//  FameFit Watch AppTests
//
//  Unit tests for WatchStartView using the WorkoutManaging protocol
//

@testable import FameFit_Watch_App
import HealthKit
import SwiftUI
import XCTest

class WatchStartViewTests: XCTestCase {
    private var mockWorkoutManager: MockWorkoutManager!

    override func setUp() {
        super.setUp()
        mockWorkoutManager = MockWorkoutManager()
    }

    override func tearDown() {
        mockWorkoutManager = nil
        super.tearDown()
    }

    func testInitialState() {
        // Given
        _ = WatchStartView()
            .environmentObject(mockWorkoutManager)

        // Then
        XCTAssertNil(mockWorkoutManager.selectedWorkout)
        XCTAssertFalse(mockWorkoutManager.isWorkoutRunning)
        XCTAssertFalse(mockWorkoutManager.showingSummaryView)
    }

    func testSelectingWorkoutType() {
        // Given
        mockWorkoutManager.shouldSimulateActiveWorkout = true

        // When
        mockWorkoutManager.selectedWorkout = .running

        // Then
        XCTAssertEqual(mockWorkoutManager.selectedWorkout, .running)
    }

    func testWorkoutSelection_CallsStartWorkout() {
        // Given
        mockWorkoutManager.shouldSimulateActiveWorkout = true
        let workoutType = HKWorkoutActivityType.cycling

        // When
        // Simulate what happens when the view sets selectedWorkout
        mockWorkoutManager.selectedWorkout = workoutType
        // In the real WorkoutManager, this triggers startWorkout via didSet
        mockWorkoutManager.startWorkout(workoutType: workoutType)

        // Then
        XCTAssertTrue(mockWorkoutManager.startWorkoutCalled)
        XCTAssertEqual(mockWorkoutManager.startWorkoutCalledWith, workoutType)
        XCTAssertTrue(mockWorkoutManager.isWorkoutRunning)
    }

    func testMultipleWorkoutTypes() {
        // Test that we can track different workout types
        let workoutTypes: [HKWorkoutActivityType] = [
            .running,
            .cycling,
            .walking,
            .swimming,
            .yoga,
            .hiking,
        ]

        for workoutType in workoutTypes {
            // Reset between tests
            mockWorkoutManager.reset()
            mockWorkoutManager.shouldSimulateActiveWorkout = true

            // When
            mockWorkoutManager.startWorkout(workoutType: workoutType)

            // Then
            XCTAssertEqual(mockWorkoutManager.selectedWorkout, workoutType)
            XCTAssertTrue(mockWorkoutManager.isWorkoutRunning)
        }
    }

    func testAuthorizationRequest() {
        // When
        mockWorkoutManager.requestAuthorization()

        // Then
        XCTAssertTrue(mockWorkoutManager.requestAuthorizationCalled)
    }

    func testAuthorizationFailure() {
        // Given
        mockWorkoutManager.shouldFailAuthorization = true

        // When
        mockWorkoutManager.requestAuthorization()

        // Then
        XCTAssertTrue(mockWorkoutManager.requestAuthorizationCalled)
        // Additional authorization failure handling would be tested here
    }
}
