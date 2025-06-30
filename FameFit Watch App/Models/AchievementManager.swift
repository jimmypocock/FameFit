//
//  AchievementManager.swift
//  WWDC_WatchApp WatchKit Extension
//
//  Created for Tough Love App
//

import Foundation
import HealthKit

class AchievementManager: ObservableObject {
    
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
            case .firstWorkout: return "First Timer"
            case .fiveMinutes: return "5 Minute Hero"
            case .tenMinutes: return "10 Minute Wonder"
            case .thirtyMinutes: return "30 Minute Machine"
            case .oneHour: return "Hour of Power"
            case .fastPace: return "Speed Demon"
            case .slowPace: return "Slow & Steady"
            case .earlyBird: return "Early Bird"
            case .nightOwl: return "Night Owl"
            case .weekStreak: return "Week Warrior"
            case .hundredCalories: return "Calorie Crusher"
            case .fiveHundredCalories: return "Inferno Mode"
            }
        }
        
        var roastMessage: String {
            switch self {
            case .firstWorkout: 
                return "Congrats on your first workout! Only took you how long to start?"
            case .fiveMinutes: 
                return "5 whole minutes? Your attention span is improving!"
            case .tenMinutes: 
                return "10 minutes! That's longer than your usual commitment!"
            case .thirtyMinutes: 
                return "30 minutes? Did you get lost on the way out?"
            case .oneHour: 
                return "An hour? Did someone lock the gym doors?"
            case .fastPace: 
                return "Slow down there, Speed Racer. This isn't the bathroom line."
            case .slowPace: 
                return "Achievement unlocked: Moving slower than continental drift!"
            case .earlyBird: 
                return "Working out before noon? Who are you trying to impress?"
            case .nightOwl: 
                return "Late night workout? Couldn't sleep thinking about your fitness?"
            case .weekStreak: 
                return "A whole week? Your couch filed a missing person report."
            case .hundredCalories: 
                return "100 calories burned! That's almost a cookie!"
            case .fiveHundredCalories: 
                return "500 calories? You can almost eat dinner guilt-free!"
            }
        }
    }
    
    @Published var unlockedAchievements: Set<Achievement> = []
    @Published var recentAchievement: Achievement?
    
    private let userDefaults = UserDefaults.standard
    private let achievementsKey = "ToughLoveAchievements"
    
    init() {
        loadAchievements()
    }
    
    private func loadAchievements() {
        if let savedAchievements = userDefaults.array(forKey: achievementsKey) as? [String] {
            unlockedAchievements = Set(savedAchievements.compactMap { Achievement(rawValue: $0) })
        }
    }
    
    private func saveAchievements() {
        let achievementStrings = unlockedAchievements.map { $0.rawValue }
        userDefaults.set(achievementStrings, forKey: achievementsKey)
    }
    
    func checkAchievements(for workout: HKWorkout?, 
                          duration: TimeInterval,
                          calories: Double,
                          distance: Double,
                          averageHeartRate: Double) {
        
        var newAchievements: [Achievement] = []
        
        // First workout
        if unlockedAchievements.isEmpty {
            newAchievements.append(.firstWorkout)
        }
        
        // Duration achievements
        if duration >= 300 && !unlockedAchievements.contains(.fiveMinutes) {
            newAchievements.append(.fiveMinutes)
        }
        
        if duration >= 600 && !unlockedAchievements.contains(.tenMinutes) {
            newAchievements.append(.tenMinutes)
        }
        
        if duration >= 1800 && !unlockedAchievements.contains(.thirtyMinutes) {
            newAchievements.append(.thirtyMinutes)
        }
        
        if duration >= 3600 && !unlockedAchievements.contains(.oneHour) {
            newAchievements.append(.oneHour)
        }
        
        // Calorie achievements
        if calories >= 100 && !unlockedAchievements.contains(.hundredCalories) {
            newAchievements.append(.hundredCalories)
        }
        
        if calories >= 500 && !unlockedAchievements.contains(.fiveHundredCalories) {
            newAchievements.append(.fiveHundredCalories)
        }
        
        // Time-based achievements
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 7 && !unlockedAchievements.contains(.earlyBird) {
            newAchievements.append(.earlyBird)
        }
        
        if hour >= 21 && !unlockedAchievements.contains(.nightOwl) {
            newAchievements.append(.nightOwl)
        }
        
        // Pace achievements (for running/walking)
        if let workoutType = workout?.workoutActivityType {
            if workoutType == .running || workoutType == .walking {
                let pace = duration / (distance / 1000) // minutes per km
                if pace < 6 && !unlockedAchievements.contains(.fastPace) {
                    newAchievements.append(.fastPace)
                }
                if pace > 12 && !unlockedAchievements.contains(.slowPace) {
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
        return (unlockedAchievements.count, Achievement.allCases.count)
    }
}