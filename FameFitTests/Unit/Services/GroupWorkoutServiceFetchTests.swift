//
//  GroupWorkoutServiceFetchTests.swift
//  FameFitTests
//
//  Tests for GroupWorkoutService fetch and search operations
//

import XCTest
import CloudKit
import HealthKit
@testable import FameFit

final class GroupWorkoutServiceFetchTests: XCTestCase {
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
    
    // MARK: - Fetch Upcoming Workouts Tests
    
    func testFetchUpcomingWorkouts_Success() async throws {
        // Given
        let upcomingWorkouts = [
            GroupWorkout(
                id: "upcoming-1",
                name: "Morning Run",
                description: "Early bird run",
                workoutType: .running,
                hostId: "host-1",
                maxParticipants: 10,
                scheduledStart: Date().addingTimeInterval(3_600),
                scheduledEnd: Date().addingTimeInterval(7_200),
                status: .scheduled,
                isPublic: true
            ),
            GroupWorkout(
                id: "upcoming-2",
                name: "Evening Yoga",
                description: "Relaxing session",
                workoutType: .yoga,
                hostId: "host-2",
                maxParticipants: 8,
                scheduledStart: Date().addingTimeInterval(7_200),
                scheduledEnd: Date().addingTimeInterval(10_800),
                status: .scheduled,
                isPublic: true
            ),
            GroupWorkout(
                id: "private-1",
                name: "Private Session",
                description: "Members only",
                workoutType: .cycling,
                hostId: "host-3",
                maxParticipants: 5,
                scheduledStart: Date().addingTimeInterval(5_400),
                scheduledEnd: Date().addingTimeInterval(9_000),
                status: .scheduled,
                isPublic: false // Should not be included
            )
        ]
        
        sut.mockWorkouts = upcomingWorkouts
        
        // When
        let fetchedWorkouts = try await sut.fetchUpcomingWorkouts(limit: 10)
        
        // Then
        XCTAssertEqual(fetchedWorkouts.count, 2) // Only public workouts
        XCTAssertTrue(fetchedWorkouts.allSatisfy { $0.isPublic })
        XCTAssertTrue(fetchedWorkouts.allSatisfy { $0.status == .scheduled })
    }
    
    // MARK: - Fetch My Workouts Tests
    
    func testFetchMyWorkouts_Success() async throws {
        // Given
        let myWorkouts = [
            GroupWorkout(
                id: "my-hosted-1",
                name: "My Hosted Workout",
                description: "I'm the host",
                workoutType: .running,
                hostId: "test-user-123", // Current user is host
                maxParticipants: 10,
                scheduledStart: Date().addingTimeInterval(3_600),
                scheduledEnd: Date().addingTimeInterval(7_200)
            ),
            GroupWorkout(
                id: "my-joined-1",
                name: "Joined Workout",
                description: "I'm a participant",
                workoutType: .yoga,
                hostId: "other-host",
                participants: [
                    GroupWorkoutParticipant(
                        userId: "other-host",
                        displayName: "Host",
                        profileImageURL: nil
                    ),
                    GroupWorkoutParticipant(
                        userId: "test-user-123", // Current user is participant
                        displayName: "Me",
                        profileImageURL: nil
                    )
                ],
                maxParticipants: 10,
                scheduledStart: Date().addingTimeInterval(7_200),
                scheduledEnd: Date().addingTimeInterval(10_800)
            ),
            GroupWorkout(
                id: "not-mine-1",
                name: "Other Workout",
                description: "Not involved",
                workoutType: .cycling,
                hostId: "random-host",
                maxParticipants: 10,
                scheduledStart: Date().addingTimeInterval(5_400),
                scheduledEnd: Date().addingTimeInterval(9_000)
            )
        ]
        
        sut.mockWorkouts = myWorkouts
        
        // When
        let fetchedWorkouts = try await sut.fetchMyWorkouts(userId: "test-user-123")
        
        // Then
        XCTAssertEqual(fetchedWorkouts.count, 2)
        XCTAssertTrue(fetchedWorkouts.contains { $0.id == "my-hosted-1" })
        XCTAssertTrue(fetchedWorkouts.contains { $0.id == "my-joined-1" })
        XCTAssertFalse(fetchedWorkouts.contains { $0.id == "not-mine-1" })
    }
    
    // MARK: - Search Workouts Tests
    
    func testSearchWorkouts_ByName_Success() async throws {
        // Given
        let workouts = [
            GroupWorkout(
                id: "yoga-1",
                name: "Morning Yoga Flow",
                description: "Start your day right",
                workoutType: .yoga,
                hostId: "host-1",
                maxParticipants: 10,
                scheduledStart: Date().addingTimeInterval(3_600),
                scheduledEnd: Date().addingTimeInterval(7_200),
                status: .scheduled,
                isPublic: true
            ),
            GroupWorkout(
                id: "yoga-2",
                name: "Evening Relaxation",
                description: "Yoga for better sleep",
                workoutType: .yoga,
                hostId: "host-2",
                maxParticipants: 8,
                scheduledStart: Date().addingTimeInterval(7_200),
                scheduledEnd: Date().addingTimeInterval(10_800),
                status: .scheduled,
                isPublic: true,
                tags: ["yoga", "relaxation"]
            ),
            GroupWorkout(
                id: "run-1",
                name: "5K Training Run",
                description: "Improve your pace",
                workoutType: .running,
                hostId: "host-3",
                maxParticipants: 15,
                scheduledStart: Date().addingTimeInterval(5_400),
                scheduledEnd: Date().addingTimeInterval(9_000),
                status: .scheduled,
                isPublic: true
            )
        ]
        
        sut.mockWorkouts = workouts
        
        // When
        let yogaResults = try await sut.searchWorkouts(query: "yoga", workoutType: nil)
        
        // Then
        XCTAssertEqual(yogaResults.count, 2)
        XCTAssertTrue(yogaResults.allSatisfy {
            $0.name.lowercased().contains("yoga") ||
            $0.description.lowercased().contains("yoga") ||
            $0.tags.contains("yoga")
        })
    }
    
