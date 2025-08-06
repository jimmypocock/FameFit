//
//  MockWorkoutChallengesService.swift
//  FameFitTests
//
//  Mock implementation of WorkoutChallengesService for testing
//

@testable import FameFit
import Foundation

final class MockWorkoutChallengesService: WorkoutChallengesServicing {
    // MARK: - Properties

    var challenges: [WorkoutChallenge] = []
    var shouldThrowError = false
    var error: Error = ChallengeError.saveFailed

    // Call tracking
    var createChallengeCallCount = 0
    var acceptChallengeCallCount = 0
    var declineChallengeCallCount = 0
    var updateProgressCallCount = 0
    var completeChallengeCallCount = 0
    var lastUpdateProgress: (challengeId: String, progress: Double, workoutId: String?)?

    // MARK: - Mock Data

    static func createMockChallenge(
        id: String = UUID().uuidString,
        creatorId: String = "creator-123",
        participants: [ChallengeParticipant]? = nil,
        type: ChallengeType = .distance,
        targetValue: Double = 10.0,
        status: ChallengeStatus = .pending,
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(7 * 24 * 3_600)
    ) -> WorkoutChallenge {
        let defaultParticipants = participants ?? [
            ChallengeParticipant(
                id: creatorId,
                displayName: "Creator",
                profileImageURL: nil,
                progress: 0
            ),
            ChallengeParticipant(
                id: "participant-456",
                displayName: "Participant",
                profileImageURL: nil,
                progress: 0
            )
        ]

        return WorkoutChallenge(
            id: id,
            creatorId: creatorId,
            participants: defaultParticipants,
            type: type,
            targetValue: targetValue,
            workoutType: type == .specificWorkout ? "Running" : nil,
            name: "\(type.displayName) Challenge",
            description: "Reach \(Int(targetValue)) \(type.unit)",
            startDate: startDate,
            endDate: endDate,
            createdTimestamp: Date(),
            status: status,
            winnerId: nil,
            xpStake: 100,
            winnerTakesAll: false,
            isPublic: true
        )
    }

    // MARK: - WorkoutChallengesServicing

    func createChallenge(_ challenge: WorkoutChallenge) async throws -> WorkoutChallenge {
        createChallengeCallCount += 1

        if shouldThrowError {
            throw error
        }

        var newChallenge = challenge
        newChallenge.status = .pending
        challenges.append(newChallenge)

        return newChallenge
    }

    func acceptChallenge(challengeId: String) async throws -> WorkoutChallenge {
        acceptChallengeCallCount += 1

        if shouldThrowError {
            throw error
        }

        guard let index = challenges.firstIndex(where: { $0.id == challengeId }) else {
            throw ChallengeError.challengeNotFound
        }

        challenges[index].status = .active
        return challenges[index]
    }

    func declineChallenge(challengeId: String) async throws {
        declineChallengeCallCount += 1

        if shouldThrowError {
            throw error
        }

        guard let index = challenges.firstIndex(where: { $0.id == challengeId }) else {
            throw ChallengeError.challengeNotFound
        }

        challenges[index].status = .declined
    }

    func cancelChallenge(challengeId: String) async throws {
        if shouldThrowError {
            throw error
        }

        guard let index = challenges.firstIndex(where: { $0.id == challengeId }) else {
            throw ChallengeError.challengeNotFound
        }

        challenges[index].status = .cancelled
    }

    func updateProgress(challengeId: String, progress: Double, workoutId: String?) async throws {
        updateProgressCallCount += 1
        lastUpdateProgress = (challengeId, progress, workoutId)

        if shouldThrowError {
            throw error
        }

        guard let challengeIndex = challenges.firstIndex(where: { $0.id == challengeId }) else {
            throw ChallengeError.challengeNotFound
        }

        // Find participant (assume first one for testing)
        if let participantIndex = challenges[challengeIndex].participants.firstIndex(where: { $0.id == "test-user" }) {
            challenges[challengeIndex].participants[participantIndex].progress = progress
            challenges[challengeIndex].participants[participantIndex].lastUpdated = Date()

            // Auto-complete if target reached
            if progress >= challenges[challengeIndex].targetValue {
                challenges[challengeIndex].status = .completed
                challenges[challengeIndex].winnerId = "test-user"
            }
        }
    }

    func completeChallenge(challengeId: String) async throws -> WorkoutChallenge {
        completeChallengeCallCount += 1

        if shouldThrowError {
            throw error
        }

        guard let index = challenges.firstIndex(where: { $0.id == challengeId }) else {
            throw ChallengeError.challengeNotFound
        }

        challenges[index].status = .completed

        // Set winner to participant with highest progress
        if let winner = challenges[index].leadingParticipant {
            challenges[index].winnerId = winner.id
        }

        return challenges[index]
    }

    func fetchActiveChallenge(for userId: String) async throws -> [WorkoutChallenge] {
        if shouldThrowError {
            throw error
        }

        return challenges.filter { challenge in
            challenge.status == .active &&
                challenge.participants.contains(where: { $0.id == userId })
        }
    }

    func fetchPendingChallenge(for userId: String) async throws -> [WorkoutChallenge] {
        if shouldThrowError {
            throw error
        }

        return challenges.filter { challenge in
            challenge.status == .pending &&
                challenge.participants.contains(where: { $0.id == userId })
        }
    }

    func fetchCompletedChallenge(for userId: String) async throws -> [WorkoutChallenge] {
        if shouldThrowError {
            throw error
        }

        return challenges.filter { challenge in
            challenge.status == .completed &&
                challenge.participants.contains(where: { $0.id == userId })
        }
    }

    func fetchChallenge(challengeId: String) async throws -> WorkoutChallenge {
        if shouldThrowError {
            throw error
        }

        guard let challenge = challenges.first(where: { $0.id == challengeId }) else {
            throw ChallengeError.challengeNotFound
        }

        return challenge
    }

    func inviteToChallenge(challengeId _: String, userIds _: [String]) async throws {
        if shouldThrowError {
            throw error
        }

        // Not implemented for mock
    }

    func getChallengeSuggestions(for userId: String) async throws -> [WorkoutChallenge] {
        if shouldThrowError {
            throw error
        }

        // Return public challenges user is not part of
        return challenges.filter { challenge in
            challenge.isPublic &&
                challenge.status == .pending &&
                !challenge.participants.contains(where: { $0.id == userId })
        }
    }

    // MARK: - Test Helpers

    func reset() {
        challenges = []
        shouldThrowError = false
        createChallengeCallCount = 0
        acceptChallengeCallCount = 0
        declineChallengeCallCount = 0
        updateProgressCallCount = 0
        completeChallengeCallCount = 0
        lastUpdateProgress = nil
    }

    func addMockChallenges() {
        // Active challenge
        challenges.append(MockWorkoutChallengesService.createMockChallenge(
            id: "active-1",
            type: .distance,
            targetValue: 50,
            status: .active
        ))

        // Pending challenge
        challenges.append(MockWorkoutChallengesService.createMockChallenge(
            id: "pending-1",
            type: .calories,
            targetValue: 2_000,
            status: .pending
        ))

        // Completed challenge
        var completedChallenge = MockWorkoutChallengesService.createMockChallenge(
            id: "completed-1",
            type: .workoutCount,
            targetValue: 10,
            status: .completed
        )
        completedChallenge.winnerId = completedChallenge.participants[0].id
        challenges.append(completedChallenge)
    }
}
