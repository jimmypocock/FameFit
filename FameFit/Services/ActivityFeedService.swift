//
//  ActivityFeedService.swift
//  FameFit
//
//  Service for managing activity feed items from workout completions
//

import CloudKit
import Combine
import Foundation
import HealthKit

// MARK: - Activity Feed Item Model

struct ActivityFeedItem: Codable, Identifiable, Equatable {
    let id: String
    let userID: String
    let activityType: String
    let workoutId: String?
    let content: String // JSON encoded content
    let visibility: String // "private", "friends_only", "public"
    let createdTimestamp: Date
    let expiresAt: Date
    let xpEarned: Int?
    let achievementName: String?

    // Computed properties for UI display
    var privacyLevel: WorkoutPrivacy {
        WorkoutPrivacy(rawValue: visibility) ?? .private
    }

    var contentData: FeedContent? {
        guard let data = content.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(FeedContent.self, from: data)
    }

    static func == (lhs: ActivityFeedItem, rhs: ActivityFeedItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Activity Feed Service Protocol

protocol ActivityFeedServicing {
    func postWorkoutActivity(
        workoutHistory: WorkoutHistoryItem,
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

    func fetchFeed(for userIds: Set<String>, since: Date?, limit: Int) async throws -> [ActivityFeedItem]
    func deleteActivity(_ activityId: String) async throws
    func updateActivityPrivacy(_ activityId: String, newPrivacy: WorkoutPrivacy) async throws

    // Publishers for real-time updates
    var newActivityPublisher: AnyPublisher<ActivityFeedItem, Never> { get }
    var privacyUpdatePublisher: AnyPublisher<(String, WorkoutPrivacy), Never> { get }
}

// MARK: - Activity Feed Service Implementation

final class ActivityFeedService: ActivityFeedServicing {
    private let cloudKitManager: any CloudKitManaging
    private let privacySettings: WorkoutPrivacySettings

    // Publishers
    private let newActivitySubject = PassthroughSubject<ActivityFeedItem, Never>()
    private let privacyUpdateSubject = PassthroughSubject<(String, WorkoutPrivacy), Never>()

    var newActivityPublisher: AnyPublisher<ActivityFeedItem, Never> {
        newActivitySubject.eraseToAnyPublisher()
    }

    var privacyUpdatePublisher: AnyPublisher<(String, WorkoutPrivacy), Never> {
        privacyUpdateSubject.eraseToAnyPublisher()
    }

    init(cloudKitManager: any CloudKitManaging, privacySettings: WorkoutPrivacySettings) {
        self.cloudKitManager = cloudKitManager
        self.privacySettings = privacySettings
    }

    // MARK: - Post Activity Methods

    func postWorkoutActivity(
        workoutHistory: WorkoutHistoryItem,
        privacy: WorkoutPrivacy,
        includeDetails: Bool
    ) async throws {
        // Validate privacy settings
        guard let workoutType = HKWorkoutActivityType.from(storageKey: workoutHistory.workoutType) else {
            throw ActivityFeedError.invalidWorkoutType
        }

        let effectivePrivacy = privacySettings.effectivePrivacy(for: workoutType)
        let finalPrivacy = min(privacy, effectivePrivacy) // Use most restrictive

        // Don't post private workouts
        guard finalPrivacy != .private else { return }

        // Create content
        let content = createWorkoutContent(
            from: workoutHistory,
            includeDetails: includeDetails && privacySettings.allowDataSharing
        )

        let contentData = try JSONEncoder().encode(content)
        guard let contentString = String(data: contentData, encoding: .utf8) else {
            throw ActivityFeedError.encodingFailed
        }

        // Create activity feed item
        let activityItem = ActivityFeedItem(
            id: UUID().uuidString,
            userID: cloudKitManager.currentUserID ?? "",
            activityType: "workout",
            workoutId: workoutHistory.id.uuidString,
            content: contentString,
            visibility: finalPrivacy.rawValue,
            createdTimestamp: Date(),
            expiresAt: Date().addingTimeInterval(30 * 24 * 3_600), // 30 days
            xpEarned: workoutHistory.followersEarned,
            achievementName: nil
        )

        try await saveToCloudKit(activityItem)

        // Notify subscribers
        newActivitySubject.send(activityItem)
    }

    func postAchievementActivity(
        achievementName: String,
        xpEarned: Int,
        privacy: WorkoutPrivacy
    ) async throws {
        // Check if achievement sharing is enabled
        guard privacySettings.shareAchievements else { return }

        let effectivePrivacy = min(privacy, privacySettings.allowPublicSharing ? .public : .friendsOnly)
        guard effectivePrivacy != .private else { return }

        let content = FeedContent(
            title: "Earned the '\(achievementName)' achievement!",
            subtitle: "Unlocked with \(xpEarned) XP",
            details: [
                "achievementName": achievementName,
                "xpEarned": String(xpEarned),
                "achievementIcon": "trophy.fill"
            ]
        )

        let contentData = try JSONEncoder().encode(content)
        guard let contentString = String(data: contentData, encoding: .utf8) else {
            throw ActivityFeedError.encodingFailed
        }

        let activityItem = ActivityFeedItem(
            id: UUID().uuidString,
            userID: cloudKitManager.currentUserID ?? "",
            activityType: "achievement",
            workoutId: nil,
            content: contentString,
            visibility: effectivePrivacy.rawValue,
            createdTimestamp: Date(),
            expiresAt: Date().addingTimeInterval(90 * 24 * 3_600), // 90 days for achievements
            xpEarned: xpEarned,
            achievementName: achievementName
        )

        try await saveToCloudKit(activityItem)
        newActivitySubject.send(activityItem)
    }

    func postLevelUpActivity(
        newLevel: Int,
        newTitle: String,
        privacy: WorkoutPrivacy
    ) async throws {
        let effectivePrivacy = min(privacy, privacySettings.allowPublicSharing ? .public : .friendsOnly)
        guard effectivePrivacy != .private else { return }

        let content = FeedContent(
            title: "Reached Level \(newLevel)!",
            subtitle: newTitle,
            details: [
                "newLevel": String(newLevel),
                "newTitle": newTitle,
                "levelIcon": "star.circle.fill"
            ]
        )

        let contentData = try JSONEncoder().encode(content)
        guard let contentString = String(data: contentData, encoding: .utf8) else {
            throw ActivityFeedError.encodingFailed
        }

        let activityItem = ActivityFeedItem(
            id: UUID().uuidString,
            userID: cloudKitManager.currentUserID ?? "",
            activityType: "level_up",
            workoutId: nil,
            content: contentString,
            visibility: effectivePrivacy.rawValue,
            createdTimestamp: Date(),
            expiresAt: Date().addingTimeInterval(365 * 24 * 3_600), // 1 year for level ups
            xpEarned: nil,
            achievementName: nil
        )

        try await saveToCloudKit(activityItem)
        newActivitySubject.send(activityItem)
    }

    // MARK: - Fetch Methods

    func fetchFeed(for userIds: Set<String>, since: Date?, limit _: Int) async throws -> [ActivityFeedItem] {
        let predicate = if let since {
            NSPredicate(
                format: "userID IN %@ AND createdTimestamp > %@ AND expiresAt > %@",
                Array(userIds),
                since as NSDate,
                Date() as NSDate
            )
        } else {
            NSPredicate(
                format: "userID IN %@ AND expiresAt > %@",
                Array(userIds),
                Date() as NSDate
            )
        }

        let query = CKQuery(recordType: "ActivityFeedItems", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]

        // Since CloudKitManager doesn't have performQuery, we'll use a simplified approach
        // In a real implementation, this would be replaced with actual CloudKit queries
        return []
    }

    func deleteActivity(_: String) async throws {
        // CloudKit delete would go here
        // For now, this is a placeholder
    }

    func updateActivityPrivacy(_ activityId: String, newPrivacy: WorkoutPrivacy) async throws {
        // CloudKit update would go here
        // For now, this is a placeholder

        // Notify subscribers
        privacyUpdateSubject.send((activityId, newPrivacy))
    }

    // MARK: - Private Helper Methods

    private func createWorkoutContent(from workout: WorkoutHistoryItem, includeDetails: Bool) -> FeedContent {
        var details: [String: String] = [
            "workoutType": workout.workoutType,
            "workoutIcon": "figure.run"
        ]

        if includeDetails {
            details["duration"] = String(workout.duration)
            if workout.totalEnergyBurned > 0 {
                details["calories"] = String(workout.totalEnergyBurned)
            }
            if let distance = workout.totalDistance, distance > 0 {
                details["distance"] = String(distance)
            }
            if workout.followersEarned > 0 {
                details["xpEarned"] = String(workout.followersEarned)
            }
        }

        let workoutDisplayName = workout.workoutType.replacingOccurrences(of: "_", with: " ").capitalized
        let title = "Completed a \(workoutDisplayName) workout"

        var subtitle: String?
        if includeDetails, workout.duration > 0 {
            let minutes = Int(workout.duration / 60)
            subtitle = "Great job on that \(minutes)-minute session! 💪"
        }

        return FeedContent(
            title: title,
            subtitle: subtitle,
            details: details
        )
    }

    private func saveToCloudKit(_ item: ActivityFeedItem) async throws {
        // CloudKit save would go here
        // For now, this is a placeholder
        print("Would save activity to CloudKit: \(item.activityType) by \(item.userID)")
    }

    private func convertRecordToActivityItem(_ record: CKRecord) -> ActivityFeedItem? {
        guard
            let userID = record["userID"] as? String,
            let activityType = record["activityType"] as? String,
            let content = record["content"] as? String,
            let visibility = record["visibility"] as? String,
            let createdTimestamp = record["createdTimestamp"] as? Date,
            let expiresAt = record["expiresAt"] as? Date
        else {
            return nil
        }

        return ActivityFeedItem(
            id: record.recordID.recordName,
            userID: userID,
            activityType: activityType,
            workoutId: record["workoutId"] as? String,
            content: content,
            visibility: visibility,
            createdTimestamp: createdTimestamp,
            expiresAt: expiresAt,
            xpEarned: record["xpEarned"] as? Int,
            achievementName: record["achievementName"] as? String
        )
    }

    // Helper to use most restrictive privacy level
    private func min(_ privacy1: WorkoutPrivacy, _ privacy2: WorkoutPrivacy) -> WorkoutPrivacy {
        let order: [WorkoutPrivacy] = [.private, .friendsOnly, .public]
        let index1 = order.firstIndex(of: privacy1) ?? 0
        let index2 = order.firstIndex(of: privacy2) ?? 0
        return order[Swift.min(index1, index2)]
    }
}

// MARK: - Activity Feed Errors

enum ActivityFeedError: LocalizedError {
    case invalidWorkoutType
    case encodingFailed
    case updateFailed(Error)
    case unauthorized
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidWorkoutType:
            "Invalid workout type"
        case .encodingFailed:
            "Failed to encode activity content"
        case let .updateFailed(error):
            "Failed to update activity: \(error.localizedDescription)"
        case .unauthorized:
            "Not authorized to post activities"
        case let .networkError(message):
            "Network error: \(message)"
        }
    }
}
