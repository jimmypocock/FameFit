//
//  WorkoutChallengeTests.swift
//  FameFitTests
//
//  Tests for WorkoutChallenge model
//

@testable import FameFit
import XCTest

final class WorkoutChallengeTests: XCTestCase {
    // MARK: - Challenge Type Tests

    func testChallengeType_DisplayNames() {
        XCTAssertEqual(ChallengeType.distance.displayName, "Distance Challenge")
        XCTAssertEqual(ChallengeType.duration.displayName, "Duration Challenge")
        XCTAssertEqual(ChallengeType.calories.displayName, "Calorie Burn Challenge")
        XCTAssertEqual(ChallengeType.workoutCount.displayName, "Workout Count Challenge")
        XCTAssertEqual(ChallengeType.totalXP.displayName, "XP Challenge")
        XCTAssertEqual(ChallengeType.specificWorkout.displayName, "Workout Type Challenge")
    }

    func testChallengeType_Icons() {
        XCTAssertEqual(ChallengeType.distance.icon, "📏")
        XCTAssertEqual(ChallengeType.duration.icon, "⏱️")
        XCTAssertEqual(ChallengeType.calories.icon, "🔥")
        XCTAssertEqual(ChallengeType.workoutCount.icon, "🏃")
        XCTAssertEqual(ChallengeType.totalXP.icon, "⭐")
        XCTAssertEqual(ChallengeType.specificWorkout.icon, "💪")
    }

    func testChallengeType_Units() {
        XCTAssertEqual(ChallengeType.distance.unit, "km")
        XCTAssertEqual(ChallengeType.duration.unit, "minutes")
        XCTAssertEqual(ChallengeType.calories.unit, "cal")
        XCTAssertEqual(ChallengeType.workoutCount.unit, "workouts")
        XCTAssertEqual(ChallengeType.totalXP.unit, "XP")
        XCTAssertEqual(ChallengeType.specificWorkout.unit, "workouts")
    }

    // MARK: - Challenge Status Tests

    func testChallengeStatus_CanBeAccepted() {
        XCTAssertTrue(ChallengeStatus.pending.canBeAccepted)
        XCTAssertFalse(ChallengeStatus.accepted.canBeAccepted)
        XCTAssertFalse(ChallengeStatus.declined.canBeAccepted)
        XCTAssertFalse(ChallengeStatus.active.canBeAccepted)
        XCTAssertFalse(ChallengeStatus.completed.canBeAccepted)
        XCTAssertFalse(ChallengeStatus.cancelled.canBeAccepted)
        XCTAssertFalse(ChallengeStatus.expired.canBeAccepted)
    }

    func testChallengeStatus_IsActive() {
        XCTAssertTrue(ChallengeStatus.active.isActive)
        XCTAssertFalse(ChallengeStatus.pending.isActive)
        XCTAssertFalse(ChallengeStatus.completed.isActive)
    }

    func testChallengeStatus_IsFinished() {
        XCTAssertTrue(ChallengeStatus.completed.isFinished)
        XCTAssertTrue(ChallengeStatus.cancelled.isFinished)
        XCTAssertTrue(ChallengeStatus.expired.isFinished)
        XCTAssertFalse(ChallengeStatus.pending.isFinished)
        XCTAssertFalse(ChallengeStatus.active.isFinished)
        XCTAssertFalse(ChallengeStatus.accepted.isFinished)
        XCTAssertFalse(ChallengeStatus.declined.isFinished)
    }

    // MARK: - WorkoutChallenge Tests

    func testWorkoutChallenge_IsExpired() {
        // Given - Challenge that ended yesterday
        let challenge = createChallenge(
            status: .active,
            endDate: Date().addingTimeInterval(-24 * 3_600)
        )

        // Then
        XCTAssertTrue(challenge.isExpired)
    }

