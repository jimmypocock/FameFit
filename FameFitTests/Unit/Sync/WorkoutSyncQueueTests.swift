//
//  WorkoutSyncQueueTests.swift
//  FameFitTests
//
//  Tests for WorkoutSyncQueue with protocol-based CloudKit abstraction
//

import XCTest
import HealthKit
import Combine
@testable import FameFit

class WorkoutSyncQueueTests: XCTestCase {
    private var syncQueue: WorkoutSyncQueue!
    private var mockCloudKitManager: MockCloudKitManager!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Clear persistent storage to ensure test isolation
        UserDefaults.standard.removeObject(forKey: "FameFitWorkoutSyncQueue")
        
        mockCloudKitManager = MockCloudKitManager()
        syncQueue = WorkoutSyncQueue(cloudKitManager: mockCloudKitManager)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        // Clear persistent storage to prevent state bleeding
        UserDefaults.standard.removeObject(forKey: "FameFitWorkoutSyncQueue")
        
        syncQueue = nil
        mockCloudKitManager = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func wait(for duration: TimeInterval) {
        Thread.sleep(forTimeInterval: duration)
    }
    
    // MARK: - Initialization Tests
    
    func testInitializationLoadsEmptyQueue() {
        // Then
        XCTAssertTrue(syncQueue.pendingWorkouts.isEmpty)
        XCTAssertFalse(syncQueue.isProcessing)
        XCTAssertEqual(syncQueue.failedCount, 0)
    }
    
    // MARK: - Enqueue Tests
    
    func testEnqueueWorkoutAddsToPendingList() {
        // Given
        let workout = TestWorkoutBuilder.createRunWorkout(
            duration: 1_800,
            calories: 250
        )
        
        // When
        syncQueue.enqueueWorkout(workout)
        
        // Wait for async operation to complete
        let expectation = XCTestExpectation(description: "Enqueue completes")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(syncQueue.pendingWorkouts.count, 1)
        XCTAssertEqual(syncQueue.pendingWorkouts.first?.workoutType, "Running")
        XCTAssertEqual(syncQueue.pendingWorkouts.first?.duration, 1800)
        XCTAssertEqual(syncQueue.pendingWorkouts.first?.calories, 250)
    }
    
    func testEnqueueMultipleWorkouts() {
        // Given
        let workout1 = TestWorkoutBuilder.createRunWorkout()
        let workout2 = TestWorkoutBuilder.createCycleWorkout()
        let workout3 = TestWorkoutBuilder.createWalkWorkout()
        
        // When
        syncQueue.enqueueWorkout(workout1)
        syncQueue.enqueueWorkout(workout2)
        syncQueue.enqueueWorkout(workout3)
        
        // Wait for async operations to complete
        let expectation = XCTestExpectation(description: "All enqueues complete")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(syncQueue.pendingWorkouts.count, 3)
        XCTAssertEqual(syncQueue.pendingCount(), 3)
    }
    
    // MARK: - Processing Tests
    
    func testProcessQueueWhenCloudKitAvailable() {
        // Given
        mockCloudKitManager.mockIsAvailable = true
        
        // Track all state changes
        var stateChanges: [Bool] = []
        var workoutCounts: [Int] = []
        
        syncQueue.$isProcessing
            .sink { isProcessing in
                stateChanges.append(isProcessing)
            }
            .store(in: &cancellables)
        
        syncQueue.$pendingWorkouts
            .sink { workouts in
                workoutCounts.append(workouts.count)
            }
            .store(in: &cancellables)
        
        // When - enqueue a workout
        let workout = TestWorkoutBuilder.createRunWorkout()
        syncQueue.enqueueWorkout(workout)
        
        // Wait for enqueue to complete on main queue
        let enqueueWait = expectation(description: "Enqueue completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            enqueueWait.fulfill()
        }
        wait(for: [enqueueWait], timeout: 1.0)
        
        // Wait for the background operation queue to finish all operations
        syncQueue.operationQueue.waitUntilAllOperationsAreFinished()
        
        // Give time for final main queue updates from background thread
        let finalWait = expectation(description: "Final wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            finalWait.fulfill()
        }
        wait(for: [finalWait], timeout: 2.0)
        
        // Verify final state
        XCTAssertFalse(syncQueue.isProcessing, "Should not be processing")
        XCTAssertEqual(syncQueue.pendingWorkouts.count, 0, "Queue should be empty after successful processing")
        
        // Verify we saw the expected state transitions
        XCTAssertTrue(workoutCounts.contains(1), "Should have seen 1 workout added")
        XCTAssertTrue(workoutCounts.contains(0), "Should have seen queue cleared")
        XCTAssertTrue(stateChanges.contains(true), "Should have seen processing = true")
        XCTAssertTrue(stateChanges.contains(where: { $0 == false }), "Should have seen processing = false")
    }
    
