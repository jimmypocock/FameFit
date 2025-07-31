//
//  XPCalculator.swift
//  FameFit
//
//  Enhanced XP calculation with detailed audit trail
//

import Foundation
import HealthKit

struct XPCalculationResult {
    let baseXP: Int
    let finalXP: Int
    let factors: XPCalculationFactors
}

class XPCalculator {
    
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
        "Other": 1.0
    ]
    
    // MARK: - Calculate XP with Detailed Factors
    static func calculateXP(
        for workout: Workout,
        userStats: UserStats? = nil
    ) -> XPCalculationResult {
        // Base XP calculation
        let baseXP = calculateBaseXP(for: workout)
        
        // Get calculation factors
        let factors = calculateFactors(for: workout, userStats: userStats)
        
        // Apply multiplier
        let finalXP = Int(Double(baseXP) * factors.totalMultiplier)
        
        return XPCalculationResult(
            baseXP: baseXP,
            finalXP: finalXP,
            factors: factors
        )
    }
    
    // MARK: - Legacy method for compatibility
    static func calculateXP(
        for workout: Workout,
        currentStreak: Int = 0,
        userMaxHeartRate: Double = 180.0
    ) -> Int {
        let userStats = UserStats(
            totalWorkouts: 0,
            currentStreak: currentStreak,
            recentWorkouts: [],
            totalXP: 0
        )
        
        let result = calculateXP(for: workout, userStats: userStats)
        return result.finalXP
    }
    
    // MARK: - Base XP Calculation
    private static func calculateBaseXP(for workout: Workout) -> Int {
        let minutes = workout.duration / 60.0
        var xp = minutes * baseXPPerMinute
        
        // Apply workout type multiplier
        let workoutMultiplier = workoutMultipliers[workout.workoutType] ?? 1.0
        xp *= workoutMultiplier
        
        // Round to nearest integer, minimum 5 XP
        return max(5, Int(round(xp)))
    }
    
    // MARK: - Calculate Factors
    private static func calculateFactors(
        for workout: Workout,
        userStats: UserStats?
    ) -> XPCalculationFactors {
        var bonuses: [XPBonus] = []
        var milestones: [String] = []
        
        // Day of week
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: workout.startDate)
        let dayName = calendar.weekdaySymbols[dayOfWeek - 1]
        
        // Time of day
        let hour = calendar.component(.hour, from: workout.startDate)
        let timeOfDay: String
        switch hour {
        case 5..<9:
            timeOfDay = "Early Morning"
            bonuses.append(XPBonus(
                type: .earlyBird,
                multiplier: 1.2,
                description: "Early bird bonus"
            ))
        case 9..<12:
            timeOfDay = "Morning"
        case 12..<17:
            timeOfDay = "Afternoon"
        case 17..<21:
            timeOfDay = "Evening"
        case 21..<24:
            timeOfDay = "Night"
            bonuses.append(XPBonus(
                type: .nightOwl,
                multiplier: 1.1,
                description: "Night owl bonus"
            ))
        default:
            timeOfDay = "Late Night"
        }
        
        // Weekend warrior
        if dayOfWeek == 1 || dayOfWeek == 7 {
            bonuses.append(XPBonus(
                type: .weekendWarrior,
                multiplier: 1.15,
                description: "Weekend warrior bonus"
            ))
        }
        
        // Consistency streak
        let streak = userStats?.currentStreak ?? 0
        if streak >= 3 {
            let streakMultiplier = min(1.0 + (Double(streak) * 0.05), 1.5)
            bonuses.append(XPBonus(
                type: .consistencyStreak,
                multiplier: streakMultiplier,
                description: "\(streak) day streak bonus"
            ))
        }
        
        // First workout of day (simplified check since we don't have recent workouts for Workout)
        if let stats = userStats, isFirstWorkoutOfDay(workout, userStats: stats) {
            bonuses.append(XPBonus(
                type: .firstWorkoutOfDay,
                multiplier: 1.1,
                description: "First workout of the day"
            ))
        }
        
        // Milestone checks
        if let stats = userStats {
            let totalWorkouts = stats.totalWorkouts + 1
            
            // Workout count milestones
            let workoutMilestones = [10, 25, 50, 100, 250, 500, 1000]
            for milestone in workoutMilestones where totalWorkouts == milestone {
                milestones.append("\(milestone) workouts completed!")
                bonuses.append(XPBonus(
                    type: .milestone,
                    multiplier: 2.0,
                    description: "\(milestone) workout milestone"
                ))
            }
            
            // Perfect week check (simplified)
            if streak >= 7 && streak % 7 == 0 {
                bonuses.append(XPBonus(
                    type: .perfectWeek,
                    multiplier: 1.5,
                    description: "Perfect week - 7 days in a row!"
                ))
                milestones.append("Perfect week achieved!")
            }
        }
        
        // Intensity bonus from heart rate
        if let avgHeartRate = workout.averageHeartRate {
            let intensityMultiplier = calculateIntensityMultiplier(
                heartRate: avgHeartRate,
                maxHeartRate: 180.0  // Default max heart rate
            )
            if intensityMultiplier > 1.0 {
                bonuses.append(XPBonus(
                    type: .varietyBonus,  // Using variety as placeholder for intensity
                    multiplier: intensityMultiplier,
                    description: "High intensity workout"
                ))
            }
        }
        
        return XPCalculationFactors(
            workoutType: workout.workoutType,
            duration: workout.duration,
            dayOfWeek: dayName,
            timeOfDay: timeOfDay,
            consistencyStreak: streak,
            milestones: milestones,
            bonuses: bonuses
        )
    }
    
    // MARK: - Helper Methods
    private static func isFirstWorkoutOfDay(_ workout: Workout, userStats: UserStats) -> Bool {
        // Simplified check - in real implementation would check against today's workouts
        return true
    }
    
    private static func calculateIntensityMultiplier(heartRate: Double, maxHeartRate: Double) -> Double {
        let percentage = (heartRate / maxHeartRate) * 100
        
        switch percentage {
        case 0..<50:
            return 0.5 // Rest zone
        case 50..<60:
            return 0.8 // Easy zone
        case 60..<70:
            return 1.0 // Moderate zone
        case 70..<85:
            return 1.3 // Hard zone
        default:
            return 1.5 // Maximum zone
        }
    }
    
    // MARK: - Level Calculation (preserved from original)
    static func getLevel(for totalXP: Int) -> (level: Int, title: String, nextLevelXP: Int) {
        let levels: [(threshold: Int, title: String)] = [
            (0, "Couch Potato"),
            (100, "Fitness Newbie"),
            (500, "Gym Regular"),
            (1_000, "Fitness Enthusiast"),
            (2_500, "Workout Warrior"),
            (5_000, "Micro-Influencer"),
            (10_000, "Rising Star"),
            (25_000, "Fitness Influencer"),
            (50_000, "Verified Athlete"),
            (100_000, "FameFit Elite"),
            (250_000, "Legendary"),
            (500_000, "Mythical"),
            (1_000_000, "FameFit God")
        ]
        
        for index in 0..<levels.count {
            if index == levels.count - 1 || totalXP < levels[index + 1].threshold {
                let currentLevel = index + 1
                let currentTitle = levels[index].title
                let nextLevelXP = index < levels.count - 1 ? levels[index + 1].threshold : Int.max
                
                return (level: currentLevel, title: currentTitle, nextLevelXP: nextLevelXP)
            }
        }
        
        return (level: 1, title: "Couch Potato", nextLevelXP: 100)
    }
    
    // MARK: - Progress Calculation (preserved from original)
    static func calculateProgress(currentXP: Int, toNextLevel: Int) -> Double {
        let levelInfo = getLevel(for: currentXP)
        
        // Find current level threshold
        var currentLevelThreshold = 0
        if levelInfo.level > 1 {
            let levels = [0, 100, 500, 1_000, 2_500, 5_000, 10_000, 25_000, 50_000, 100_000, 250_000, 500_000, 1_000_000]
            if levelInfo.level - 1 < levels.count {
                currentLevelThreshold = levels[levelInfo.level - 1]
            }
        }
        
        let xpInCurrentLevel = currentXP - currentLevelThreshold
        let xpNeededForLevel = toNextLevel - currentLevelThreshold
        
        return Double(xpInCurrentLevel) / Double(xpNeededForLevel)
    }
    
    // MARK: - Special Bonuses (preserved from original)
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
            bonus += 1_000 // One year of workouts
        default:
            break
        }
        
        // Personal record bonus
        if isPersonalRecord {
            bonus += 25
        }
        
        // Holiday bonus
        if isHoliday {
            bonus += 50
        }
        
        return bonus
    }
}

