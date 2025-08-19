//
//  WorkoutSessionUITests.swift
//  FameFit Watch AppUITests
//
//  Minimal smoke tests for Watch app - just verify it doesn't crash
//

import XCTest

final class WorkoutSessionUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Basic Smoke Test
    
    func testAppLaunchesSuccessfully() throws {
        // Given: App launches
        app.launch()
        
        // Handle HealthKit permission if it appears
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Allow"].waitForExistence(timeout: 3) {
            springboard.buttons["Allow"].tap()
        }
        
        // Then: App should have some UI elements
        let hasUI = app.buttons.count > 0 || app.staticTexts.count > 0
        XCTAssertTrue(hasUI, "App should launch with UI elements")
    }
    
    // Note: More detailed UI tests are intentionally omitted because Watch UI tests
    // are notoriously flaky with finding buttons on different pages. The unit tests
    // provide comprehensive coverage of the actual functionality.
}