    func testProcessQueueWhenCloudKitNotAvailable() {
        // Given
        mockCloudKitManager.mockIsAvailable = false
        let workout = TestWorkoutBuilder.createRunWorkout()
        
        // Wait for enqueue to complete
        let enqueueExpectation = XCTestExpectation(description: "Enqueue completes")
        syncQueue.enqueueWorkout(workout)
        DispatchQueue.main.async {
            enqueueExpectation.fulfill()
        }
        wait(for: [enqueueExpectation], timeout: 1.0)
        
        XCTAssertEqual(syncQueue.pendingWorkouts.count, 1)
        
        // When
        syncQueue.processQueue()
        
        // Then
        XCTAssertFalse(syncQueue.isProcessing)
        XCTAssertEqual(syncQueue.pendingWorkouts.count, 1) // Workout still pending
    }
    
    func testProcessQueueDoesNotRunConcurrently() {
        // Given
        mockCloudKitManager.mockIsAvailable = true
        
        // Manually set processing state to true to simulate ongoing processing
        syncQueue.isProcessing = true
        
        // Add a workout to the queue
        let workout = TestWorkoutBuilder.createRunWorkout()
        syncQueue.pendingWorkouts.append(PendingWorkout(from: workout))
        
        // When - Try to start processing while already processing
        syncQueue.processQueue()
        
        // Then - Should still be processing (not reset or changed)
        XCTAssertTrue(syncQueue.isProcessing, "Should still be processing")
        XCTAssertEqual(syncQueue.pendingWorkouts.count, 1, "Should still have the workout")
        
        // Reset for cleanup
        syncQueue.isProcessing = false
        syncQueue.clearQueue()
    }
    
    // MARK: - Clear Queue Tests
    
    func testClearQueueRemovesAllPendingWorkouts() {
        // Given
        syncQueue.enqueueWorkout(TestWorkoutBuilder.createRunWorkout())
        syncQueue.enqueueWorkout(TestWorkoutBuilder.createCycleWorkout())
        
        // Wait for enqueues to complete
        let enqueueExpectation = XCTestExpectation(description: "Enqueues complete")
        DispatchQueue.main.async {
            enqueueExpectation.fulfill()
        }
        wait(for: [enqueueExpectation], timeout: 1.0)
        
        XCTAssertEqual(syncQueue.pendingWorkouts.count, 2)
        
        // When
        syncQueue.clearQueue()
        
        // Then
        XCTAssertTrue(syncQueue.pendingWorkouts.isEmpty)
        XCTAssertEqual(syncQueue.failedCount, 0)
    }
    
    // MARK: - Retry Failed Tests
    
    func testRetryFailedResetsRetryCountsAndProcesses() {
        // Given - Create failed workouts
        var failedWorkout1 = PendingWorkout(
            from: TestWorkoutBuilder.createRunWorkout()
        )
        failedWorkout1.retryCount = 3
        failedWorkout1.lastRetryDate = Date()
        
        var failedWorkout2 = PendingWorkout(
            from: TestWorkoutBuilder.createCycleWorkout()
        )
        failedWorkout2.retryCount = 3
        failedWorkout2.lastRetryDate = Date()
        
        // Add directly to pending workouts
        syncQueue.pendingWorkouts = [failedWorkout1, failedWorkout2]
        syncQueue.failedCount = 2
        
        // When
        syncQueue.retryFailed()
        
        // Then
        XCTAssertEqual(syncQueue.pendingWorkouts.count, 2)
        XCTAssertTrue(syncQueue.pendingWorkouts.allSatisfy { $0.retryCount == 0 })
        XCTAssertTrue(syncQueue.pendingWorkouts.allSatisfy { $0.lastRetryDate == nil })
    }
    
    // MARK: - Workout Check Tests
    
    func testIsWorkoutInQueueReturnsTrueForExistingWorkout() {
        // Given
        let workout = TestWorkoutBuilder.createRunWorkout(
            startDate: Date().addingTimeInterval(-1_800)
        )
        syncQueue.enqueueWorkout(workout)
        
        // Wait for enqueue to complete
        let expectation = XCTestExpectation(description: "Enqueue completes")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // When
        let isInQueue = syncQueue.isWorkoutInQueue(workout)
        
        // Then
        XCTAssertTrue(isInQueue)
    }
    
