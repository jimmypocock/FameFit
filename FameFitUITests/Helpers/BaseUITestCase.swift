import XCTest

/// Base class for all UI tests with common setup and utilities
class BaseUITestCase: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Set up common interruption handlers
        setupInterruptionHandlers()
    }
    
    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Common Setup
    
    /// Sets up handlers for common system alerts
    private func setupInterruptionHandlers() {
        // HealthKit permissions
        addUIInterruptionMonitor(withDescription: "HealthKit Permission") { alert in
            let labels = ["OK", "Allow", "Don't Allow"]
            for label in labels {
                if alert.buttons[label].exists {
                    alert.buttons[label].tap()
                    return true
                }
            }
            return false
        }
        
        // Notification permissions
        addUIInterruptionMonitor(withDescription: "Notification Permission") { alert in
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            } else if alert.buttons["Don't Allow"].exists {
                alert.buttons["Don't Allow"].tap()
                return true
            }
            return false
        }
        
        // Location permissions (if needed in future)
        addUIInterruptionMonitor(withDescription: "Location Permission") { alert in
            if alert.buttons["Allow While Using App"].exists {
                alert.buttons["Allow While Using App"].tap()
                return true
            } else if alert.buttons["Don't Allow"].exists {
                alert.buttons["Don't Allow"].tap()
                return true
            }
            return false
        }
    }
    
    // MARK: - Launch Helpers
    
    /// Launch app with UI testing flag
    func launchApp() {
        app.launchArguments.append("UI-Testing")
        app.launch()
        
        // Small delay to ensure app is fully launched
        wait(for: 0.5)
    }
    
    /// Launch app with reset state for clean testing
    func launchAppWithCleanState() {
        app.launchArguments = ["UI-Testing", "--reset-state"]
        app.launch()
        
        // Wait for state reset to complete
        wait(for: 1.0)
    }
    
    /// Launch app with mock authentication
    func launchAppWithMockAuth() {
        app.launchArguments = ["UI-Testing", "--mock-auth-for-onboarding"]
        app.launch()
        
        wait(for: 0.5)
    }
    
    /// Launch app skipping onboarding
    func launchAppSkippingOnboarding() {
        app.launchArguments = ["UI-Testing", "--skip-onboarding"]
        app.launch()
        
        wait(for: 0.5)
    }
    
    // MARK: - Wait Helpers
    
    /// Wait for a specific duration
    func wait(for duration: TimeInterval) {
        Thread.sleep(forTimeInterval: duration)
    }
    
    /// Wait for element to exist with custom timeout
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5.0) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    // MARK: - Safe Element Access
    
    /// Safely get labels from a collection of elements
    func getLabels(from query: XCUIElementQuery) -> [String] {
        return query.allElementsBoundByIndex.compactMap { element in
            element.exists ? element.label : nil
        }
    }
    
    /// Safely tap an element using coordinates to avoid scrolling issues
    func safeTap(_ element: XCUIElement) {
        if element.exists && element.isHittable {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
    
    /// Trigger interruption monitors by performing a neutral action
    func triggerInterruptionMonitor() {
        // Tap in a neutral area to trigger any pending interruption monitors
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        wait(for: 0.5)
    }
    
    // MARK: - Debug Helpers
    
    /// Print current UI state for debugging
    func printCurrentUIState() {
        print("=== Current UI State ===")
        print("Buttons: \(getLabels(from: app.buttons))")
        print("Static texts: \(getLabels(from: app.staticTexts))")
        print("Text fields: \(getLabels(from: app.textFields))")
        print("=======================")
    }
    
    // MARK: - Common Assertions
    
    /// Assert element exists with helpful error message
    func assertExists(_ element: XCUIElement, _ message: String) {
        if !element.exists {
            printCurrentUIState()
        }
        XCTAssertTrue(element.exists, message)
    }
    
    /// Assert and wait for element
    func assertExistsEventually(_ element: XCUIElement, _ message: String, timeout: TimeInterval = 5.0) {
        let exists = waitForElement(element, timeout: timeout)
        if !exists {
            printCurrentUIState()
        }
        XCTAssertTrue(exists, message)
    }
}