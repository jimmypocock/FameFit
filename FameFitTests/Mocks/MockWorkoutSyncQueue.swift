//
//  MockWorkoutSyncQueue.swift
//  FameFitTests
//
//  Mock implementation of WorkoutSyncQueuing for testing
//

import Combine
@testable import FameFit
import Foundation
import HealthKit

/// Mock workout sync queue for testing
class MockWorkoutSyncQueue: WorkoutSyncQueuing {
    // MARK: - Published Properties

    @Published var pendingWorkouts: [PendingWorkout] = []
    @Published var isProcessing = false
    @Published var failedCount = 0

    // MARK: - Publisher Properties

    var pendingWorkoutsPublisher: AnyPublisher<[PendingWorkout], Never> {
        $pendingWorkouts.eraseToAnyPublisher()
    }

    var isProcessingPublisher: AnyPublisher<Bool, Never> {
        $isProcessing.eraseToAnyPublisher()
    }

    var failedCountPublisher: AnyPublisher<Int, Never> {
        $failedCount.eraseToAnyPublisher()
    }

    // MARK: - Test Control Properties

    var enqueueWorkoutCalled = false
    var enqueueWorkoutCallCount = 0
    var lastEnqueuedWorkout: HKWorkout?

    var processQueueCalled = false
    var processQueueCallCount = 0

    var clearQueueCalled = false
    var retryFailedCalled = false

    var shouldFailProcessing = false
    var processDelay: TimeInterval = 0

    // Control whether workout is already in queue
    var workoutInQueueResponse = false

    // MARK: - Initialization

    init() {
        // Empty initializer for test setup
    }

    // MARK: - WorkoutSyncQueuing Methods

    func enqueueWorkout(_ workout: HKWorkout) {
        enqueueWorkoutCalled = true
        enqueueWorkoutCallCount += 1
        lastEnqueuedWorkout = workout

        let pending = PendingWorkout(from: workout)
        pendingWorkouts.append(pending)
    }

    func processQueue() {
        processQueueCalled = true
        processQueueCallCount += 1

        guard !pendingWorkouts.isEmpty else { return }

        isProcessing = true

        // Simulate async processing
        DispatchQueue.main.asyncAfter(deadline: .now() + processDelay) { [weak self] in
            guard let self else { return }

            if shouldFailProcessing {
                // Simulate failures - increase retry counts
                pendingWorkouts = pendingWorkouts.map { workout in
                    var updated = workout
                    updated.retryCount += 1
                    updated.lastRetryDate = Date()
                    return updated
                }
                failedCount = pendingWorkouts.filter { $0.retryCount >= 3 }.count
            } else {
                // Simulate success - clear the queue
                pendingWorkouts.removeAll()
                failedCount = 0
            }

            isProcessing = false
        }
    }

    func clearQueue() {
        clearQueueCalled = true
        pendingWorkouts.removeAll()
        failedCount = 0
    }

    func retryFailed() {
        retryFailedCalled = true

        // Reset retry counts for failed workouts
        pendingWorkouts = pendingWorkouts.map { workout in
            if workout.retryCount >= 3 {
                var updated = workout
                updated.retryCount = 0
                updated.lastRetryDate = nil
                return updated
            }
            return workout
        }

        failedCount = 0
    }

    func isWorkoutInQueue(_: HKWorkout) -> Bool {
        workoutInQueueResponse
    }

    func pendingCount() -> Int {
        pendingWorkouts.count
    }

    // MARK: - Test Helper Methods

    func reset() {
        pendingWorkouts.removeAll()
        isProcessing = false
        failedCount = 0

        enqueueWorkoutCalled = false
        enqueueWorkoutCallCount = 0
        lastEnqueuedWorkout = nil

        processQueueCalled = false
        processQueueCallCount = 0

        clearQueueCalled = false
        retryFailedCalled = false

        shouldFailProcessing = false
        processDelay = 0
        workoutInQueueResponse = false
    }

    func simulateWorkoutInQueue(_ workout: PendingWorkout) {
        pendingWorkouts.append(workout)
    }

    func simulateProcessingState(_ processing: Bool) {
        isProcessing = processing
    }

    func simulateFailedWorkouts(count: Int) {
        failedCount = count

        // Add some failed workouts to the queue
        for index in 0 ..< count {
            var workout = PendingWorkout(from: TestWorkoutBuilder.createWorkout(
                type: .running,
                startDate: Date().addingTimeInterval(Double(-index * 3600 - 1800)),
                endDate: Date().addingTimeInterval(Double(-index * 3600)),
                calories: 200
            ))
            workout.retryCount = 3 // Max retries reached
            workout.lastRetryDate = Date()
            pendingWorkouts.append(workout)
        }
    }
}
