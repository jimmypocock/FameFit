//
//  WorkoutMetricsCollector.swift
//  FameFit Watch App
//
//  Collects workout metrics with battery-optimized update frequencies
//

import Foundation
import HealthKit
import Combine

final class WorkoutMetricsCollector: NSObject, WorkoutMetricsCollecting {
    // MARK: - Properties
    
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var startDate: Date?
    private var displayMode: WatchConfiguration.DisplayMode = .active
    
    // MARK: - Publishers
    
    private let heartRateSubject = CurrentValueSubject<Double, Never>(0)
    private let activeEnergySubject = CurrentValueSubject<Double, Never>(0)
    private let distanceSubject = CurrentValueSubject<Double, Never>(0)
    private let elapsedTimeSubject = CurrentValueSubject<TimeInterval, Never>(0)
    
    var heartRate: AnyPublisher<Double, Never> {
        heartRateSubject.eraseToAnyPublisher()
    }
    
    var activeEnergy: AnyPublisher<Double, Never> {
        activeEnergySubject.eraseToAnyPublisher()
    }
    
    var distance: AnyPublisher<Double, Never> {
        distanceSubject.eraseToAnyPublisher()
    }
    
    var elapsedTime: AnyPublisher<TimeInterval, Never> {
        elapsedTimeSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Aggregated Metrics
    
    private var heartRateSamples: [Double] = []
    var averageHeartRate: Double {
        guard !heartRateSamples.isEmpty else { return 0 }
        return heartRateSamples.reduce(0, +) / Double(heartRateSamples.count)
    }
    
    var totalActiveEnergy: Double {
        activeEnergySubject.value
    }
    
    var totalDistance: Double {
        distanceSubject.value
    }
    
    // MARK: - Timers
    
    private var elapsedTimeTimer: Timer?
    private var metricsUpdateTimer: Timer?
    
    // MARK: - WorkoutMetricsCollecting Protocol
    
    func startCollecting(for session: HKWorkoutSession) {
        self.session = session
        self.builder = session.associatedWorkoutBuilder()
        self.startDate = Date()
        
        // Set delegate to receive updates
        builder?.delegate = self
        
        // Start timers based on display mode
        startTimers()
        
        FameFitLogger.debug("📊 Started collecting metrics", category: FameFitLogger.workout)
    }
    
    func stopCollecting() {
        stopTimers()
        
        // Reset values
        heartRateSubject.send(0)
        activeEnergySubject.send(0)
        distanceSubject.send(0)
        elapsedTimeSubject.send(0)
        heartRateSamples.removeAll()
        
        session = nil
        builder = nil
        startDate = nil
        
        FameFitLogger.debug("📊 Stopped collecting metrics", category: FameFitLogger.workout)
    }
    
    func updateFrequency(for mode: WatchConfiguration.DisplayMode) {
        guard displayMode != mode else { return }
        
        displayMode = mode
        
        // Restart timers with new frequency
        stopTimers()
        if session != nil {
            startTimers()
        }
        
        FameFitLogger.debug("📊 Updated metrics frequency for mode: \(mode)", category: FameFitLogger.workout)
    }
    
    // MARK: - Private Methods
    
    private func startTimers() {
        // Elapsed time timer
        let elapsedInterval = WatchConfiguration.UpdateFrequency.elapsedTime(for: displayMode)
        if elapsedInterval > 0 {
            elapsedTimeTimer = Timer.scheduledTimer(
                withTimeInterval: elapsedInterval,
                repeats: true
            ) { [weak self] _ in
                self?.updateElapsedTime()
            }
        }
        
        // Metrics update timer
        let metricsInterval = WatchConfiguration.UpdateFrequency.metrics(for: displayMode)
        if metricsInterval > 0 {
            metricsUpdateTimer = Timer.scheduledTimer(
                withTimeInterval: metricsInterval,
                repeats: true
            ) { [weak self] _ in
                self?.updateMetrics()
            }
        }
    }
    
    private func stopTimers() {
        elapsedTimeTimer?.invalidate()
        elapsedTimeTimer = nil
        metricsUpdateTimer?.invalidate()
        metricsUpdateTimer = nil
    }
    
    private func updateElapsedTime() {
        guard let startDate = startDate else { return }
        let elapsed = Date().timeIntervalSince(startDate)
        elapsedTimeSubject.send(elapsed)
    }
    
    private func updateMetrics() {
        guard let builder = builder else { return }
        
        // Update from builder's statistics
        updateHeartRate(from: builder)
        updateActiveEnergy(from: builder)
        updateDistance(from: builder)
    }
    
    private func updateHeartRate(from builder: HKLiveWorkoutBuilder) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let statistics = builder.statistics(for: heartRateType)
        let heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
        
        // Only update if value is valid
        if heartRate >= WatchConfiguration.HealthKit.minValidHeartRate &&
           heartRate <= WatchConfiguration.HealthKit.maxValidHeartRate {
            heartRateSubject.send(heartRate)
            heartRateSamples.append(heartRate)
            
            // Limit sample storage for memory efficiency
            if heartRateSamples.count > 1000 {
                heartRateSamples.removeFirst(100)
            }
        }
    }
    
    private func updateActiveEnergy(from builder: HKLiveWorkoutBuilder) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let statistics = builder.statistics(for: energyType)
        let energy = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        
        activeEnergySubject.send(energy)
    }
    
    private func updateDistance(from builder: HKLiveWorkoutBuilder) {
        // Get appropriate distance type based on workout
        let distanceType = getDistanceType()
        guard let type = distanceType else { return }
        
        let statistics = builder.statistics(for: type)
        let distance = statistics?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
        
        distanceSubject.send(distance)
    }
    
    private func getDistanceType() -> HKQuantityType? {
        guard let workoutType = session?.workoutConfiguration.activityType else { return nil }
        
        switch workoutType {
        case .cycling, .handCycling:
            return HKQuantityType.quantityType(forIdentifier: .distanceCycling)
        case .swimming:
            return HKQuantityType.quantityType(forIdentifier: .distanceSwimming)
        default:
            return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutMetricsCollector: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                       didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Update metrics when new data is collected
        // This is more battery-efficient than polling
        DispatchQueue.main.async { [weak self] in
            for type in collectedTypes {
                if type.identifier == HKQuantityTypeIdentifier.heartRate.rawValue {
                    self?.updateHeartRate(from: workoutBuilder)
                } else if type.identifier == HKQuantityTypeIdentifier.activeEnergyBurned.rawValue {
                    self?.updateActiveEnergy(from: workoutBuilder)
                } else if type.identifier == HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue ||
                          type.identifier == HKQuantityTypeIdentifier.distanceCycling.rawValue ||
                          type.identifier == HKQuantityTypeIdentifier.distanceSwimming.rawValue {
                    self?.updateDistance(from: workoutBuilder)
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}

// MARK: - Mock Implementation for Previews

final class MockMetricsCollector: WorkoutMetricsCollecting {
    let heartRate = Just(120.0).eraseToAnyPublisher()
    let activeEnergy = Just(250.0).eraseToAnyPublisher()
    let distance = Just(2500.0).eraseToAnyPublisher()
    let elapsedTime = Just(TimeInterval(1800)).eraseToAnyPublisher()
    
    var averageHeartRate: Double = 118
    var totalActiveEnergy: Double = 250
    var totalDistance: Double = 2500
    
    func startCollecting(for session: HKWorkoutSession) {}
    func stopCollecting() {}
    func updateFrequency(for mode: WatchConfiguration.DisplayMode) {}
}