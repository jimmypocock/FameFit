//
//  MockWorkoutManager.swift
//  FameFit Watch AppTests
//
//  Mock implementation of WorkoutManaging for testing
//

import Foundation
import HealthKit
@testable import FameFit_Watch_App

class MockWorkoutManager: ObservableObject, WorkoutManaging {
    // MARK: - Published Properties
    
    @Published var selectedWorkout: HKWorkoutActivityType?
    @Published var showingSummaryView: Bool = false
    
    // MARK: - Mock Control Properties
    
    var isWorkoutRunning: Bool = false
    var isPaused: Bool = false
    var displayElapsedTime: TimeInterval = 0
    var averageHeartRate: Double = 0
    var heartRate: Double = 0
    var activeEnergy: Double = 0
    var distance: Double = 0
    var workout: HKWorkout?
    var averageHeartRateForSummary: Double = 0
    var totalCaloriesForSummary: Double = 0
    var totalDistanceForSummary: Double = 0
    var elapsedTimeForSummary: TimeInterval = 0
    
    // MARK: - Method Tracking
    
    var startWorkoutCalled = false
    var startWorkoutCalledWith: HKWorkoutActivityType?
    var pauseCalled = false
    var resumeCalled = false
    var togglePauseCalled = false
    var endWorkoutCalled = false
    var resetWorkoutCalled = false
    var requestAuthorizationCalled = false
    
    // MARK: - Mock Configuration
    
    var shouldFailAuthorization = false
    var shouldSimulateActiveWorkout = false
    
    // MARK: - WorkoutManaging Implementation
    
    func startWorkout(workoutType: HKWorkoutActivityType) {
        startWorkoutCalled = true
        startWorkoutCalledWith = workoutType
        
        if shouldSimulateActiveWorkout {
            isWorkoutRunning = true
            isPaused = false
            selectedWorkout = workoutType
            
            // Simulate some workout data
            displayElapsedTime = 300 // 5 minutes
            heartRate = 120
            averageHeartRate = 115
            activeEnergy = 50
            distance = 1000 // 1km
        }
    }
    
    func pause() {
        pauseCalled = true
        if isWorkoutRunning {
            isPaused = true
        }
    }
    
    func resume() {
        resumeCalled = true
        if isWorkoutRunning {
            isPaused = false
        }
    }
    
    func togglePause() {
        togglePauseCalled = true
        if isWorkoutRunning {
            isPaused.toggle()
        }
    }
    
    func endWorkout() {
        endWorkoutCalled = true
        
        if isWorkoutRunning {
            // Transfer current values to summary
            averageHeartRateForSummary = averageHeartRate
            totalCaloriesForSummary = activeEnergy
            totalDistanceForSummary = distance
            elapsedTimeForSummary = displayElapsedTime
            
            // Create a mock workout
            workout = createMockWorkout()
            
            // Reset running state
            isWorkoutRunning = false
            isPaused = false
            showingSummaryView = true
        }
    }
    
    func resetWorkout() {
        resetWorkoutCalled = true
        
        // Reset all values
        selectedWorkout = nil
        isWorkoutRunning = false
        isPaused = false
        displayElapsedTime = 0
        averageHeartRate = 0
        heartRate = 0
        activeEnergy = 0
        distance = 0
        workout = nil
        showingSummaryView = false
    }
    
    func requestAuthorization() {
        requestAuthorizationCalled = true
        
        if shouldFailAuthorization {
            // Simulate authorization failure
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockWorkout() -> HKWorkout? {
        // Create a mock workout for testing
        _ = selectedWorkout ?? .running
        _ = Date().addingTimeInterval(-displayElapsedTime)
        _ = Date()
        
        // Create energy and distance quantities
        let energyUnit = HKUnit.kilocalorie()
        _ = HKQuantity(unit: energyUnit, doubleValue: totalCaloriesForSummary)
        
        let distanceUnit = HKUnit.meter()
        _ = HKQuantity(unit: distanceUnit, doubleValue: totalDistanceForSummary)
        
        // Note: In real tests, we might need to use HKWorkout.init with proper parameters
        // For now, we'll return nil as creating HKWorkout requires specific setup
        return nil
    }
    
    // MARK: - Test Helper Methods
    
    func simulateWorkoutInProgress(
        type: HKWorkoutActivityType = .running,
        duration: TimeInterval = 600,
        heartRate: Double = 130,
        calories: Double = 75,
        distance: Double = 1500
    ) {
        selectedWorkout = type
        isWorkoutRunning = true
        isPaused = false
        displayElapsedTime = duration
        self.heartRate = heartRate
        self.averageHeartRate = heartRate - 5
        self.activeEnergy = calories
        self.distance = distance
    }
    
    func simulatePausedWorkout() {
        guard isWorkoutRunning else { return }
        isPaused = true
    }
    
    func simulateWorkoutCompletion() {
        guard isWorkoutRunning else { return }
        endWorkout()
    }
    
    func reset() {
        // Reset all tracking properties
        startWorkoutCalled = false
        startWorkoutCalledWith = nil
        pauseCalled = false
        resumeCalled = false
        togglePauseCalled = false
        endWorkoutCalled = false
        resetWorkoutCalled = false
        requestAuthorizationCalled = false
        
        // Reset configuration
        shouldFailAuthorization = false
        shouldSimulateActiveWorkout = false
        
        // Reset workout state
        resetWorkout()
    }
}