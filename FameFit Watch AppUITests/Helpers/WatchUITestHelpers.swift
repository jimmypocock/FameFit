//
//  WatchUITestHelpers.swift
//  FameFit Watch AppUITests
//
//  Robust helper utilities for Watch app UI testing
//

import XCTest

extension XCUIApplication {
    
    /// Handle HealthKit permission dialog if it appears
    func handleHealthKitPermission(timeout: TimeInterval = 3) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        if allowButton.waitForExistence(timeout: timeout) {
            allowButton.tap()
        }
    }
    
    /// Start a workout by selecting from the list
    /// - Parameter type: The workout type to select (e.g., "Running", "Walking")
    /// - Returns: True if workout was successfully started
    @discardableResult
    func startWorkout(type: String) -> Bool {
        // Try to find as button first, then as text
        let workoutButton = buttons[type].firstMatch
        let workoutText = staticTexts[type].firstMatch
        
        if workoutButton.waitForExistence(timeout: 5) {
            workoutButton.tap()
            return true
        } else if workoutText.waitForExistence(timeout: 2) {
            workoutText.tap()
            return true
        }
        
        return false
    }
    
    /// Check if we're in a workout session by looking for workout UI elements
    func isInWorkoutSession() -> Bool {
        // Check for any common workout session elements
        return buttons["Pause"].exists ||
               buttons["Resume"].exists ||
               buttons["End"].exists ||
               otherElements["MetricsView"].exists
    }
    
    /// Navigate between workout session pages
    enum WorkoutPage {
        case metrics
        case controls
        case nowPlaying
    }
    
    func navigateToWorkoutPage(_ page: WorkoutPage) {
        switch page {
        case .metrics:
            // Metrics is usually the default/center page
            // Swipe right if we're on controls
            if buttons["End"].exists {
                swipeRight()
            }
        case .controls:
            // Controls is usually to the left
            swipeLeft()
        case .nowPlaying:
            // Now Playing is usually to the right
            swipeRight()
        }
    }
    
    /// Safely end workout if one is in progress
    func endWorkoutIfNeeded() {
        if isInWorkoutSession() {
            navigateToWorkoutPage(.controls)
            
            if buttons["End"].waitForExistence(timeout: 3) {
                buttons["End"].tap()
                
                // Dismiss summary if it appears
                if buttons["Done"].waitForExistence(timeout: 3) {
                    buttons["Done"].tap()
                }
            }
        }
    }
}

/// Test data helpers
struct WatchUITestData {
    static let workoutTypes = ["Running", "Walking", "Cycling", "Yoga", "Swimming"]
    static let defaultTimeout: TimeInterval = 5
    static let shortTimeout: TimeInterval = 3
}

/// XCTest assertion helpers for Watch-specific UI
extension XCTestCase {
    
    /// Assert that a workout can be started
    func assertCanStartWorkout(type: String, in app: XCUIApplication, 
                               file: StaticString = #file, line: UInt = #line) {
        app.handleHealthKitPermission()
        
        let started = app.startWorkout(type: type)
        XCTAssertTrue(started, "Should be able to start \(type) workout", 
                     file: file, line: line)
        
        // Verify we're in a workout session
        XCTAssertTrue(app.isInWorkoutSession(), 
                     "Should be in workout session after starting", 
                     file: file, line: line)
    }
    
    /// Assert that the app has launched successfully
    func assertAppLaunched(_ app: XCUIApplication, 
                          file: StaticString = #file, line: UInt = #line) {
        // Check for any expected UI element that indicates successful launch
        let launched = app.buttons.count > 0 || app.staticTexts.count > 0
        XCTAssertTrue(launched, "App should have UI elements after launch", 
                     file: file, line: line)
    }
}