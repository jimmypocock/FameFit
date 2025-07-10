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
        let nextButton = app.buttons["Next"]
        
        // Chad's introduction
        XCTAssertTrue(app.staticTexts["💪"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textViews.containing(.text, "Chad").element.exists)
        nextButton.tap()
        
        // Sierra's introduction
        XCTAssertTrue(app.staticTexts["🏃‍♀️"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textViews.containing(.text, "Sierra").element.exists)
        nextButton.tap()
        
        // Zen's introduction
        XCTAssertTrue(app.staticTexts["🧘‍♂️"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textViews.containing(.text, "Zen").element.exists)
        nextButton.tap()
    }
    
    // MARK: - Sign In Tests
    
    func testSignInWithAppleFlow() {
        // Navigate to sign in screen
        navigateToSignInScreen()
        
        // Verify Sign in with Apple button exists
        let signInButton = app.buttons.matching(identifier: "Sign in with Apple").element
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5), "Should show Sign in with Apple button")
        
        // Note: Can't fully test Sign in with Apple in UI tests
        // Would need to use XCUITest's authorization testing capabilities
    }
    
    // MARK: - HealthKit Permission Tests
    
    func testHealthKitPermissionScreen() {
        // Navigate through onboarding to HealthKit screen
        navigateToHealthKitScreen()
        
        // Verify HealthKit permission UI elements
        XCTAssertTrue(app.staticTexts["Health Access"].exists, "Should show Health Access title")
        XCTAssertTrue(app.staticTexts.containing(.text, "track your workouts").element.exists)
        XCTAssertTrue(app.buttons["Authorize HealthKit"].exists, "Should show authorize button")
    }
    
    // MARK: - Complete Flow Test
    
    func testCompleteOnboardingFlow() {
        // Go through all character introductions
        let nextButton = app.buttons["Next"]
        
        // Character introductions
        for _ in 0..<6 {  // 6 characters
            if nextButton.exists {
                nextButton.tap()
            }
        }
        
        // Continue to explanation screens
        while nextButton.exists && nextButton.isEnabled {
            nextButton.tap()
            sleep(1)  // Brief pause to let animations complete
        }
        
        // Should eventually reach sign in or main screen
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                self.app.buttons["Sign in with Apple"].exists ||
                self.app.staticTexts["Followers"].exists
            },
            object: nil
        )
        
        wait(for: [expectation], timeout: 10)
    }
    
    // MARK: - Helper Methods
    
    private func navigateToSignInScreen() {
        let nextButton = app.buttons["Next"]
        
        // Skip through character introductions
        for _ in 0..<10 {
            if nextButton.exists && nextButton.isEnabled {
                nextButton.tap()
            }
            if app.buttons["Sign in with Apple"].exists {
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