import XCTest

// MARK: - UI Test Helper Extensions

extension XCUIElement {
    /// Wait for element to not exist
    func waitForNonExistence(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Tap element if it exists
    func tapIfExists() {
        if exists {
            tap()
        }
    }

    /// Clear text field and type new text
    func clearAndType(_ text: String) {
        tap()

        // Select all text
        press(forDuration: 1.0)

        // Delete it
        if let deleteKey = XCUIApplication().keys["delete"].exists ? XCUIApplication().keys["delete"] : nil {
            deleteKey.tap()
        }

        // Type new text
        typeText(text)
    }
}

// MARK: - Common Test Helpers

enum UITestHelpers {
    /// Complete onboarding flow if needed
    static func completeOnboardingIfNeeded(in app: XCUIApplication) {
        if app.staticTexts["FAMEFIT"].exists {
            let nextButton = app.buttons["Next"]

            // Go through onboarding screens
            for _ in 0 ..< 20 {
                if nextButton.exists && nextButton.isEnabled {
                    nextButton.tap()
                }

                // Check if we've reached a stopping point
                if app.buttons["Sign in with Apple"].exists ||
                    app.staticTexts["Total XP"].exists
                {
                    break
                }
            }
        }
    }

    /// Get current XP count from UI
    static func getFollowerCount(from app: XCUIApplication) -> Int? {
        let xpSection = app.otherElements.containing(.staticText, identifier: "Total XP").firstMatch

        if xpSection.exists {
            let numericLabels = xpSection.staticTexts.matching(
                NSPredicate(format: "label MATCHES %@", "^[0-9]+$")
            )

            if numericLabels.count > 0 {
                let followerText = numericLabels.firstMatch.label
                return Int(followerText)
            }
        }

        // Alternative: Look for any numeric text near "Total XP" label
        let allNumericTexts = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "^[0-9]+$")
        )

        for i in 0 ..< allNumericTexts.count {
            let element = allNumericTexts.element(boundBy: i)
            if element.exists, let value = Int(element.label) {
                return value
            }
        }

        return nil
    }

    /// Wait for element with retry
    static func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10, message: String? = nil) {
        let exists = element.waitForExistence(timeout: timeout)
        if !exists {
            XCTFail(message ?? "Element \(element) did not appear within \(timeout) seconds")
        }
    }

    /// Take screenshot with descriptive name
    static func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Screenshot: \(name)") { activity in
            activity.add(attachment)
        }
    }
}

// MARK: - Mock Data Helpers

enum MockDataHelpers {
    /// Launch arguments for different test scenarios
    enum LaunchArgument {
        static let uiTesting = "UI-Testing"
        static let resetState = "--reset-state"
        static let skipOnboarding = "--skip-onboarding"
        static let mockHealthKit = "--mock-healthkit"
        static let debugMenu = "--show-debug-menu"
    }

    /// Configure app for specific test scenario
    static func configureApp(for scenario: TestScenario) -> XCUIApplication {
        let app = XCUIApplication()

        switch scenario {
        case .freshInstall:
            app.launchArguments = [LaunchArgument.uiTesting, LaunchArgument.resetState]

        case .existingUser:
            app.launchArguments = [LaunchArgument.uiTesting, LaunchArgument.skipOnboarding]

        case .mockWorkouts:
            app.launchArguments = [
                LaunchArgument.uiTesting,
                LaunchArgument.skipOnboarding,
                LaunchArgument.mockHealthKit,
            ]

        case .debugMode:
            app.launchArguments = [
                LaunchArgument.uiTesting,
                LaunchArgument.debugMenu,
            ]
        }

        return app
    }

    enum TestScenario {
        case freshInstall
        case existingUser
        case mockWorkouts
        case debugMode
    }
}