// MARK: - User Stats for Calculation
struct UserStats {
    let totalWorkouts: Int
    let currentStreak: Int
    let recentWorkouts: [HKWorkout]
    let totalXP: Int
}

// MARK: - XP Unlock System (preserved from original)
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
        XPUnlock(xpRequired: 2_500, name: "Gold Badge", description: "Workout warrior status", category: .badge),
        XPUnlock(xpRequired: 10_000, name: "Platinum Badge", description: "Rising star achievement", category: .badge),
        XPUnlock(xpRequired: 50_000, name: "Diamond Badge", description: "Verified athlete status", category: .badge),
        
        // Features
        XPUnlock(
            xpRequired: 100,
            name: "Custom Messages",
            description: "Personalized workout messages",
            category: .feature
        ),
        XPUnlock(
            xpRequired: 1_000,
            name: "Workout Stats",
            description: "Detailed analytics dashboard",
            category: .feature
        ),
        XPUnlock(
            xpRequired: 5_000,
            name: "Character Personality",
            description: "New coach personality options",
            category: .feature
        ),
        XPUnlock(xpRequired: 25_000, name: "Custom App Icon", description: "Exclusive app icons", category: .feature),
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
            xpRequired: 2_500,
            name: "Workout Themes",
            description: "Custom workout UI themes",
            category: .customization
        ),
        XPUnlock(
            xpRequired: 10_000,
            name: "Animation Pack",
            description: "Special celebration animations",
            category: .customization
        ),
        
        // Achievements
        XPUnlock(
            xpRequired: 1_000,
            name: "Fitness Enthusiast",
            description: "Reached 1,000 XP!",
            category: .achievement
        ),
        XPUnlock(xpRequired: 10_000, name: "Rising Star", description: "Reached 10,000 XP!", category: .achievement),
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
        )
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