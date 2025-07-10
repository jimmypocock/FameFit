import XCTest

class MainScreenUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "--skip-onboarding"]
        app.launch()
        
        // Complete onboarding if needed
        completeOnboardingIfNeeded()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Main Screen Layout Tests
    
    func testMainScreenElements() {
        // Verify all main screen elements are present
        XCTAssertTrue(app.staticTexts["Followers"].waitForExistence(timeout: 5), "Should show Followers label")
        XCTAssertTrue(app.staticTexts["Status"].exists, "Should show Status label")
        XCTAssertTrue(app.staticTexts["Workouts"].exists, "Should show Workouts stat")
        XCTAssertTrue(app.staticTexts["Streak"].exists, "Should show Streak stat")
        XCTAssertTrue(app.staticTexts["Your Journey"].exists, "Should show Your Journey section")
        XCTAssertTrue(app.buttons["Sign Out"].exists, "Should show Sign Out button")
    }
    
    func testFollowerCountDisplay() {
        // Verify follower count is displayed as a number
        let followerLabels = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+$"))
        XCTAssertGreaterThan(followerLabels.count, 0, "Should display at least one numeric value for followers")
    }
    
    func testStatusDisplay() {
        // Verify status is displayed
        let possibleStatuses = ["Fitness Newbie", "Micro-Influencer", "Rising Star", "Verified Influencer", "FameFit Elite"]
        
        var statusFound = false
        for status in possibleStatuses {
            if app.staticTexts[status].exists {
                statusFound = true
                break
            }
        }
        
        XCTAssertTrue(statusFound, "Should display a valid status")
    }
    
    // MARK: - User Interaction Tests
    
    func testSignOutButton() {
        let signOutButton = app.buttons["Sign Out"]
        XCTAssertTrue(signOutButton.exists, "Sign Out button should exist")
        XCTAssertTrue(signOutButton.isEnabled, "Sign Out button should be enabled")
        
        // Tap sign out
        signOutButton.tap()
        
        // Should return to onboarding
        XCTAssertTrue(app.staticTexts["FAMEFIT"].waitForExistence(timeout: 5), "Should return to onboarding after sign out")
    }
    
    func testScrolling() {
        // Test that the view is scrollable if content is long
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            // Verify we can scroll back
            scrollView.swipeDown()
        }
    }
    
    // MARK: - Workout Information Tests
    
    func testWorkoutInformationDisplay() {
        // Verify workout information is displayed
        XCTAssertTrue(app.staticTexts.containing(.text, "Complete workouts").element.exists, 
                     "Should show workout instructions")
        XCTAssertTrue(app.staticTexts["Current rate: +5 followers per workout"].exists, 
                     "Should show follower rate")
    }
    
    func testUserNameDisplay() {
        // Look for a greeting or user name
        // The actual implementation might vary
        let greetingTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Welcome"))
        XCTAssertGreaterThan(greetingTexts.count, 0, "Should display a welcome message")
    }
    
    // MARK: - Helper Methods
    
    private func completeOnboardingIfNeeded() {
        if app.staticTexts["FAMEFIT"].exists {
            // Complete onboarding flow
            let nextButton = app.buttons["Next"]
            for _ in 0..<20 {
                if nextButton.exists && nextButton.isEnabled {
                    nextButton.tap()
                }
                if app.buttons["Sign in with Apple"].exists {
                    // Can't complete sign in during UI tests
                    break
                }
                if app.staticTexts["Followers"].exists {
                    // Already at main screen
                    break
                }
            }
        }
    }
}