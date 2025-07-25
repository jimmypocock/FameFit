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
    let createdAt: Date
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
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(30 * 24 * 3600), // 30 days
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
                "achievementIcon": "trophy.fill",
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
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(90 * 24 * 3600), // 90 days for achievements
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
                "levelIcon": "star.circle.fill",
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
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(365 * 24 * 3600), // 1 year for level ups
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
                format: "userID IN %@ AND createdAt > %@ AND expiresAt > %@",
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
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

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
            "workoutIcon": "figure.run",
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
            let createdAt = record["createdAt"] as? Date,
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
            createdAt: createdAt,
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

// MARK: - Mock Activity Feed Service

final class MockActivityFeedService: ActivityFeedServicing {
    var postedActivities: [ActivityFeedItem] = []
    var shouldFail = false
    var mockError: ActivityFeedError = .networkError("Mock error")

    private let newActivitySubject = PassthroughSubject<ActivityFeedItem, Never>()
    private let privacyUpdateSubject = PassthroughSubject<(String, WorkoutPrivacy), Never>()

    var newActivityPublisher: AnyPublisher<ActivityFeedItem, Never> {
        newActivitySubject.eraseToAnyPublisher()
    }

    var privacyUpdatePublisher: AnyPublisher<(String, WorkoutPrivacy), Never> {
        privacyUpdateSubject.eraseToAnyPublisher()
    }

    func postWorkoutActivity(
        workoutHistory: WorkoutHistoryItem,
        privacy: WorkoutPrivacy,
        includeDetails: Bool
    ) async throws {
        if shouldFail {
            throw mockError
        }

        let content = FeedContent(
            title: "Completed a workout",
            subtitle: includeDetails ? "Great session!" : nil,
            details: ["workoutType": workoutHistory.workoutType]
        )

        let contentData = try JSONEncoder().encode(content)
        let contentString = String(data: contentData, encoding: .utf8) ?? ""

        let activity = ActivityFeedItem(
            id: UUID().uuidString,
            userID: "mock-user",
            activityType: "workout",
            workoutId: workoutHistory.id.uuidString,
            content: contentString,
            visibility: privacy.rawValue,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(30 * 24 * 3600),
            xpEarned: workoutHistory.followersEarned,
            achievementName: nil
        )

        postedActivities.append(activity)
        newActivitySubject.send(activity)
    }

    func postAchievementActivity(
        achievementName: String,
        xpEarned: Int,
        privacy: WorkoutPrivacy
    ) async throws {
        if shouldFail {
            throw mockError
        }

        let content = FeedContent(
            title: "Earned achievement: \(achievementName)",
            subtitle: "\(xpEarned) XP earned",
            details: ["achievementName": achievementName, "xpEarned": String(xpEarned)]
        )

        let contentData = try JSONEncoder().encode(content)
        let contentString = String(data: contentData, encoding: .utf8) ?? ""

        let activity = ActivityFeedItem(
            id: UUID().uuidString,
            userID: "mock-user",
            activityType: "achievement",
            workoutId: nil,
            content: contentString,
            visibility: privacy.rawValue,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(90 * 24 * 3600),
            xpEarned: xpEarned,
            achievementName: achievementName
        )

        postedActivities.append(activity)
        newActivitySubject.send(activity)
    }

    func postLevelUpActivity(
        newLevel: Int,
        newTitle: String,
        privacy: WorkoutPrivacy
    ) async throws {
        if shouldFail {
            throw mockError
        }

        let content = FeedContent(
            title: "Reached Level \(newLevel)!",
            subtitle: newTitle,
            details: ["newLevel": String(newLevel), "newTitle": newTitle]
        )

        let contentData = try JSONEncoder().encode(content)
        let contentString = String(data: contentData, encoding: .utf8) ?? ""

        let activity = ActivityFeedItem(
            id: UUID().uuidString,
            userID: "mock-user",
            activityType: "level_up",
            workoutId: nil,
            content: contentString,
            visibility: privacy.rawValue,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(365 * 24 * 3600),
            xpEarned: nil,
            achievementName: nil
        )

        postedActivities.append(activity)
        newActivitySubject.send(activity)
    }

