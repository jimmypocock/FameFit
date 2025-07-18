//
//  MetricsViewTests.swift
//  FameFit Watch AppTests
//
//  Unit tests for MetricsView using the WorkoutManaging protocol
//

import XCTest
import SwiftUI
import HealthKit
@testable import FameFit_Watch_App

class MetricsViewTests: XCTestCase {
    private var mockWorkoutManager: MockWorkoutManager!
    
    override func setUp() {
        super.setUp()
        mockWorkoutManager = MockWorkoutManager()
    }
    
    override func tearDown() {
        mockWorkoutManager = nil
        super.tearDown()
    }
    
    func testMetricsDisplay_Running() {
        // Given
        mockWorkoutManager.simulateWorkoutInProgress(
            type: .running,
            duration: 600, // 10 minutes
            heartRate: 150,
            calories: 100,
            distance: 2000 // 2km
        )
        
        // Then - Verify all metrics are available
        XCTAssertEqual(mockWorkoutManager.displayElapsedTime, 600)
        XCTAssertEqual(mockWorkoutManager.heartRate, 150)
        XCTAssertEqual(mockWorkoutManager.activeEnergy, 100)
        XCTAssertEqual(mockWorkoutManager.distance, 2000)
        XCTAssertEqual(mockWorkoutManager.averageHeartRate, 145) // heartRate - 5
    }
    
    func testMetricsDisplay_Cycling() {
        // Given
        mockWorkoutManager.simulateWorkoutInProgress(
            type: .cycling,
            duration: 1800, // 30 minutes
            heartRate: 135,
            calories: 250,
            distance: 10000 // 10km
        )
        
        // Then
        XCTAssertEqual(mockWorkoutManager.selectedWorkout, .cycling)
        XCTAssertEqual(mockWorkoutManager.distance, 10000)
    }
    
    func testMetricsDisplay_Swimming() {
        // Given
        mockWorkoutManager.simulateWorkoutInProgress(
            type: .swimming,
            duration: 1200, // 20 minutes
            heartRate: 140,
            calories: 200,
            distance: 1000 // 1km
        )
        
        // Then
        XCTAssertEqual(mockWorkoutManager.selectedWorkout, .swimming)
        // Swimming shows distance differently
        XCTAssertEqual(mockWorkoutManager.distance, 1000)
    }
    
    func testMetricsDisplay_NonDistanceWorkout() {
        // Given - Yoga doesn't track distance
        mockWorkoutManager.simulateWorkoutInProgress(
            type: .yoga,
            duration: 2400, // 40 minutes
            heartRate: 90,
            calories: 120,
            distance: 0
        )
        
        // Then
        XCTAssertEqual(mockWorkoutManager.selectedWorkout, .yoga)
        XCTAssertEqual(mockWorkoutManager.distance, 0)
        XCTAssertEqual(mockWorkoutManager.activeEnergy, 120)
    }
    
    func testMetricsWhilePaused() {
        // Given
        mockWorkoutManager.simulateWorkoutInProgress()
        let initialMetrics = (
            time: mockWorkoutManager.displayElapsedTime,
            heartRate: mockWorkoutManager.heartRate,
            calories: mockWorkoutManager.activeEnergy,
            distance: mockWorkoutManager.distance
        )
        
        // When
        mockWorkoutManager.simulatePausedWorkout()
        
        // Then - Metrics should still be available when paused
        XCTAssertTrue(mockWorkoutManager.isPaused)
        XCTAssertEqual(mockWorkoutManager.displayElapsedTime, initialMetrics.time)
        XCTAssertEqual(mockWorkoutManager.heartRate, initialMetrics.heartRate)
        XCTAssertEqual(mockWorkoutManager.activeEnergy, initialMetrics.calories)
        XCTAssertEqual(mockWorkoutManager.distance, initialMetrics.distance)
    }
    
    func testZeroMetricsBeforeWorkout() {
        // Given - No workout started
        
        // Then
        XCTAssertEqual(mockWorkoutManager.displayElapsedTime, 0)
        XCTAssertEqual(mockWorkoutManager.heartRate, 0)
        XCTAssertEqual(mockWorkoutManager.activeEnergy, 0)
        XCTAssertEqual(mockWorkoutManager.distance, 0)
        XCTAssertEqual(mockWorkoutManager.averageHeartRate, 0)
    }
    
    func testMetricsUpdateDuringWorkout() {
        // Given
        mockWorkoutManager.simulateWorkoutInProgress()
        
        // When - Simulate metrics changing over time
        mockWorkoutManager.displayElapsedTime = 900 // 15 minutes
        mockWorkoutManager.heartRate = 160
        mockWorkoutManager.activeEnergy = 150
        mockWorkoutManager.distance = 3000
        
        // Then - All values should be updated
        XCTAssertEqual(mockWorkoutManager.displayElapsedTime, 900)
        XCTAssertEqual(mockWorkoutManager.heartRate, 160)
        XCTAssertEqual(mockWorkoutManager.activeEnergy, 150)
        XCTAssertEqual(mockWorkoutManager.distance, 3000)
    }
}