//
//  ActivityFeedProtocol.swift
//  FameFit
//
//  Protocol for activity feed service operations
//

import Combine
import Foundation

protocol ActivityFeedProtocol {
    func postWorkoutActivity(
        workout: Workout,
        privacy: WorkoutPrivacy,
        includeDetails: Bool
    ) async throws
    
    func postAchievementActivity(
        achievementName: String,
        xpEarned: Int,
        privacy: WorkoutPrivacy
    ) async throws
    
    func postLevelUpActivity(
        newLevel: Int,
        newTitle: String,
        privacy: WorkoutPrivacy
    ) async throws
    
    func fetchFeed(for userIDs: Set<String>, since: Date?, limit: Int) async throws -> [ActivityFeedRecord]
    func deleteActivity(_ activityID: String) async throws
    func updateActivityPrivacy(_ activityID: String, newPrivacy: WorkoutPrivacy) async throws
    
    // Publishers for real-time updates
    var newActivityPublisher: AnyPublisher<ActivityFeedRecord, Never> { get }
    var privacyUpdatePublisher: AnyPublisher<(String, WorkoutPrivacy), Never> { get }
}