//
//  AchievementManager.swift
//  FameFit Watch App
//
//  Created for Tough Love App
//

import Foundation
import HealthKit

class AchievementManager: ObservableObject, AchievementManaging {
    enum Achievement: String, CaseIterable {
        case firstWorkout = "first_workout"
        case fiveMinutes = "five_minutes"
        case tenMinutes = "ten_minutes"
        case thirtyMinutes = "thirty_minutes"
        case oneHour = "one_hour"
        case fastPace = "fast_pace"
        case slowPace = "slow_pace"
        case earlyBird = "early_bird"
        case nightOwl = "night_owl"
        case weekStreak = "week_streak"
        case hundredCalories = "hundred_calories"
        case fiveHundredCalories = "five_hundred_calories"

        var title: String {
            switch self {
            case .firstWorkout: "First Timer"
            case .fiveMinutes: "5 Minute Hero"
            case .tenMinutes: "10 Minute Wonder"
            case .thirtyMinutes: "30 Minute Machine"
            case .oneHour: "Hour of Power"
            case .fastPace: "Speed Demon"
            case .slowPace: "Slow & Steady"
            case .earlyBird: "Early Bird"
            case .nightOwl: "Night Owl"
            case .weekStreak: "Week Warrior"
            case .hundredCalories: "Calorie Crusher"
            case .fiveHundredCalories: "Inferno Mode"
            }
        }

        var roastMessage: String {
            switch self {
            case .firstWorkout:
                "Congrats on your first workout! Only took you how long to start?"
            case .fiveMinutes:
                "5 whole minutes? Your attention span is improving!"
            case .tenMinutes:
                "10 minutes! That's longer than your usual commitment!"
            case .thirtyMinutes:
                "30 minutes? Did you get lost on the way out?"
            case .oneHour:
                "An hour? Did someone lock the gym doors?"
            case .fastPace:
                "Slow down there, Speed Racer. This isn't the bathroom line."
            case .slowPace:
                "Achievement unlocked: Moving slower than continental drift!"
            case .earlyBird:
                "Working out before noon? Who are you trying to impress?"
            case .nightOwl:
                "Late night workout? Couldn't sleep thinking about your fitness?"
            case .weekStreak:
                "A whole week? Your couch filed a missing person report."
            case .hundredCalories:
                "100 calories burned! That's almost a cookie!"
            case .fiveHundredCalories:
                "500 calories? You can almost eat dinner guilt-free!"
            }
        }
    }

    @Published var unlockedAchievements: Set<Achievement> = []
    @Published var recentAchievement: Achievement?

    private let persister: AchievementPersisting

    init(persister: AchievementPersisting? = nil) {
        self.persister = persister ?? UserDefaultsAchievementPersister()
        loadAchievements()
    }

    private func loadAchievements() {
        if let savedAchievements = persister.loadAchievements() {
            unlockedAchievements = Set(savedAchievements.compactMap { Achievement(rawValue: $0) })
        }
    }

    private func saveAchievements() {
        let achievementStrings = unlockedAchievements.map(\.rawValue)
        persister.saveAchievements(achievementStrings)
    }

    func checkAchievements(
        for workout: HKWorkout?,
        duration: TimeInterval,
        calories: Double,
        distance: Double,
        averageHeartRate _: Double
    ) {
        var newAchievements: [Achievement] = []

        // First workout
        if unlockedAchievements.isEmpty {
            newAchievements.append(.firstWorkout)
        }

        // Duration achievements
        if duration >= 300, !unlockedAchievements.contains(.fiveMinutes) {
            newAchievements.append(.fiveMinutes)
        }

        if duration >= 600, !unlockedAchievements.contains(.tenMinutes) {
            newAchievements.append(.tenMinutes)
        }

        if duration >= 1800, !unlockedAchievements.contains(.thirtyMinutes) {
            newAchievements.append(.thirtyMinutes)
        }

        if duration >= 3600, !unlockedAchievements.contains(.oneHour) {
            newAchievements.append(.oneHour)
        }

        // Calorie achievements
        if calories >= 100, !unlockedAchievements.contains(.hundredCalories) {
            newAchievements.append(.hundredCalories)
        }

        if calories >= 500, !unlockedAchievements.contains(.fiveHundredCalories) {
            newAchievements.append(.fiveHundredCalories)
        }

        // Time-based achievements
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 7, !unlockedAchievements.contains(.earlyBird) {
            newAchievements.append(.earlyBird)
        }

        if hour >= 21, !unlockedAchievements.contains(.nightOwl) {
            newAchievements.append(.nightOwl)
        }

        // Pace achievements (for running/walking)
        if let workoutType = workout?.workoutActivityType {
            if workoutType == .running || workoutType == .walking {
                let pace = duration / (distance / 1000) // minutes per km
                if pace < 6, !unlockedAchievements.contains(.fastPace) {
                    newAchievements.append(.fastPace)
                }
                if pace > 12, !unlockedAchievements.contains(.slowPace) {
                    newAchievements.append(.slowPace)
                }
            }
        }

        // Update unlocked achievements
        for achievement in newAchievements {
            unlockedAchievements.insert(achievement)
            recentAchievement = achievement
        }

        if !newAchievements.isEmpty {
            saveAchievements()
        }
    }

    func checkWeekStreak() {
        // This would need to track workout history over time
        // For MVP, we'll skip this complex achievement
    }

    func getAchievementProgress() -> (unlocked: Int, total: Int) {
        (unlockedAchievements.count, Achievement.allCases.count)
    }
}
