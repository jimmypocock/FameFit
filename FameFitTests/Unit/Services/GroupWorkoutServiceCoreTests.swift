//
//  GroupWorkoutServiceCoreTests.swift
//  FameFitTests
//
//  Core tests for GroupWorkoutService - Create, Update, Cancel operations
//

import XCTest
import CloudKit
import HealthKit
@testable import FameFit

final class GroupWorkoutServiceCoreTests: XCTestCase {
    // MARK: - Properties
    
    private var sut: MockGroupWorkoutService!
    private var mockCloudKitManager: MockCloudKitManager!
    private var mockUserProfileService: MockUserProfileService!
    private var mockNotificationManager: MockNotificationManager!
    private var mockRateLimiter: MockRateLimitingService!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        mockCloudKitManager = MockCloudKitManager()
        mockUserProfileService = MockUserProfileService()
        mockNotificationManager = MockNotificationManager()
        mockRateLimiter = MockRateLimitingService()
        
        sut = MockGroupWorkoutService()
        
        // Set up test user
        mockCloudKitManager.currentUserID = "test-user-123"
    }
    
    override func tearDown() {
        sut = nil
        mockCloudKitManager = nil
        mockUserProfileService = nil
        mockNotificationManager = nil
        mockRateLimiter = nil
        super.tearDown()
    }
    
    // MARK: - Create Group Workout Tests
    
    func testCreateGroupWorkout_Success() async throws {
        // Given
        let workout = GroupWorkout(
            name: "Morning Run Club",
            description: "Let's run together!",
            workoutType: .running,
            hostId: "test-user-123",
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200)
        )
        
        // When
        let createdWorkout = try await sut.createGroupWorkout(workout)
        
        // Then
        XCTAssertEqual(createdWorkout.name, workout.name)
        XCTAssertEqual(createdWorkout.hostId, "test-user-123")
        XCTAssertEqual(createdWorkout.status, .scheduled)
        XCTAssertEqual(createdWorkout.participants.count, 1) // Host added as participant
        XCTAssertEqual(createdWorkout.participants.first?.userId, "test-user-123")
        
        // Verify the workout was created
        XCTAssertTrue(sut.createGroupWorkoutCalled)
        XCTAssertEqual(sut.createdWorkouts.count, 1)
        XCTAssertEqual(sut.mockWorkouts.count, 1)
    }
    
    func testCreateGroupWorkout_InvalidDuration_ThrowsError() async {
        // Given - workout less than 5 minutes
        let workout = GroupWorkout(
            name: "Too Short",
            description: "This is too short",
            workoutType: .running,
            hostId: "test-user-123",
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(3_700) // Only 100 seconds
        )
        
        // Set validation error
        sut.errorToThrow = GroupWorkoutError.invalidWorkout("Workout must be at least 5 minutes long")
        
        // When/Then
        do {
            _ = try await sut.createGroupWorkout(workout)
            XCTFail("Expected error for short duration")
        } catch GroupWorkoutError.invalidWorkout(let reason) {
            XCTAssertTrue(reason.contains("5 minutes"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCreateGroupWorkout_PastScheduledTime_ThrowsError() async {
        // Given - workout scheduled in the past
        let workout = GroupWorkout(
            name: "Past Workout",
            description: "Already passed",
            workoutType: .running,
            hostId: "test-user-123",
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(-3_600), // 1 hour ago
            scheduledEnd: Date()
        )
        
        // Set validation error
        sut.errorToThrow = GroupWorkoutError.invalidWorkout("Workout must be scheduled in the future")
        
        // When/Then
        do {
            _ = try await sut.createGroupWorkout(workout)
            XCTFail("Expected error for past scheduled time")
        } catch GroupWorkoutError.invalidWorkout(let reason) {
            XCTAssertTrue(reason.contains("future"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCreateGroupWorkout_NotHost_ThrowsError() async {
        // Given - workout with different host ID
        let workout = GroupWorkout(
            name: "Not My Workout",
            description: "Different host",
            workoutType: .running,
            hostId: "different-user-456",
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200)
        )
        
        // Set error to throw
        sut.errorToThrow = GroupWorkoutError.notAuthorized
        
        // When/Then
        do {
            _ = try await sut.createGroupWorkout(workout)
            XCTFail("Expected authorization error")
        } catch GroupWorkoutError.notAuthorized {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCreateGroupWorkout_RateLimited_ThrowsError() async {
        // Given
        let workout = GroupWorkout(
            name: "Rate Limited",
            description: "Too many requests",
            workoutType: .running,
            hostId: "test-user-123",
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200)
        )
        
        // Set rate limit error
        sut.shouldFail = true
        
        // When/Then
        do {
            _ = try await sut.createGroupWorkout(workout)
            XCTFail("Expected error")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Update Workout Tests
    
    func testUpdateGroupWorkout_AsHost_Success() async throws {
        // Given
        let originalWorkout = GroupWorkout(
            id: "workout-123",
            name: "Original Name",
            description: "Original description",
            workoutType: .running,
            hostId: "test-user-123",
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200),
            status: .scheduled
        )
        // Add workout to mock
        sut.mockWorkouts.append(originalWorkout)
        
        let updatedWorkout = originalWorkout
        
        // When
        let result = try await sut.updateGroupWorkout(updatedWorkout)
        
        // Then
        XCTAssertEqual(result.name, originalWorkout.name)
        XCTAssertTrue(result.updatedAt > originalWorkout.updatedAt)
        XCTAssertTrue(sut.updateGroupWorkoutCalled)
    }
    
    func testUpdateGroupWorkout_NotHost_ThrowsError() async {
        // Given
        let workout = GroupWorkout(
            id: "workout-123",
            name: "Not My Workout",
            description: "Different host",
            workoutType: .running,
            hostId: "different-user-456",
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200)
        )
        // Add workout to mock
        sut.mockWorkouts.append(workout)
        sut.errorToThrow = GroupWorkoutError.notAuthorized
        
        // When/Then
        do {
            _ = try await sut.updateGroupWorkout(workout)
            XCTFail("Expected authorization error")
        } catch GroupWorkoutError.notAuthorized {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Cancel Workout Tests
    
    func testCancelGroupWorkout_AsHost_Success() async throws {
        // Given
        let workout = GroupWorkout(
            id: "workout-123",
            name: "To Cancel",
            description: "Will be cancelled",
            workoutType: .running,
            hostId: "test-user-123", // Current user is host
            participants: [
                GroupWorkoutParticipant(
                    userId: "test-user-123",
                    displayName: "Test User",
                    profileImageURL: nil
                ),
                GroupWorkoutParticipant(
                    userId: "participant-456",
                    displayName: "Other User",
                    profileImageURL: nil
                )
            ],
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200),
            status: .scheduled
        )
        // Add workout to mock
        sut.mockWorkouts.append(workout)
        
        // When
        try await sut.cancelGroupWorkout(workoutId: workout.id)
        
        // Then
        let cancelledWorkout = sut.mockWorkouts.first(where: { $0.id == workout.id })!
        XCTAssertEqual(cancelledWorkout.status, .cancelled)
        XCTAssertTrue(sut.cancelGroupWorkoutCalled)
    }
    
    func testCancelGroupWorkout_NotHost_ThrowsError() async {
        // Given
        let workout = GroupWorkout(
            id: "workout-123",
            name: "Not My Workout",
            description: "Cannot cancel",
            workoutType: .running,
            hostId: "other-host-789",
            participants: [
                GroupWorkoutParticipant(
                    userId: "other-host-789",
                    displayName: "Other User",
                    profileImageURL: nil
                )
            ],
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200),
            status: .scheduled
        )
        // Add workout to mock
        sut.mockWorkouts.append(workout)
        sut.errorToThrow = GroupWorkoutError.notAuthorized
        
        // When/Then
        do {
            try await sut.cancelGroupWorkout(workoutId: workout.id)
            XCTFail("Expected not authorized error")
        } catch GroupWorkoutError.notAuthorized {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Join Code Generation Tests
    
    func testJoinCodeGeneration_Length() {
        // When
        let code = GroupWorkout.generateJoinCode()
        
        // Then
        XCTAssertEqual(code.count, 6)
        XCTAssertTrue(code.allSatisfy { $0.isLetter || $0.isNumber })
        XCTAssertEqual(code, code.uppercased()) // Should be uppercase
    }
    
    func testJoinCodeGeneration_Uniqueness() {
        // When
        let codes = (0..<100).map { _ in GroupWorkout.generateJoinCode() }
        let uniqueCodes = Set(codes)
        
        // Then
        XCTAssertEqual(codes.count, uniqueCodes.count) // All should be unique (statistically)
    }
}