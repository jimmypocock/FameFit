//
//  XPCalculatorTests.swift
//  FameFitTests
//
//  Tests for XP calculation engine
//

@testable import FameFit
import XCTest

final class XPCalculatorTests: XCTestCase {
    // MARK: - Test Data

    private func createWorkout(
        duration: TimeInterval = 3600, // 1 hour
        workoutType: String = "Running",
        startDate: Date? = nil,
        averageHeartRate: Double? = 140
    ) -> WorkoutHistoryItem {
        // Use provided date or create a fixed weekday date (Tuesday 2pm) to avoid weekend/time bonuses
        let fixedDate: Date
        if let providedDate = startDate {
            fixedDate = providedDate
        } else {
            let calendar = Calendar.current
            var components = DateComponents()
            components.year = 2024
            components.month = 1
            components.day = 2 // Tuesday
            components.hour = 14 // 2pm
            fixedDate = calendar.date(from: components)!
        }

        return WorkoutHistoryItem(
            id: UUID(),
            workoutType: workoutType,
            startDate: fixedDate,
            endDate: fixedDate.addingTimeInterval(duration),
            duration: duration,
            totalEnergyBurned: 500,
            totalDistance: 5000,
            averageHeartRate: averageHeartRate,
            followersEarned: 0,
            xpEarned: 0,
            source: "Test"
        )
    }

    // MARK: - Basic Calculation Tests

    func testBasicXPCalculation() {
        // Create a specific date during normal hours (2pm on a Tuesday)
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 2 // Tuesday
        components.hour = 14 // 2pm
        let specificDate = calendar.date(from: components)!

        // 60 minute running workout with NO heart rate data
        let workout = createWorkout(
            duration: 3600,
            workoutType: "Running",
            startDate: specificDate,
            averageHeartRate: nil
        )

        // Base: 60 mins * 1.0 = 60
        // Running multiplier: 1.2x = 72
        // No intensity (no HR), no streak, normal time
        let xp = XPCalculator.calculateXP(for: workout)

        XCTAssertEqual(xp, 72, "60 minute run should earn 72 XP")
    }

    func testShortWorkoutMinimumXP() {
        // 1 minute workout
        let workout = createWorkout(duration: 60, workoutType: "Walking")

        let xp = XPCalculator.calculateXP(for: workout)

        XCTAssertGreaterThanOrEqual(xp, 1, "Even short workouts should earn at least 1 XP")
    }

    // MARK: - Workout Type Multiplier Tests

    func testWorkoutTypeMultipliers() {
        let testCases: [(type: String, expectedMultiplier: Double)] = [
            ("High Intensity Interval Training", 1.5),
            ("Swimming", 1.4),
            ("Strength Training", 1.3),
            ("Running", 1.2),
            ("Cycling", 1.0),
            ("Yoga", 0.8),
            ("Walking", 0.7),
            ("Unknown Workout", 1.0), // Default
        ]

        for testCase in testCases {
            let workout = createWorkout(
                duration: 3600,
                workoutType: testCase.type,
                averageHeartRate: nil // Remove HR to isolate workout type
            )

            let xp = XPCalculator.calculateXP(for: workout)
            let expectedXP = Int(round(60 * testCase.expectedMultiplier))

            XCTAssertEqual(xp, expectedXP, "\(testCase.type) should have \(testCase.expectedMultiplier)x multiplier")
        }
    }

    // MARK: - Intensity Multiplier Tests

    func testIntensityMultipliers() {
        let maxHR = 180.0
        let testCases: [(hr: Double, zone: String, multiplier: Double)] = [
            (80, "Rest", 0.5), // 44% of max
            (100, "Easy", 0.8), // 55% of max
            (115, "Moderate", 1.0), // 64% of max
            (140, "Hard", 1.3), // 78% of max
            (160, "Maximum", 1.5), // 89% of max
        ]

        for testCase in testCases {
            let workout = createWorkout(
                duration: 3600,
                workoutType: "Cycling", // 1.0x multiplier
                averageHeartRate: testCase.hr
            )

            let xp = XPCalculator.calculateXP(for: workout, userMaxHeartRate: maxHR)
            let expectedXP = Int(round(60 * 1.0 * testCase.multiplier))

            XCTAssertEqual(xp, expectedXP, "\(testCase.zone) zone should have \(testCase.multiplier)x multiplier")
        }
    }

    // MARK: - Streak Multiplier Tests

    func testStreakMultipliers() {
        let workout = createWorkout(
            duration: 3600,
            workoutType: "Cycling",
            averageHeartRate: nil
        )

        let testCases: [(streak: Int, multiplier: Double)] = [
            (0, 1.0),
            (1, 1.05),
            (5, 1.25),
            (10, 1.5),
            (15, 1.75),
            (20, 2.0),
            (30, 2.0), // Capped at 2.0
        ]

        for testCase in testCases {
            let xp = XPCalculator.calculateXP(for: workout, currentStreak: testCase.streak)
            let expectedXP = Int(round(60 * testCase.multiplier))

            XCTAssertEqual(
                xp,
                expectedXP,
                "\(testCase.streak) day streak should have \(testCase.multiplier)x multiplier"
            )
        }
    }

