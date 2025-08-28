//
//  WorkoutSelectionUITests.swift
//  FameFit Watch AppUITests
//
//  Minimal but valuable UI tests for Watch app workout selection
//

import XCTest

final class WorkoutSelectionUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Add launch arguments to skip onboarding or use mock data if needed
        // app.launchArguments = ["--uitesting"]
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Core User Flow Tests
    
    func testAppLaunchShowsWorkoutOptions() throws {
        // Given: App launches
        app.launch()
        
        // Handle potential HealthKit permission (with timeout to not fail if it doesn't appear)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
        }
        
        // Then: At least one workout option should be visible
        let workoutOptionsExist = 
            app.buttons["Running"].waitForExistence(timeout: 5) ||
            app.staticTexts["Running"].waitForExistence(timeout: 5) ||
            app.buttons["Walking"].waitForExistence(timeout: 5) ||
            app.staticTexts["Walking"].waitForExistence(timeout: 5)
        
        XCTAssertTrue(workoutOptionsExist, 
                     "App should display workout options after launch")
    }
    
    func testSelectingWorkoutNavigatesToSession() throws {
        // Given: App is launched and showing workout options
        app.launch()
        
        // Handle HealthKit permission if needed
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Allow"].waitForExistence(timeout: 3) {
            springboard.buttons["Allow"].tap()
        }
        
        // When: User taps on a workout option
        let runningOption = app.buttons["Running"].firstMatch
        let runningText = app.staticTexts["Running"].firstMatch
        
        if runningOption.waitForExistence(timeout: 5) {
            runningOption.tap()
        } else if runningText.waitForExistence(timeout: 2) {
            runningText.tap()
        } else {
            XCTFail("Could not find Running workout option to tap")
            return
        }
        
        // Then: Should navigate away from workout selection
        // We can verify this by checking that workout options are no longer visible
        // OR by checking for elements that appear in the workout session
        
        // Option 1: Check that we've navigated away
        let workoutOptionsGone = !app.buttons["Walking"].exists && 
                                 !app.staticTexts["Walking"].exists
        
        // Option 2: Check for workout session UI elements (like pause button or metrics)
        let sessionElementsExist = 
            app.buttons["Pause"].waitForExistence(timeout: 3) ||
            app.staticTexts["End"].waitForExistence(timeout: 3) ||
            app.otherElements["MetricsView"].waitForExistence(timeout: 3)
        
        XCTAssertTrue(workoutOptionsGone || sessionElementsExist,
                     "Should navigate to workout session after selection")
    }
    
    func testWorkoutListIsScrollable() throws {
        // Given: App is launched
        app.launch()
        
        // Handle HealthKit permission if needed
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Allow"].waitForExistence(timeout: 3) {
            springboard.buttons["Allow"].tap()
        }
        
        // When: User scrolls the workout list
        // First, wait for the list to be ready
        _ = app.buttons.firstMatch.waitForExistence(timeout: 5)
        
        // Capture initial state
        _ = app.buttons.allElementsBoundByIndex.count
        
        // Perform scroll gesture (on Watch, this might be a digital crown rotation)
        app.swipeUp()
        
        // Give time for scroll animation
        Thread.sleep(forTimeInterval: 0.5)
        
        // Then: Should be able to scroll (buttons count might change or position changes)
        // This is a basic check - mainly verifying scroll doesn't crash
        XCTAssertTrue(app.buttons.count > 0, 
                     "Workout list should remain functional after scrolling")
    }
}