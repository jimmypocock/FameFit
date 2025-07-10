import XCTest

class WorkoutFlowUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "--skip-onboarding", "--mock-healthkit"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Workout Detection UI Tests
    
    func testFollowerCountSection() {
        // Verify follower count UI is visible
        XCTAssertTrue(app.staticTexts["Followers"].waitForExistence(timeout: 5), "Should show Followers label")
        
        // Get initial follower count
        let initialCount = getFollowerCount()
        XCTAssertNotNil(initialCount, "Should display a follower count")
    }
    
    func testWorkoutStatsDisplay() {
        // Verify workout stats are displayed
        XCTAssertTrue(app.staticTexts["Workouts"].exists, "Should show Workouts label")
        XCTAssertTrue(app.staticTexts["Streak"].exists, "Should show Streak label")
        
        // Verify stats have values
        let workoutStat = app.staticTexts.matching(identifier: "workout-count").firstMatch
        let streakStat = app.staticTexts.matching(identifier: "streak-count").firstMatch
        
        if workoutStat.exists {
            XCTAssertFalse(workoutStat.label.isEmpty, "Workout count should have a value")
        }
        
        if streakStat.exists {
            XCTAssertFalse(streakStat.label.isEmpty, "Streak count should have a value")
        }
    }
    
    func testWorkoutInstructionsVisible() {
        // Verify instructions are visible
        XCTAssertTrue(app.staticTexts["Your Journey"].exists, "Should show Your Journey section")
        XCTAssertTrue(app.staticTexts.containing(.text, "Complete workouts").element.exists, 
                     "Should show workout instructions")
        XCTAssertTrue(app.staticTexts["Current rate: +5 followers per workout"].exists, 
                     "Should show follower gain rate")
    }
    
    // MARK: - Mock Workout Tests
    
    func testMockWorkoutFlow() {
        // This test would use mock data if the app supports it
        // In a real implementation, you might:
        // 1. Trigger a mock workout through a debug menu
        // 2. Verify the follower count increases
        // 3. Check for notification or UI update
        
        let initialFollowers = getFollowerCount() ?? 0
        
        // If the app has a debug menu for triggering mock workouts
        if app.buttons["Debug Menu"].exists {
            app.buttons["Debug Menu"].tap()
            
            if app.buttons["Trigger Mock Workout"].exists {
                app.buttons["Trigger Mock Workout"].tap()
                
                // Wait for UI to update
                sleep(2)
                
                let newFollowers = getFollowerCount() ?? 0
                XCTAssertEqual(newFollowers, initialFollowers + 5, 
                             "Followers should increase by 5 after workout")
            }
        }
    }
    
    // MARK: - UI Update Tests
    
    func testUIUpdatesAfterWorkout() {
        // Verify UI can handle updates
        // In a real test with HealthKit integration, this would:
        // 1. Record initial state
        // 2. Trigger a workout (through companion Watch app or mock)
        // 3. Verify all UI elements update correctly
        
        // For now, just verify the UI is responsive
        let refreshControl = app.otherElements["pull.to.refresh"]
        if refreshControl.exists {
            refreshControl.swipeDown()
            
            // Verify UI remains stable after refresh
            XCTAssertTrue(app.staticTexts["Followers"].exists, "UI should remain stable after refresh")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFollowerCount() -> Int? {
        // Look for numeric text that represents follower count
        let followerSection = app.otherElements.containing(.staticText, identifier: "Followers").firstMatch
        
        if followerSection.exists {
            let numericLabels = followerSection.staticTexts.matching(
                NSPredicate(format: "label MATCHES %@", "^[0-9]+$")
            )
            
            if numericLabels.count > 0 {
                let followerText = numericLabels.firstMatch.label
                return Int(followerText)
            }
        }
        
        return nil
    }
    
    private func waitForFollowerCountChange(from initialCount: Int, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                if let currentCount = self.getFollowerCount() {
                    return currentCount != initialCount
                }
                return false
            },
            object: nil
        )
        
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}