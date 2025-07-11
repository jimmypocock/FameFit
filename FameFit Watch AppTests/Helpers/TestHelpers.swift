import XCTest
import HealthKit
@testable import FameFit_Watch_App

// MARK: - Test Expectations

extension XCTestCase {
    /// Wait for a published property to change
    func waitForPublishedValue<T: Equatable>(
        _ keyPath: KeyPath<WorkoutManager, T>,
        toEqual expectedValue: T,
        in manager: WorkoutManager,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = expectation(description: "Waiting for \(keyPath) to equal \(expectedValue)")
        
        var cancellable: Any?
        cancellable = manager.objectWillChange.sink { _ in
            if manager[keyPath: keyPath] == expectedValue {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
        _ = cancellable // Keep reference
    }
}

// MARK: - Mock Delegates

class MockWorkoutSessionDelegate: NSObject, HKWorkoutSessionDelegate {
    var didChangeToStateCalled = false
    var lastToState: HKWorkoutSessionState?
    var lastFromState: HKWorkoutSessionState?
    
    func workoutSession(_ workoutSession: HKWorkoutSession, 
                       didChangeTo toState: HKWorkoutSessionState, 
                       from fromState: HKWorkoutSessionState, 
                       date: Date) {
        didChangeToStateCalled = true
        lastToState = toState
        lastFromState = fromState
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        // Handle error
    }
}

// MARK: - Test Data Builders

extension HKWorkoutActivityType {
    static var testTypes: [HKWorkoutActivityType] {
        return [.running, .cycling, .walking]
    }
}

// MARK: - Async Test Helpers

extension XCTestCase {
    func waitForAsync(timeout: TimeInterval = 5.0, completion: @escaping () -> Void) {
        let expectation = expectation(description: "Async operation")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
    }
}

// MARK: - Snapshot Testing Helper

extension WorkoutManager {
    var stateSnapshot: WorkoutStateSnapshot {
        WorkoutStateSnapshot(
            selectedWorkout: selectedWorkout,
            isWorkoutRunning: isWorkoutRunning,
            isPaused: isPaused,
            showingSummaryView: showingSummaryView,
            hasSession: session != nil,
            hasBuilder: builder != nil,
            heartRate: heartRate,
            activeEnergy: activeEnergy,
            distance: distance
        )
    }
}

struct WorkoutStateSnapshot: Equatable {
    let selectedWorkout: HKWorkoutActivityType?
    let isWorkoutRunning: Bool
    let isPaused: Bool
    let showingSummaryView: Bool
    let hasSession: Bool
    let hasBuilder: Bool
    let heartRate: Double
    let activeEnergy: Double
    let distance: Double
}