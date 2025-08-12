//
//  MockHealthKitSystemTests.swift
//  FameFitTests
//
//  Tests for the mock HealthKit system
//

import XCTest
@testable import FameFit
import HealthKit

final class MockHealthKitSystemTests: XCTestCase {
    
    var mockService: MockHealthKitService!
    
    override func setUp() {
        super.setUp()
        mockService = MockHealthKitService()
        mockService.reset()
        
        #if DEBUG
        // Clear any persisted mock data
        MockDataStorage.shared.clearAll()
        #endif
    }
    
    override func tearDown() {
        mockService.reset()
        mockService = nil
        super.tearDown()
    }
    
    // MARK: - Service Resolution Tests
    
    func testServiceResolverReturnsMockWhenEnabled() {
        #if DEBUG
        // Enable mock services
        ServiceResolver.enableMockServices()
        
        let service = ServiceResolver.healthKitService
        XCTAssertTrue(service is MockHealthKitService)
        XCTAssertTrue(ServiceResolver.isUsingMockData)
        
        // Disable mock services
        ServiceResolver.disableMockServices()
        #endif
    }
    
    func testServiceResolverReturnsRealServiceByDefault() {
        #if DEBUG
        ServiceResolver.disableMockServices()
        #endif
        
        let service = ServiceResolver.healthKitService
        XCTAssertTrue(service is HealthKitService)
        XCTAssertFalse(ServiceResolver.isUsingMockData)
    }
    
    // MARK: - Workout Generation Tests
    
    func testGenerateQuickTestWorkout() {
        #if DEBUG
        let workout = mockService.generateWorkout(
            scenario: .quickTest(duration: 60),
            startDate: Date()
        )
        
        XCTAssertEqual(workout.duration, 60)
        XCTAssertEqual(workout.workoutActivityType, .running)
        XCTAssertNotNil(workout.metadata?["testWorkout"])
        #endif
    }
    
    func testGenerateMorningRunWorkout() {
        #if DEBUG
        let workout = mockService.generateWorkout(scenario: .morningRun)
        
        XCTAssertEqual(workout.workoutActivityType, .running)
        XCTAssertEqual(workout.duration, 30 * 60) // 30 minutes
        XCTAssertEqual(workout.metadata?["timeOfDay"] as? String, "morning")
        
        // Check morning time
        let hour = Calendar.current.component(.hour, from: workout.startDate)
        XCTAssertEqual(hour, 7)
        #endif
    }
    
    func testGenerateHIITWorkout() {
        #if DEBUG
        let workout = mockService.generateWorkout(scenario: .eveningHIIT)
        
        XCTAssertEqual(workout.workoutActivityType, .highIntensityIntervalTraining)
        XCTAssertEqual(workout.duration, 25 * 60) // 25 minutes
        XCTAssertEqual(workout.metadata?["intervals"] as? Int, 8)
        #endif
    }
    
    func testGenerateGroupWorkout() {
        #if DEBUG
        let workout = mockService.generateWorkout(
            scenario: .groupWorkout(participants: 5)
        )
        
        XCTAssertEqual(workout.workoutActivityType, .running)
        XCTAssertTrue(workout.metadata?["isGroupWorkout"] as? Bool ?? false)
        XCTAssertEqual(workout.metadata?["participantCount"] as? Int, 5)
        XCTAssertNotNil(workout.metadata?["groupID"])
        #endif
    }
    
    // MARK: - Bulk Generation Tests
    
    func testGenerateWeekStreak() {
        #if DEBUG
        let workouts = mockService.generateStreak(days: 7)
        
        XCTAssertEqual(workouts.count, 7)
        
        // Verify each workout is on a different day
        let calendar = Calendar.current
        let days = workouts.map { calendar.startOfDay(for: $0.startDate) }
        let uniqueDays = Set(days)
        XCTAssertEqual(uniqueDays.count, 7)
        
        // Verify streak metadata
        for (index, workout) in workouts.enumerated() {
            let expectedStreakDay = 7 - index
            XCTAssertEqual(workout.metadata?["streakDay"] as? Int, expectedStreakDay)
        }
        #endif
    }
    
    func testGenerateWeekOfVariedWorkouts() {
        #if DEBUG
        let workouts = mockService.generateWeekOfWorkouts()
        
        XCTAssertEqual(workouts.count, 7)
        
        // Verify variety of workout types
        let types = Set(workouts.map { $0.workoutActivityType })
        XCTAssertGreaterThan(types.count, 3) // Should have at least 4 different types
        #endif
    }
    
