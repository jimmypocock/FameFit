//
//  WorkoutManaging.swift
//  FameFit Watch App
//
//  Protocol abstraction for workout management functionality
//

import Foundation
import HealthKit

/// Protocol defining the contract for workout management in the Watch app
/// This abstraction enables better testability and reduces coupling to HealthKit
protocol WorkoutManaging: ObservableObject {
    // MARK: - Workout State
    
    /// The currently selected workout type, setting this starts a workout
    var selectedWorkout: HKWorkoutActivityType? { get set }
    
    /// Controls the presentation of the summary view
    var showingSummaryView: Bool { get set }
    
    /// Indicates if a workout session is currently active
    var isWorkoutRunning: Bool { get }
    
    /// Indicates if the current workout is paused
    var isPaused: Bool { get }
    
    // MARK: - Workout Metrics
    
    /// The elapsed time for the current workout in seconds
    var displayElapsedTime: TimeInterval { get }
    
    /// The average heart rate for the current workout
    var averageHeartRate: Double { get }
    
    /// The current heart rate reading
    var heartRate: Double { get }
    
    /// The total active energy burned in kilocalories
    var activeEnergy: Double { get }
    
    /// The total distance covered in meters
    var distance: Double { get }
    
    // MARK: - Workout Summary Data
    
    /// The completed workout object, available after ending a workout
    var workout: HKWorkout? { get }
    
    /// Average heart rate for the completed workout
    var averageHeartRateForSummary: Double { get }
    
    /// Total calories burned for the completed workout
    var totalCaloriesForSummary: Double { get }
    
    /// Total distance for the completed workout
    var totalDistanceForSummary: Double { get }
    
    /// Elapsed time for the completed workout
    var elapsedTimeForSummary: TimeInterval { get }
    
    // MARK: - Workout Control Methods
    
    /// Start a new workout with the specified type
    /// - Parameter workoutType: The type of workout to start
    func startWorkout(workoutType: HKWorkoutActivityType)
    
    /// Pause the current workout
    func pause()
    
    /// Resume a paused workout
    func resume()
    
    /// Toggle between pause and resume states
    func togglePause()
    
    /// End the current workout and prepare summary data
    func endWorkout()
    
    /// Reset the workout manager state
    func resetWorkout()
    
    /// Request HealthKit authorization for required data types
    func requestAuthorization()
}
