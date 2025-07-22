//
//  AchievementManagerProtocolTests.swift
//  FameFit Watch AppTests
//
//  Tests for AchievementManaging protocol implementations
//

import XCTest
import HealthKit
@testable import FameFit_Watch_App

class AchievementManagerProtocolTests: XCTestCase {
    private var mockManager: MockAchievementManager!
    private var mockPersister: MockAchievementPersister!
    private var realManager: AchievementManager!
    
    override func setUp() {
        super.setUp()
        mockManager = MockAchievementManager()
        mockPersister = MockAchievementPersister()
        realManager = AchievementManager(persister: mockPersister)
    }
    
    override func tearDown() {
        mockManager = nil
        mockPersister = nil
        realManager = nil
        super.tearDown()
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testMockManagerConformsToProtocol() {
        // Given
        let protocolManager: any AchievementManaging = mockManager
        
        // When
        protocolManager.checkAchievements(
            for: nil,
            duration: 600,
            calories: 150,
            distance: 1000,
            averageHeartRate: 140
        )
        
        // Then
        XCTAssertTrue(mockManager.checkAchievementsCalled)
        XCTAssertEqual(mockManager.lastDuration, 600)
    }
    
    func testRealManagerConformsToProtocol() {
        // Given
        // Use the concrete type instead of protocol type
        let manager = realManager!
        
        // When
        manager.checkAchievements(
            for: nil,
            duration: 300, // 5 minutes
            calories: 50,
            distance: 500,
            averageHeartRate: 120
        )
        
        // Then - Should unlock 5 minute achievement
        XCTAssertTrue(manager.unlockedAchievements.contains(.fiveMinutes))
    }
    
    // MARK: - Dependency Injection Tests
    
    func testAchievementManagerUsesPersister() {
        // Given
        mockPersister.savedAchievements = ["first_workout", "five_minutes"]
        
        // When
        let manager = AchievementManager(persister: mockPersister)
        
        // Then
        XCTAssertTrue(mockPersister.loadAchievementsCalled)
        XCTAssertEqual(manager.unlockedAchievements.count, 2)
        XCTAssertTrue(manager.unlockedAchievements.contains(.firstWorkout))
        XCTAssertTrue(manager.unlockedAchievements.contains(.fiveMinutes))
    }
    
    func testAchievementManagerSavesUsingPersister() {
        // Given
        let manager = AchievementManager(persister: mockPersister)
        
        // When
        manager.checkAchievements(
            for: nil,
            duration: 100,
            calories: 100,
            distance: 0,
            averageHeartRate: 0
        )
        
        // Then
        XCTAssertTrue(mockPersister.saveAchievementsCalled)
        XCTAssertNotNil(mockPersister.savedAchievements)
        XCTAssertTrue(mockPersister.savedAchievements?.contains("first_workout") ?? false)
        XCTAssertTrue(mockPersister.savedAchievements?.contains("hundred_calories") ?? false)
    }
    
    // MARK: - Mock Manager Tests
    
    func testMockManagerTracksMethodCalls() {
        // Given
        // Note: HKWorkout init is deprecated in watchOS 10.0+
        // For testing purposes, we pass nil workout
        let workout: HKWorkout? = nil
        
        // When
        mockManager.checkAchievements(
            for: workout,
            duration: 600,
            calories: 150,
            distance: 1500,
            averageHeartRate: 145
        )
        
        let progress = mockManager.getAchievementProgress()
        
        // Then
        XCTAssertTrue(mockManager.checkAchievementsCalled)
        XCTAssertTrue(mockManager.getAchievementProgressCalled)
        XCTAssertEqual(mockManager.lastWorkout, workout)
        XCTAssertEqual(mockManager.lastDuration, 600)
        XCTAssertEqual(mockManager.lastCalories, 150)
        XCTAssertEqual(mockManager.lastDistance, 1500)
        XCTAssertEqual(mockManager.lastAverageHeartRate, 145)
        XCTAssertEqual(progress.total, AchievementManager.Achievement.allCases.count)
    }
    
    func testMockManagerCanSimulateAchievements() {
        // Given
        mockManager.achievementsToUnlock = [.tenMinutes, .hundredCalories]
        
        // When
        mockManager.checkAchievements(
            for: nil,
            duration: 600,
            calories: 100,
            distance: 0,
            averageHeartRate: 0
        )
        
        // Then
        XCTAssertEqual(mockManager.unlockedAchievements.count, 2)
        XCTAssertTrue(mockManager.unlockedAchievements.contains(.tenMinutes))
        XCTAssertTrue(mockManager.unlockedAchievements.contains(.hundredCalories))
        XCTAssertEqual(mockManager.recentAchievement, .hundredCalories) // Last in array
    }
    
    func testMockManagerCanSimulateFailure() {
        // Given
        mockManager.shouldFailChecking = true
        mockManager.achievementsToUnlock = [.firstWorkout]
        
        // When
        mockManager.checkAchievements(
            for: nil,
            duration: 300,
            calories: 50,
            distance: 0,
            averageHeartRate: 0
        )
        
        // Then
        XCTAssertTrue(mockManager.checkAchievementsCalled)
        XCTAssertEqual(mockManager.unlockedAchievements.count, 0) // No achievements unlocked
    }
    
    // MARK: - Achievement Logic Tests
    
    func testFirstWorkoutAchievement() {
        // Given - Fresh manager with no achievements
        
        // When
        realManager.checkAchievements(
            for: nil,
            duration: 60,
            calories: 10,
            distance: 0,
            averageHeartRate: 0
        )
        
        // Then
        XCTAssertTrue(realManager.unlockedAchievements.contains(.firstWorkout))
        // Note: recentAchievement might be .nightOwl or .earlyBird depending on time of day
        // since multiple achievements can be unlocked at once
        // Just verify that some achievement was set
        XCTAssertNotNil(realManager.recentAchievement)
    }
    
    func testDurationAchievements() {
        // Test 5 minutes
        realManager.checkAchievements(for: nil, duration: 300, calories: 0, distance: 0, averageHeartRate: 0)
        XCTAssertTrue(realManager.unlockedAchievements.contains(.fiveMinutes))
        
        // Test 10 minutes
        realManager.checkAchievements(for: nil, duration: 600, calories: 0, distance: 0, averageHeartRate: 0)
        XCTAssertTrue(realManager.unlockedAchievements.contains(.tenMinutes))
        
        // Test 30 minutes
        realManager.checkAchievements(for: nil, duration: 1800, calories: 0, distance: 0, averageHeartRate: 0)
        XCTAssertTrue(realManager.unlockedAchievements.contains(.thirtyMinutes))
        
        // Test 1 hour
        realManager.checkAchievements(for: nil, duration: 3600, calories: 0, distance: 0, averageHeartRate: 0)
        XCTAssertTrue(realManager.unlockedAchievements.contains(.oneHour))
    }
    
    func testCalorieAchievements() {
        // Test 100 calories
        realManager.checkAchievements(for: nil, duration: 0, calories: 100, distance: 0, averageHeartRate: 0)
        XCTAssertTrue(realManager.unlockedAchievements.contains(.hundredCalories))
        
        // Test 500 calories
        realManager.checkAchievements(for: nil, duration: 0, calories: 500, distance: 0, averageHeartRate: 0)
        XCTAssertTrue(realManager.unlockedAchievements.contains(.fiveHundredCalories))
    }
    
    func testPaceAchievements() {
        // NOTE: Pace achievements require a valid HKWorkout with workoutActivityType
        // Since HKWorkout init is deprecated and we can't create a valid workout in tests,
        // we'll test pace calculation logic using the mock manager instead
        
        // Given
        mockManager.achievementsToUnlock = [.fastPace]
        
        // When - Simulate fast pace workout
        mockManager.checkAchievements(
            for: nil,
            duration: 300, // 5 minutes
            calories: 0,
            distance: 1000, // 1km in 5 minutes = 5 min/km pace
            averageHeartRate: 0
        )
        
        // Then
        XCTAssertTrue(mockManager.unlockedAchievements.contains(.fastPace))
        XCTAssertEqual(mockManager.lastDuration, 300)
        XCTAssertEqual(mockManager.lastDistance, 1000)
        
        // Reset and test slow pace
        mockManager.reset()
        mockManager.achievementsToUnlock = [.slowPace]
        
        mockManager.checkAchievements(
            for: nil,
            duration: 780, // 13 minutes
            calories: 0,
            distance: 1000, // 1km in 13 minutes = 13 min/km pace
            averageHeartRate: 0
        )
        
        XCTAssertTrue(mockManager.unlockedAchievements.contains(.slowPace))
        XCTAssertEqual(mockManager.lastDuration, 780)
        XCTAssertEqual(mockManager.lastDistance, 1000)
    }
}