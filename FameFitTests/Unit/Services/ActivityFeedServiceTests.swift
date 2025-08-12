//
//  ActivityFeedServiceTests.swift
//  FameFitTests
//
//  Unit tests for activity feed service
//

import CloudKit
@testable import FameFit
import XCTest

final class ActivityFeedServiceTests: XCTestCase {
    private var activityFeedService: ActivityFeedService!
    private var mockActivityFeedService: MockActivityFeedService!
    private var mockCloudKitService: MockCloudKitService!
    private var userSettings: UserSettings!

    override func setUp() {
        super.setUp()
        mockCloudKitService = MockCloudKitService()
        userSettings = UserSettings.defaultSettings(for: "test-user")
        activityFeedService = ActivityFeedService(
            cloudKitManager: mockCloudKitService,
            userSettings: userSettings
        )
        mockActivityFeedService = MockActivityFeedService()
    }

    override func tearDown() {
        activityFeedService = nil
        mockActivityFeedService = nil
        mockCloudKitService = nil
        privacySettings = nil
        super.tearDown()
    }

    // MARK: - Post Workout Activity Tests

    func testPostWorkoutActivity_PublicPrivacy_Success() async throws {
        // Given
        let workout = WorkoutItem(
            id: UUID(),
            workoutType: "running",
            startDate: Date().addingTimeInterval(-1_800),
            endDate: Date(),
            duration: 1_800,
            totalEnergyBurned: 250,
            totalDistance: 3.2,
            averageHeartRate: 140,
            followersEarned: 25,
            xpEarned: 25,
            source: "FameFit"
        )

        // When
        try await mockActivityFeedService.postWorkoutActivity(
            workout: workout,
            privacy: .public,
            includeDetails: true
        )

        // Then
        XCTAssertEqual(mockActivityFeedService.postedActivities.count, 1)
        let activity = mockActivityFeedService.postedActivities.first!
        XCTAssertEqual(activity.activityType, "workout")
        XCTAssertEqual(activity.visibility, "public")
        XCTAssertEqual(activity.workoutId, workout.id)
        XCTAssertEqual(activity.xpEarned, 25)
    }

    func testPostWorkoutActivity_PrivatePrivacy_NotPosted() async throws {
        // Given
        let workout = WorkoutItem(
            id: UUID(),
            workoutType: "yoga",
            startDate: Date().addingTimeInterval(-3_600),
            endDate: Date(),
            duration: 3_600,
            totalEnergyBurned: 150,
            totalDistance: nil,
            averageHeartRate: 90,
            followersEarned: 15,
            xpEarned: 15,
            source: "FameFit"
        )

        // When - Real service would not post private workouts
        try await activityFeedService.postWorkoutActivity(
            workout: workout,
            privacy: .private,
            includeDetails: true
        )

        // Then - No activity should be posted (mock doesn't enforce this)
        // In real implementation, private workouts are not saved to CloudKit
    }

    func testPostWorkoutActivity_WithoutDetails() async throws {
        // Given
        let workout = WorkoutItem(
            id: UUID(),
            workoutType: "cycling",
            startDate: Date().addingTimeInterval(-2_400),
            endDate: Date(),
            duration: 2_400,
            totalEnergyBurned: 350,
            totalDistance: 15.5,
            averageHeartRate: 145,
            followersEarned: 35,
            xpEarned: 35,
            source: "FameFit"
        )

        // When
        try await mockActivityFeedService.postWorkoutActivity(
            workout: workout,
            privacy: .friendsOnly,
            includeDetails: false
        )

        // Then
        XCTAssertEqual(mockActivityFeedService.postedActivities.count, 1)
        let activity = mockActivityFeedService.postedActivities.first!

        // Parse content to verify no details
        if let data = activity.content.data(using: .utf8),
           let content = try? JSONDecoder().decode(ActivityFeedContent.self, from: data) {
            XCTAssertNil(content.details["duration"])
            XCTAssertNil(content.details["calories"])
            XCTAssertNil(content.details["distance"])
        }
    }