    func testSimulateGroupWorkoutWithParticipants() {
        #if DEBUG
        let participants = ["Alice", "Bob", "Charlie"]
        let workouts = mockService.simulateGroupWorkout(
            hostName: "TestUser",
            participantNames: participants
        )
        
        XCTAssertEqual(workouts.count, 4) // Host + 3 participants
        
        // Verify all have same group ID
        let groupIDs = workouts.compactMap { $0.metadata?["groupID"] as? String }
        let uniqueGroupID = Set(groupIDs)
        XCTAssertEqual(uniqueGroupID.count, 1)
        
        // Verify host
        let hostWorkout = workouts.first { $0.metadata?["isHost"] as? Bool == true }
        XCTAssertNotNil(hostWorkout)
        XCTAssertEqual(hostWorkout?.metadata?["participantName"] as? String, "TestUser")
        #endif
    }
    
    // MARK: - Data Injection Tests
    
    func testInjectWorkout() {
        #if DEBUG
        let workout = mockService.generateWorkout(scenario: .quickTest())
        
        XCTAssertEqual(mockService.mockWorkouts.count, 0)
        
        mockService.injectWorkout(workout)
        
        XCTAssertEqual(mockService.mockWorkouts.count, 1)
        XCTAssertEqual(mockService.mockWorkouts.first?.uuid, workout.uuid)
        #endif
    }
    
    func testInjectMultipleWorkouts() {
        #if DEBUG
        let workouts = mockService.generateWeekOfWorkouts()
        
        mockService.injectWorkouts(workouts)
        
        XCTAssertEqual(mockService.mockWorkouts.count, workouts.count)
        #endif
    }
    
    func testClearAllWorkouts() {
        #if DEBUG
        // Add some workouts
        let workouts = mockService.generateStreak(days: 5)
        mockService.injectWorkouts(workouts)
        
        XCTAssertEqual(mockService.mockWorkouts.count, 5)
        
        // Clear all
        mockService.clearAllWorkouts()
        
        XCTAssertEqual(mockService.mockWorkouts.count, 0)
        XCTAssertEqual(mockService.savedWorkouts.count, 0)
        #endif
    }
    
    // MARK: - Mock Data Storage Tests
    
    func testSaveAndLoadWorkouts() {
        #if DEBUG
        let workouts = mockService.generateStreak(days: 3)
        
        MockDataStorage.shared.saveWorkouts(workouts)
        let loaded = MockDataStorage.shared.loadWorkouts()
        
        XCTAssertEqual(loaded.count, 3)
        
        // Verify workout properties are preserved
        for (index, workout) in workouts.enumerated() {
            XCTAssertEqual(loaded[index].duration, workout.duration)
            XCTAssertEqual(loaded[index].workoutActivityType, workout.workoutActivityType)
        }
        #endif
    }
    
