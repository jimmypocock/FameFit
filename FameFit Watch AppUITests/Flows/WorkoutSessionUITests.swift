//
//  WorkoutSessionUITests.swift
//  FameFit Watch AppUITests
//
//  Tests for active workout session UI on Watch app
//

import XCTest

final class WorkoutSessionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // NOTE: Workout session flow testing removed due to HealthKit permission complexity
    // These flows are better tested through:
    // 1. Unit tests of WorkoutManager business logic
    // 2. Manual testing for the full integration flow
    // 3. The WorkoutSelectionUITests verify basic navigation
}
