//
//  AnyWorkoutManager.swift
//  FameFit Watch App
//
//  Type-erased wrapper for WorkoutManaging protocol
//  This allows us to use the protocol with @StateObject and @EnvironmentObject
//

import Foundation
import HealthKit
import Combine

/// Type-erased wrapper for WorkoutManaging protocol
/// This enables using protocol types with SwiftUI property wrappers
final class AnyWorkoutManager: WorkoutManaging {
    private let wrapped: any WorkoutManaging
    
    // MARK: - Published Properties Relay
    
    @Published var selectedWorkout: HKWorkoutActivityType?
    @Published var showingSummaryView: Bool = false
    
    // Relay all other properties from the wrapped instance
    var isWorkoutRunning: Bool { wrapped.isWorkoutRunning }
    var isPaused: Bool { wrapped.isPaused }
    var displayElapsedTime: TimeInterval { wrapped.displayElapsedTime }
    var averageHeartRate: Double { wrapped.averageHeartRate }
    var heartRate: Double { wrapped.heartRate }
    var activeEnergy: Double { wrapped.activeEnergy }
    var distance: Double { wrapped.distance }
    var workout: HKWorkout? { wrapped.workout }
    var averageHeartRateForSummary: Double { wrapped.averageHeartRateForSummary }
    var totalCaloriesForSummary: Double { wrapped.totalCaloriesForSummary }
    var totalDistanceForSummary: Double { wrapped.totalDistanceForSummary }
    var elapsedTimeForSummary: TimeInterval { wrapped.elapsedTimeForSummary }
    
    private var cancellables = Set<AnyCancellable>()
    
    init<T: WorkoutManaging>(_ workoutManager: T) {
        self.wrapped = workoutManager
        
        // Set up two-way binding for published properties
        workoutManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Sync selectedWorkout
        if let published = workoutManager as? WorkoutManager {
            published.$selectedWorkout
                .assign(to: &$selectedWorkout)
            
            $selectedWorkout
                .sink { [weak published] value in
                    published?.selectedWorkout = value
                }
                .store(in: &cancellables)
            
            // Sync showingSummaryView
            published.$showingSummaryView
                .assign(to: &$showingSummaryView)
            
            $showingSummaryView
                .sink { [weak published] value in
                    published?.showingSummaryView = value
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Method Forwarding
    
    func startWorkout(workoutType: HKWorkoutActivityType) {
        wrapped.startWorkout(workoutType: workoutType)
    }
    
    func pause() {
        wrapped.pause()
    }
    
    func resume() {
        wrapped.resume()
    }
    
    func togglePause() {
        wrapped.togglePause()
    }
    
    func endWorkout() {
        wrapped.endWorkout()
    }
    
    func resetWorkout() {
        wrapped.resetWorkout()
    }
    
    func requestAuthorization() {
        wrapped.requestAuthorization()
    }
}