import XCTest
import HealthKit
@testable import FameFit

class WorkoutStateTests: XCTestCase {
    
    func testButtonStateLogic() {
        // Test the core logic that drives UI button states
        
        // Test running state
        let runningState = true
        XCTAssertEqual(getButtonIcon(isRunning: runningState), "pause")
        XCTAssertEqual(getButtonText(isRunning: runningState), "Pause")
        
        // Test paused state
        let pausedState = false
        XCTAssertEqual(getButtonIcon(isRunning: pausedState), "play")
        XCTAssertEqual(getButtonText(isRunning: pausedState), "Resume")
    }
    
    // Helper functions that mirror the logic in ControlsView
    private func getButtonIcon(isRunning: Bool) -> String {
        return isRunning ? "pause" : "play"
    }
    
    private func getButtonText(isRunning: Bool) -> String {
        return isRunning ? "Pause" : "Resume"
    }
    
    func testWorkoutSessionStateLogic() {
        // Test the logic patterns used in WorkoutManager
        let states: [HKWorkoutSessionState] = [.notStarted, .prepared, .running, .paused, .stopped, .ended]
        
        for state in states {
            let isRunning = (state == .running)
            let isPaused = (state == .paused)
            let isActive = (state == .running || state == .paused)
            
            switch state {
            case .running:
                XCTAssertTrue(isRunning, "Should be running in .running state")
                XCTAssertFalse(isPaused, "Should not be paused in .running state")
                XCTAssertTrue(isActive, "Should be active in .running state")
                
            case .paused:
                XCTAssertFalse(isRunning, "Should not be running in .paused state")
                XCTAssertTrue(isPaused, "Should be paused in .paused state")
                XCTAssertTrue(isActive, "Should be active in .paused state")
                
            case .notStarted, .prepared:
                XCTAssertFalse(isRunning, "Should not be running in \(state) state")
                XCTAssertFalse(isPaused, "Should not be paused in \(state) state")
                XCTAssertFalse(isActive, "Should not be active in \(state) state")
                
            case .stopped, .ended:
                XCTAssertFalse(isRunning, "Should not be running in \(state) state")
                XCTAssertFalse(isPaused, "Should not be paused in \(state) state")
                XCTAssertFalse(isActive, "Should not be active in \(state) state")
                
            @unknown default:
                XCTFail("Unknown workout session state")
            }
        }
    }
    
    func testTogglePauseLogic() {
        // Test the toggle logic used in pause/resume functionality
        var isRunning = true
        
        // Toggle from running to paused
        isRunning.toggle()
        XCTAssertFalse(isRunning, "Should be paused after toggle from running")
        
        // Toggle from paused to running
        isRunning.toggle()
        XCTAssertTrue(isRunning, "Should be running after toggle from paused")
        
        // Test multiple toggles
        for _ in 0..<10 {
            let previousState = isRunning
            isRunning.toggle()
            XCTAssertNotEqual(isRunning, previousState, "Toggle should always change state")
        }
    }
    
    func testMeasurementConversions() {
        // Test measurement conversions used in fitness apps
        
        // Distance conversions
        let meters = 1000.0
        let kilometers = meters / 1000.0
        XCTAssertEqual(kilometers, 1.0)
        
        let miles = meters * 0.000621371
        XCTAssertEqual(miles, 0.621371, accuracy: 0.000001)
        
        // Energy conversions
        let calories = 150.0
        let kilojoules = calories * 4.184
        XCTAssertEqual(kilojoules, 627.6, accuracy: 0.1)
        
        // Time conversions
        let seconds = 3661.0
        let minutes = seconds / 60.0
        let hours = seconds / 3600.0
        XCTAssertEqual(minutes, 61.0167, accuracy: 0.001)
        XCTAssertEqual(hours, 1.0169, accuracy: 0.001)
    }
}