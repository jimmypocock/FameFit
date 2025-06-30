//
//  WorkoutManager.swift
//  WWDC_WatchApp WatchKit Extension
//
//  Created by paige on 2021/12/11.
//

import Foundation
import HealthKit

// MARK: WORKOUT MANAGER
/*
 Initialize..
 
 List(workoutTypes) { workoutType in
 NavigationLink(
 workoutType.name,
 destination: SessionPagingView(),
 tag: workoutType,
 selection: $workoutManager.selectedWorkout
 )
 .padding(
 EdgeInsets(top: 15, leading: 5, bottom: 15, trailing: 5)
 ) //: NAVIGATION LINK
 } //: LIST
 .listStyle(.carousel)
 .navigationBarTitle("Workouts")
 
 */
class WorkoutManager: NSObject, ObservableObject {
    
    // MARK: - FameFit Properties
    @Published var currentMessage: String = ""
    @Published var lastMilestoneTime: TimeInterval = 0
    let achievementManager = AchievementManager()
    private var messageTimer: Timer?
    
    var selectedWorkout: HKWorkoutActivityType? {
        didSet {
            guard let selectedWorkout = selectedWorkout else { return }
            startWorkout(workoutType: selectedWorkout)
        }
    }
    
    @Published var showingSummaryView: Bool = false {
        didSet {
            // Sheet dismissed
            if showingSummaryView == false {
                resetWorkout()
            }
        }
    }
    
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    func startWorkout(workoutType: HKWorkoutActivityType) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = .outdoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            // Handle any exceptions.
            return
        }
        
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        
        session?.delegate = self
        builder?.delegate = self
        
        // Start the workout session and begin data collection.
        let startDate = Date()
        session?.startActivity(with: startDate)
        builder?.beginCollection(withStart: startDate, completion: { success, error in
            // The workout has started
            if success {
                self.startFameFitMessages()
                self.showFameFitMessage(for: .workoutStart)
            }
        })
        
    }
    
    // MARK: - FameFit Methods
    
    private func startFameFitMessages() {
        // Send a motivational roast every 5 minutes
        messageTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.checkMilestones()
        }
    }
    
    private func stopFameFitMessages() {
        messageTimer?.invalidate()
        messageTimer = nil
    }
    
    private func showFameFitMessage(for category: FameFitMessages.MessageCategory) {
        DispatchQueue.main.async {
            self.currentMessage = FameFitMessages.getMessage(for: category)
        }
        
        // Clear message after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.currentMessage = ""
        }
    }
    
    private func checkMilestones() {
        guard let elapsedTime = builder?.elapsedTime else { return }
        
        // Show milestone messages at 5, 10, 20, 30 minutes
        if elapsedTime >= 300 && lastMilestoneTime < 300 {
            showFameFitMessage(for: .workoutMilestone)
            DispatchQueue.main.async {
                self.lastMilestoneTime = 300
            }
        } else if elapsedTime >= 600 && lastMilestoneTime < 600 {
            showFameFitMessage(for: .workoutMilestone)
            DispatchQueue.main.async {
                self.lastMilestoneTime = 600
            }
        } else if elapsedTime >= 1200 && lastMilestoneTime < 1200 {
            showFameFitMessage(for: .workoutMilestone)
            DispatchQueue.main.async {
                self.lastMilestoneTime = 1200
            }
        } else if elapsedTime >= 1800 && lastMilestoneTime < 1800 {
            showFameFitMessage(for: .workoutMilestone)
            DispatchQueue.main.async {
                self.lastMilestoneTime = 1800
            }
        } else {
            // Random encouragement between milestones
            if Bool.random() {
                showFameFitMessage(for: .encouragement)
            } else {
                showFameFitMessage(for: .roast)
            }
        }
    }
    
    // Request authorization to access Healthkit.
    func requestAuthorization() {
        
        // The quantity type to write to the health store.
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        // The quantity types to read from the health store.
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.activitySummaryType()
        ]
        
        // Request authorization for those quantity types
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            // Handle error.
        }
        
    }
    
    // MARK: - State Control
    
    // The workout session state
    @Published var running = false
    
    func pause() {
        session?.pause()
    }
    
    func resume() {
        session?.resume()
    }
    
    func togglePuase() {
        if running == true {
            pause()
        } else {
            resume()
        }
    }
    
    func endWorkout() {
        // Show end workout message
        if let duration = builder?.elapsedTime,
           let workoutType = selectedWorkout?.name {
            DispatchQueue.main.async {
                self.currentMessage = FameFitMessages.getWorkoutSpecificMessage(
                    workoutType: workoutType,
                    duration: duration
                )
            }
        } else {
            showFameFitMessage(for: .workoutEnd)
        }
        
        stopFameFitMessages()
        session?.end()
        DispatchQueue.main.async {
            self.showingSummaryView = true
        }
    }
    
    // MARK: - Workout Metrics
    @Published var averageHeartRate: Double = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distance: Double = 0
    @Published var workout: HKWorkout?
    
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.running = toState == .running
        }
        // Wait for the session to transition states before ending the builder.
        if toState == .ended {
            builder?.endCollection(withEnd: date, completion: { success, error in
                self.builder?.finishWorkout(completion: { workout, error in
                    DispatchQueue.main.async {
                        self.workout = workout
                        
                        // Check for achievements
                        if let workout = workout {
                            self.achievementManager.checkAchievements(
                                for: workout,
                                duration: workout.duration,
                                calories: self.activeEnergy,
                                distance: self.distance,
                                averageHeartRate: self.averageHeartRate
                            )
                            
                            // Show achievement message if any
                            if let achievement = self.achievementManager.recentAchievement {
                                self.currentMessage = achievement.roastMessage
                            }
                        }
                    }
                })
            })
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        
    }
    
}

// MARK: - HKLiveWorkoutBuilderDelegate
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
                
            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning), HKQuantityType.quantityType(forIdentifier: .distanceCycling):
                let meterUnit = HKUnit.meter()
                self.distance = statistics.sumQuantity()?.doubleValue(for: meterUnit) ?? 0
                
            default: return
                
            }
        }
        
    }
    
    func resetWorkout() {
        DispatchQueue.main.async {
            self.selectedWorkout = nil
            self.builder = nil
            self.session = nil
            self.workout = nil
            self.activeEnergy = 0
            self.averageHeartRate = 0
            self.heartRate = 0
            self.distance = 0
            self.currentMessage = ""
            self.lastMilestoneTime = 0
        }
        stopFameFitMessages()
    }
    
}
