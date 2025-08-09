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
    var postedActivities: [ActivityFeedRecord] = []
    var shouldFail = false
    var mockError: ActivityFeedError = .networkError("Mock error")

    private let newActivitySubject = PassthroughSubject<ActivityFeedRecord, Never>()
    private let privacyUpdateSubject = PassthroughSubject<(String, WorkoutPrivacy), Never>()

    var newActivityPublisher: AnyPublisher<ActivityFeedRecord, Never> {
        newActivitySubject.eraseToAnyPublisher()
    }

    var privacyUpdatePublisher: AnyPublisher<(String, WorkoutPrivacy), Never> {
        privacyUpdateSubject.eraseToAnyPublisher()
    }

    func postWorkoutActivity(
        workout: Workout,
        privacy: WorkoutPrivacy,
        includeDetails: Bool
    ) async throws {
        if shouldFail {
            throw mockError
        }

        let content = ActivityFeedContent(
            title: "Completed a \(workout.workoutType) workout",
            subtitle: includeDetails ? "Duration: \(Int(workout.duration / 60)) minutes" : nil,
            details: includeDetails ? [
                "workoutType": workout.workoutType,
                "duration": String(workout.duration),
                "calories": String(workout.totalEnergyBurned),
                "xpEarned": String(workout.followersEarned)
            ] : ["workoutType": workout.workoutType]
        )

        let contentData = try JSONEncoder().encode(content)
        let contentString = String(data: contentData, encoding: .utf8) ?? ""

        let activity = ActivityFeedRecord(
            id: UUID().uuidString,
            userID: "mock-user",
            username: "MockUser",
            activityType: "workout",
            workoutID: workout.id,
            content: contentString,
            visibility: privacy.rawValue,
            creationDate: Date(),
            expiresAt: Date().addingTimeInterval(30 * 24 * 3_600),
            xpEarned: workout.followersEarned,
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

        let content = ActivityFeedContent(
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

        let activity = ActivityFeedRecord(
            id: UUID().uuidString,
            userID: "mock-user",
            username: "MockUser",
            activityType: "achievement",
            workoutID: nil,
            content: contentString,
            visibility: privacy.rawValue,
            creationDate: Date(),
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

        let content = ActivityFeedContent(
            title: "Reached Level \(newLevel)!",
            subtitle: newTitle,
            details: ["newLevel": String(newLevel), "newTitle": newTitle]
        )

        let contentData = try JSONEncoder().encode(content)
        let contentString = String(data: contentData, encoding: .utf8) ?? ""

        let activity = ActivityFeedRecord(
            id: UUID().uuidString,
            userID: "mock-user",
            username: "MockUser",
            activityType: "level_up",
            workoutID: nil,
            content: contentString,
            visibility: privacy.rawValue,
            creationDate: Date(),
            expiresAt: Date().addingTimeInterval(365 * 24 * 3_600),
            xpEarned: nil,
            achievementName: nil
        )

        postedActivities.append(activity)
        newActivitySubject.send(activity)
    }

    func fetchFeed(for userIds: Set<String>, since: Date?, limit: Int) async throws -> [ActivityFeedRecord] {
        if shouldFail {
            throw mockError
        }

        // If no activities posted, create some mock ones for testing
        if postedActivities.isEmpty, !userIds.isEmpty {
            // Create mock activities for the requested users
            var mockActivities: [ActivityFeedRecord] = []

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
                let workoutContent = ActivityFeedContent(
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
                    mockActivities.append(ActivityFeedRecord(
                        id: UUID().uuidString,
                        userID: userId,
                        username: "User\(index)",
                        activityType: "workout",
                        workoutID: UUID().uuidString,
                        content: contentString,
                        visibility: "public",
                        creationDate: Date().addingTimeInterval(userTimeOffset),
                        expiresAt: Date().addingTimeInterval(30 * 24 * 3_600),
                        xpEarned: 45,
                        achievementName: nil
                    ))
                }

                // Achievement activity
                let achievementContent = ActivityFeedContent(
                    title: "Earned the 'Workout Warrior' badge",
                    subtitle: "Completed 50 workouts!",
                    details: [
                        "achievementName": "Workout Warrior",
                        "achievementIcon": "medal.fill"
                    ]
                )

                if let contentData = try? JSONEncoder().encode(achievementContent),
                   let contentString = String(data: contentData, encoding: .utf8) {
                    mockActivities.append(ActivityFeedRecord(
                        id: UUID().uuidString,
                        userID: userId,
                        username: "User\(index)",
                        activityType: "achievement",
                        workoutID: nil,
                        content: contentString,
                        visibility: "friends_only",
                        creationDate: Date().addingTimeInterval(userTimeOffset - 3_600),
                        expiresAt: Date().addingTimeInterval(90 * 24 * 3_600),
                        xpEarned: 50,
                        achievementName: "Workout Warrior"
                    ))
                }

                // Level up activity
                let levelUpContent = ActivityFeedContent(
                    title: "Reached Level 5!",
                    subtitle: "Fitness Enthusiast",
                    details: [
                        "newLevel": "5",
                        "newTitle": "Fitness Enthusiast"
                    ]
                )

                if let contentData = try? JSONEncoder().encode(levelUpContent),
                   let contentString = String(data: contentData, encoding: .utf8) {
                    mockActivities.append(ActivityFeedRecord(
                        id: UUID().uuidString,
                        userID: userId,
                        username: "User\(index)",
                        activityType: "level_up",
                        workoutID: nil,
                        content: contentString,
                        visibility: "public",
                        creationDate: Date().addingTimeInterval(userTimeOffset - 7_200),
                        expiresAt: Date().addingTimeInterval(365 * 24 * 3_600),
                        xpEarned: nil,
                        achievementName: nil
                    ))
                }
            }

            // Filter by since date if provided
            if let since {
                mockActivities = mockActivities.filter { $0.creationDate < since }
            }

            // Sort by creation date (newest first) and return limited results
            return mockActivities.sorted { $0.creationDate > $1.creationDate }.prefix(limit).map { $0 }
        }

        let filtered = postedActivities.filter { userIds.contains($0.userID) }
        let sorted = filtered.sorted { $0.creationDate > $1.creationDate }
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
            updatedActivity = ActivityFeedRecord(
                id: updatedActivity.id,
                userID: updatedActivity.userID,
                username: updatedActivity.username,
                activityType: updatedActivity.activityType,
                workoutID: updatedActivity.workoutID,
                content: updatedActivity.content,
                visibility: newPrivacy.rawValue,
                creationDate: updatedActivity.creationDate,
                expiresAt: updatedActivity.expiresAt,
                xpEarned: updatedActivity.xpEarned,
                achievementName: updatedActivity.achievementName
            )
            postedActivities[index] = updatedActivity
            privacyUpdateSubject.send((activityId, newPrivacy))
        }
    }
}
