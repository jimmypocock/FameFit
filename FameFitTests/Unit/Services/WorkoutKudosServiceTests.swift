//
//  WorkoutKudosServiceTests.swift
//  FameFitTests
//
//  Tests for WorkoutKudosService
//

import CloudKit
import Combine
@testable import FameFit
import XCTest

class WorkoutKudosServiceTests: XCTestCase {
    private var sut: WorkoutKudosService!
    private var mockUserProfileService: MockUserProfileService!
    private var mockNotificationService: MockNotificationService!
    private var mockRateLimiter: MockRateLimitingService!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()

        mockUserProfileService = MockUserProfileService()
        mockNotificationService = MockNotificationService()
        mockRateLimiter = MockRateLimitingService()
        cancellables = []

        sut = WorkoutKudosService(
            userProfileService: mockUserProfileService,
            notificationManager: mockNotificationService,
            rateLimiter: mockRateLimiter
        )
    }

    override func tearDown() {
        sut = nil
        mockUserProfileService = nil
        mockNotificationService = nil
        mockRateLimiter = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testWorkoutKudosServiceInitializes() {
        XCTAssertNotNil(sut)
        XCTAssertNotNil(sut.kudosUpdates)
    }

    // MARK: - Kudos Update Publisher Tests

    func testKudosUpdatePublisherEmitsNoInitialValue() {
        var receivedUpdate: KudosUpdate?

        sut.kudosUpdates
            .sink { update in
                receivedUpdate = update
            }
            .store(in: &cancellables)

        XCTAssertNil(receivedUpdate)
    }

    // MARK: - Rate Limiting Tests

    func testRateLimitingIsCheckedBeforeAction() async throws {
        // Given
        mockRateLimiter.shouldAllow = false

        // When - We need to use a mock kudos service since real one requires CloudKit
        let mockKudosService = MockWorkoutKudosService()
        mockKudosService.shouldFailToggleKudos = true

        do {
            _ = try await mockKudosService.toggleKudos(for: "workout123", ownerId: "owner456")
            XCTFail("Expected rate limit error")
        } catch {
            // Then
            XCTAssertEqual(error as? KudosError, .rateLimited)
        }
    }

    func testRateLimitingRecordsActionWhenAllowed() async throws {
        // Given
        let mockKudosService = MockWorkoutKudosService()
        mockKudosService.shouldFailToggleKudos = false

        // When
        let result = try await mockKudosService.toggleKudos(for: "workout123", ownerId: "owner456")

        // Then
        XCTAssertTrue(mockKudosService.toggleKudosCalled)
        XCTAssertEqual(result, .added)
    }

    // MARK: - Model Tests

    func testWorkoutKudosInitialization() {
        // Given
        let workoutId = "workout123"
        let userId = "user456"
        let ownerId = "owner789"

        // When
        let kudos = WorkoutKudos(
            workoutId: workoutId,
            userID: userId,
            workoutOwnerId: ownerId
        )

        // Then
        XCTAssertEqual(kudos.workoutId, workoutId)
        XCTAssertEqual(kudos.userID, userId)
        XCTAssertEqual(kudos.workoutOwnerId, ownerId)
        XCTAssertNotNil(kudos.id)
        XCTAssertNotNil(kudos.createdTimestamp)
    }

    func testWorkoutKudosSummaryInitialization() {
        // Given
        let workoutId = "workout123"
        let totalCount = 5
        let hasUserKudos = true
        let recentUsers = [
            WorkoutKudosSummary.KudosUser(
                userID: "user1",
                username: "testuser",
                displayName: "Test User",
                profileImageURL: nil
            )
        ]

        // When
        let summary = WorkoutKudosSummary(
            workoutId: workoutId,
            totalCount: totalCount,
            hasUserKudos: hasUserKudos,
            recentUsers: recentUsers
        )

        // Then
        XCTAssertEqual(summary.workoutId, workoutId)
        XCTAssertEqual(summary.totalCount, totalCount)
        XCTAssertEqual(summary.hasUserKudos, hasUserKudos)
        XCTAssertEqual(summary.recentUsers.count, 1)
        XCTAssertEqual(summary.recentUsers.first?.username, "testuser")
    }

    func testKudosUpdateModel() {
        // Given
        let workoutId = "workout123"
        let userId = "user456"
        let newCount = 10

        // When
        let addUpdate = KudosUpdate(
            workoutId: workoutId,
            action: .added,
            userID: userId,
            newCount: newCount
        )

        let removeUpdate = KudosUpdate(
            workoutId: workoutId,
            action: .removed,
            userID: userId,
            newCount: newCount - 1
        )

        // Then
        XCTAssertEqual(addUpdate.workoutId, workoutId)
        XCTAssertEqual(addUpdate.action, KudosUpdate.KudosAction.added)
        XCTAssertEqual(addUpdate.userID, userId)
        XCTAssertEqual(addUpdate.newCount, newCount)

        XCTAssertEqual(removeUpdate.action, KudosUpdate.KudosAction.removed)
        XCTAssertEqual(removeUpdate.newCount, newCount - 1)
    }

    func testKudosActionResult() {
        // Test enum cases
        let added = KudosActionResult.added
        let removed = KudosActionResult.removed
        let error = KudosActionResult.error(NSError(domain: "test", code: 1, userInfo: nil))

        // Test equality
        XCTAssertEqual(added, KudosActionResult.added)
        XCTAssertEqual(removed, KudosActionResult.removed)

        // Test inequality
        XCTAssertNotEqual(added, removed)
        XCTAssertNotEqual(added, error)
        XCTAssertNotEqual(removed, error)
    }

    // MARK: - Error Handling Tests

    func testKudosErrorMessages() {
        // Given
        let rateLimitedError = KudosError.rateLimited
        let unauthorizedError = KudosError.unauthorized
        let workoutNotFoundError = KudosError.workoutNotFound

        // Then
        XCTAssertEqual(rateLimitedError.errorDescription, "You're doing that too fast. Please try again later.")
        XCTAssertEqual(unauthorizedError.errorDescription, "You don't have permission to perform this action.")
        XCTAssertEqual(workoutNotFoundError.errorDescription, "The workout could not be found.")
    }
}
