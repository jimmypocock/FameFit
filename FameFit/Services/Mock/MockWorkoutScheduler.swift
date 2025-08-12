//
//  MockWorkoutScheduler.swift
//  FameFit
//
//  Simulates background workout delivery for development testing
//

#if DEBUG

import Foundation
import HealthKit

/// Manages scheduled generation and delivery of mock workouts
final class MockWorkoutScheduler {
    
    // MARK: - Properties
    
    static let shared = MockWorkoutScheduler()
    
    private var timer: Timer?
    private var scheduledTasks: [UUID: DispatchWorkItem] = [:]
    private let queue = DispatchQueue(label: "com.famefit.mockscheduler", qos: .background)
    
    // MARK: - Initialization
    
    private init() {
        loadAndProcessScheduledWorkouts()
    }
    
    // MARK: - Scheduling
    
    /// Schedules a workout to appear after the specified delay
    func scheduleWorkout(
        scenario: MockHealthKitService.WorkoutScenario,
        after delay: TimeInterval,
        recurring: Bool = false,
        recurrenceInterval: TimeInterval? = nil
    ) -> UUID {
        
        let taskID = UUID()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.deliverWorkout(scenario: scenario)
            
            // Schedule next occurrence if recurring
            if recurring, let interval = recurrenceInterval {
                _ = self?.scheduleWorkout(
                    scenario: scenario,
                    after: interval,
                    recurring: true,
                    recurrenceInterval: interval
                )
            }
        }
        
        scheduledTasks[taskID] = workItem
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
        
        // Persist the schedule
        let scheduled = ScheduledWorkout(
            scheduledDate: Date().addingTimeInterval(delay),
            scenarioName: String(describing: scenario),
            isRecurring: recurring,
            recurrenceInterval: recurrenceInterval
        )
        
        var schedules = MockDataStorage.shared.loadScheduledWorkouts()
        schedules.append(scheduled)
        MockDataStorage.shared.saveScheduledWorkouts(schedules)
        
        FameFitLogger.debug(
            "Scheduled mock workout for delivery in \(Int(delay))s",
            category: FameFitLogger.healthKit
        )
        
