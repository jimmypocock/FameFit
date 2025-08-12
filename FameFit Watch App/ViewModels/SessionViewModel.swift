//
//  SessionViewModel.swift
//  FameFit Watch App
//
//  ViewModel for active workout session - handles metrics and controls
//

import Foundation
import SwiftUI
import HealthKit
import Combine

@MainActor
final class SessionViewModel: ObservableObject {
    // MARK: - Dependencies
    
    private let healthKitSession: HealthKitSessionManaging
    private let metricsCollector: WorkoutMetricsCollecting
    let stateManager: WorkoutStateManaging
    private let groupWorkoutCoordinator: GroupWorkoutCoordinating
    private let achievementManager: any AchievementManaging
    
    // MARK: - Published State
    
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distance: Double = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var averageHeartRate: Double = 0
    @Published var currentMessage: String = ""
    @Published var isPaused = false
    @Published var isEnding = false
    @Published var showingSummary = false
    @Published var errorMessage: String?
    
    // MARK: - Display Mode Management
    
    private var displayMode: WatchConfiguration.DisplayMode = .active
    private var updateTimer: Timer?
    private var metricsUpdateTimer: Timer?
    private var messageRotationTimer: Timer?
    
    // MARK: - Private State
    
    private var cancellables = Set<AnyCancellable>()
    private var lastMilestoneTime: TimeInterval = 0
    
    // MARK: - Computed Properties
    
    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedHeartRate: String {
        heartRate > 0 ? "\(Int(heartRate))" : "--"
    }
    
    var formattedCalories: String {
        "\(Int(activeEnergy))"
    }
    
    var formattedDistance: String {
        if distance > 0 {
            let miles = distance / 1609.34
            return String(format: "%.2f mi", miles)
        }
        return "0.00 mi"
    }
    
    var isGroupWorkout: Bool {
        groupWorkoutCoordinator.currentGroupWorkout != nil
    }
    
    var groupWorkoutName: String? {
        groupWorkoutCoordinator.currentGroupWorkout?.name
    }
    
    var participantCount: Int {
        groupWorkoutCoordinator.participantCount
    }
    
    // MARK: - Initialization
    
    init(
        healthKitSession: HealthKitSessionManaging,
        metricsCollector: WorkoutMetricsCollecting,
        stateManager: WorkoutStateManaging,
        groupWorkoutCoordinator: GroupWorkoutCoordinating,
        achievementManager: any AchievementManaging
    ) {
        self.healthKitSession = healthKitSession
        self.metricsCollector = metricsCollector
        self.stateManager = stateManager
        self.groupWorkoutCoordinator = groupWorkoutCoordinator
        self.achievementManager = achievementManager
        
        setupMessageProvider()
        setupSubscriptions()
    }
    
    // MARK: - Setup
    
    private func setupMessageProvider() {
        // Simple message setup for now
        currentMessage = "Let's go!"
    }
    
    private func setupSubscriptions() {
        // Subscribe to metrics updates
        metricsCollector.heartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in
                self?.heartRate = hr
            }
            .store(in: &cancellables)
        
        metricsCollector.activeEnergy
            .receive(on: DispatchQueue.main)
            .sink { [weak self] energy in
                self?.activeEnergy = energy
            }
            .store(in: &cancellables)
        
