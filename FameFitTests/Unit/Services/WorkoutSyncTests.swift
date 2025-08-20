//
//  WorkoutSyncTests.swift
//  FameFitTests
//
//  Critical tests for HealthKit to CloudKit workout synchronization
//  These tests ensure data integrity and prevent duplicate syncing
//

import XCTest
import HealthKit
import CloudKit
@testable import FameFit

final class WorkoutSyncTests: XCTestCase {
    
    // MARK: - Properties
    
    private var healthKitService: MockHealthKitService!
    private var cloudKitService: MockCloudKitService!
    private var workoutProcessor: WorkoutProcessor!
    private var workoutSyncService: WorkoutSyncService!
    private var userProfileService: MockUserProfileService!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        
        healthKitService = MockHealthKitService()
        cloudKitService = MockCloudKitService()
        userProfileService = MockUserProfileService()
        
        // Set up user profile
        let testProfile = UserProfile(
            id: "test-user",
            userID: "test-user",
            username: "testuser",
            bio: "Test user",
            workoutCount: 0,
            totalXP: 0,
            creationDate: Date(),
            modificationDate: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )
        userProfileService.setCurrentProfile(testProfile)
        cloudKitService.currentUserID = "test-user"
        
        // Create processor and sync service
        workoutProcessor = WorkoutProcessor(
            cloudKitManager: cloudKitService,
            xpTransactionService: XPTransactionService(cloudKitManager: cloudKitService),
            activityFeedService: MockActivityFeedService(),
            notificationManager: nil,
            userProfileService: userProfileService,
            workoutChallengesService: WorkoutChallengesService(cloudKitManager: cloudKitService),
            workoutChallengeLinksService: WorkoutChallengeLinksService(cloudKitManager: cloudKitService),
            activitySettingsService: ActivityFeedSettingsService(cloudKitManager: cloudKitService)
        )
        
        workoutSyncService = WorkoutSyncService(
            cloudKitManager: cloudKitService,
            healthKitService: healthKitService
        )
        workoutSyncService.workoutProcessor = workoutProcessor
        
