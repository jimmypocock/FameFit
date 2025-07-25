//
//  MockAchievementManager.swift
//  FameFit Watch AppTests
//
//  Mock implementation of AchievementManaging for testing
//

@testable import FameFit_Watch_App
import Foundation
import HealthKit

/// Mock achievement manager for testing
class MockAchievementManager: ObservableObject, AchievementManaging {
    typealias AchievementType = AchievementManager.Achievement

    @Published var unlockedAchievements: Set<AchievementType> = []
    @Published var recentAchievement: AchievementType?

    // Test control properties
    var checkAchievementsCalled = false
    var getAchievementProgressCalled = false

    var lastWorkout: HKWorkout?
    var lastDuration: TimeInterval?
    var lastCalories: Double?
    var lastDistance: Double?
    var lastAverageHeartRate: Double?

    // Control test behavior
    var achievementsToUnlock: [AchievementType] = []
    var shouldFailChecking = false

    func checkAchievements(
        for workout: HKWorkout?,
        duration: TimeInterval,
        calories: Double,
        distance: Double,
        averageHeartRate: Double
    ) {
        checkAchievementsCalled = true
        lastWorkout = workout
        lastDuration = duration
        lastCalories = calories
        lastDistance = distance
        lastAverageHeartRate = averageHeartRate

        if !shouldFailChecking {
            // Unlock predetermined achievements
            for achievement in achievementsToUnlock {
                unlockedAchievements.insert(achievement)
                recentAchievement = achievement
            }
        }
    }

    func getAchievementProgress() -> (unlocked: Int, total: Int) {
        getAchievementProgressCalled = true
        return (unlockedAchievements.count, AchievementType.allCases.count)
    }

    // Test helper methods
    func reset() {
        unlockedAchievements.removeAll()
        recentAchievement = nil

        checkAchievementsCalled = false
        getAchievementProgressCalled = false

        lastWorkout = nil
        lastDuration = nil
        lastCalories = nil
        lastDistance = nil
        lastAverageHeartRate = nil

        achievementsToUnlock.removeAll()
        shouldFailChecking = false
    }

    func simulateUnlockedAchievements(_ achievements: [AchievementType]) {
        unlockedAchievements = Set(achievements)
        recentAchievement = achievements.last
    }
}

/// Mock achievement persister for testing
class MockAchievementPersister: AchievementPersisting {
    var savedAchievements: [String]?
    var saveAchievementsCalled = false
    var loadAchievementsCalled = false

    func saveAchievements(_ achievements: [String]) {
        saveAchievementsCalled = true
        savedAchievements = achievements
    }

    func loadAchievements() -> [String]? {
        loadAchievementsCalled = true
        return savedAchievements
    }

    func reset() {
        savedAchievements = nil
        saveAchievementsCalled = false
        loadAchievementsCalled = false
    }
}