        metricsCollector.distance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dist in
                self?.distance = dist
            }
            .store(in: &cancellables)
        
        metricsCollector.elapsedTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.elapsedTime = time
                self?.checkMilestones(time)
            }
            .store(in: &cancellables)
        
        // Subscribe to session state changes
        healthKitSession.sessionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleSessionStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func startWorkout() async {
        guard let workoutType = stateManager.selectedWorkoutType else { return }
        
        do {
            // Request HealthKit authorization if needed
            try await healthKitSession.requestAuthorization()
            
            // Start the session
            let session = try await healthKitSession.startSession(for: workoutType)
            
            // Start collecting metrics
            metricsCollector.startCollecting(for: session)
            
            // Update state
            stateManager.setWorkoutActive(true)
            
            // Start update timers based on display mode
            startUpdateTimers()
            
            // Start message rotation
            startMessageRotation()
            
        } catch {
            errorMessage = "Failed to start workout: \(error.localizedDescription)"
        }
    }
    
    func pauseWorkout() async {
        do {
            try await healthKitSession.pauseSession()
            isPaused = true
            stateManager.setPaused(true)
            stopUpdateTimers()
        } catch {
            errorMessage = "Failed to pause workout: \(error.localizedDescription)"
        }
    }
    
    func resumeWorkout() async {
        do {
            try await healthKitSession.resumeSession()
            isPaused = false
            stateManager.setPaused(false)
            startUpdateTimers()
        } catch {
            errorMessage = "Failed to resume workout: \(error.localizedDescription)"
        }
    }
    
    func endWorkout() async {
        isEnding = true
        stopUpdateTimers()
        
        do {
            // End the session and get the workout
            let workout = try await healthKitSession.endSession()
            
            // Stop collecting metrics
            metricsCollector.stopCollecting()
            
            // Check for achievements
            if let workout = workout {
                await checkAchievements(for: workout)
            }
            
            // Update state
            stateManager.setWorkoutActive(false)
            stateManager.reset()
            
            // Leave group workout if applicable
            if isGroupWorkout {
                await groupWorkoutCoordinator.leaveGroupWorkout()
            }
            
            // Show summary
            showingSummary = true
            
        } catch {
            errorMessage = "Failed to end workout: \(error.localizedDescription)"
        }
        
        isEnding = false
    }
    
    func updateDisplayMode(_ mode: WatchConfiguration.DisplayMode) {
        displayMode = mode
        metricsCollector.updateFrequency(for: mode)
        restartUpdateTimers()
    }
    
    // MARK: - Private Methods
    
    private func startUpdateTimers() {
        // Elapsed time timer
        let elapsedInterval = WatchConfiguration.UpdateFrequency.elapsedTime(for: displayMode)
        if elapsedInterval > 0 {
            updateTimer = Timer.scheduledTimer(withTimeInterval: elapsedInterval, repeats: true) { _ in
                // Timer tick - elapsed time is updated via subscription
            }
        }
        
        // Metrics update timer
        let metricsInterval = WatchConfiguration.UpdateFrequency.metrics(for: displayMode)
        if metricsInterval > 0 {
            metricsUpdateTimer = Timer.scheduledTimer(withTimeInterval: metricsInterval, repeats: true) { _ in
                Task {
                    await self.syncMetricsIfNeeded()
                }
            }
        }
    }
    
    private func stopUpdateTimers() {
        updateTimer?.invalidate()
        updateTimer = nil
        metricsUpdateTimer?.invalidate()
        metricsUpdateTimer = nil
        messageRotationTimer?.invalidate()
        messageRotationTimer = nil
    }
    
    private func restartUpdateTimers() {
        stopUpdateTimers()
        if !isPaused {
            startUpdateTimers()
        }
    }
    
    private func startMessageRotation() {
        messageRotationTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                self.updateMessage()
            }
        }
    }
    
    private func updateMessage() {
        // Simple context-aware messages
        if elapsedTime < 60 {
            currentMessage = "Great start!"
        } else if isPaused {
            currentMessage = "Ready to continue?"
        } else if heartRate > 160 {
            currentMessage = "High intensity! 🔥"
        } else if activeEnergy > 100 {
            currentMessage = "\(Int(activeEnergy)) calories burned!"
        } else {
            currentMessage = "Keep going!"
        }
    }
    
    private func checkMilestones(_ time: TimeInterval) {
        // Check every 5 minutes
        let fiveMinutes: TimeInterval = 300
        if time - lastMilestoneTime >= fiveMinutes {
            lastMilestoneTime = time
            updateMessage()
        }
    }
    
    private func handleSessionStateChange(_ state: HKWorkoutSessionState) {
        switch state {
        case .running:
            isPaused = false
        case .paused:
            isPaused = true
        case .ended, .stopped:
            Task {
                await endWorkout()
            }
        default:
            break
        }
    }
    
    private func syncMetricsIfNeeded() async {
        guard isGroupWorkout else { return }
        
        // Sync metrics with group workout
        let metricsData = WorkoutMetricsData(
            heartRate: heartRate,
            activeEnergy: activeEnergy,
            distance: distance,
            elapsedTime: elapsedTime,
            timestamp: Date()
        )
        
        await groupWorkoutCoordinator.syncParticipantData(metricsData)
    }
    
    private func checkAchievements(for workout: HKWorkout) async {
        // Get active energy burned using the new API
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let activeEnergy = workout.statistics(for: activeEnergyType)?.sumQuantity()
        let calories = activeEnergy?.doubleValue(for: .kilocalorie()) ?? 0
        
        achievementManager.checkAchievements(
            for: workout,
            duration: workout.duration,
            calories: calories,
            distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
            averageHeartRate: averageHeartRate
        )
        
        // Achievements will be displayed in summary view
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Note: Can't call async methods from deinit
        // Timers will be cleaned up automatically when the object is deallocated
        cancellables.removeAll()
    }
}