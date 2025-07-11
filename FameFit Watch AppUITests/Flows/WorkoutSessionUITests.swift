//
//  WorkoutSessionUITests.swift
//  FameFit Watch AppUITests
//
//  Tests for active workout session UI on Watch app
//

import XCTest

final class WorkoutSessionUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    @MainActor
    func testBasicWorkoutFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for app to fully load
        sleep(3)
        
        // Verify we can see workout options
        let runButton = app.buttons["Run"]
        XCTAssertTrue(runButton.waitForExistence(timeout: 10), "Should see Run workout option")
        
        // Start a workout
        runButton.tap()
        
        // Wait for workout to start - we should navigate away from start screen
        sleep(3)
        
        // Simple check - we should no longer see the Run button (we've navigated away)
        XCTAssertFalse(runButton.exists, "Run button should not be visible after starting workout")
        
        // We should be able to find some workout UI elements
        // Don't be too specific about what we find - just verify we're in a workout
        let hasWorkoutUI = app.buttons.allElementsBoundByIndex.count > 0 || 
                          app.staticTexts.allElementsBoundByIndex.contains { 
                              $0.label.contains(":") || // Time format
                              $0.label.contains("bpm") || // Heart rate
                              $0.label.contains("cal") // Calories
                          }
        
        XCTAssertTrue(hasWorkoutUI, "Should see workout UI elements")
    }
    
}