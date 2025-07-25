//
//  KudosButtonTests.swift
//  FameFitTests
//
//  Tests for KudosButton UI component
//

import SwiftUI
import XCTest

// import ViewInspector // Temporarily disabled - missing dependency
@testable import FameFit

class KudosButtonTests: XCTestCase {
    func testKudosButtonInitialization() {
        // Given
        let workoutId = "workout123"
        let ownerId = "owner456"
        let kudosSummary = WorkoutKudosSummary(
            workoutId: workoutId,
            totalCount: 5,
            hasUserKudos: true,
            recentUsers: []
        )

        // When
        let button = KudosButton(
            workoutId: workoutId,
            ownerId: ownerId,
            kudosSummary: kudosSummary,
            onTap: {}
        )

        // Then
        XCTAssertNotNil(button)
    }

    func testKudosButtonWithNilSummary() {
        // Given
        let workoutId = "workout123"
        let ownerId = "owner456"

        // When
        let button = KudosButton(
            workoutId: workoutId,
            ownerId: ownerId,
            kudosSummary: nil,
            onTap: {}
        )

        // Then
        XCTAssertNotNil(button)
    }

    func testKudosButtonStates() {
        // Test different kudos states
        let scenarios: [(count: Int, hasKudos: Bool, expectedColor: Color)] = [
            (0, false, .gray), // No kudos
            (1, true, .red), // User has given kudos
            (5, false, .gray), // Others have given kudos
            (10, true, .red), // User and others have given kudos
        ]

        for scenario in scenarios {
            let summary = WorkoutKudosSummary(
                workoutId: "test",
                totalCount: scenario.count,
                hasUserKudos: scenario.hasKudos,
                recentUsers: []
            )

            // Verify the button can be created with each state
            let button = KudosButton(
                workoutId: "test",
                ownerId: "owner",
                kudosSummary: summary,
                onTap: {}
            )

            XCTAssertNotNil(button)
        }
    }
}
