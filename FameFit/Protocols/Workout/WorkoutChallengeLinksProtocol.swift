//
//  WorkoutChallengeLinksProtocol.swift
//  FameFit
//
//  Protocol for workout challenge links service operations
//

import Foundation

protocol WorkoutChallengeLinksProtocol {
    // Create and manage links
    func createLink(workoutID: String, workoutChallengeID: String, userID: String, contributionValue: Double, contributionType: String, workoutDate: Date) async throws -> WorkoutChallengeLink
    func verifyLink(linkID: String) async throws -> WorkoutChallengeLink
    func deleteLink(linkID: String) async throws
    
    // Verification methods
    func requestManualVerification(linkID: String, note: String?) async throws -> WorkoutChallengeLink
    func approveManualVerification(linkID: String) async throws -> WorkoutChallengeLink
    func verifyWithGracePeriod(linkID: String, challengeEndDate: Date) async throws -> WorkoutChallengeLink
    func retryVerificationWithBackoff(linkID: String) async throws -> WorkoutChallengeLink
    
    // Query links
    func fetchLinks(for workoutChallengeID: String) async throws -> [WorkoutChallengeLink]
    func fetchLinks(for workoutID: String, in workoutChallengeIDs: [String]) async throws -> [WorkoutChallengeLink]
    func fetchUserLinks(userID: String, workoutChallengeID: String) async throws -> [WorkoutChallengeLink]
    func fetchVerifiedLinks(for workoutChallengeID: String) async throws -> [WorkoutChallengeLink]
    
    // Progress calculations
    func calculateTotalProgress(for workoutChallengeID: String) async throws -> Double
    func calculateUserProgress(userID: String, workoutChallengeID: String) async throws -> Double
    func getLeaderboard(for workoutChallengeID: String) async throws -> [(userID: String, progress: Double)]
    
    // Bulk operations for workout completion
    func processWorkoutForChallenges(workout: Workout, userID: String, activeChallengeIDs: [String]) async throws -> [WorkoutChallengeLink]
}