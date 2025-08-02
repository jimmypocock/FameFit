//
//  WorkoutChallengesServiceTests.swift
//  FameFitTests
//
//  Tests for WorkoutChallengesService
//

import CloudKit
@testable import FameFit
import XCTest

final class WorkoutChallengesServiceTests: XCTestCase {
    private var sut: TestableWorkoutChallengesService!
    private var mockCloudKitManager: MockCloudKitManager!
    private var mockUserProfileService: MockUserProfileService!
    private var mockNotificationManager: MockNotificationManager!
    private var mockRateLimiter: MockRateLimitingService!
    private var mockPublicDatabase: MockCKDatabase!
    private var mockPrivateDatabase: MockCKDatabase!

    override func setUp() {
        super.setUp()

        mockCloudKitManager = MockCloudKitManager()
        mockCloudKitManager.currentUserID = "test-user"

        mockUserProfileService = MockUserProfileService()
        mockNotificationManager = MockNotificationManager()
        mockRateLimiter = MockRateLimitingService()
        mockPublicDatabase = MockCKDatabase()
        mockPrivateDatabase = MockCKDatabase()

        sut = TestableWorkoutChallengesService(
            cloudKitManager: mockCloudKitManager,
            userProfileService: mockUserProfileService,
            notificationManager: mockNotificationManager,
            rateLimiter: mockRateLimiter
        )
    }

    override func tearDown() {
        sut = nil
        mockCloudKitManager = nil
        mockUserProfileService = nil
        mockNotificationManager = nil
        mockRateLimiter = nil
        mockPublicDatabase = nil
        mockPrivateDatabase = nil
        super.tearDown()
    }

    // MARK: - Create Challenge Tests

    func testCreateChallenge_Success() async throws {
        // Given
        let participants = [
            ChallengeParticipant(id: "test-user", username: "TestUser", profileImageURL: nil),
            ChallengeParticipant(id: "user-2", username: "User2", profileImageURL: nil)
        ]

        let challenge = WorkoutChallenge(
            id: "new-challenge",
            creatorId: "test-user",
            participants: participants,
            type: .distance,
            targetValue: 50.0,
            workoutType: nil,
            name: "50km Distance Challenge",
            description: "Run 50km this week",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 24 * 3_600),
            createdTimestamp: Date(),
            status: .pending,
            winnerId: nil,
            xpStake: 0,
            winnerTakesAll: false,
            isPublic: true,
            maxParticipants: 10,
            joinCode: nil
        )

        // When
        let createdChallenge = try await sut.createChallenge(challenge)