    func testWorkoutChallenge_NotExpired_WhenNotActive() {
        // Given - Ended challenge but not active
        let challenge = createChallenge(
            status: .pending,
            endDate: Date().addingTimeInterval(-24 * 3_600)
        )

        // Then
        XCTAssertFalse(challenge.isExpired)
    }

    func testWorkoutChallenge_DaysRemaining() {
        // Given - Challenge ending in exactly 3 days from start of today
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let threeDaysFromToday = calendar.date(byAdding: .day, value: 3, to: startOfToday)!
        // Add 1 hour to ensure it's not at the very start of the day
        let endDate = calendar.date(byAdding: .hour, value: 1, to: threeDaysFromToday)!
        let challenge = createChallenge(endDate: endDate)

        // Then - The implementation adds 1 to include the end date
        XCTAssertEqual(challenge.daysRemaining, 4)
    }

    func testWorkoutChallenge_DaysRemaining_WhenPast() {
        // Given - Challenge ended 2 days ago
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let challenge = createChallenge(endDate: twoDaysAgo)

        // Then
        XCTAssertEqual(challenge.daysRemaining, 0)
    }

    func testWorkoutChallenge_ProgressPercentage() {
        // Given
        var challenge = createChallenge(targetValue: 100)
        challenge.participants = [
            ChallengeParticipant(id: "1", username: "User1", profileImageURL: nil, progress: 30),
            ChallengeParticipant(id: "2", username: "User2", profileImageURL: nil, progress: 50)
        ]

        // Then - Average progress is 40%
        XCTAssertEqual(challenge.progressPercentage, 40.0)
    }

    func testWorkoutChallenge_ProgressPercentage_CappedAt100() {
        // Given
        var challenge = createChallenge(targetValue: 50)
        challenge.participants = [
            ChallengeParticipant(id: "1", username: "User1", profileImageURL: nil, progress: 60),
            ChallengeParticipant(id: "2", username: "User2", profileImageURL: nil, progress: 80)
        ]

        // Then - Should be capped at 100%
        XCTAssertEqual(challenge.progressPercentage, 100.0)
    }

    func testWorkoutChallenge_LeadingParticipant() {
        // Given
        var challenge = createChallenge()
        challenge.participants = [
            ChallengeParticipant(id: "1", username: "User1", profileImageURL: nil, progress: 30),
            ChallengeParticipant(id: "2", username: "User2", profileImageURL: nil, progress: 50),
            ChallengeParticipant(id: "3", username: "User3", profileImageURL: nil, progress: 45)
        ]

        // Then
        let leader = challenge.leadingParticipant
        XCTAssertEqual(leader?.id, "2")
        XCTAssertEqual(leader?.progress, 50)
    }

    // MARK: - Validation Tests

    func testWorkoutChallenge_ValidChallenge() {
        // Valid challenges
        XCTAssertTrue(WorkoutChallenge.isValidChallenge(type: .distance, targetValue: 50, duration: 7 * 24 * 3_600))
        XCTAssertTrue(WorkoutChallenge.isValidChallenge(type: .duration, targetValue: 1_000, duration: 24 * 3_600))
        XCTAssertTrue(WorkoutChallenge.isValidChallenge(type: .calories, targetValue: 5_000, duration: 3 * 24 * 3_600))
        XCTAssertTrue(WorkoutChallenge.isValidChallenge(type: .workoutCount, targetValue: 20, duration: 14 * 24 * 3_600))
        XCTAssertTrue(WorkoutChallenge.isValidChallenge(type: .totalXP, targetValue: 500, duration: 7 * 24 * 3_600))
        XCTAssertTrue(WorkoutChallenge.isValidChallenge(
            type: .specificWorkout,
            targetValue: 10,
            duration: 7 * 24 * 3_600
        ))
    }

    func testWorkoutChallenge_InvalidChallenge_NegativeValues() {
        XCTAssertFalse(WorkoutChallenge.isValidChallenge(type: .distance, targetValue: -10, duration: 7 * 24 * 3_600))
        XCTAssertFalse(WorkoutChallenge.isValidChallenge(type: .distance, targetValue: 50, duration: -100))
        XCTAssertFalse(WorkoutChallenge.isValidChallenge(type: .distance, targetValue: 0, duration: 7 * 24 * 3_600))
    }