    // MARK: - Time of Day Tests

    func testTimeOfDayBonuses() {
        let calendar = Calendar.current
        // Use a fixed weekday (Tuesday) to avoid weekend bonus
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 2 // Tuesday

        let testCases: [(hour: Int, multiplier: Double)] = [
            (6, 1.2), // Early bird
            (14, 1.0), // Normal hours
            (23, 1.1), // Night owl
            (2, 0.8), // Late night
        ]

        for testCase in testCases {
            components.hour = testCase.hour
            components.minute = 0

            let startDate = calendar.date(from: components)!
            let workout = createWorkout(
                duration: 3600,
                workoutType: "Cycling",
                startDate: startDate,
                averageHeartRate: nil
            )

            let xp = XPCalculator.calculateXP(for: workout)
            let expectedXP = Int(round(60 * testCase.multiplier))

            XCTAssertEqual(xp, expectedXP, "\(testCase.hour):00 should have \(testCase.multiplier)x multiplier")
        }
    }

    // MARK: - Weekend Bonus Tests

    func testWeekendBonus() {
        let calendar = Calendar.current

        // Create Tuesday at 2pm
        var tuesdayComponents = DateComponents()
        tuesdayComponents.year = 2024
        tuesdayComponents.month = 1
        tuesdayComponents.day = 2 // Tuesday
        tuesdayComponents.hour = 14 // 2pm
        let tuesday = calendar.date(from: tuesdayComponents)!

        // Create Saturday at 2pm
        var saturdayComponents = DateComponents()
        saturdayComponents.year = 2024
        saturdayComponents.month = 1
        saturdayComponents.day = 6 // Saturday
        saturdayComponents.hour = 14 // 2pm
        let saturday = calendar.date(from: saturdayComponents)!

        let weekdayWorkout = createWorkout(
            duration: 3600,
            workoutType: "Cycling",
            startDate: tuesday,
            averageHeartRate: nil
        )

        let weekendWorkout = createWorkout(
            duration: 3600,
            workoutType: "Cycling",
            startDate: saturday,
            averageHeartRate: nil
        )

        let weekdayXP = XPCalculator.calculateXP(for: weekdayWorkout)
        let weekendXP = XPCalculator.calculateXP(for: weekendWorkout)

        // Weekend should be 1.1x weekday
        XCTAssertEqual(weekdayXP, 60, "Weekday cycling should be 60 XP")
        XCTAssertEqual(weekendXP, 66, "Weekend cycling should be 66 XP (60 * 1.1)")
    }

    // MARK: - Combined Multipliers Test

    func testCombinedMultipliers() {
        // Create a morning weekend HIIT workout with high intensity and streak
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 7 // Saturday
        components.hour = 7 // 7 AM
        let workoutDate = calendar.date(from: components)!

        let workout = createWorkout(
            duration: 1800, // 30 minutes
            workoutType: "High Intensity Interval Training",
            startDate: workoutDate,
            averageHeartRate: 155 // High intensity
        )

        let xp = XPCalculator.calculateXP(
            for: workout,
            currentStreak: 10,
            userMaxHeartRate: 180
        )

        // Expected calculation:
        // Base: 30 mins = 30 XP
        // HIIT: 1.5x = 45
        // High intensity (86% max HR): 1.5x = 67.5
        // 10 day streak: 1.5x = 101.25
        // Morning: 1.2x = 121.5
        // Weekend: 1.1x = 133.65

        XCTAssertEqual(xp, 134, "Combined multipliers should stack correctly")
    }

    // MARK: - Special Bonus Tests

    func testSpecialBonuses() {
        XCTAssertEqual(XPCalculator.calculateSpecialBonus(workoutNumber: 1, isPersonalRecord: false), 50)
        XCTAssertEqual(XPCalculator.calculateSpecialBonus(workoutNumber: 10, isPersonalRecord: false), 100)
        XCTAssertEqual(XPCalculator.calculateSpecialBonus(workoutNumber: 50, isPersonalRecord: false), 250)
        XCTAssertEqual(XPCalculator.calculateSpecialBonus(workoutNumber: 100, isPersonalRecord: false), 500)
        XCTAssertEqual(XPCalculator.calculateSpecialBonus(workoutNumber: 365, isPersonalRecord: false), 1000)

        // Personal record bonus
        XCTAssertEqual(XPCalculator.calculateSpecialBonus(workoutNumber: 5, isPersonalRecord: true), 25)

        // Holiday bonus
        XCTAssertEqual(
            XPCalculator.calculateSpecialBonus(workoutNumber: 5, isPersonalRecord: false, isHoliday: true),
            50
        )

        // Combined bonuses
        XCTAssertEqual(
            XPCalculator.calculateSpecialBonus(workoutNumber: 10, isPersonalRecord: true, isHoliday: true),
            175
        )
    }

    // MARK: - Level Calculation Tests

