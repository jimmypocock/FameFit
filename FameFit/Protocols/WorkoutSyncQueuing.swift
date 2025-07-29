//
//  WorkoutSyncQueuing.swift
//  FameFit
//
//  Protocol for workout sync queue management
//

import Combine
import Foundation
import HealthKit

/// Protocol for managing workout synchronization queue
protocol WorkoutSyncQueuing: ObservableObject {
    // MARK: - Properties

    /// Array of workouts pending synchronization
    var pendingWorkouts: [PendingWorkout] { get }

    /// Publisher for pending workouts updates
    var pendingWorkoutsPublisher: AnyPublisher<[PendingWorkout], Never> { get }

    /// Indicates if the queue is currently processing
    var isProcessing: Bool { get }

    /// Publisher for processing state updates
    var isProcessingPublisher: AnyPublisher<Bool, Never> { get }

    /// Number of workouts that have failed all retry attempts
    var failedCount: Int { get }

    /// Publisher for failed count updates
    var failedCountPublisher: AnyPublisher<Int, Never> { get }

    // MARK: - Methods

    /// Adds a workout to the sync queue
    /// - Parameter workout: The HKWorkout to sync
    func enqueueWorkout(_ workout: HKWorkout)

    /// Processes all pending workouts in the queue
    func processQueue()

    /// Clears all pending workouts from the queue
    func clearQueue()

    /// Resets retry counts for failed workouts and reprocesses them
    func retryFailed()

    /// Checks if a specific workout is already in the queue
    /// - Parameter workout: The workout to check
    /// - Returns: True if the workout is in the queue
    func isWorkoutInQueue(_ workout: HKWorkout) -> Bool

    /// Gets the count of workouts pending sync
    /// - Returns: Number of pending workouts
    func pendingCount() -> Int
}

// MARK: - PendingWorkout Structure

/// Represents a workout pending synchronization
struct PendingWorkout: Codable, Equatable {
    let id: UUID
    let workoutType: String
    let duration: TimeInterval
    let calories: Double
    let endDate: Date
    var retryCount: Int
    var lastRetryDate: Date?

    /// Creates a pending workout from an HKWorkout
    /// - Parameter workout: The HealthKit workout to convert
    init(from workout: HKWorkout) {
        id = UUID()
        workoutType = workout.workoutActivityType.displayName
        duration = workout.duration
        // Get calories from workout statistics
        if let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let energyBurned = workout.statistics(for: energyBurnedType)?.sumQuantity() {
            calories = energyBurned.doubleValue(for: .kilocalorie())
        } else {
            calories = 0
        }
        endDate = workout.endDate
        retryCount = 0
        lastRetryDate = nil
    }
}