    func testWorkoutChallenge_InvalidChallenge_ExceedsLimits() {
        XCTAssertFalse(WorkoutChallenge.isValidChallenge(type: .distance, targetValue: 1_001, duration: 7 * 24 * 3_600))
        XCTAssertFalse(WorkoutChallenge.isValidChallenge(type: .duration, targetValue: 10_001, duration: 7 * 24 * 3_600))
        XCTAssertFalse(WorkoutChallenge.isValidChallenge(type: .calories, targetValue: 50_001, duration: 7 * 24 * 3_600))
        XCTAssertFalse(WorkoutChallenge.isValidChallenge(
            type: .workoutCount,
            targetValue: 101,
            duration: 7 * 24 * 3_600
        ))
        XCTAssertFalse(WorkoutChallenge.isValidChallenge(type: .totalXP, targetValue: 10_001, duration: 7 * 24 * 3_600))
        XCTAssertFalse(WorkoutChallenge.isValidChallenge(
            type: .specificWorkout,
            targetValue: 51,
            duration: 7 * 24 * 3_600
        ))
    }

    // MARK: - CloudKit Conversion Tests

    func testWorkoutChallenge_CloudKitConversion() throws {
        // Given
        let originalChallenge = createChallenge(
            id: "test-123",
            creatorId: "creator-456",
            type: .distance,
            targetValue: 42.5,
            status: .active,
            xpStake: 250,
            winnerTakesAll: true,
            isPublic: false
        )

        // When - Convert to CKRecord and back
        let record = originalChallenge.toCKRecord()
        let convertedChallenge = WorkoutChallenge(from: record)

        // Then
        XCTAssertNotNil(convertedChallenge)
        XCTAssertEqual(convertedChallenge?.id, originalChallenge.id)
        XCTAssertEqual(convertedChallenge?.creatorId, originalChallenge.creatorId)
        XCTAssertEqual(convertedChallenge?.type, originalChallenge.type)
        XCTAssertEqual(convertedChallenge?.targetValue, originalChallenge.targetValue)
        XCTAssertEqual(convertedChallenge?.status, originalChallenge.status)
        XCTAssertEqual(convertedChallenge?.xpStake, originalChallenge.xpStake)
        XCTAssertEqual(convertedChallenge?.winnerTakesAll, originalChallenge.winnerTakesAll)
        XCTAssertEqual(convertedChallenge?.isPublic, originalChallenge.isPublic)
    }

    // MARK: - Helper Methods

    private func createChallenge(
        id: String = "test-challenge",
        creatorId: String = "creator-123",
        type: ChallengeType = .distance,
        targetValue: Double = 50.0,
        status: ChallengeStatus = .pending,
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(7 * 24 * 3_600),
        xpStake: Int = 0,
        winnerTakesAll: Bool = false,
        isPublic: Bool = true,
        maxParticipants: Int = 10,
        joinCode: String? = nil
    ) -> WorkoutChallenge {
        WorkoutChallenge(
            id: id,
            creatorId: creatorId,
            participants: [
                ChallengeParticipant(id: creatorId, username: "Creator", profileImageURL: nil),
                ChallengeParticipant(id: "participant-2", username: "Participant2", profileImageURL: nil)
            ],
            type: type,
            targetValue: targetValue,
            workoutType: type == .specificWorkout ? "Running" : nil,
            name: "\(type.displayName) Test",
            description: "Test challenge",
            startDate: startDate,
            endDate: endDate,
            createdTimestamp: Date(),
            status: status,
            winnerId: nil,
            xpStake: xpStake,
            winnerTakesAll: winnerTakesAll,
            isPublic: isPublic,
            maxParticipants: maxParticipants,
            joinCode: joinCode
        )
    }
}
