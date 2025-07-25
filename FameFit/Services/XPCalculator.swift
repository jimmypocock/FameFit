//
//  XPCalculator.swift
//  FameFit
//
//  XP calculation engine for workout rewards
//

import Foundation
import HealthKit

/// Calculates Influencer XP based on workout data and user context
enum XPCalculator {
    // MARK: - Configuration

    private static let baseXPPerMinute: Double = 1.0

    private static let workoutMultipliers: [String: Double] = [
        "High Intensity Interval Training": 1.5,
        "Swimming": 1.4,
        "Strength Training": 1.3,
        "Running": 1.2,
        "Outdoor Running": 1.2,
        "Treadmill Running": 1.2,
        "Cycling": 1.0,
        "Indoor Cycling": 1.0,
        "Yoga": 0.8,
        "Walking": 0.7,
        "Hiking": 1.1,
        "Elliptical": 1.0,
        "Rowing": 1.3,
        "Stair Climbing": 1.2,
        "Dance": 1.1,
        "Martial Arts": 1.4,
        "Boxing": 1.4,
        "Core Training": 1.1,
        "Cross Training": 1.2,
        "Functional Training": 1.2,
        "Traditional Strength Training": 1.3,
        "Mixed Cardio": 1.1,
        "Other": 1.0,
    ]

    // MARK: - Main Calculation

    static func calculateXP(
        for workout: WorkoutHistoryItem,
        currentStreak: Int = 0,
        userMaxHeartRate: Double = 180.0
    ) -> Int {
        // Base XP from duration
        let minutes = workout.duration / 60.0
        var xp = minutes * baseXPPerMinute

        // Apply workout type multiplier
        let workoutMultiplier = workoutMultipliers[workout.workoutType] ?? 1.0
        xp *= workoutMultiplier

        // Apply intensity multiplier if heart rate data available
        if let avgHeartRate = workout.averageHeartRate {
            let intensityMultiplier = calculateIntensityMultiplier(
                heartRate: avgHeartRate,
                maxHeartRate: userMaxHeartRate
            )
            xp *= intensityMultiplier
        }

        // Apply streak multiplier
        let streakMultiplier = calculateStreakMultiplier(streak: currentStreak)
        xp *= streakMultiplier

        // Apply time of day bonus
        let timeBonus = calculateTimeOfDayBonus(startDate: workout.startDate)
        xp *= timeBonus

        // Apply weekend bonus
        if isWeekend(workout.startDate) {
            xp *= 1.1
        }

        // Round to nearest integer, minimum 1 XP
        return max(1, Int(round(xp)))
    }

    // MARK: - Multiplier Calculations

    private static func calculateIntensityMultiplier(heartRate: Double, maxHeartRate: Double) -> Double {
        let percentage = (heartRate / maxHeartRate) * 100

        switch percentage {
        case 0 ..< 50:
            return 0.5 // Rest zone
        case 50 ..< 60:
            return 0.8 // Easy zone
        case 60 ..< 70:
            return 1.0 // Moderate zone
        case 70 ..< 85:
            return 1.3 // Hard zone
        default:
            return 1.5 // Maximum zone
        }
    }

    private static func calculateStreakMultiplier(streak: Int) -> Double {
        // 5% bonus per day, capped at 100% (20 days)
        let multiplier = 1.0 + (Double(streak) * 0.05)
        return min(multiplier, 2.0)
    }

    private static func calculateTimeOfDayBonus(startDate: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: startDate)

