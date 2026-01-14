//
//  MockHealthKitService+Development.swift
//  FameFit
//
//  Development extensions for MockHealthKitService with scenario-based testing
//

#if DEBUG

import Foundation
import HealthKit

extension MockHealthKitService {
    
    // MARK: - Workout Scenarios
    
    enum WorkoutScenario {
        case quickTest(duration: TimeInterval = 30)
        case morningRun
        case eveningHIIT
        case strengthTraining
        case yoga
        case groupWorkout(participants: Int = 3)
        case challengeWorkout(position: Int, total: Int)
        case longRun
        case recovery
        case custom(type: HKWorkoutActivityType, duration: TimeInterval, intensity: Double)
    }
    
    // MARK: - Scenario Generation
    
    /// Generates a workout based on a predefined scenario
    func generateWorkout(
        scenario: WorkoutScenario,
        startDate: Date = Date()
    ) -> HKWorkout {
        
        switch scenario {
        case .quickTest(let duration):
            return MockWorkoutGenerator.generateWorkout(
                type: .running,
                duration: duration,
                startDate: startDate,
                intensity: 0.5,
                metadata: ["testWorkout": true]
            )
            
        case .morningRun:
            let morningStart = Calendar.current.date(
                bySettingHour: 7,
                minute: 0,
                second: 0,
                of: startDate
            ) ?? startDate
            
            return MockWorkoutGenerator.generateWorkout(
                type: .running,
                duration: 30 * 60, // 30 minutes
                startDate: morningStart,
                intensity: 0.65,
                metadata: ["timeOfDay": "morning"]
            )
            
        case .eveningHIIT:
            let eveningStart = Calendar.current.date(
                bySettingHour: 18,
                minute: 30,
                second: 0,
                of: startDate
            ) ?? startDate
            
            return MockWorkoutGenerator.generateWorkout(
                type: .highIntensityIntervalTraining,
                duration: 25 * 60, // 25 minutes
                startDate: eveningStart,
                intensity: 0.85,
                metadata: ["timeOfDay": "evening", "intervals": 8]
            )
            
        case .strengthTraining:
            return MockWorkoutGenerator.generateWorkout(
                type: .functionalStrengthTraining,
                duration: 45 * 60, // 45 minutes
                startDate: startDate,
                intensity: 0.7,
                metadata: ["equipment": "weights", "muscleGroups": "full body"]
            )
            
        case .yoga:
            return MockWorkoutGenerator.generateWorkout(
                type: .yoga,
                duration: 60 * 60, // 60 minutes
                startDate: startDate,
                intensity: 0.3,
                metadata: ["style": "vinyasa"]
            )
            
        case .groupWorkout(let participants):
            return MockWorkoutGenerator.generateWorkout(
                type: .running,
                duration: 35 * 60, // 35 minutes
                startDate: startDate,
                intensity: 0.7,
                metadata: [
                    "isGroupWorkout": true,
                    "participantCount": participants,
                    "groupID": UUID().uuidString
                ]
            )
            
        case .challengeWorkout(let position, let total):
            return MockWorkoutGenerator.generateWorkout(
                type: .cycling,
                duration: 40 * 60, // 40 minutes
                startDate: startDate,
                intensity: 0.75,
                metadata: [
                    "challengeID": UUID().uuidString,
                    "position": position,
                    "totalParticipants": total
                ]
            )
            
        case .longRun:
            return MockWorkoutGenerator.generateWorkout(
                type: .running,
                duration: 90 * 60, // 90 minutes
                startDate: startDate,
                intensity: 0.6,
                metadata: ["workoutType": "endurance"]
            )
            
        case .recovery:
            return MockWorkoutGenerator.generateWorkout(
                type: .walking,
                duration: 20 * 60, // 20 minutes
                startDate: startDate,
                intensity: 0.3,
                metadata: ["workoutType": "recovery"]
            )
            
        case .custom(let type, let duration, let intensity):
            return MockWorkoutGenerator.generateWorkout(
                type: type,
                duration: duration,
                startDate: startDate,
                intensity: intensity
            )
        }
    }
    
    // MARK: - Bulk Generation
    
    /// Generates a workout streak for the specified number of days
    func generateStreak(
        days: Int,
        workoutType: HKWorkoutActivityType = .running,
        endDate: Date = Date()
    ) -> [HKWorkout] {
        
        var workouts: [HKWorkout] = []
        let calendar = Calendar.current
        
        for dayOffset in 0..<days {
            guard let workoutDate = calendar.date(
                byAdding: .day,
                value: -dayOffset,
                to: endDate
            ) else { continue }
            
            // Vary the time of day
            let hour = [6, 7, 12, 17, 18, 19].randomElement() ?? 7
            guard let startTime = calendar.date(
                bySettingHour: hour,
                minute: 0,
                second: 0,
                of: workoutDate
            ) else { continue }
            
            // Vary intensity and duration
            let intensity = Double.random(in: 0.5...0.8)
            let duration = TimeInterval.random(in: 20...45) * 60
            
            let workout = MockWorkoutGenerator.generateWorkout(
                type: workoutType,
                duration: duration,
                startDate: startTime,
                intensity: intensity,
                metadata: ["streakDay": days - dayOffset]
            )
            
            workouts.append(workout)
        }
        
        return workouts
    }
    