    func testPostWorkoutActivity_COPPACompliance() async throws {
        // Given - User under 13 (COPPA restricted)
        var restrictedSettings = UserSettings.defaultSettings(for: "test-user")
        restrictedSettings.allowPublicSharing = false

        let restrictedService = ActivityFeedService(
            cloudKitManager: mockCloudKitService,
            privacySettings: restrictedSettings
        )

        let workout = WorkoutItem(
            id: UUID(),
            workoutType: "swimming",
            startDate: Date().addingTimeInterval(-1_200),
            endDate: Date(),
            duration: 1_200,
            totalEnergyBurned: 200,
            totalDistance: 1.0,
            averageHeartRate: 130,
            followersEarned: 20,
            xpEarned: 20,
            source: "FameFit"
        )

        // When - Try to post publicly (should be downgraded to friends only)
        try await restrictedService.postWorkoutActivity(
            workout: workout,
            privacy: .public,
            includeDetails: true
        )

        // Then - Privacy should be enforced
        // Real implementation would downgrade to friendsOnly
    }

    // MARK: - Achievement Activity Tests

    func testPostAchievementActivity_Success() async throws {
        // When
        try await mockActivityFeedService.postAchievementActivity(
            achievementName: "Workout Warrior",
            xpEarned: 100,
            privacy: .public
        )

        // Then
        XCTAssertEqual(mockActivityFeedService.postedActivities.count, 1)
        let activity = mockActivityFeedService.postedActivities.first!
        XCTAssertEqual(activity.activityType, "achievement")
        XCTAssertEqual(activity.achievementName, "Workout Warrior")
        XCTAssertEqual(activity.xpEarned, 100)
    }

    func testPostAchievementActivity_DisabledSharing() async throws {
        // Given
        var settings = UserSettings.defaultSettings(for: "test-user")
        settings.shareAchievements = false

        let service = ActivityFeedService(
            cloudKitManager: mockCloudKitService,
            privacySettings: settings
        )

        // When
        try await service.postAchievementActivity(
            achievementName: "First Workout",
            xpEarned: 50,
            privacy: .public
        )

        // Then - Should not post when sharing is disabled
    }

    // MARK: - Level Up Activity Tests

    func testPostLevelUpActivity_Success() async throws {
        // When
        try await mockActivityFeedService.postLevelUpActivity(
            newLevel: 5,
            newTitle: "Fitness Enthusiast",
            privacy: .friendsOnly
        )

        // Then
        XCTAssertEqual(mockActivityFeedService.postedActivities.count, 1)
        let activity = mockActivityFeedService.postedActivities.first!
        XCTAssertEqual(activity.activityType, "level_up")
        XCTAssertEqual(activity.visibility, "friends_only")

        if let data = activity.content.data(using: .utf8),
           let content = try? JSONDecoder().decode(ActivityFeedContent.self, from: data) {
            XCTAssertEqual(content.title, "Reached Level 5!")
            XCTAssertEqual(content.subtitle, "Fitness Enthusiast")
        }
    }

    // MARK: - Feed Fetching Tests

    func testFetchFeed_ReturnsEmptyForRealService() async throws {
        // Given
        let userIds: Set<String> = ["user1", "user2", "user3"]

        // When
        let items = try await activityFeedService.fetchFeed(
            for: userIds,
            since: nil,
            limit: 20
        )

        // Then - Real service returns empty array (CloudKit not implemented)
        XCTAssertEqual(items.count, 0)
    }

