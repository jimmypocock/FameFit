import XCTest

class WorkoutFlowUITests: BaseUITestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Launch app skipping onboarding
        app.launchArguments = ["UI-Testing", "--skip-onboarding"]
        app.launch()
        wait(for: 0.5)
    }
    
    // MARK: - Workout Detection UI Tests
    
    func testFollowerCountSection() {
        // Wait for main screen to load
        assertExistsEventually(app.staticTexts["Influencer XP"], "Should show Influencer XP label")
        
        // Get initial follower count using safe element access
        let staticTexts = getLabels(from: app.staticTexts)
        let hasNumericValue = staticTexts.contains { label in
            Int(label) != nil
        }
        
        XCTAssertTrue(hasNumericValue, "Should display a follower count")
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
    
    func testWorkoutStatsVisible() {
        // Verify workout stats are visible
        XCTAssertTrue(app.staticTexts["Workouts"].exists, "Should show Workouts stat")
        XCTAssertTrue(app.staticTexts["Streak"].exists, "Should show Streak stat")
        
        // Verify stats section exists
        let memberSince = app.staticTexts["Member Since"].exists
        let lastWorkout = app.staticTexts["Last Workout"].exists
        
        XCTAssertTrue(memberSince && lastWorkout, "Should show membership info")
    }
    
    // MARK: - Mock Workout Tests
    
    func testMockWorkoutFlow() {
        // This test would use mock data if the app supports it
        // In a real implementation, you might:
        // 1. Trigger a mock workout through a debug menu
        // 2. Verify the XP count increases
        // 3. Check for notification or UI update
        
        let initialXP = getFollowerCount() ?? 0
        
        // If the app has a debug menu for triggering mock workouts
        if app.buttons["Debug Menu"].exists {
            app.buttons["Debug Menu"].tap()
            
            if app.buttons["Trigger Mock Workout"].exists {
                app.buttons["Trigger Mock Workout"].tap()
                
                // Wait for UI to update
                sleep(2)
                
                let newXP = getFollowerCount() ?? 0
                XCTAssertGreaterThan(newXP, initialXP, 
                             "XP should increase after workout")
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
            XCTAssertTrue(app.staticTexts["Influencer XP"].exists, "UI should remain stable after refresh")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFollowerCount() -> Int? {
        // Look for numeric text that represents XP count
        let xpSection = app.otherElements.containing(.staticText, identifier: "Influencer XP").firstMatch
        
        if xpSection.exists {
            let numericLabels = xpSection.staticTexts.matching(
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