    /// Generates a week of varied workouts
    func generateWeekOfWorkouts(startDate: Date = Date()) -> [HKWorkout] {
        let calendar = Calendar.current
        var workouts: [HKWorkout] = []
        
        // Define a typical week of workouts
        let weekPlan: [(day: Int, scenario: WorkoutScenario)] = [
            (0, .morningRun),
            (1, .strengthTraining),
            (2, .eveningHIIT),
            (3, .recovery),
            (4, .groupWorkout(participants: 4)),
            (5, .longRun),
            (6, .yoga)
        ]
        
        for (dayOffset, scenario) in weekPlan {
            guard let workoutDate = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: startDate
            ) else { continue }
            
            let workout = generateWorkout(
                scenario: scenario,
                startDate: workoutDate
            )
            workouts.append(workout)
        }
        
        return workouts
    }
    
    // MARK: - Group Workout Simulation
    
    /// Simulates multiple participants in a group workout
    func simulateGroupWorkout(
        hostName: String = "You",
        participantNames: [String] = ["Alice", "Bob", "Charlie"],
        workoutType: HKWorkoutActivityType = .running,
        startDate: Date = Date()
    ) -> [HKWorkout] {
        
        let groupID = UUID().uuidString
        let baseDuration = TimeInterval.random(in: 25...40) * 60
        var workouts: [HKWorkout] = []
        
        // Generate host workout
        let hostWorkout = MockWorkoutGenerator.generateWorkout(
            type: workoutType,
            duration: baseDuration,
            startDate: startDate,
            intensity: 0.7,
            metadata: [
                "isGroupWorkout": true,
                "groupID": groupID,
                "participantName": hostName,
                "isHost": true,
                "participantCount": participantNames.count + 1
            ]
        )
        workouts.append(hostWorkout)
        
        // Generate participant workouts with slight variations
        for participantName in participantNames {
            let variation = Double.random(in: -0.1...0.1)
            let participantDuration = baseDuration * (1 + variation)
            let participantIntensity = 0.7 + Double.random(in: -0.15...0.15)
            
            let participantWorkout = MockWorkoutGenerator.generateWorkout(
                type: workoutType,
                duration: participantDuration,
                startDate: startDate.addingTimeInterval(Double.random(in: -30...30)),
                intensity: participantIntensity,
                metadata: [
                    "isGroupWorkout": true,
                    "groupID": groupID,
                    "participantName": participantName,
                    "isHost": false,
                    "participantCount": participantNames.count + 1
                ]
            )
            workouts.append(participantWorkout)
        }
        
        return workouts
    }
    
    // MARK: - Challenge Simulation
    
    /// Generates workouts for a challenge leaderboard
    func generateChallengeWorkouts(
        challengeID: String = UUID().uuidString,
        participantCount: Int = 10,
        daysBack: Int = 7
    ) -> [HKWorkout] {
        
        var workouts: [HKWorkout] = []
        let calendar = Calendar.current
        
        for participant in 0..<participantCount {
            let workoutsForParticipant = Int.random(in: 3...daysBack)
            
            for _ in 0..<workoutsForParticipant {
                let daysAgo = Int.random(in: 0..<daysBack)
                guard let workoutDate = calendar.date(
                    byAdding: .day,
                    value: -daysAgo,
                    to: Date()
                ) else { continue }
                
                let workout = MockWorkoutGenerator.generateWorkout(
                    type: [.running, .cycling, .highIntensityIntervalTraining].randomElement() ?? .running,
                    duration: TimeInterval.random(in: 20...60) * 60,
                    startDate: workoutDate,
                    intensity: Double.random(in: 0.5...0.9),
                    metadata: [
                        "challengeID": challengeID,
                        "participantID": "participant_\(participant)",
                        "participantName": "User \(participant + 1)"
                    ]
                )
                workouts.append(workout)
            }
        }
        
        return workouts
    }
    
    // MARK: - Data Injection
    
    /// Adds a workout to the mock data store and triggers observers
    func injectWorkout(_ workout: HKWorkout) {
        mockWorkouts.insert(workout, at: 0)
        triggerWorkoutObserver()
        
        FameFitLogger.debug(
            "Injected mock workout: \(workout.workoutActivityType.name) - \(Int(workout.duration/60))min",
            category: FameFitLogger.healthKit
        )
    }
    
    /// Adds multiple workouts to the mock data store
    func injectWorkouts(_ workouts: [HKWorkout]) {
        mockWorkouts.insert(contentsOf: workouts, at: 0)
        triggerWorkoutObserver()
        
        FameFitLogger.debug(
            "Injected \(workouts.count) mock workouts",
            category: FameFitLogger.healthKit
        )
    }
    
    /// Clears all mock workouts and resets state
    func clearAllWorkouts() {
        mockWorkouts.removeAll()
        savedWorkouts.removeAll()
        
        FameFitLogger.debug(
            "Cleared all mock workouts",
            category: FameFitLogger.healthKit
        )
    }
}

// MARK: - Quick Actions

extension MockHealthKitService {
    
    /// Adds a workout that just finished
    func addJustCompletedWorkout(type: HKWorkoutActivityType = .running) {
        let workout = generateWorkout(
            scenario: .quickTest(duration: 30 * 60),
            startDate: Date().addingTimeInterval(-35 * 60)
        )
        injectWorkout(workout)
    }
    
    /// Adds workouts from today
    func addTodaysWorkouts() {
        let morning = generateWorkout(scenario: .morningRun)
        let evening = generateWorkout(scenario: .eveningHIIT)
        injectWorkouts([morning, evening])
    }
    
    /// Adds a week streak ending today
    func addWeekStreak() {
        let workouts = generateStreak(days: 7)
        injectWorkouts(workouts)
    }
    
    /// Adds a group workout that just finished
    func addRecentGroupWorkout() {
        let workouts = simulateGroupWorkout(
            startDate: Date().addingTimeInterval(-45 * 60)
        )
        injectWorkouts(workouts)
    }
}

#endif