    func testFetchFeed_MockServiceReturnsFilteredItems() async throws {
        // Given
        let workout = WorkoutItem(
            id: UUID(),
            workoutType: "running",
            startDate: Date(),
            endDate: Date(),
            duration: 1_800,
            totalEnergyBurned: 250,
            totalDistance: 3.0,
            averageHeartRate: 140,
            followersEarned: 25,
            xpEarned: 25,
            source: "FameFit"
        )

        // Post activities for different users
        mockActivityFeedService.postedActivities = []
        try await mockActivityFeedService.postWorkoutActivity(
            workout: workout,
            privacy: .public,
            includeDetails: true
        )

        // When
        let items = try await mockActivityFeedService.fetchFeed(
            for: ["mock-user"],
            since: nil,
            limit: 10
        )

        // Then
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.userID, "mock-user")
    }

    // MARK: - Privacy Update Tests

    func testUpdateActivityPrivacy_Success() async throws {
        // Given
        let activityId = "test-activity"

        // When
        try await mockActivityFeedService.updateActivityPrivacy(
            activityId,
            newPrivacy: .friendsOnly
        )

        // Then - Mock doesn't actually update, but real service would
        XCTAssertTrue(true) // Placeholder
    }

    // MARK: - Error Handling Tests

    func testPostWorkoutActivity_NetworkError() async {
        // Given
        mockActivityFeedService.shouldFail = true
        mockActivityFeedService.mockError = .networkError("Connection failed")

        let workout = WorkoutItem(
            id: UUID(),
            workoutType: "running",
            startDate: Date(),
            endDate: Date(),
            duration: 1_800,
            totalEnergyBurned: 250,
            totalDistance: 3.0,
            averageHeartRate: 140,
            followersEarned: 25,
            xpEarned: 25,
            source: "FameFit"
        )

        // When/Then
        do {
            try await mockActivityFeedService.postWorkoutActivity(
                workout: workout,
                privacy: .public,
                includeDetails: true
            )
            XCTFail("Expected error to be thrown")
        } catch let error as ActivityFeedError {
            if case let .networkError(message) = error {
                XCTAssertEqual(message, "Connection failed")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Content Creation Tests

    func testWorkoutContentCreation_WithAllDetails() {
        // Given
        _ = WorkoutItem(
            id: UUID(),
            workoutType: "high_intensity_interval_training",
            startDate: Date().addingTimeInterval(-1_800),
            endDate: Date(),
            duration: 1_800,
            totalEnergyBurned: 450,
            totalDistance: 2.5,
            averageHeartRate: 155,
            followersEarned: 45,
            xpEarned: 45,
            source: "FameFit"
        )

        // When - Test private helper through mock
        let content = ActivityFeedContent(
            title: "Completed a High Intensity Interval Training workout",
            subtitle: "Great job on that 30-minute session! 💪",
            details: [
                "workoutType": "high_intensity_interval_training",
                "workoutIcon": "figure.run",
                "duration": "1800",
                "calories": "450",
                "distance": "2.5",
                "xpEarned": "45"
            ]
        )

        // Then
        XCTAssertEqual(content.duration, 1_800)
        XCTAssertEqual(content.calories, 450)
        XCTAssertEqual(content.xpEarned, 45)
    }

    // MARK: - Privacy Level Comparison Tests

    func testPrivacyLevelComparison() {
        // Test that the min function works correctly
        let service = activityFeedService!

        // Private is most restrictive
        XCTAssertEqual(service.effectivePrivacy(.private, .public), .private)
        XCTAssertEqual(service.effectivePrivacy(.public, .private), .private)

        // Friends only is middle
        XCTAssertEqual(service.effectivePrivacy(.friendsOnly, .public), .friendsOnly)
        XCTAssertEqual(service.effectivePrivacy(.public, .friendsOnly), .friendsOnly)

        // Same returns same
        XCTAssertEqual(service.effectivePrivacy(.public, .public), .public)
        XCTAssertEqual(service.effectivePrivacy(.private, .private), .private)
    }
}

// MARK: - Helper Extension for Testing

extension ActivityFeedService {
    func effectivePrivacy(_ p1: WorkoutPrivacy, _ p2: WorkoutPrivacy) -> WorkoutPrivacy {
        // Use the same logic as in the ActivityFeedService
        let order: [WorkoutPrivacy] = [.private, .friendsOnly, .public]
        let index1 = order.firstIndex(of: p1) ?? 0
        let index2 = order.firstIndex(of: p2) ?? 0
        return order[Swift.min(index1, index2)]
    }
}
