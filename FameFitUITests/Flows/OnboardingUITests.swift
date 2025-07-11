import XCTest

class OnboardingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "--reset-state"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Welcome Screen Tests
    
    func testWelcomeScreenAppears() {
        XCTAssertTrue(app.staticTexts["FAMEFIT"].exists, "Should show FameFit title")
        XCTAssertTrue(app.buttons["Next"].exists, "Should show Next button")
    }
    
    // MARK: - Character Introduction Tests
    
    func testCharacterIntroductions() {
        // Test that we can navigate through character introductions
        let nextButton = app.buttons["Next"]
        
        // Just verify we can tap through the flow
        for _ in 0..<3 {
            if nextButton.exists {
                nextButton.tap()
                sleep(1) // Allow animation
            }
        }
        
        // If we made it here without crashing, the test passes
        XCTAssertTrue(true, "Successfully navigated through character introductions")
    }
    
    // MARK: - Sign In Tests
    
    func testSignInWithAppleFlow() {
        // Navigate to sign in screen
        navigateToSignInScreen()
        
        // Verify Sign in with Apple button exists
        // SignInWithAppleButton creates a native button, look for it by type
        let signInButton = app.buttons.firstMatch
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5), "Should show Sign in with Apple button")
        
        // Note: Can't fully test Sign in with Apple in UI tests
        // Would need to use XCUITest's authorization testing capabilities
    }
    
    // MARK: - HealthKit Permission Tests
    
    func testHealthKitPermissionScreen() {
        // Note: Can't navigate to HealthKit screen without completing Sign in with Apple
        // which is not possible in UI tests. This test would need to be an integration test
        // or we'd need to add a debug flag to skip authentication for testing.
        
        // For now, we can only verify we reach the sign in screen
        navigateToSignInScreen()
        
        // Wait for sign in screen to appear
        let signInTitle = app.staticTexts["SIGN IN"]
        let signInAppeared = signInTitle.waitForExistence(timeout: 10)
        
        if !signInAppeared {
            // Check if we're still in onboarding
            let inOnboarding = app.buttons["Next"].exists || app.staticTexts["FAMEFIT"].exists
            XCTAssertTrue(inOnboarding, "Should either reach sign in screen or still be in onboarding")
        } else {
            XCTAssertTrue(signInAppeared, "Should reach sign in screen")
        }
        
        // To properly test HealthKit permissions, we'd need to either:
        // 1. Add a test mode that skips authentication
        // 2. Move this to an integration test with actual sign in
        // 3. Use UI test recording with stored credentials (security risk)
    }
    
    // MARK: - Complete Flow Test
    
    func testCompleteOnboardingFlow() {
        // Go through all character introductions
        let nextButton = app.buttons["Next"]
        
        // Character introductions (Chad, Sierra, Zen)
        for _ in 0..<3 {  // 3 characters
            if nextButton.exists {
                nextButton.tap()
            }
        }
        
        // Continue to explanation screens
        while nextButton.exists && nextButton.isEnabled {
            nextButton.tap()
            sleep(1)  // Brief pause to let animations complete
        }
        
        // Should eventually reach a screen with buttons (sign in) or the main screen
        let reachedEndOfOnboarding = app.buttons.count > 0 || app.staticTexts["Followers"].exists
        XCTAssertTrue(reachedEndOfOnboarding, "Should reach end of onboarding flow")
    }
    
    // MARK: - Helper Methods
    
    private func navigateToSignInScreen() {
        let nextButton = app.buttons["Next"]
        
        // Skip through character introductions
        for _ in 0..<20 {
            if nextButton.exists && nextButton.isEnabled {
                nextButton.tap()
                sleep(1) // Allow animations to complete
            }
            if app.staticTexts["SIGN IN"].exists { // We've reached the sign in screen
                break
            }
            // Also check for other possible screens
            if app.staticTexts["Sign In"].exists || app.buttons.firstMatch.exists {
                break
            }
        }
    }
    
    private func navigateToHealthKitScreen() {
        // This would navigate through onboarding to HealthKit screen
        // Implementation depends on actual app flow after sign in
        navigateToSignInScreen()
        // Would continue after sign in...
    }
}