    func testRemoveOldWorkouts() {
        #if DEBUG
        // Create workouts with different dates
        let oldDate = Date().addingTimeInterval(-7 * 86400) // 7 days ago
        let recentDate = Date().addingTimeInterval(-86400) // 1 day ago
        
        let oldWorkout = MockWorkoutGenerator.generateWorkout(
            type: .running,
            duration: 1800,
            startDate: oldDate
        )
        
        let recentWorkout = MockWorkoutGenerator.generateWorkout(
            type: .cycling,
            duration: 2400,
            startDate: recentDate
        )
        
        MockDataStorage.shared.saveWorkouts([oldWorkout, recentWorkout])
        
        // Remove workouts older than 3 days
        let cutoffDate = Date().addingTimeInterval(-3 * 86400)
        MockDataStorage.shared.removeWorkoutsOlderThan(cutoffDate)
        
        let remaining = MockDataStorage.shared.loadWorkouts()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.workoutActivityType, .cycling)
        #endif
    }
    
    func testMockConfiguration() {
        #if DEBUG
        let config = MockConfiguration(
            autoGenerateWorkouts: true,
            generationInterval: 1800,
            defaultIntensity: 0.8,
            defaultWorkoutType: HKWorkoutActivityType.cycling.rawValue,
            enableBackgroundGeneration: true,
            maxStoredWorkouts: 50
        )
        
        MockDataStorage.shared.saveConfiguration(config)
        let loaded = MockDataStorage.shared.loadConfiguration()
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.autoGenerateWorkouts, true)
        XCTAssertEqual(loaded?.generationInterval, 1800)
        XCTAssertEqual(loaded?.defaultIntensity, 0.8)
        XCTAssertEqual(loaded?.maxStoredWorkouts, 50)
        #endif
    }
    
    // MARK: - Realistic Data Generation Tests
    
    func testGenerateRealisticHeartRateData() {
        #if DEBUG
        let heartRateData = MockWorkoutGenerator.generateHeartRateData(
            for: .running,
            duration: 1800, // 30 minutes
            intensity: 0.7
        )
        
        XCTAssertGreaterThan(heartRateData.count, 0)
        
        // Verify heart rate is within reasonable bounds
        for (_, heartRate) in heartRateData {
            XCTAssertGreaterThanOrEqual(heartRate, 50) // Above resting
            XCTAssertLessThanOrEqual(heartRate, 200) // Below max
        }
        
        // Verify warmup pattern (should start lower)
        if heartRateData.count > 10 {
            let firstQuarter = heartRateData.prefix(heartRateData.count / 4)
            let lastQuarter = heartRateData.suffix(heartRateData.count / 4)
            
            let avgFirst = firstQuarter.map { $0.heartRate }.reduce(0, +) / Double(firstQuarter.count)
            let avgLast = lastQuarter.map { $0.heartRate }.reduce(0, +) / Double(lastQuarter.count)
            
            // Early heart rate should generally be lower than peak
            XCTAssertLessThan(avgFirst, avgLast + 20) // Allow for variation
        }
        #endif
    }
    
    func testGeneratePaceData() {
        #if DEBUG
        let paceData = MockWorkoutGenerator.generatePaceData(
            for: .running,
            duration: 1800,
            totalDistance: 5000 // 5km
        )
        
        XCTAssertGreaterThan(paceData.count, 0)
        
        // Verify pace is reasonable (between 3-10 min/km for running)
        for (_, pace) in paceData {
            XCTAssertGreaterThan(pace, 3.0)
            XCTAssertLessThan(pace, 10.0)
        }
        #endif
    }
    
    // MARK: - Quick Action Tests
    
    func testAddJustCompletedWorkout() {
        #if DEBUG
        mockService.addJustCompletedWorkout()
        
        XCTAssertEqual(mockService.mockWorkouts.count, 1)
        
        let workout = mockService.mockWorkouts.first
        XCTAssertNotNil(workout)
        
        // Should be recent (within last hour)
        let timeSinceEnd = Date().timeIntervalSince(workout!.endDate)
        XCTAssertLessThan(timeSinceEnd, 3600)
        #endif
    }
    
    func testAddTodaysWorkouts() {
        #if DEBUG
        mockService.addTodaysWorkouts()
        
        XCTAssertEqual(mockService.mockWorkouts.count, 2)
        
        // Both should be from today
        let calendar = Calendar.current
        for workout in mockService.mockWorkouts {
            XCTAssertTrue(calendar.isDateInToday(workout.startDate))
        }
        #endif
    }
}

// MARK: - Mock Workout Scheduler Tests

final class MockWorkoutSchedulerTests: XCTestCase {
    
    #if DEBUG
    var scheduler: MockWorkoutScheduler!
    
    override func setUp() {
        super.setUp()
        scheduler = MockWorkoutScheduler.shared
        scheduler.cancelAll()
    }
    
    override func tearDown() {
        scheduler.cancelAll()
        scheduler = nil
        super.tearDown()
    }
    
    func testScheduleWorkoutDelivery() {
        let expectation = self.expectation(description: "Workout delivered")
        
        // Subscribe to notification
        let observer = NotificationCenter.default.addObserver(
            forName: .mockWorkoutDelivered,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertNotNil(notification.object as? HKWorkout)
            expectation.fulfill()
        }
        
        // Schedule workout for immediate delivery
        _ = scheduler.scheduleWorkout(
            scenario: .quickTest(),
            after: 0.1
        )
        
        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testCancelScheduledWorkout() {
        let taskID = scheduler.scheduleWorkout(
            scenario: .quickTest(),
            after: 10.0
        )
        
        // Cancel immediately
        scheduler.cancelScheduled(taskID: taskID)
        
        // Verify it doesn't deliver
        let expectation = self.expectation(description: "No workout delivered")
        expectation.isInverted = true
        
        let observer = NotificationCenter.default.addObserver(
            forName: .mockWorkoutDelivered,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 0.5)
        NotificationCenter.default.removeObserver(observer)
    }
    #endif
}