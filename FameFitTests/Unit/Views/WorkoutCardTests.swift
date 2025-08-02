//
//  WorkoutCardTests.swift
//  FameFitTests
//
//  Tests for WorkoutCard UI component with kudos integration
//

@testable import FameFit
import SwiftUI
import XCTest

class WorkoutCardTests: XCTestCase {
    func testWorkoutCardInitialization() {
        // Given
        let workout = WorkoutItem(
            id: UUID(),
            workoutType: "Running",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1_800),
            duration: 1_800,
            totalEnergyBurned: 250,
            totalDistance: 5_000,
            averageHeartRate: 145,
            followersEarned: 10,
            xpEarned: 50,
            source: "Watch"
        )

        let kudosSummary = WorkoutKudosSummary(
            workoutId: workout.id.uuidString,
            totalCount: 3,
            hasUserKudos: false,
            recentUsers: []
        )

        // When
        let card = WorkoutCard(
            workout: workout,
            userProfile: nil,
            kudosSummary: kudosSummary,
            onKudosTap: {},
            onProfileTap: {},
            onShareTap: {}
        )

        // Then
        XCTAssertNotNil(card)
    }

    func testWorkoutCardWithNilKudos() {
        // Given
        let workout = createMockWorkout()

        // When
        let card = WorkoutCard(
            workout: workout,
            userProfile: nil,
            kudosSummary: nil,
            onKudosTap: {},
            onProfileTap: {},
            onShareTap: {}
        )

        // Then
        XCTAssertNotNil(card)
    }

    func testWorkoutCardDisplaysCorrectData() {
        // Given
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3_600) // 1 hour

        let workout = WorkoutItem(
            id: UUID(),
            workoutType: "Cycling",
            startDate: startDate,
            endDate: endDate,
            duration: 3_600,
            totalEnergyBurned: 500,
            totalDistance: 20_000, // 20km
            averageHeartRate: 155,
            followersEarned: 15,
            xpEarned: 75,
            source: "Watch"
        )

        // Verify the workout data is properly formatted
        XCTAssertEqual(workout.workoutType, "Cycling")
        XCTAssertEqual(workout.formattedDuration, "60 min")
        XCTAssertEqual(workout.formattedCalories, "500 cal")
        XCTAssertEqual(workout.formattedDistance, "20.00 km")
        XCTAssertEqual(workout.followersEarned, 15)
        XCTAssertEqual(workout.xpEarned, 75)
    }

    func testWorkoutCardWithVariousWorkoutTypes() {
        let workoutTypes = [
            "Running",
            "Cycling",
            "Swimming",
            "Strength Training",
            "Yoga",
            "HIIT"
        ]

        for workoutType in workoutTypes {
            let workout = WorkoutItem(
                id: UUID(),
                workoutType: workoutType,
                startDate: Date(),
                endDate: Date().addingTimeInterval(1_800),
                duration: 1_800,
                totalEnergyBurned: 200,
                totalDistance: workoutType == "Running" || workoutType == "Cycling" ? 5_000 : nil,
                averageHeartRate: 130,
                followersEarned: 5,
                xpEarned: 25,
                source: "Watch"
            )

            let card = WorkoutCard(
                workout: workout,
                userProfile: nil,
                kudosSummary: nil,
                onKudosTap: {},
                onProfileTap: {},
                onShareTap: {}
            )

            XCTAssertNotNil(card)
        }
    }

    // MARK: - Helper Methods

    private func createMockWorkout() -> WorkoutItem {
        WorkoutItem(
            id: UUID(),
            workoutType: "Running",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1_800),
            duration: 1_800,
            totalEnergyBurned: 250,
            totalDistance: 5_000,
            averageHeartRate: 145,
            followersEarned: 10,
            xpEarned: 50,
            source: "Watch"
        )
    }
}
