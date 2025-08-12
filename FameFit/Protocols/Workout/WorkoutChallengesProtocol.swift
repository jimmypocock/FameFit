//
//  WorkoutChallengesProtocol.swift
//  FameFit
//
//  Protocol for workout challenges service operations
//

import Foundation

protocol WorkoutChallengesProtocol {
    func createChallenge(_ challenge: WorkoutChallenge) async throws -> WorkoutChallenge
    func acceptChallenge(workoutChallengeID: String) async throws -> WorkoutChallenge
    func declineChallenge(workoutChallengeID: String) async throws
    func cancelChallenge(workoutChallengeID: String) async throws
    func updateProgress(workoutChallengeID: String, progress: Double, workoutID: String?) async throws
    func completeChallenge(workoutChallengeID: String) async throws -> WorkoutChallenge
    func fetchActiveChallenge(for userID: String) async throws -> [WorkoutChallenge]
    func fetchPendingChallenge(for userID: String) async throws -> [WorkoutChallenge]
    func fetchCompletedChallenge(for userID: String) async throws -> [WorkoutChallenge]
    func fetchChallenge(workoutChallengeID: String) async throws -> WorkoutChallenge
    func inviteToChallenge(workoutChallengeID: String, userIDs: [String]) async throws
    func getChallengeSuggestions(for userID: String) async throws -> [WorkoutChallenge]
}