    func fetchFeed(for userIds: Set<String>, since: Date?, limit: Int) async throws -> [ActivityFeedItem] {
        if shouldFail {
            throw mockError
        }

        // If no activities posted, create some mock ones for testing
        if postedActivities.isEmpty, !userIds.isEmpty {
            // Create mock activities for the requested users
            var mockActivities: [ActivityFeedItem] = []

            // Calculate base time offset based on 'since' parameter for pagination
            let baseTimeOffset: TimeInterval = if let since {
                // For pagination, create older items
                since.timeIntervalSinceNow - 3600 // 1 hour before 'since'
            } else {
                // Initial load
                -3600 // 1 hour ago
            }

            for (index, userId) in userIds.prefix(3).enumerated() { // Create activities for up to 3 users
                let userTimeOffset = baseTimeOffset - Double(index * 3600) // Space users by 1 hour

                // Workout activity
                let workoutContent = FeedContent(
                    title: "Completed a High Intensity Interval Training",
                    subtitle: "Great job on that 30-minute session! 💪",
                    details: [
                        "workoutType": "High Intensity Interval Training",
                        "duration": "1800",
                        "calories": "450",
                        "xpEarned": "45",
                    ]
                )

                if let contentData = try? JSONEncoder().encode(workoutContent),
                   let contentString = String(data: contentData, encoding: .utf8)
                {
                    mockActivities.append(ActivityFeedItem(
                        id: UUID().uuidString,
                        userID: userId,
                        activityType: "workout",
                        workoutId: UUID().uuidString,
                        content: contentString,
                        visibility: "public",
                        createdAt: Date().addingTimeInterval(userTimeOffset),
                        expiresAt: Date().addingTimeInterval(30 * 24 * 3600),
                        xpEarned: 45,
                        achievementName: nil
                    ))
                }

                // Achievement activity
                let achievementContent = FeedContent(
                    title: "Earned the 'Workout Warrior' badge",
                    subtitle: "Completed 50 workouts!",
                    details: [
                        "achievementName": "Workout Warrior",
                        "achievementIcon": "medal.fill",
                    ]
                )

                if let contentData = try? JSONEncoder().encode(achievementContent),
                   let contentString = String(data: contentData, encoding: .utf8)
                {
                    mockActivities.append(ActivityFeedItem(
                        id: UUID().uuidString,
                        userID: userId,
                        activityType: "achievement",
                        workoutId: nil,
                        content: contentString,
                        visibility: "friends_only",
                        createdAt: Date().addingTimeInterval(userTimeOffset - 3600),
                        expiresAt: Date().addingTimeInterval(90 * 24 * 3600),
                        xpEarned: 50,
                        achievementName: "Workout Warrior"
                    ))
                }

                // Level up activity
                let levelUpContent = FeedContent(
                    title: "Reached Level 5!",
                    subtitle: "Fitness Enthusiast",
                    details: [
                        "newLevel": "5",
                        "newTitle": "Fitness Enthusiast",
                    ]
                )

                if let contentData = try? JSONEncoder().encode(levelUpContent),
                   let contentString = String(data: contentData, encoding: .utf8)
                {
                    mockActivities.append(ActivityFeedItem(
                        id: UUID().uuidString,
                        userID: userId,
                        activityType: "level_up",
                        workoutId: nil,
                        content: contentString,
                        visibility: "public",
                        createdAt: Date().addingTimeInterval(userTimeOffset - 7200),
                        expiresAt: Date().addingTimeInterval(365 * 24 * 3600),
                        xpEarned: nil,
                        achievementName: nil
                    ))
                }
            }

            // Filter by since date if provided
            if let since {
                mockActivities = mockActivities.filter { $0.createdAt < since }
            }

            // Sort by creation date (newest first) and return limited results
            return mockActivities.sorted { $0.createdAt > $1.createdAt }.prefix(limit).map { $0 }
        }

        let filtered = postedActivities.filter { userIds.contains($0.userID) }
        let sorted = filtered.sorted { $0.createdAt > $1.createdAt }
        return Array(sorted.prefix(limit))
    }

    func deleteActivity(_ activityId: String) async throws {
        if shouldFail {
            throw mockError
        }

        postedActivities.removeAll { $0.id == activityId }
    }

    func updateActivityPrivacy(_ activityId: String, newPrivacy: WorkoutPrivacy) async throws {
        if shouldFail {
            throw mockError
        }

        if let index = postedActivities.firstIndex(where: { $0.id == activityId }) {
            var updatedActivity = postedActivities[index]
            updatedActivity = ActivityFeedItem(
                id: updatedActivity.id,
                userID: updatedActivity.userID,
                activityType: updatedActivity.activityType,
                workoutId: updatedActivity.workoutId,
                content: updatedActivity.content,
                visibility: newPrivacy.rawValue,
                createdAt: updatedActivity.createdAt,
                expiresAt: updatedActivity.expiresAt,
                xpEarned: updatedActivity.xpEarned,
                achievementName: updatedActivity.achievementName
            )
            postedActivities[index] = updatedActivity
            privacyUpdateSubject.send((activityId, newPrivacy))
        }
    }
}
