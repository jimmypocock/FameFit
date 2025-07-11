//
//  WorkoutSelectionUITests.swift
//  FameFit Watch AppUITests
//
//  Tests for workout selection and launch flow on Watch app
//

import XCTest

final class WorkoutSelectionUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testLaunchAndNavigateToWorkout() throws {
        // Launch the Watch app
        let app = XCUIApplication()
        app.launch()
        
        // Give the app a moment to fully launch
        sleep(3)
        
        // Look for workout buttons - they might be in a carousel list
        let runButton = app.buttons["Run"]
        let walkButton = app.buttons["Walk"]
        let bikeButton = app.buttons["Bike"]
        
        // Wait for at least one workout option to appear
        let workoutExists = runButton.waitForExistence(timeout: 5) || 
                           walkButton.waitForExistence(timeout: 5) || 
                           bikeButton.waitForExistence(timeout: 5)
        
        XCTAssertTrue(workoutExists, "Should see at least one workout option")
        
        // Test navigation by tapping a workout
        if runButton.exists {
            runButton.tap()
            sleep(2)
            // Verify we navigated to the session view
            XCTAssertTrue(app.staticTexts["Run"].exists || app.navigationBars["Run"].exists, 
                         "Should navigate to Run workout session")
        }
    }
    
    // Commented out due to LaunchServices issues on simulators
    // Uncomment only when needed for specific performance testing
    /*
    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    */
}