    func testIsWorkoutInQueueReturnsFalseForNonExistingWorkout() {
        // Given
        let workout1 = TestWorkoutBuilder.createRunWorkout()
        let workout2 = TestWorkoutBuilder.createCycleWorkout()
        syncQueue.enqueueWorkout(workout1)
        
        // When
        let isInQueue = syncQueue.isWorkoutInQueue(workout2)
        
        // Then
        XCTAssertFalse(isInQueue)
    }
    
    // MARK: - Publisher Tests
    
    func testPendingWorkoutsPublisherEmitsUpdates() {
        // Given
        // Ensure clean state
        syncQueue.clearQueue()
        
        let expectation = XCTestExpectation(description: "Publisher emits")
        var receivedCounts: [Int] = []
        
        syncQueue.pendingWorkoutsPublisher
            .map { $0.count }
            .sink { count in
                receivedCounts.append(count)
                if receivedCounts.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        syncQueue.enqueueWorkout(TestWorkoutBuilder.createRunWorkout())
        syncQueue.enqueueWorkout(TestWorkoutBuilder.createCycleWorkout())
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedCounts, [0, 1, 2])
    }
    
    func testIsProcessingPublisherEmitsStateChanges() {
        // Given
        mockCloudKitManager.mockIsAvailable = true
        
        var states: [Bool] = []
        
        syncQueue.isProcessingPublisher
            .sink { isProcessing in
                states.append(isProcessing)
            }
            .store(in: &cancellables)
        
        // When
        let workout = TestWorkoutBuilder.createRunWorkout()
        syncQueue.enqueueWorkout(workout)
        
        // Wait for enqueue to complete
        let enqueueWait = expectation(description: "Enqueue wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            enqueueWait.fulfill()
        }
        wait(for: [enqueueWait], timeout: 1.0)
        
        // Wait for background processing to complete
        syncQueue.operationQueue.waitUntilAllOperationsAreFinished()
        
        // Give time for final state updates
        let finalWait = expectation(description: "Final wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            finalWait.fulfill()
        }
        wait(for: [finalWait], timeout: 1.0)
        
        // Should have seen state transitions
        XCTAssertTrue(states.contains(false), "Should have false state")
        XCTAssertTrue(states.contains(true), "Should have true state")
        
        // Find the last state after we saw true
        if let firstTrueIndex = states.firstIndex(of: true) {
            let statesAfterTrue = Array(states.suffix(from: firstTrueIndex))
            XCTAssertTrue(statesAfterTrue.contains(false), "Should have false after true")
        }
    }
    
    func testFailedCountPublisherEmitsUpdates() {
        // Given
        let expectation = XCTestExpectation(description: "Failed count updates")
        var counts: [Int] = []
        
        syncQueue.failedCountPublisher
            .sink { count in
                counts.append(count)
                if counts.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When - Simulate failed workouts
        var failedWorkout = PendingWorkout(
            from: TestWorkoutBuilder.createRunWorkout()
        )
        failedWorkout.retryCount = 3
        syncQueue.pendingWorkouts = [failedWorkout]
        syncQueue.failedCount = 1
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(counts, [0, 1])
    }
    
    // MARK: - Integration Tests
    
    func testFullWorkflowFromEnqueueToSuccess() {
        // Given
        let workout = TestWorkoutBuilder.createRunWorkout(
            duration: 3_600,
            calories: 500
        )
        
        // Ensure the mock will succeed
        mockCloudKitManager.mockIsAvailable = true
        mockCloudKitManager.shouldFailAddFollowers = false
        
        // Track state changes
        var processingStates: [Bool] = []
        
        // Monitor processing state changes
        syncQueue.isProcessingPublisher
            .sink { isProcessing in
                processingStates.append(isProcessing)
            }
            .store(in: &cancellables)
        
        // When - enqueue workout
        syncQueue.enqueueWorkout(workout)
        
        // First wait for enqueue to complete
        let enqueueWait = expectation(description: "Enqueue wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            enqueueWait.fulfill()
        }
        wait(for: [enqueueWait], timeout: 1.0)
        
        // Wait for the background operation queue to finish
        syncQueue.operationQueue.waitUntilAllOperationsAreFinished()
        
        // Give more time for main queue updates from background thread
        let finalWait = expectation(description: "Final wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            finalWait.fulfill()
        }
        wait(for: [finalWait], timeout: 3.0)
        
        // Then - Verify final state
        XCTAssertFalse(syncQueue.isProcessing, "Processing should be complete")
        XCTAssertEqual(syncQueue.pendingWorkouts.count, 0, "Queue should be empty after successful sync")
        XCTAssertTrue(processingStates.contains(true), "Should have seen processing = true")
        XCTAssertEqual(processingStates.last, false, "Should end with processing = false")
    }
}
