//
//  MockActivityFeedService.swift
//  FameFitTests
//
//  Mock implementation of ActivityFeedServicing for testing
//

import Combine
@testable import FameFit
import Foundation

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
        workoutHistory: WorkoutItem,
        privacy: WorkoutPrivacy,
        includeDetails: Bool
    ) async throws {
        if shouldFail {
            throw mockError
        }

        let content = FeedContent(
            title: "Completed a \(workoutHistory.workoutType) workout",
            subtitle: includeDetails ? "Duration: \(Int(workoutHistory.duration / 60)) minutes" : nil,
            details: includeDetails ? [
                "workoutType": workoutHistory.workoutType,
                "duration": String(workoutHistory.duration),
                "calories": String(workoutHistory.totalEnergyBurned),
                "xpEarned": String(workoutHistory.followersEarned)
            ] : ["workoutType": workoutHistory.workoutType]
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
            createdTimestamp: Date(),
            expiresAt: Date().addingTimeInterval(30 * 24 * 3_600),
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
            title: "Earned the '\(achievementName)' achievement!",
            subtitle: "Unlocked with \(xpEarned) XP",
            details: [
                "achievementName": achievementName,
                "xpEarned": String(xpEarned),
                "achievementIcon": "trophy.fill"
            ]
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
            createdTimestamp: Date(),
            expiresAt: Date().addingTimeInterval(90 * 24 * 3_600),
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
            createdTimestamp: Date(),
            expiresAt: Date().addingTimeInterval(365 * 24 * 3_600),
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
                since.timeIntervalSinceNow - 3_600 // 1 hour before 'since'
            } else {
                // Initial load
                -3_600 // 1 hour ago
            }

            for (index, userId) in userIds.prefix(3).enumerated() { // Create activities for up to 3 users
                let userTimeOffset = baseTimeOffset - Double(index * 3_600) // Space users by 1 hour

                // Workout activity
                let workoutContent = FeedContent(
                    title: "Completed a High Intensity Interval Training",
                    subtitle: "Great job on that 30-minute session! 💪",
                    details: [
                        "workoutType": "High Intensity Interval Training",
                        "duration": "1800",
                        "calories": "450",
                        "xpEarned": "45"
                    ]
                )

                if let contentData = try? JSONEncoder().encode(workoutContent),
                   let contentString = String(data: contentData, encoding: .utf8) {
                    mockActivities.append(ActivityFeedItem(
                        id: UUID().uuidString,
                        userID: userId,
                        activityType: "workout",
                        workoutId: UUID().uuidString,
                        content: contentString,
                        visibility: "public",
                        createdTimestamp: Date().addingTimeInterval(userTimeOffset),
                        expiresAt: Date().addingTimeInterval(30 * 24 * 3_600),
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
                        "achievementIcon": "medal.fill"
                    ]
                )

                if let contentData = try? JSONEncoder().encode(achievementContent),
                   let contentString = String(data: contentData, encoding: .utf8) {
                    mockActivities.append(ActivityFeedItem(
                        id: UUID().uuidString,
                        userID: userId,
                        activityType: "achievement",
                        workoutId: nil,
                        content: contentString,
                        visibility: "friends_only",
                        createdTimestamp: Date().addingTimeInterval(userTimeOffset - 3_600),
                        expiresAt: Date().addingTimeInterval(90 * 24 * 3_600),
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
                        "newTitle": "Fitness Enthusiast"
                    ]
                )

                if let contentData = try? JSONEncoder().encode(levelUpContent),
                   let contentString = String(data: contentData, encoding: .utf8) {
                    mockActivities.append(ActivityFeedItem(
                        id: UUID().uuidString,
                        userID: userId,
                        activityType: "level_up",
                        workoutId: nil,
                        content: contentString,
                        visibility: "public",
                        createdTimestamp: Date().addingTimeInterval(userTimeOffset - 7_200),
                        expiresAt: Date().addingTimeInterval(365 * 24 * 3_600),
                        xpEarned: nil,
                        achievementName: nil
                    ))
                }
            }

            // Filter by since date if provided
            if let since {
                mockActivities = mockActivities.filter { $0.createdTimestamp < since }
            }

            // Sort by creation date (newest first) and return limited results
            return mockActivities.sorted { $0.createdTimestamp > $1.createdTimestamp }.prefix(limit).map { $0 }
        }

        let filtered = postedActivities.filter { userIds.contains($0.userID) }
        let sorted = filtered.sorted { $0.createdTimestamp > $1.createdTimestamp }
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
                createdTimestamp: updatedActivity.createdTimestamp,
                expiresAt: updatedActivity.expiresAt,
                xpEarned: updatedActivity.xpEarned,
                achievementName: updatedActivity.achievementName
            )
            postedActivities[index] = updatedActivity
            privacyUpdateSubject.send((activityId, newPrivacy))
        }
    }
}