        return taskID
    }
    
    /// Cancels a scheduled workout
    func cancelScheduled(taskID: UUID) {
        scheduledTasks[taskID]?.cancel()
        scheduledTasks.removeValue(forKey: taskID)
        
        FameFitLogger.debug(
            "Cancelled scheduled mock workout",
            category: FameFitLogger.healthKit
        )
    }
    
    /// Cancels all scheduled workouts
    func cancelAll() {
        scheduledTasks.values.forEach { $0.cancel() }
        scheduledTasks.removeAll()
        MockDataStorage.shared.saveScheduledWorkouts([])
        
        FameFitLogger.debug(
            "Cancelled all scheduled mock workouts",
            category: FameFitLogger.healthKit
        )
    }
    
    // MARK: - Automatic Generation
    
    /// Starts automatic workout generation at regular intervals
    func startAutomaticGeneration(
        interval: TimeInterval = 3600,
        scenarios: [MockHealthKitService.WorkoutScenario] = [.morningRun, .eveningHIIT]
    ) {
        
        stopAutomaticGeneration()
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let scenario = scenarios.randomElement() else { return }
            self?.deliverWorkout(scenario: scenario)
        }
        
        FameFitLogger.info(
            "Started automatic mock workout generation (interval: \(Int(interval))s)",
            category: FameFitLogger.healthKit
        )
    }
    
    /// Stops automatic workout generation
    func stopAutomaticGeneration() {
        timer?.invalidate()
        timer = nil
        
        FameFitLogger.info(
            "Stopped automatic mock workout generation",
            category: FameFitLogger.healthKit
        )
    }
    
    // MARK: - Simulation
    
    /// Simulates a realistic workout appearing pattern
    func simulateRealisticDay() {
        let calendar = Calendar.current
        let now = Date()
        
        // Morning workout (7 AM)
        if let morningTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now),
           morningTime > now {
            let delay = morningTime.timeIntervalSince(now)
            _ = scheduleWorkout(scenario: .morningRun, after: delay)
        }
        
        // Lunch workout (12:30 PM)
        if let lunchTime = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: now),
           lunchTime > now {
            let delay = lunchTime.timeIntervalSince(now)
            _ = scheduleWorkout(scenario: .quickTest(duration: 20 * 60), after: delay)
        }
        
        // Evening workout (6 PM)
        if let eveningTime = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now),
           eveningTime > now {
            let delay = eveningTime.timeIntervalSince(now)
            _ = scheduleWorkout(scenario: .eveningHIIT, after: delay)
        }
        
        FameFitLogger.info(
            "Scheduled realistic day of mock workouts",
            category: FameFitLogger.healthKit
        )
    }
    
    /// Simulates workouts appearing from other devices (like Apple Watch)
    func simulateWatchSync(workoutCount: Int = 1, maxDelay: TimeInterval = 10) {
        for i in 0..<workoutCount {
            let delay = Double.random(in: 2...maxDelay)
            let scenario = MockHealthKitService.WorkoutScenario.quickTest(
                duration: TimeInterval.random(in: 15...45) * 60
            )
            
            queue.asyncAfter(deadline: .now() + delay + Double(i * 2)) { [weak self] in
                self?.deliverWorkout(
                    scenario: scenario,
                    metadata: [
                        "source": "Apple Watch",
                        "syncedFrom": "watchOS",
                        "syncDelay": Int(delay)
                    ]
                )
            }
        }
        
        FameFitLogger.debug(
            "Simulating Watch sync with \(workoutCount) workouts",
            category: FameFitLogger.healthKit
        )
    }
    
    // MARK: - Private Helpers
    
    private func deliverWorkout(
        scenario: MockHealthKitService.WorkoutScenario,
        metadata: [String: Any]? = nil
    ) {
        
        DispatchQueue.main.async {
            let workout = MockHealthKitService.shared.generateWorkout(
                scenario: scenario,
                startDate: Date().addingTimeInterval(-3600) // Workout finished 1 hour ago
            )
            
            // Add any additional metadata
            if let metadata = metadata {
                // Note: HKWorkout metadata is immutable after creation
                // In a real scenario, we'd need to recreate the workout with merged metadata
                FameFitLogger.debug(
                    "Additional metadata would be added: \(metadata)",
                    category: FameFitLogger.healthKit
                )
            }
            
            MockHealthKitService.shared.injectWorkout(workout)
            
            // Save to persistent storage
            MockDataStorage.shared.appendWorkout(workout)
            
            // Post notification for UI updates
            NotificationCenter.default.post(
                name: .mockWorkoutDelivered,
                object: workout
            )
            
            FameFitLogger.info(
                "Delivered scheduled mock workout: \(workout.workoutActivityType.name)",
                category: FameFitLogger.healthKit
            )
        }
    }
    
    private func loadAndProcessScheduledWorkouts() {
        let schedules = MockDataStorage.shared.loadScheduledWorkouts()
        let now = Date()
        
        for schedule in schedules {
            if schedule.scheduledDate > now {
                let delay = schedule.scheduledDate.timeIntervalSince(now)
                
                // Recreate the scheduled task
                let workItem = DispatchWorkItem { [weak self] in
                    // Try to parse the scenario from the stored name
                    self?.deliverWorkoutFromScheduleName(schedule.scenarioName)
                    
                    if schedule.isRecurring, let interval = schedule.recurrenceInterval {
                        // Reschedule if recurring
                        let newSchedule = ScheduledWorkout(
                            scheduledDate: Date().addingTimeInterval(interval),
                            scenarioName: schedule.scenarioName,
                            isRecurring: true,
                            recurrenceInterval: interval
                        )
                        
                        var schedules = MockDataStorage.shared.loadScheduledWorkouts()
                        schedules.append(newSchedule)
                        MockDataStorage.shared.saveScheduledWorkouts(schedules)
                    }
                }
                
                scheduledTasks[schedule.id] = workItem
                queue.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
        }
        
        // Clean up expired schedules
        let activeSchedules = schedules.filter { $0.scheduledDate > now || $0.isRecurring }
        MockDataStorage.shared.saveScheduledWorkouts(activeSchedules)
    }
    
    private func deliverWorkoutFromScheduleName(_ name: String) {
        // Map stored names back to scenarios
        let scenario: MockHealthKitService.WorkoutScenario
        
        switch name {
        case "morningRun":
            scenario = .morningRun
        case "eveningHIIT":
            scenario = .eveningHIIT
        case "strengthTraining":
            scenario = .strengthTraining
        case "yoga":
            scenario = .yoga
        case "recovery":
            scenario = .recovery
        case "longRun":
            scenario = .longRun
        default:
            scenario = .quickTest()
        }
        
        deliverWorkout(scenario: scenario)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let mockWorkoutDelivered = Notification.Name("com.famefit.mockWorkoutDelivered")
    static let mockWorkoutScheduled = Notification.Name("com.famefit.mockWorkoutScheduled")
}

// MARK: - Convenience Extensions

extension MockWorkoutScheduler {
    
    /// Quick action to simulate a workout appearing in the background
    func simulateBackgroundWorkout() {
        let delay = Double.random(in: 2...10)
        _ = scheduleWorkout(scenario: .quickTest(), after: delay)
    }
    
    /// Simulates a group workout starting soon
    func simulateUpcomingGroupWorkout(in seconds: TimeInterval = 300) {
        _ = scheduleWorkout(
            scenario: .groupWorkout(participants: Int.random(in: 2...6)),
            after: seconds
        )
    }
    
    /// Simulates challenge workouts appearing throughout the day
    func simulateChallengeActivity(participantCount: Int = 5) {
        for i in 0..<participantCount {
            let delay = Double.random(in: 60...3600)
            _ = scheduleWorkout(
                scenario: .challengeWorkout(position: i + 1, total: participantCount),
                after: delay
            )
        }
    }
}

#endif