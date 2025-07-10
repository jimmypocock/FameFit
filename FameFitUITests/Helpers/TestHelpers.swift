import XCTest

class TestHelpers {
    
    /// Launches app in authenticated state for testing
    static func launchAuthenticatedApp() -> XCUIApplication {
        let app = XCUIApplication()
        
        // Use launch environment instead of arguments
        app.launchEnvironment = [
            "UI_TESTING_MODE": "true",
            "SKIP_ONBOARDING": "true",
            "MOCK_USER_ID": "test-user-123",
            "MOCK_USER_NAME": "Test User",
            "ENABLE_MOCK_HEALTHKIT": "true"
        ]
        
        app.launch()
        return app
    }
    
    /// Completes onboarding flow manually
    static func completeOnboarding(app: XCUIApplication) {
        // Check if we're in onboarding
        if app.staticTexts["Welcome to FameFit"].exists {
            // Navigate through each screen
            while app.buttons["Next"].exists {
                app.buttons["Next"].tap()
            }
            
            if app.buttons["Let's Go!"].exists {
                app.buttons["Let's Go!"].tap()
            }
            
            // Handle Sign in with Apple
            // In a real test, you'd use a test account or mock
        }
    }
    
    /// Waits for main view to appear
    static func waitForMainView(app: XCUIApplication, timeout: TimeInterval = 10) -> Bool {
        // Look for multiple indicators that we're on the main screen
        let mainViewElements = [
            app.staticTexts["Welcome back,"],
            app.staticTexts["Followers"],
            app.navigationBars["FameFit"]
        ]
        
        for element in mainViewElements {
            if element.waitForExistence(timeout: timeout) {
                return true
            }
        }
        
        return false
    }
    
    /// Gets current follower count from UI
    static func getFollowerCount(app: XCUIApplication) -> Int {
        // More robust follower count detection
        let followerLabel = app.staticTexts["Followers"]
        if followerLabel.exists {
            // The follower count is usually the next large number after "Followers" label
            let allTexts = app.staticTexts.allElementsBoundByIndex
            
            for i in 0..<allTexts.count {
                let element = allTexts[i]
                if let value = Int(element.label),
                   element.frame.height > 30 { // Large text
                    return value
                }
            }
        }
        return 0
    }
}