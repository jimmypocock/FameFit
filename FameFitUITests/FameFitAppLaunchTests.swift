//
//  FameFitAppLaunchTests.swift
//  FameFitUITests
//
//  Basic UI test to verify app launches successfully
//

import XCTest

final class FameFitAppLaunchTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // In UI tests it is usually best to stop immediately when a failure occurs
        continueAfterFailure = false
        
        // Initialize the app
        app = XCUIApplication()
        
        // You can add launch arguments here for test configuration
        // For example: app.launchArguments = ["--reset-state"]
    }
    
    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }
    
    func testAppLaunchesSuccessfully() throws {
        // Given: The app is ready to launch
        XCTAssertNotNil(app, "App should be initialized")
        
        // When: We launch the app
        app.launch()
        
        // Then: The app should be in running state
        XCTAssertTrue(app.state == .runningForeground, "App should be running in foreground")
        
        // Wait a moment to ensure the app has fully launched
        let exists = app.wait(for: .runningForeground, timeout: 3.0)
        XCTAssertTrue(exists, "App should remain in running state")
        
        // Verify that at least one element exists (basic UI loaded)
        // This will be true whether we're on onboarding or main view
        let anyElement = app.windows.firstMatch.exists || 
                         app.buttons.firstMatch.exists || 
                         app.staticTexts.firstMatch.exists
        
        XCTAssertTrue(anyElement, "App should have loaded some UI elements")
    }
    
    func testAppLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            // Measure how long it takes for the app to launch
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                app.launch()
            }
        }
    }
}