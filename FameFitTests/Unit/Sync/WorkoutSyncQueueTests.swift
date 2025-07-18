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
        
        // Create expectation for processing to complete
        let processingComplete = XCTestExpectation(description: "Processing completes")
        
        // Wait for queue to become empty after having workouts
        var hasHadWorkouts = false
        syncQueue.$pendingWorkouts
            .sink { workouts in
                print("Test - Workouts changed: \(workouts.count)")
                if !workouts.isEmpty {
                    hasHadWorkouts = true
                    print("Test - Had workouts set to true")
                }
                if workouts.isEmpty && hasHadWorkouts {
                    print("Test - Processing complete, fulfilling expectation")
                    processingComplete.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When - enqueue a workout (triggers processing automatically)
        let workout = TestWorkoutBuilder.createRunWorkout()
        print("Test - Enqueuing workout")
        syncQueue.enqueueWorkout(workout)
        
        // Wait for processing to complete
        let result = XCTWaiter.wait(for: [processingComplete], timeout: 10.0)
        print("Test - Wait result: \(result)")
        
        // Then - verify final state
        print("Test - Final state: workouts=\(syncQueue.pendingWorkouts.count), processing=\(syncQueue.isProcessing)")
        XCTAssertEqual(syncQueue.pendingWorkouts.count, 0, "Queue should be empty")
        XCTAssertFalse(syncQueue.isProcessing, "Should not be processing")
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
        
        let expectation = XCTestExpectation(description: "Processing state changes")
        var states: [Bool] = []
        
        syncQueue.isProcessingPublisher
            .sink { isProcessing in
                states.append(isProcessing)
                // Complete when we see processing finish (false after true)
                if states.count >= 2 && states.contains(true) && !isProcessing {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        let workout = TestWorkoutBuilder.createRunWorkout()
        syncQueue.enqueueWorkout(workout)
        
        // Then
        wait(for: [expectation], timeout: 10.0)
        
        // Should have seen state transitions
        XCTAssertTrue(states.contains(false), "Should have false state")
        XCTAssertTrue(states.contains(true), "Should have true state")
        XCTAssertEqual(states.last, false, "Should end in false (not processing)")
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
        
        // Set up expectation for completion
        let processExpectation = XCTestExpectation(description: "Processing completes")
        
        // Wait for queue to empty after having workouts
        var hasHadWorkouts = false
        syncQueue.$pendingWorkouts
            .sink { workouts in
                if !workouts.isEmpty {
                    hasHadWorkouts = true
                }
                if workouts.isEmpty && hasHadWorkouts {
                    processExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When - enqueue workout (automatically triggers processing)
        syncQueue.enqueueWorkout(workout)
        
        // Then
        wait(for: [processExpectation], timeout: 10.0)
        XCTAssertTrue(syncQueue.pendingWorkouts.isEmpty, "Workouts should be processed")
        XCTAssertEqual(syncQueue.failedCount, 0)
        XCTAssertFalse(syncQueue.isProcessing, "Processing should be complete")
    }
}