        // Then
        XCTAssertEqual(createdChallenge.status, ChallengeStatus.pending)
        XCTAssertEqual(mockRateLimiter.recordActionCallCount, 1)
        XCTAssertGreaterThanOrEqual(
            mockNotificationManager.scheduleNotificationCallCount,
            1
        ) // At least one notification
    }

    func testCreateChallenge_NotAuthenticated() async {
        // Given
        mockCloudKitManager.currentUserID = nil
        let challenge = MockWorkoutChallengesService.createMockChallenge()

        // When/Then
        do {
            _ = try await sut.createChallenge(challenge)
            XCTFail("Should throw notAuthenticated error")
        } catch let error as ChallengeError {
            XCTAssertEqual(error, ChallengeError.notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateChallenge_InvalidChallenge() async {
        // Given - Invalid target value
        let challenge = MockWorkoutChallengesService.createMockChallenge(
            targetValue: -10 // Invalid negative value
        )

        // When/Then
        do {
            _ = try await sut.createChallenge(challenge)
            XCTFail("Should throw invalidChallenge error")
        } catch let error as ChallengeError {
            XCTAssertEqual(error, ChallengeError.invalidChallenge)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateChallenge_RateLimited() async {
        // Given
        mockRateLimiter.shouldThrowError = true
        mockRateLimiter.errorToThrow = RateLimitError.limitExceeded(action: "workoutPost", resetTime: Date())
        let challenge = MockWorkoutChallengesService.createMockChallenge()

        print("DEBUG: Mock rate limiter shouldThrowError: \(mockRateLimiter.shouldThrowError)")
        print("DEBUG: Mock rate limiter errorToThrow: \(String(describing: mockRateLimiter.errorToThrow))")

        // When/Then
        do {
            _ = try await sut.createChallenge(challenge)
            XCTFail("Should throw rateLimited error")
        } catch let error as ChallengeError {
            print("DEBUG: Caught ChallengeError: \(error)")
            XCTAssertEqual(error, ChallengeError.rateLimited)
        } catch {
            print("DEBUG: Caught unexpected error: \(error)")
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Accept Challenge Tests

    func testAcceptChallenge_Success() async throws {
        // Given
        let challengeId = "test-challenge"
        sut.setMockRecord(
            createMockChallengeRecord(
                id: challengeId,
                status: .pending,
                participants: ["test-user", "user-2"]
            ),
            for: challengeId
        )

        // When
        let acceptedChallenge = try await sut.acceptChallenge(challengeId: challengeId)

        // Then
        XCTAssertEqual(acceptedChallenge.status, .active)
        XCTAssertEqual(mockNotificationManager.scheduleNotificationCallCount, 2) // Notify both participants
    }

    func testAcceptChallenge_NotParticipant() async {
        // Given
        let challengeId = "test-challenge"
        sut.setMockRecord(
            createMockChallengeRecord(
                id: challengeId,
                status: .pending,
                participants: ["other-user-1", "other-user-2"] // test-user not included
            ),
            for: challengeId
        )

        // When/Then
        do {
            _ = try await sut.acceptChallenge(challengeId: challengeId)
            XCTFail("Should throw notParticipant error")
        } catch let error as ChallengeError {
            XCTAssertEqual(error, ChallengeError.notParticipant)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAcceptChallenge_InvalidStatus() async {
        // Given
        let challengeId = "test-challenge"
        sut.setMockRecord(
            createMockChallengeRecord(
                id: challengeId,
                status: .completed, // Cannot accept completed challenge
                participants: ["test-user", "user-2"]
            ),
            for: challengeId
        )

        // When/Then
        do {
            _ = try await sut.acceptChallenge(challengeId: challengeId)
            XCTFail("Should throw invalidStatus error")
        } catch let error as ChallengeError {
            XCTAssertEqual(error, ChallengeError.invalidStatus)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Update Progress Tests

    func testUpdateProgress_Success() async throws {
        // Given
        let challengeId = "test-challenge"
        let participants = [
            ChallengeParticipant(id: "test-user", username: "TestUser", profileImageURL: nil, progress: 0),
            ChallengeParticipant(id: "user-2", username: "User2", profileImageURL: nil, progress: 0)
        ]

        sut.setMockRecord(
            createMockChallengeRecord(
                id: challengeId,
                status: .active,
                participants: ["test-user", "user-2"],
                participantData: participants
            ),
            for: challengeId
        )

        // When
        try await sut.updateProgress(challengeId: challengeId, progress: 25.5, workoutId: "workout-123")

        // Then
        XCTAssertEqual(mockCloudKitManager.saveCallCount, 1)
    }

    func testUpdateProgress_ReachesTarget_CompletesChallenge() async throws {
        // Given
        let challengeId = "test-challenge"
        let targetValue = 50.0
        let participants = [
            ChallengeParticipant(id: "test-user", username: "TestUser", profileImageURL: nil, progress: 45),
            ChallengeParticipant(id: "user-2", username: "User2", profileImageURL: nil, progress: 30)
        ]

        sut.setMockRecord(
            createMockChallengeRecord(
                id: challengeId,
                status: .active,
                participants: ["test-user", "user-2"],
                participantData: participants,
                targetValue: targetValue
            ),
            for: challengeId
        )

        // When - Update progress to exceed target
        try await sut.updateProgress(challengeId: challengeId, progress: 55.0, workoutId: nil)

        // Then - Should trigger completion
        XCTAssertGreaterThanOrEqual(
            mockNotificationManager.scheduleNotificationCallCount,
            2
        ) // Completion notifications
    }

    func testUpdateProgress_ChallengeNotActive() async {
        // Given
        let challengeId = "test-challenge"
        sut.setMockRecord(
            createMockChallengeRecord(
                id: challengeId,
                status: .pending, // Not active
                participants: ["test-user", "user-2"]
            ),
            for: challengeId
        )

        // When/Then
        do {
            try await sut.updateProgress(challengeId: challengeId, progress: 10.0, workoutId: nil)
            XCTFail("Should throw challengeNotActive error")
        } catch let error as ChallengeError {
            XCTAssertEqual(error, ChallengeError.challengeNotActive)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Complete Challenge Tests

    func testCompleteChallenge_Success() async throws {
        // Given
        let challengeId = "test-challenge"
        let participants = [
            ChallengeParticipant(id: "test-user", username: "TestUser", profileImageURL: nil, progress: 55),
            ChallengeParticipant(id: "user-2", username: "User2", profileImageURL: nil, progress: 45)
        ]

        sut.setMockRecord(
            createMockChallengeRecord(
                id: challengeId,
                status: .active,
                participants: ["test-user", "user-2"],
                participantData: participants,
                xpStake: 100
            ),
            for: challengeId
        )

        // When
        let completedChallenge = try await sut.completeChallenge(challengeId: challengeId)

        // Then
        XCTAssertEqual(completedChallenge.status, .completed)
        XCTAssertEqual(completedChallenge.winnerId, "test-user") // Highest progress
        XCTAssertGreaterThanOrEqual(mockNotificationManager.scheduleNotificationCallCount, 2) // Notify all participants
    }

    // MARK: - Fetch Challenges Tests

    func testFetchActiveChallenge_Success() async throws {
        // Given
        sut.setMockQueryResults([
            createMockChallengeRecord(id: "active-1", status: .active, participants: ["test-user", "user-2"]),
            createMockChallengeRecord(id: "active-2", status: .active, participants: ["test-user", "user-3"])
        ])

        // When
        let activeChallenges = try await sut.fetchActiveChallenge(for: "test-user")

        // Then
        XCTAssertEqual(activeChallenges.count, 2)
        XCTAssertTrue(activeChallenges.allSatisfy { $0.status == .active })
    }

    func testFetchPendingChallenge_Success() async throws {
        // Given
        sut.setMockQueryResults([
            createMockChallengeRecord(id: "pending-1", status: .pending, participants: ["test-user", "user-2"])
        ])

        // When
        let pendingChallenges = try await sut.fetchPendingChallenge(for: "test-user")

        // Then
        XCTAssertEqual(pendingChallenges.count, 1)
        XCTAssertEqual(pendingChallenges[0].status, .pending)
    }

    func testGetChallengeSuggestions_Success() async throws {
        // Given
        sut.setMockQueryResults([
            createMockChallengeRecord(
                id: "public-1",
                status: .pending,
                participants: ["user-1", "user-2"],
                isPublic: true
            ),
            createMockChallengeRecord(
                id: "public-2",
                status: .pending,
                participants: ["user-3", "user-4"],
                isPublic: true
            )
        ])

        // When
        let suggestions = try await sut.getChallengeSuggestions(for: "test-user")

        // Then
        XCTAssertEqual(suggestions.count, 2)
        XCTAssertTrue(suggestions.allSatisfy(\.isPublic))
    }

    // MARK: - Helper Methods

    private func createMockChallengeRecord(
        id: String,
        status: ChallengeStatus,
        participants: [String],
        participantData: [ChallengeParticipant]? = nil,
        targetValue: Double = 50.0,
        xpStake: Int = 0,
        isPublic: Bool = true
    ) -> CKRecord {
        let record = CKRecord(recordType: "WorkoutChallenges", recordID: CKRecord.ID(recordName: id))

        let actualParticipants = participantData ?? participants.map { userId in
            ChallengeParticipant(id: userId, username: "User\(userId)", profileImageURL: nil)
        }

        record["creatorId"] = participants.first ?? "test-user"
        record["participants"] = try? JSONEncoder().encode(actualParticipants)
        record["type"] = ChallengeType.distance.rawValue
        record["targetValue"] = targetValue
        record["name"] = "Test Challenge"
        record["description"] = "Test Description"
        record["startDate"] = Date()
        record["endDate"] = Date().addingTimeInterval(7 * 24 * 3_600)
        record["createdAt"] = Date()
        record["status"] = status.rawValue
        record["xpStake"] = Int64(xpStake)
        record["winnerTakesAll"] = Int64(0)
        record["isPublic"] = isPublic ? Int64(1) : Int64(0)

        return record
    }
}
