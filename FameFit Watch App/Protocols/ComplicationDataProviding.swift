//
//  ComplicationDataProviding.swift
//  FameFit Watch App
//
//  Protocol abstraction for complication data access
//

import Foundation
import HealthKit

// MARK: - Complication Data Provider Protocol

protocol ComplicationDataProviding {
    // MARK: - Fitness Stats
    var currentXP: Int { get }
    var currentStreak: Int { get }
    var todayWorkoutCount: Int { get }
    var totalWorkouts: Int { get }
    var currentLevel: Int { get }
    
    // MARK: - Active Workout State
    var isWorkoutActive: Bool { get }
    var currentWorkoutType: HKWorkoutActivityType? { get }
    var workoutElapsedTime: TimeInterval { get }
    var workoutActiveEnergy: Double { get }
    
    // MARK: - Data Refresh
    func refreshData() async
    func refreshWorkoutState()
}

// MARK: - Production Implementation

class ProductionComplicationDataProvider: ComplicationDataProviding {
    private let workoutManager: (any WorkoutManaging)?
    
    // Simple data storage that can be updated from the main app
    private var cachedXP: Int = 0
    private var cachedStreak: Int = 0
    private var cachedTotalWorkouts: Int = 0
    private var cachedTodayWorkouts: Int = 0
    
    init(workoutManager: (any WorkoutManaging)?) {
        self.workoutManager = workoutManager
        loadCachedData()
    }
    
    // MARK: - Fitness Stats
    
    var currentXP: Int {
        cachedXP
    }
    
    var currentStreak: Int {
        cachedStreak
    }
    
    var todayWorkoutCount: Int {
        cachedTodayWorkouts
    }
    
    var totalWorkouts: Int {
        cachedTotalWorkouts
    }
    
    var currentLevel: Int {
        // Calculate level from XP
        max(1, currentXP / 1000)
    }
    
    // MARK: - Active Workout State
    
    var isWorkoutActive: Bool {
        workoutManager?.isWorkoutRunning ?? false
    }
    
    var currentWorkoutType: HKWorkoutActivityType? {
        workoutManager?.selectedWorkout
    }
    
    var workoutElapsedTime: TimeInterval {
        workoutManager?.displayElapsedTime ?? 0
    }
    
    var workoutActiveEnergy: Double {
        workoutManager?.activeEnergy ?? 0
    }
    
    // MARK: - Data Management
    
    func updateFitnessStats(xp: Int, streak: Int, totalWorkouts: Int, todayWorkouts: Int) {
        cachedXP = xp
        cachedStreak = streak
        cachedTotalWorkouts = totalWorkouts
        cachedTodayWorkouts = todayWorkouts
        saveCachedData()
    }
    
    // MARK: - Data Refresh
    
    func refreshData() async {
        // Load from UserDefaults or other local storage
        loadCachedData()
    }
    
    func refreshWorkoutState() {
        // Refresh workout manager state if needed
        // This would be implementation-specific
    }
    
    // MARK: - Private Methods
    
    private func loadCachedData() {
        let defaults = UserDefaults.standard
        cachedXP = defaults.integer(forKey: "ComplicationXP")
        cachedStreak = defaults.integer(forKey: "ComplicationStreak")
        cachedTotalWorkouts = defaults.integer(forKey: "ComplicationTotalWorkouts")
        cachedTodayWorkouts = defaults.integer(forKey: "ComplicationTodayWorkouts")
    }
    
    private func saveCachedData() {
        let defaults = UserDefaults.standard
        defaults.set(cachedXP, forKey: "ComplicationXP")
        defaults.set(cachedStreak, forKey: "ComplicationStreak")
        defaults.set(cachedTotalWorkouts, forKey: "ComplicationTotalWorkouts")
        defaults.set(cachedTodayWorkouts, forKey: "ComplicationTodayWorkouts")
    }
}

// MARK: - Mock Implementation

class MockComplicationDataProvider: ComplicationDataProviding {
    var currentXP: Int = 2500
    var currentStreak: Int = 7
    var todayWorkoutCount: Int = 2
    var totalWorkouts: Int = 45
    var currentLevel: Int = 3
    
    var isWorkoutActive: Bool = false
    var currentWorkoutType: HKWorkoutActivityType? = nil
    var workoutElapsedTime: TimeInterval = 0
    var workoutActiveEnergy: Double = 0
    
    // Test data modification
    func setWorkoutActive(_ active: Bool, type: HKWorkoutActivityType? = .running) {
        isWorkoutActive = active
        currentWorkoutType = active ? type : nil
        workoutElapsedTime = active ? 1200 : 0 // 20 minutes
        workoutActiveEnergy = active ? 150 : 0 // 150 calories
    }
    
    func setFitnessStats(xp: Int, streak: Int, workouts: Int) {
        currentXP = xp
        currentStreak = streak
        totalWorkouts = workouts
        currentLevel = max(1, xp / 1000)
        todayWorkoutCount = min(workouts, 3) // Assume max 3 per day
    }
    
    func refreshData() async {
        // Mock implementation - could simulate loading delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    func refreshWorkoutState() {
        // Mock implementation - no action needed
    }
}