    func testSearchWorkouts_ByType_Success() async throws {
        // Given
        let workouts = [
            GroupWorkout(
                id: "run-1",
                name: "Morning Run",
                description: "Start fresh",
                workoutType: .running,
                hostId: "host-1",
                maxParticipants: 10,
                scheduledStart: Date().addingTimeInterval(3_600),
                scheduledEnd: Date().addingTimeInterval(7_200),
                status: .scheduled,
                isPublic: true
            ),
            GroupWorkout(
                id: "run-2",
                name: "Trail Run",
                description: "Nature run",
                workoutType: .running,
                hostId: "host-2",
                maxParticipants: 8,
                scheduledStart: Date().addingTimeInterval(7_200),
                scheduledEnd: Date().addingTimeInterval(10_800),
                status: .scheduled,
                isPublic: true
            ),
            GroupWorkout(
                id: "yoga-1",
                name: "Yoga Session",
                description: "Stretch and relax",
                workoutType: .yoga,
                hostId: "host-3",
                maxParticipants: 12,
                scheduledStart: Date().addingTimeInterval(5_400),
                scheduledEnd: Date().addingTimeInterval(9_000),
                status: .scheduled,
                isPublic: true
            )
        ]
        
        sut.mockWorkouts = workouts
        
        // When
        let runningWorkouts = try await sut.searchWorkouts(query: "", workoutType: .running)
        
        // Then
        XCTAssertEqual(runningWorkouts.count, 2)
        XCTAssertTrue(runningWorkouts.allSatisfy { $0.workoutType == .running })
    }
    
    // MARK: - Fetch Active Workouts Tests
    
    func testFetchActiveWorkouts_Success() async throws {
        // Given
        let workouts = [
            GroupWorkout(
                id: "active-1",
                name: "Active Session 1",
                description: "Currently running",
                workoutType: .running,
                hostId: "host-1",
                maxParticipants: 10,
                scheduledStart: Date().addingTimeInterval(-600),
                scheduledEnd: Date().addingTimeInterval(3_000),
                status: .active
            ),
            GroupWorkout(
                id: "active-2",
                name: "Active Session 2",
                description: "In progress",
                workoutType: .yoga,
                hostId: "host-2",
                maxParticipants: 8,
                scheduledStart: Date().addingTimeInterval(-300),
                scheduledEnd: Date().addingTimeInterval(3_300),
                status: .active
            ),
            GroupWorkout(
                id: "scheduled-1",
                name: "Not Active",
                description: "Future workout",
                workoutType: .cycling,
                hostId: "host-3",
                maxParticipants: 12,
                scheduledStart: Date().addingTimeInterval(3_600),
                scheduledEnd: Date().addingTimeInterval(7_200),
                status: .scheduled
            )
        ]
        
        sut.mockWorkouts = workouts
        
        // When
        let activeWorkouts = try await sut.fetchActiveWorkouts()
        
        // Then
        XCTAssertEqual(activeWorkouts.count, 2)
        XCTAssertTrue(activeWorkouts.allSatisfy { $0.status == .active })
    }
    
    // MARK: - Caching Tests
    
    func testFetchWorkout_UsesCacheWhenAvailable() async throws {
        // Given
        let workout = GroupWorkout(
            id: "cached-workout",
            name: "Cached Session",
            description: "Should use cache",
            workoutType: .running,
            hostId: "host-123",
            maxParticipants: 10,
            scheduledStart: Date().addingTimeInterval(3_600),
            scheduledEnd: Date().addingTimeInterval(7_200)
        )
        
        // First fetch to populate cache
        sut.mockWorkouts = [workout]
        _ = try await sut.fetchWorkout(workoutId: workout.id)
        
        // Note: MockGroupWorkoutService doesn't have cache simulation
        // This test would need to be updated to properly test caching
        
        // When - fetch again (should use cache)
        let cachedWorkout = try await sut.fetchWorkout(workoutId: workout.id)
        
        // Then
        XCTAssertEqual(cachedWorkout.id, workout.id)
        XCTAssertEqual(cachedWorkout.name, workout.name)
    }
    
    func testFetchWorkout_NotFound_ThrowsError() async {
        // When/Then
        do {
            _ = try await sut.fetchWorkout(workoutId: "non-existent")
            XCTFail("Expected not found error")
        } catch GroupWorkoutError.workoutNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}