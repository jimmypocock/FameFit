//
//  WorkoutManager.swift
//  FameFit Watch App
//
//  Created by paige on 2021/12/11.
//

import Foundation
import HealthKit

class WorkoutManager: NSObject, ObservableObject {
    // MARK: - Core Properties
    @Published var selectedWorkout: HKWorkoutActivityType?
    @Published var showingSummaryView: Bool = false {
        didSet {
            if showingSummaryView == false {
                resetWorkout()
            }
        }
    }

    let healthStore = HKHealthStore()
    @Published var session: HKWorkoutSession?
    #if os(watchOS)
    var builder: HKLiveWorkoutBuilder?
    #else
    var builder: AnyObject?
    #endif

    // MARK: - Workout Control
    func startWorkout(workoutType: HKWorkoutActivityType) {
        print("Starting workout: \(workoutType)")
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = .unknown // Start with unknown, not outdoor
        
        #if os(watchOS)
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            
            print("Session and builder created successfully")
        } catch {
            print("Failed to create workout session: \(error)")
            DispatchQueue.main.async {
                self.isWorkoutRunning = false
            }
            return
        }

        // Set up data source
        guard let builder = builder else {
            print("Builder is nil")
            return
        }
        
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        // Set delegates
        session?.delegate = self
        builder.delegate = self

        // Start the session first
        session?.startActivity(with: Date())
        print("Session started")
        
