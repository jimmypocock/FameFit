//
//  WatchUITestHelpers.swift
//  FameFit Watch AppUITests
//
//  Helper utilities for Watch app UI testing
//

import XCTest

extension XCUIApplication {
    
    /// Launch the Watch app and wait for it to be ready
    func launchAndWaitForReady() {
        launch()
        
        // Wait for the app to fully launch
        _ = waitForExistence(timeout: 5)
        
        // Additional wait for Watch app initialization
        Thread.sleep(forTimeInterval: 2)
    }
    
    /// Start a workout of the specified type
    func startWorkout(type: String) {
        let workoutButton = buttons[type].firstMatch
        guard workoutButton.waitForExistence(timeout: 5) else {
            XCTFail("Could not find workout button: \(type)")
            return
        }
        workoutButton.tap()
    }
    
    /// Navigate to the controls view in an active workout
    func navigateToControlsView() {
        // Swipe left to get to controls
        swipeLeft()
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    /// End the current workout session
    func endWorkout() {
        navigateToControlsView()
        
        let endButton = buttons["End"].firstMatch
        guard endButton.waitForExistence(timeout: 3) else {
            XCTFail("Could not find End button")
            return
        }
        endButton.tap()
    }
}

/// Common workout types for testing
enum TestWorkoutType {
    static let run = "Run"
    static let walk = "Walk"
    static let bike = "Bike"
}