        // Clear any previous state
        UserDefaults.standard.removeObject(forKey: "SyncedWorkoutIDs")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "SyncedWorkoutIDs")
        super.tearDown()
    }
    
    // MARK: - Critical Tests
    
    /// Test 1: Workout ID must be preserved from HKWorkout.uuid
    func testWorkoutIDPreservation() {
        // Given: An HKWorkout with a specific UUID
        let hkWorkout = TestWorkoutBuilder.createWorkout(
            type: .running,
            duration: 1800,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 250),
            totalDistance: HKQuantity(unit: .meter(), doubleValue: 5000)
        )
        let expectedID = hkWorkout.uuid.uuidString
        
        // When: Converting to Workout model
        let workout = Workout(from: hkWorkout, followersEarned: 10)
        
        // Then: The ID must match the HKWorkout UUID
        XCTAssertEqual(workout.id, expectedID, 
                      "Workout ID must be the HKWorkout UUID to prevent duplicates")
    }
    
    /// Test 2: Same HKWorkout must not create duplicate CloudKit records
    func testPreventDuplicateCloudKitRecords() async throws {
        // Given: A single HKWorkout
        let hkWorkout = TestWorkoutBuilder.createWorkout(
            type: .cycling,
            duration: 3600,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 400)
        )
        
        // When: Processing the same workout multiple times
        try await workoutProcessor.processHealthKitWorkout(hkWorkout)
        try await workoutProcessor.processHealthKitWorkout(hkWorkout)
        try await workoutProcessor.processHealthKitWorkout(hkWorkout)
        
        // Then: Only one workout should be saved to CloudKit
        let savedWorkouts = cloudKitService.workoutHistory
        XCTAssertEqual(savedWorkouts.count, 1, 
                      "Same HKWorkout should only create one CloudKit record")
        
        // And: The saved workout should have the correct ID
        XCTAssertEqual(savedWorkouts.first?.id, hkWorkout.uuid.uuidString,
                      "CloudKit record must use HKWorkout UUID as ID")
    }
    
    /// Test 3: Idempotent sync - processing same workout is safe
    func testIdempotentWorkoutSync() async throws {
        // Given: Multiple HKWorkouts including duplicates
        let workout1 = TestWorkoutBuilder.createWorkout(type: .running)
        let workout2 = TestWorkoutBuilder.createWorkout(type: .cycling)
        let workout3 = workout1 // Same as workout1
        
        // When: Syncing all workouts
        healthKitService.mockWorkouts = [workout1, workout2, workout3]
        await workoutSyncService.performManualSync()
        
        // Then: Only unique workouts should be saved
        let savedWorkouts = cloudKitService.workoutHistory
        XCTAssertEqual(savedWorkouts.count, 2, 
                      "Only unique workouts should be saved")
        
        // And: IDs should match HKWorkout UUIDs
        let savedIDs = Set(savedWorkouts.map { $0.id })
        let expectedIDs = Set([workout1.uuid.uuidString, workout2.uuid.uuidString])
        XCTAssertEqual(savedIDs, expectedIDs,
                      "Saved workout IDs must match HKWorkout UUIDs")
    }
    
    /// Test 4: CloudKit record must contain correct workout ID
    func testCloudKitRecordIDConsistency() {
        // Given: A workout from HKWorkout
        let hkWorkout = TestWorkoutBuilder.createWorkout(type: .swimming)
        let workout = Workout(from: hkWorkout, followersEarned: 15)
        
        // When: Creating CloudKit record
        let record = workout.toCKRecord(userID: "test-user")
        
        // Then: Record must contain the correct ID
        XCTAssertEqual(record["id"] as? String, hkWorkout.uuid.uuidString,
                      "CloudKit record 'id' field must be HKWorkout UUID")
    }
    
    /// Test 5: Query by workout ID must work correctly
    func testQueryWorkoutByID() async throws {
        // Given: A saved workout
        let hkWorkout = TestWorkoutBuilder.createWorkout(type: .yoga)
        try await workoutProcessor.processHealthKitWorkout(hkWorkout)
        
        // When: Querying by workout ID
        let workoutID = hkWorkout.uuid.uuidString
        let predicate = NSPredicate(format: "id == %@", workoutID)
        let results = try await cloudKitService.database.fetch(
            withQuery: CKQuery(recordType: "Workouts", predicate: predicate)
        )
        
        // Then: Should find exactly one workout
        XCTAssertEqual(results.matchResults.count, 1,
                      "Should find workout by HKWorkout UUID")
        
        // And: The found workout should have correct ID
        if let record = results.matchResults.first?.1.get(Result<CKRecord, Error>.self) {
            XCTAssertEqual(record["id"] as? String, workoutID,
                          "Found workout must have correct ID")
        }
    }
    
    /// Test 6: Sync state tracking must use correct IDs
    func testSyncStateTracking() async throws {
        // Given: A workout to sync
        let hkWorkout = TestWorkoutBuilder.createWorkout(type: .traditionalStrengthTraining)
        
        // When: Processing the workout
        healthKitService.mockWorkouts = [hkWorkout]
        await workoutSyncService.performManualSync()
        
        // Then: Sync tracking should use HKWorkout UUID
        let syncedIDs = UserDefaults.standard.array(forKey: "SyncedWorkoutIDs") as? [String] ?? []
        XCTAssertTrue(syncedIDs.contains(hkWorkout.uuid.uuidString),
                     "Sync tracking must use HKWorkout UUID")
        
        // And: Processing again should skip it
        cloudKitService.workoutHistory.removeAll()
        await workoutSyncService.performManualSync()
        XCTAssertEqual(cloudKitService.workoutHistory.count, 0,
                      "Already synced workout should be skipped")
    }
    
    /// Test 7: Edge case - nil metadata doesn't break ID generation
    func testNilMetadataHandling() {
        // Given: HKWorkout without metadata
        let hkWorkout = TestWorkoutBuilder.createWorkout(type: .walking)
        
        // When: Converting to Workout
        let workout = Workout(from: hkWorkout, followersEarned: 5)
        
        // Then: ID should still be HKWorkout UUID
        XCTAssertEqual(workout.id, hkWorkout.uuid.uuidString,
                      "ID must be HKWorkout UUID even without metadata")
    }
    
    /// Test 8: Group workout ID preservation
    func testGroupWorkoutIDPreservation() async throws {
        // Given: HKWorkout with group workout metadata
        let groupWorkoutID = UUID().uuidString
        var metadata: [String: Any] = [:]
        metadata["groupWorkoutID"] = groupWorkoutID
        
        let hkWorkout = TestWorkoutBuilder.createWorkout(
            type: .functionalStrengthTraining,
            metadata: metadata
        )
        
        // When: Processing the workout
        try await workoutProcessor.processHealthKitWorkout(hkWorkout)
        
        // Then: Group workout ID should be preserved
        let savedWorkout = cloudKitService.workoutHistory.first
        XCTAssertEqual(savedWorkout?.groupWorkoutID, groupWorkoutID,
                      "Group workout ID must be preserved")
        
        // And: Main ID should still be HKWorkout UUID
        XCTAssertEqual(savedWorkout?.id, hkWorkout.uuid.uuidString,
                      "Main ID must still be HKWorkout UUID")
    }
    
    /// Test 9: Recovery from interrupted sync
    func testRecoveryFromInterruptedSync() async throws {
        // Given: Multiple workouts
        let workouts = [
            TestWorkoutBuilder.createWorkout(type: .running),
            TestWorkoutBuilder.createWorkout(type: .cycling),
            TestWorkoutBuilder.createWorkout(type: .swimming)
        ]
        
        // When: First sync partially completes (simulate interruption)
        healthKitService.mockWorkouts = [workouts[0]]
        await workoutSyncService.performManualSync()
        
        // And: Second sync includes all workouts
        healthKitService.mockWorkouts = workouts
        await workoutSyncService.performManualSync()
        
        // Then: All unique workouts should be saved exactly once
        let savedWorkouts = cloudKitService.workoutHistory
        XCTAssertEqual(savedWorkouts.count, 3,
                      "All workouts should be saved despite interruption")
        
        // And: No duplicates
        let uniqueIDs = Set(savedWorkouts.map { $0.id })
        XCTAssertEqual(uniqueIDs.count, 3,
                      "No duplicate workouts should exist")
    }
    
    /// Test 10: CloudKit conflict resolution
    func testCloudKitConflictResolution() async throws {
        // Given: A workout that exists in CloudKit
        let hkWorkout = TestWorkoutBuilder.createWorkout(type: .tennis)
        let existingWorkout = Workout(from: hkWorkout, followersEarned: 10)
        cloudKitService.workoutHistory.append(existingWorkout)
        
        // When: Trying to sync the same workout again
        try await workoutProcessor.processHealthKitWorkout(hkWorkout)
        
        // Then: Should not create duplicate
        XCTAssertEqual(cloudKitService.workoutHistory.count, 1,
                      "Should not duplicate existing CloudKit record")
        
        // And: Existing record should be preserved
        XCTAssertEqual(cloudKitService.workoutHistory.first?.id, hkWorkout.uuid.uuidString,
                      "Existing record with correct ID should be preserved")
    }
}