//
//  GroupWorkoutServiceParticipantTests.swift
//  FameFitTests
//
//  Tests for GroupWorkoutService participant operations - Join, Leave, Start, Complete
//

import CloudKit
@testable import FameFit
import HealthKit
import XCTest

final class GroupWorkoutServiceParticipantTests: XCTestCase {
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
        sut.notificationManager = mockNotificationManager

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

    // MARK: - Join Group Workout Tests

    func testJoinGroupWorkout_Success() async throws {
        // Given
        let existingWorkout = GroupWorkout(
            id: "workout-123",
            name: "Evening Yoga",
            description: "Relaxing yoga session",
            workoutType: .yoga,
            hostID: "host-456",
            participants: [
                GroupWorkoutParticipant(
                    userId: "host-456",
                    username: "HostUser",
                    profileImageURL: nil
                )
            ],
            maxParticipants: 5,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200),
            status: .scheduled
        )
        sut.mockWorkouts.append(existingWorkout)

        // When
        let joinedWorkout = try await sut.joinGroupWorkout(workoutId: existingWorkout.id)

        // Then
        XCTAssertEqual(joinedWorkout.participants.count, 2)
        XCTAssertTrue(joinedWorkout.participantIds.contains("test-user-123"))

        // Verify notification sent to host
        XCTAssertTrue(mockNotificationManager.scheduleNotificationCalled)
        XCTAssertEqual(mockNotificationManager.lastScheduledUserId, "host-456")
    }

    func testJoinGroupWorkout_AlreadyJoined_ReturnsExisting() async throws {
        // Given
        let existingWorkout = GroupWorkout(
            id: "workout-123",
            name: "Morning Ride",
            description: "Cycling together",
            workoutType: .cycling,
            hostID: "host-456",
            participants: [
                GroupWorkoutParticipant(
                    userId: "host-456",
                    username: "HostUser",
                    profileImageURL: nil
                ),
                GroupWorkoutParticipant(
                    userId: "test-user-123", // Already joined
                    username: "TestUser",
                    profileImageURL: nil
                )
            ],
            maxParticipants: 5,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200),
            status: .scheduled
        )
        sut.mockWorkouts.append(existingWorkout)

        // When
        let workout = try await sut.joinGroupWorkout(workoutId: existingWorkout.id)

        // Then
        XCTAssertEqual(workout.participants.count, 2) // No change
        XCTAssertFalse(mockNotificationManager.scheduleNotificationCalled) // No notification
    }

    func testJoinGroupWorkout_Full_ThrowsError() async {
        // Given
        let fullWorkout = GroupWorkout(
            id: "workout-123",
            name: "Full Session",
            description: "No more space",
            workoutType: .running,
            hostID: "host-456",
            participants: [
                GroupWorkoutParticipant(userId: "user-1", username: "User1", profileImageURL: nil),
                GroupWorkoutParticipant(userId: "user-2", username: "User2", profileImageURL: nil)
            ],
            maxParticipants: 2, // Already at capacity
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200),
            status: .scheduled
        )
        sut.mockWorkouts.append(fullWorkout)

        // When/Then
        do {
            _ = try await sut.joinGroupWorkout(workoutId: fullWorkout.id)
            XCTFail("Expected workout full error")
        } catch GroupWorkoutError.workoutFull {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testJoinGroupWorkout_Cancelled_ThrowsError() async {
        // Given
        let cancelledWorkout = GroupWorkout(
            id: "workout-123",
            name: "Cancelled Session",
            description: "This was cancelled",
            workoutType: .running,
            hostID: "host-456",
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200),
            status: .cancelled
        )
        sut.mockWorkouts.append(cancelledWorkout)

        // When/Then
        do {
            _ = try await sut.joinGroupWorkout(workoutId: cancelledWorkout.id)
            XCTFail("Expected cannot join error")
        } catch GroupWorkoutError.cannotJoin {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Join with Code Tests

    func testJoinWithCode_Success() async throws {
        // Given
        let privateWorkout = GroupWorkout(
            id: "private-workout-123",
            name: "Private Session",
            description: "Join with code only",
            workoutType: .running,
            hostID: "host-456",
            participants: [
                GroupWorkoutParticipant(
                    userId: "host-456",
                    username: "HostUser",
                    profileImageURL: nil
                )
            ],
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200),
            status: .scheduled,
            isPublic: false,
            joinCode: "ABC123"
        )
        sut.mockWorkouts.append(privateWorkout)

        // When
        let joinedWorkout = try await sut.joinWithCode("ABC123")

        // Then
        XCTAssertEqual(joinedWorkout.id, privateWorkout.id)
        XCTAssertEqual(joinedWorkout.participants.count, 2)
        XCTAssertTrue(joinedWorkout.participantIds.contains("test-user-123"))
    }

    func testJoinWithCode_InvalidCode_ThrowsError() async {
        // When/Then
        do {
            _ = try await sut.joinWithCode("INVALID")
            XCTFail("Expected invalid join code error")
        } catch GroupWorkoutError.invalidJoinCode {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Start Workout Tests

    func testStartGroupWorkout_AsHost_Success() async throws {
        // Given
        let workout = GroupWorkout(
            id: "workout-123",
            name: "Ready to Start",
            description: "Let's begin",
            workoutType: .running,
            hostID: "test-user-123", // Current user is host
            participants: [
                GroupWorkoutParticipant(
                    userId: "test-user-123",
                    username: "TestUser",
                    profileImageURL: nil
                ),
                GroupWorkoutParticipant(
                    userId: "participant-456",
                    username: "OtherUser",
                    profileImageURL: nil
                )
            ],
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(300), // 5 minutes from now
            scheduledEnd: Date().addingTimeInterval(3_900),
            status: .scheduled
        )
        sut.mockWorkouts.append(workout)

        // When
        let startedWorkout = try await sut.startGroupWorkout(workoutId: workout.id)

        // Then
        XCTAssertEqual(startedWorkout.status, .active)
        XCTAssertNotNil(startedWorkout.participants.first(where: { $0.userId == "test-user-123" })?.workoutData)
        XCTAssertEqual(startedWorkout.participants.first(where: { $0.userId == "test-user-123" })?.status, .active)

        // Verify notifications sent
        XCTAssertTrue(mockNotificationManager.scheduleNotificationCalled)
    }

    func testStartGroupWorkout_AsParticipant_Success() async throws {
        // Given
        let workout = GroupWorkout(
            id: "workout-123",
            name: "Participant Start",
            description: "Starting as participant",
            workoutType: .running,
            hostID: "host-789",
            participants: [
                GroupWorkoutParticipant(
                    userId: "host-789",
                    username: "HostUser",
                    profileImageURL: nil
                ),
                GroupWorkoutParticipant(
                    userId: "test-user-123", // Current user is participant
                    username: "TestUser",
                    profileImageURL: nil
                )
            ],
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(300),
            scheduledEnd: Date().addingTimeInterval(3_900),
            status: .scheduled
        )
        sut.mockWorkouts.append(workout)

        // When
        let startedWorkout = try await sut.startGroupWorkout(workoutId: workout.id)

        // Then
        XCTAssertEqual(startedWorkout.status, .active)
        XCTAssertNotNil(startedWorkout.participants.first(where: { $0.userId == "test-user-123" })?.workoutData)
    }

    func testStartGroupWorkout_NotParticipant_ThrowsError() async {
        // Given
        let workout = GroupWorkout(
            id: "workout-123",
            name: "Not My Workout",
            description: "Cannot start",
            workoutType: .running,
            hostID: "other-host",
            participants: [
                GroupWorkoutParticipant(
                    userId: "other-host",
                    username: "OtherUser",
                    profileImageURL: nil
                )
            ],
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(300),
            scheduledEnd: Date().addingTimeInterval(3_900),
            status: .scheduled
        )
        sut.mockWorkouts.append(workout)

        // When/Then
        do {
            _ = try await sut.startGroupWorkout(workoutId: workout.id)
            XCTFail("Expected not participant error")
        } catch GroupWorkoutError.notParticipant {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Complete Workout Tests

    func testCompleteGroupWorkout_Success() async throws {
        // Given
        let activeWorkout = GroupWorkout(
            id: "workout-123",
            name: "Active Workout",
            description: "In progress",
            workoutType: .running,
            hostID: "test-user-123",
            participants: [
                GroupWorkoutParticipant(
                    userId: "test-user-123",
                    username: "TestUser",
                    profileImageURL: nil,
                    status: .active,
                    workoutData: GroupWorkoutData(
                        startTime: Date().addingTimeInterval(-1_800),
                        totalEnergyBurned: 250,
                        totalDistance: 5_000,
                        lastUpdated: Date()
                    )
                )
            ],
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(-1_800),
            scheduledEnd: Date().addingTimeInterval(1_800),
            status: .active
        )
        sut.mockWorkouts.append(activeWorkout)

        // When
        let completedWorkout = try await sut.completeGroupWorkout(workoutId: activeWorkout.id)

        // Then
        XCTAssertEqual(completedWorkout.status, .completed)
        let participant = completedWorkout.participants.first(where: { $0.userId == "test-user-123" })
        XCTAssertEqual(participant?.status, .completed)
        XCTAssertNotNil(participant?.workoutData?.endTime)
    }

    // MARK: - Leave Workout Tests

    func testLeaveGroupWorkout_AsParticipant_Success() async throws {
        // Given
        let workout = GroupWorkout(
            id: "workout-123",
            name: "Leave Test",
            description: "Testing leave",
            workoutType: .running,
            hostID: "host-456",
            participants: [
                GroupWorkoutParticipant(
                    userId: "host-456",
                    username: "HostUser",
                    profileImageURL: nil
                ),
                GroupWorkoutParticipant(
                    userId: "test-user-123",
                    username: "TestUser",
                    profileImageURL: nil
                )
            ],
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200),
            status: .scheduled
        )
        sut.mockWorkouts.append(workout)

        // When
        try await sut.leaveGroupWorkout(workoutId: workout.id)

        // Then
        let updatedWorkout = sut.mockWorkouts.first(where: { $0.id == workout.id })!
        let participant = updatedWorkout.participants.first(where: { $0.userId == "test-user-123" })
        XCTAssertNil(participant) // Should be removed from participants
    }

    func testLeaveGroupWorkout_AsHost_ThrowsError() async {
        // Given
        let workout = GroupWorkout(
            id: "workout-123",
            name: "Host Cannot Leave",
            description: "Must cancel instead",
            workoutType: .running,
            hostID: "test-user-123", // Current user is host
            participants: [
                GroupWorkoutParticipant(
                    userId: "test-user-123",
                    username: "TestUser",
                    profileImageURL: nil
                )
            ],
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200),
            status: .scheduled
        )
        sut.mockWorkouts.append(workout)

        // When/Then
        do {
            try await sut.leaveGroupWorkout(workoutId: workout.id)
            XCTFail("Expected host cannot leave error")
        } catch GroupWorkoutError.hostCannotLeave {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Real-time Update Tests

    func testUpdateParticipantData_SendsRealtimeUpdate() async throws {
        // Given
        let workout = GroupWorkout(
            id: "workout-123",
            name: "Active Session",
            description: "In progress",
            workoutType: .running,
            hostID: "host-456",
            participants: [
                GroupWorkoutParticipant(
                    userId: "test-user-123",
                    username: "TestUser",
                    profileImageURL: nil,
                    status: .active
                )
            ],
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(-600),
            scheduledEnd: Date().addingTimeInterval(3_000),
            status: .active
        )
        sut.mockWorkouts.append(workout)

        let workoutData = GroupWorkoutData(
            startTime: Date().addingTimeInterval(-600),
            totalEnergyBurned: 150,
            totalDistance: 2_500,
            averageHeartRate: 145,
            currentHeartRate: 150,
            lastUpdated: Date()
        )

        var receivedUpdate: GroupWorkoutUpdate?
        let expectation = expectation(description: "Receive update")

        let cancellable = sut.activeWorkoutUpdates.sink { update in
            receivedUpdate = update
            expectation.fulfill()
        }

        // When
        try await sut.updateParticipantData(workoutId: workout.id, data: workoutData)

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertNotNil(receivedUpdate)
        XCTAssertEqual(receivedUpdate?.workoutId, workout.id)
        XCTAssertEqual(receivedUpdate?.participantId, "test-user-123")
        XCTAssertEqual(receivedUpdate?.updateType, .progress)
        XCTAssertEqual(receivedUpdate?.data?.totalEnergyBurned, 150)

        cancellable.cancel()
    }
}
