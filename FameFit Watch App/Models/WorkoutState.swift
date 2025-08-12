//
//  WorkoutState.swift
//  FameFit Watch App
//
//  Single source of truth for workout state to prevent multiple updates per frame
//

import Foundation
import HealthKit

/// Aggregated workout state to batch updates and improve performance
struct WorkoutState: Equatable {
    // Session state
    var isRunning: Bool = false
    var isPaused: Bool = false
    var sessionState: HKWorkoutSessionState = .notStarted
    
    // Metrics (updated frequently)
    var elapsedTime: TimeInterval = 0
    var activeEnergy: Double = 0
    var heartRate: Double = 0
    var averageHeartRate: Double = 0
    var distance: Double = 0
    
    // Workout info
    var workoutType: HKWorkoutActivityType?
    var workout: HKWorkout?
    var completedWorkout: HKWorkout?
    
    // Group workout info
    var isGroupWorkout: Bool = false
    var groupWorkoutID: String?
    var groupWorkoutName: String?
    var isGroupWorkoutHost: Bool = false
    var groupParticipantCount: Int = 0
    
    // Update tracking
    var lastMetricsUpdate: Date = Date()
    
    /// Check if only metrics changed (for optimized updates)
    func metricsOnlyChanged(from previous: WorkoutState) -> Bool {
        // Check if only the frequently-changing metrics are different
        return isRunning == previous.isRunning &&
               isPaused == previous.isPaused &&
               sessionState == previous.sessionState &&
               workoutType == previous.workoutType &&
               workout == previous.workout &&
               completedWorkout == previous.completedWorkout &&
               isGroupWorkout == previous.isGroupWorkout &&
               groupWorkoutID == previous.groupWorkoutID &&
               // Only these change frequently
               (elapsedTime != previous.elapsedTime ||
                activeEnergy != previous.activeEnergy ||
                heartRate != previous.heartRate ||
                averageHeartRate != previous.averageHeartRate ||
                distance != previous.distance)
    }
}

/// Separate struct for high-frequency display updates
/// This is NOT @Published, views that need it can observe it directly
struct WorkoutDisplayMetrics {
    var displayElapsedTime: TimeInterval = 0
    var formattedTime: String = "00:00"
    var heartRateDisplay: String = "--"
    var caloriesDisplay: String = "0"
    var distanceDisplay: String = "0.0"
}