        // Begin collection after session starts
        builder.beginCollection(withStart: Date()) { [weak self] success, error in
            print("Begin collection result: \(success), error: \(String(describing: error))")
            
            DispatchQueue.main.async {
                if success {
                    self?.isWorkoutRunning = true
                    print("Workout is now running")
                } else {
                    print("Failed to begin collection: \(error?.localizedDescription ?? "Unknown error")")
                    self?.workoutError = "Failed to start workout: \(error?.localizedDescription ?? "Unknown error")"
                    self?.isWorkoutRunning = false
                }
                
                // Start display timer only if HealthKit succeeded
                if success {
                    self?.startDisplayTimer()
                }
            }
        }
        #endif
    }


    // MARK: - Authorization
    func requestAuthorization() {
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]

        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if !success {
                print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    // MARK: - State Control

    // MARK: - Workout State
    @Published var isWorkoutRunning = false
    @Published var isPaused = false
    @Published var workoutError: String?
    @Published var currentMessage: String = ""
    
    // Display timer for smooth UI updates (NOT the actual workout timer)
    @Published var displayElapsedTime: TimeInterval = 0
    private var displayTimer: Timer?
    
    // DEBUG: Time acceleration for testing
    #if DEBUG
    private let timeMultiplier: Double = 60.0 // 1 second = 1 minute
    #else
    private let timeMultiplier: Double = 1.0
    #endif
    
    private var lastMilestoneTime: TimeInterval = 0
    private var messageTimer: Timer?
    
    // Achievement tracking
    let achievementManager = AchievementManager()

    func pause() {
        session?.pause()
        // State will be updated by HealthKit delegate
        print("Requested workout pause")
    }

    func resume() {
        session?.resume()
        // State will be updated by HealthKit delegate
        print("Requested workout resume")
    }

    func togglePause() {
        if isWorkoutRunning {
            pause()
        } else if isPaused {
            resume()
        }
    }

    func endWorkout() {
        print("Ending workout")
        displayTimer?.invalidate()
        
        guard let session = session else {
            // Don't show error if we're already showing summary
            if !showingSummaryView {
                workoutError = "No active workout to end"
            }
            return
        }
        
        // Show workout-specific end message based on type and duration
        if let workoutType = selectedWorkout {
            let workoutName = getWorkoutName(for: workoutType)
            currentMessage = FameFitMessages.getWorkoutSpecificMessage(
                workoutType: workoutName,
                duration: displayElapsedTime
            )
        } else {
            currentMessage = FameFitMessages.getMessage(for: .workoutEnd)
        }
        
        session.end()
        // Summary will be shown by HealthKit delegate when workout ends
    }

    // MARK: - Workout Metrics
    @Published var averageHeartRate: Double = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distance: Double = 0
    @Published var workout: HKWorkout?

    func resetWorkout() {
        selectedWorkout = nil
        builder = nil
        session = nil
        workout = nil
        activeEnergy = 0
        averageHeartRate = 0
        heartRate = 0
        distance = 0
        isWorkoutRunning = false
        isPaused = false
        displayElapsedTime = 0
        workoutError = nil
        currentMessage = ""
        lastMilestoneTime = 0
        displayTimer?.invalidate()
        displayTimer = nil
        messageTimer?.invalidate()
        messageTimer = nil
    }
    
    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateDisplayTime()
            }
        }
    }
    
    private func updateDisplayTime() {
        #if os(watchOS)
        if let builderTime = builder?.elapsedTime {
            self.displayElapsedTime = builderTime * timeMultiplier
        }
        #endif
    }
    
    private func startMilestoneTimer() {
        messageTimer?.invalidate()
        // Check every 5 seconds (which is 5 minutes in accelerated time)
        messageTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkMilestones()
        }
    }
    
    private func checkMilestones() {
        let currentTime = displayElapsedTime
        
        // Check for duration achievements in real-time
        var achievementUnlocked = false
        
        if currentTime >= 300 && !achievementManager.unlockedAchievements.contains(.fiveMinutes) {
            achievementManager.unlockedAchievements.insert(.fiveMinutes)
            currentMessage = "🏆 Achievement Unlocked: \(AchievementManager.Achievement.fiveMinutes.roastMessage)"
            achievementUnlocked = true
            lastMilestoneTime = 300
        } else if currentTime >= 600 && !achievementManager.unlockedAchievements.contains(.tenMinutes) {
            achievementManager.unlockedAchievements.insert(.tenMinutes)
            currentMessage = "🏆 Achievement Unlocked: \(AchievementManager.Achievement.tenMinutes.roastMessage)"
            achievementUnlocked = true
            lastMilestoneTime = 600
        } else if currentTime >= 1800 && !achievementManager.unlockedAchievements.contains(.thirtyMinutes) {
            achievementManager.unlockedAchievements.insert(.thirtyMinutes)
            currentMessage = "🏆 Achievement Unlocked: \(AchievementManager.Achievement.thirtyMinutes.roastMessage)"
            achievementUnlocked = true
            lastMilestoneTime = 1800
        }
        
        // If no achievement, show regular milestone or random message
        if !achievementUnlocked {
            if currentTime >= 300 && lastMilestoneTime < 300 {
                currentMessage = FameFitMessages.getMessage(for: .workoutMilestone)
                lastMilestoneTime = 300
            } else if currentTime >= 600 && lastMilestoneTime < 600 {
                currentMessage = FameFitMessages.getMessage(for: .workoutMilestone)
                lastMilestoneTime = 600
            } else if currentTime >= 1200 && lastMilestoneTime < 1200 {
                currentMessage = FameFitMessages.getMessage(for: .workoutMilestone)
                lastMilestoneTime = 1200
            } else if currentTime >= 1800 && lastMilestoneTime < 1800 {
                currentMessage = FameFitMessages.getMessage(for: .workoutMilestone)
                lastMilestoneTime = 1800
            } else {
                // Random encouragement or roast between milestones
                if Bool.random() {
                    currentMessage = FameFitMessages.getMessage(for: .encouragement)
                } else {
                    currentMessage = FameFitMessages.getMessage(for: .roast)
                }
            }
        }
    }
    
    private func getWorkoutName(for workoutType: HKWorkoutActivityType) -> String {
        switch workoutType {
        case .running:
            return "Run"
        case .cycling:
            return "Bike"
        case .walking:
            return "Walk"
        default:
            return "Workout"
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            switch toState {
            case .running:
                self?.isWorkoutRunning = true
                self?.isPaused = false
                self?.workoutError = nil
                if self?.displayTimer == nil {
                    self?.startDisplayTimer()
                }
                // Show start message
                self?.currentMessage = FameFitMessages.getMessage(for: .workoutStart)
                // Start checking for milestones
                self?.startMilestoneTimer()
            case .paused:
                self?.isWorkoutRunning = false
                self?.isPaused = true
                self?.displayTimer?.invalidate()
                self?.displayTimer = nil
                self?.messageTimer?.invalidate()
            case .stopped:
                self?.isWorkoutRunning = false
                self?.isPaused = false
                self?.displayTimer?.invalidate()
                self?.displayTimer = nil
            case .notStarted:
                self?.isWorkoutRunning = false
                self?.isPaused = false
                self?.displayTimer?.invalidate()
                self?.displayTimer = nil
            default:
                break
            }
        }

        // Wait for the session to transition states before ending the builder.
        if toState == .ended {
            builder?.endCollection(withEnd: date) { [weak self] _, error in
                self?.builder?.finishWorkout { [weak self] workout, error in
                    DispatchQueue.main.async {
                        self?.workout = workout
                        
                        // Check for achievements
                        if let workout = workout {
                            self?.achievementManager.checkAchievements(
                                for: workout,
                                duration: self?.displayElapsedTime ?? 0,
                                calories: self?.activeEnergy ?? 0,
                                distance: self?.distance ?? 0,
                                averageHeartRate: self?.averageHeartRate ?? 0
                            )
                            
                            // Show achievement message if any
                            if let achievement = self?.achievementManager.recentAchievement {
                                self?.currentMessage = "🏆 \(achievement.title): \(achievement.roastMessage)"
                            }
                        }
                        
                        // Clean up references
                        self?.session = nil
                        self?.builder = nil
                        // Now show summary after workout is fully processed
                        self?.showingSummaryView = true
                    }
                }
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
#if os(watchOS)
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { return }
            let statistics = workoutBuilder.statistics(for: quantityType)

            // Update the published values.
            updateForStatistics(statistics)
        }
    }

    func updateForStatistics(_ statistics: HKStatistics?) {
        guard let statistics = statistics else {
            return
        }

        DispatchQueue.main.async {
            switch statistics.quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                self.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                self.averageHeartRate = statistics.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0

            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                let energyUnit = HKUnit.kilocalorie()
                self.activeEnergy = statistics.sumQuantity()?.doubleValue(for: energyUnit) ?? 0

            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
                 HKQuantityType.quantityType(forIdentifier: .distanceCycling):
                let meterUnit = HKUnit.meter()
                self.distance = statistics.sumQuantity()?.doubleValue(for: meterUnit) ?? 0

            default: return
            }
        }
    }
}
#endif