    func testLevelCalculation() {
        let testCases: [(xp: Int, expectedLevel: Int, expectedTitle: String)] = [
            (0, 1, "Couch Potato"),
            (50, 1, "Couch Potato"),
            (100, 2, "Fitness Newbie"),
            (499, 2, "Fitness Newbie"),
            (500, 3, "Gym Regular"),
            (1000, 4, "Fitness Enthusiast"),
            (5000, 6, "Micro-Influencer"),
            (100_000, 10, "FameFit Elite"),
            (1_000_000, 13, "FameFit God"),
        ]

        for testCase in testCases {
            let levelInfo = XPCalculator.getLevel(for: testCase.xp)

            XCTAssertEqual(
                levelInfo.level,
                testCase.expectedLevel,
                "XP \(testCase.xp) should be level \(testCase.expectedLevel)"
            )
            XCTAssertEqual(
                levelInfo.title,
                testCase.expectedTitle,
                "XP \(testCase.xp) should have title '\(testCase.expectedTitle)'"
            )
        }
    }

    func testNextLevelXP() {
        let testCases: [(xp: Int, expectedNext: Int)] = [
            (0, 100),
            (100, 500),
            (500, 1000),
            (999, 1000),
            (1000, 2500),
        ]

        for testCase in testCases {
            let levelInfo = XPCalculator.getLevel(for: testCase.xp)
            XCTAssertEqual(
                levelInfo.nextLevelXP,
                testCase.expectedNext,
                "XP \(testCase.xp) should need \(testCase.expectedNext) for next level"
            )
        }
    }

    // MARK: - Progress Calculation Tests

    func testProgressCalculation() {
        // Level 1 → 2 (0 to 100 XP)
        XCTAssertEqual(XPCalculator.calculateProgress(currentXP: 0, toNextLevel: 100), 0.0)
        XCTAssertEqual(XPCalculator.calculateProgress(currentXP: 50, toNextLevel: 100), 0.5)
        XCTAssertEqual(XPCalculator.calculateProgress(currentXP: 99, toNextLevel: 100), 0.99)

        // Level 2 → 3 (100 to 500 XP)
        XCTAssertEqual(XPCalculator.calculateProgress(currentXP: 100, toNextLevel: 500), 0.0)
        XCTAssertEqual(XPCalculator.calculateProgress(currentXP: 300, toNextLevel: 500), 0.5)
        XCTAssertEqual(XPCalculator.calculateProgress(currentXP: 499, toNextLevel: 500), 0.9975, accuracy: 0.0001)
    }

    // MARK: - Unlock System Tests

    func testUnlockAvailability() {
        let unlocks0 = XPCalculator.getAvailableUnlocks(for: 0)
        XCTAssertTrue(unlocks0.isEmpty, "No unlocks at 0 XP")

        let unlocks100 = XPCalculator.getAvailableUnlocks(for: 100)
        XCTAssertEqual(unlocks100.count, 2, "Should have 2 unlocks at 100 XP")
        XCTAssertTrue(unlocks100.contains { $0.name == "Bronze Badge" })
        XCTAssertTrue(unlocks100.contains { $0.name == "Custom Messages" })

        let unlocks5000 = XPCalculator.getAvailableUnlocks(for: 5000)
        XCTAssertTrue(unlocks5000.contains { $0.name == "Character Personality" })

        let unlocksMillion = XPCalculator.getAvailableUnlocks(for: 1_000_000)
        XCTAssertEqual(unlocksMillion.count, XPCalculator.unlockables.count, "Should have all unlocks at 1M XP")
    }

    func testNextUnlock() {
        let next0 = XPCalculator.getNextUnlock(for: 0)
        XCTAssertEqual(next0?.xpRequired, 100)
        XCTAssertEqual(next0?.name, "Bronze Badge")

        let next100 = XPCalculator.getNextUnlock(for: 100)
        XCTAssertEqual(next100?.xpRequired, 500)

        let nextMillion = XPCalculator.getNextUnlock(for: 1_000_000)
        XCTAssertNil(nextMillion, "No more unlocks after 1M XP")
    }

    // MARK: - Edge Case Tests

    func testZeroDurationWorkout() {
        let workout = createWorkout(duration: 0)
        let xp = XPCalculator.calculateXP(for: workout)

        XCTAssertEqual(xp, 1, "Zero duration should still give minimum 1 XP")
    }

    func testNilHeartRate() {
        let workout = createWorkout(averageHeartRate: nil)
        let xp = XPCalculator.calculateXP(for: workout)

        // Should calculate without intensity multiplier
        XCTAssertEqual(xp, 72, "Should handle nil heart rate gracefully")
    }

    func testVeryHighStreak() {
        let workout = createWorkout(duration: 3600, workoutType: "Cycling", averageHeartRate: nil)
        let xp = XPCalculator.calculateXP(for: workout, currentStreak: 100)

        // Should cap at 2.0x
        XCTAssertEqual(xp, 120, "Streak multiplier should cap at 2.0x")
    }
}
