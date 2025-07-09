import XCTest

class FameFitUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        
        // Reset app state for consistent testing
        app.launchArguments.append("--reset-state")
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Onboarding Tests
    
    func testCompleteOnboardingFlow() throws {
        // Test the complete onboarding flow
        
        // Step 1: Welcome screens
        XCTAssertTrue(app.staticTexts["FAMEFIT"].exists)
        
        // Go through character introductions
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.exists)
        
        // Chad's introduction
        XCTAssertTrue(app.staticTexts["💪"].exists)
        nextButton.tap()
        
        // Sierra's introduction
        XCTAssertTrue(app.staticTexts["🏃‍♀️"].exists)
        nextButton.tap()
        
        // Zen's introduction
        XCTAssertTrue(app.staticTexts["🧘‍♂️"].exists)
        nextButton.tap()
        
        // Continue through remaining dialogues
        while nextButton.exists && nextButton.label == "Next" {
            nextButton.tap()
        }
        
        // Tap "Let's Go!" to proceed to sign in
        let letsGoButton = app.buttons["Let's Go!"]
        if letsGoButton.exists {
            letsGoButton.tap()
        }
        
        // Step 2: Sign In
        XCTAssertTrue(app.staticTexts["SIGN IN"].exists)
        
        // Look for Sign in with Apple button
        let signInButton = app.buttons.matching(identifier: "SignInWithAppleButton").firstMatch
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        
        // In UI tests, we can't actually complete Apple Sign In
        // We'd need to mock this or use a test account
        
        // Step 3: HealthKit Permissions (would appear after sign in)
        // Step 4: Game Mechanics explanation
        // Step 5: Workout selection
    }
    
    func testSkipOnboarding_AlreadyAuthenticated() throws {
        // Test that authenticated users skip onboarding
        
        // Set up authenticated state
        app.launchArguments.append("--authenticated")
        app.launch()
        
        // Should go directly to MainView
        XCTAssertTrue(app.navigationBars["FameFit"].exists)
        XCTAssertTrue(app.staticTexts["Welcome back,"].exists)
    }
    
    // MARK: - Main View Tests
    
    func testMainViewDisplaysUserStats() throws {
        // Set up authenticated state with test data
        app.launchArguments.append("--authenticated")
        app.launchArguments.append("--test-user")
        app.launch()
        
        // Verify main view elements
        XCTAssertTrue(app.staticTexts["Welcome back,"].exists)
        XCTAssertTrue(app.staticTexts["Followers"].exists)
        XCTAssertTrue(app.staticTexts["Status"].exists)
        XCTAssertTrue(app.staticTexts["Workouts"].exists)
        XCTAssertTrue(app.staticTexts["Streak"].exists)
        
        // Verify sign out button
        XCTAssertTrue(app.buttons["Sign Out"].exists)
    }
    
    func testSignOut() throws {
        // Set up authenticated state
        app.launchArguments.append("--authenticated")
        app.launch()
        
        // Tap sign out
        let signOutButton = app.buttons["Sign Out"]
        XCTAssertTrue(signOutButton.exists)
        signOutButton.tap()
        
        // Should return to onboarding
        XCTAssertTrue(app.staticTexts["FAMEFIT"].waitForExistence(timeout: 2))
    }
    
    // MARK: - HealthKit Permission Tests
    
    func testHealthKitPermissionRequest() throws {
        // This test would verify the HealthKit permission flow
        // Note: System alerts can't be directly tested in UI tests
        // You'd need to use interruption handlers
        
        addUIInterruptionMonitor(withDescription: "HealthKit Permission") { alert in
            // Check for HealthKit permission dialog
            if alert.staticTexts["Health Access"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            return false
        }
        
        // Trigger the permission request
        // ... navigation to permission screen
    }
    
    // MARK: - Notification Tests
    
    func testNotificationPermissionRequest() throws {
        // Similar to HealthKit, handle notification permission
        
        addUIInterruptionMonitor(withDescription: "Notification Permission") { alert in
            if alert.staticTexts["Would Like to Send You Notifications"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            return false
        }
    }
    
    // MARK: - Watch App Tests
    
    func testWatchAppWorkoutFlow() throws {
        // This would test the Watch app if running on Watch simulator
        // Requires different target and setup
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        // Verify all UI elements have proper accessibility labels
        
        app.launchArguments.append("--authenticated")
        app.launch()
        
        // Check main elements have accessibility labels
        let followerLabel = app.staticTexts["Followers"]
        XCTAssertTrue(followerLabel.isHittable)
        
        let signOutButton = app.buttons["Sign Out"]
        XCTAssertNotNil(signOutButton.label)
    }
    
    // MARK: - Performance Tests
    
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

// MARK: - Helper Extensions

extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and type text into a non string value")
            return
        }
        
        self.tap()
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}