        switch hour {
        case 5 ..< 9:
            return 1.2 // Early bird bonus
        case 9 ..< 22:
            return 1.0 // Normal hours
        case 22 ..< 24:
            return 1.1 // Night owl bonus
        default:
            return 0.8 // Late night (discourage unhealthy hours)
        }
    }

    private static func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
    }

    // MARK: - Special Bonuses

    static func calculateSpecialBonus(
        workoutNumber: Int,
        isPersonalRecord: Bool,
        isHoliday: Bool = false
    ) -> Int {
        var bonus = 0

        // Milestone bonuses
        switch workoutNumber {
        case 1:
            bonus += 50 // First workout
        case 10:
            bonus += 100 // 10th workout
        case 50:
            bonus += 250 // 50th workout
        case 100:
            bonus += 500 // 100th workout
        case 365:
            bonus += 1000 // One year of workouts
        default:
            break
        }

        // Personal record bonus
        if isPersonalRecord {
            bonus += 25
        }

        // Holiday bonus (would need holiday calendar integration)
        if isHoliday {
            bonus += 50
        }

        return bonus
    }

    // MARK: - Level Calculation

    static func getLevel(for totalXP: Int) -> (level: Int, title: String, nextLevelXP: Int) {
        let levels: [(threshold: Int, title: String)] = [
            (0, "Couch Potato"),
            (100, "Fitness Newbie"),
            (500, "Gym Regular"),
            (1000, "Fitness Enthusiast"),
            (2500, "Workout Warrior"),
            (5000, "Micro-Influencer"),
            (10000, "Rising Star"),
            (25000, "Fitness Influencer"),
            (50000, "Verified Athlete"),
            (100_000, "FameFit Elite"),
            (250_000, "Legendary"),
            (500_000, "Mythical"),
            (1_000_000, "FameFit God"),
        ]

        for index in 0 ..< levels.count {
            if index == levels.count - 1 || totalXP < levels[index + 1].threshold {
                let currentLevel = index + 1
                let currentTitle = levels[index].title
                let nextLevelXP = index < levels.count - 1 ? levels[index + 1].threshold : Int.max

                return (level: currentLevel, title: currentTitle, nextLevelXP: nextLevelXP)
            }
        }

        return (level: 1, title: "Couch Potato", nextLevelXP: 100)
    }

    // MARK: - Progress Calculation

    static func calculateProgress(currentXP: Int, toNextLevel: Int) -> Double {
        let levelInfo = getLevel(for: currentXP)

        // Find current level threshold
        var currentLevelThreshold = 0
        if levelInfo.level > 1 {
            let levels = [0, 100, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100_000, 250_000, 500_000, 1_000_000]
            if levelInfo.level - 1 < levels.count {
                currentLevelThreshold = levels[levelInfo.level - 1]
            }
        }

        let xpInCurrentLevel = currentXP - currentLevelThreshold
        let xpNeededForLevel = toNextLevel - currentLevelThreshold

        return Double(xpInCurrentLevel) / Double(xpNeededForLevel)
    }
}

// MARK: - XP Unlock System

struct XPUnlock {
    let xpRequired: Int
    let name: String
    let description: String
    let category: UnlockCategory

    enum UnlockCategory {
        case badge
        case feature
        case customization
        case achievement
    }
}

extension XPCalculator {
    static let unlockables: [XPUnlock] = [
        // Badges
        XPUnlock(xpRequired: 100, name: "Bronze Badge", description: "Your first milestone!", category: .badge),
        XPUnlock(xpRequired: 500, name: "Silver Badge", description: "Dedicated fitness enthusiast", category: .badge),
        XPUnlock(xpRequired: 2500, name: "Gold Badge", description: "Workout warrior status", category: .badge),
        XPUnlock(xpRequired: 10000, name: "Platinum Badge", description: "Rising star achievement", category: .badge),
        XPUnlock(xpRequired: 50000, name: "Diamond Badge", description: "Verified athlete status", category: .badge),

        // Features
        XPUnlock(
            xpRequired: 100,
            name: "Custom Messages",
            description: "Personalized workout messages",
            category: .feature
        ),
        XPUnlock(
            xpRequired: 1000,
            name: "Workout Stats",
            description: "Detailed analytics dashboard",
            category: .feature
        ),
        XPUnlock(
            xpRequired: 5000,
            name: "Character Personality",
            description: "New coach personality options",
            category: .feature
        ),
        XPUnlock(xpRequired: 25000, name: "Custom App Icon", description: "Exclusive app icons", category: .feature),
        XPUnlock(
            xpRequired: 100_000,
            name: "Exclusive Workouts",
            description: "Special workout types",
            category: .feature
        ),

        // Customization
        XPUnlock(
            xpRequired: 500,
            name: "Profile Theme",
            description: "Customize your profile look",
            category: .customization
        ),
        XPUnlock(
            xpRequired: 2500,
            name: "Workout Themes",
            description: "Custom workout UI themes",
            category: .customization
        ),
        XPUnlock(
            xpRequired: 10000,
            name: "Animation Pack",
            description: "Special celebration animations",
            category: .customization
        ),

        // Achievements
        XPUnlock(
            xpRequired: 1000,
            name: "Fitness Enthusiast",
            description: "Reached 1,000 XP!",
            category: .achievement
        ),
        XPUnlock(xpRequired: 10000, name: "Rising Star", description: "Reached 10,000 XP!", category: .achievement),
        XPUnlock(
            xpRequired: 100_000,
            name: "FameFit Elite",
            description: "Reached 100,000 XP!",
            category: .achievement
        ),
        XPUnlock(
            xpRequired: 1_000_000,
            name: "FameFit God",
            description: "Reached 1 million XP!",
            category: .achievement
        ),
    ]

    static func getAvailableUnlocks(for xp: Int) -> [XPUnlock] {
        unlockables.filter { $0.xpRequired <= xp }
    }

    static func getNextUnlock(for xp: Int) -> XPUnlock? {
        unlockables
            .filter { $0.xpRequired > xp }
            .sorted { $0.xpRequired < $1.xpRequired }
            .first
    }
}
