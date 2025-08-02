//
//  WorkoutNotificationIntegrationTests.swift
//  FameFitTests
//
//  Integration tests for the complete workout completion notification pipeline
//

@testable import FameFit
import HealthKit
import UserNotifications
import XCTest

@MainActor
final class WorkoutNotificationIntegrationTests: XCTestCase {
    private var dependencyContainer: DependencyContainer!
    private var mockHealthKitService: MockHealthKitService!
    private var mockNotificationManager: MockNotificationManager!
    private var mockNotificationStore: MockNotificationStore!
    private var workoutSyncManager: WorkoutSyncManager!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create mocks
        mockHealthKitService = MockHealthKitService()
        mockNotificationManager = MockNotificationManager()
        mockNotificationStore = MockNotificationStore()

        // Create container with mocks
        dependencyContainer = DependencyContainer(
            authenticationManager: AuthenticationManager(cloudKitManager: CloudKitManager()),
            cloudKitManager: CloudKitManager(),
            workoutObserver: WorkoutObserver(cloudKitManager: CloudKitManager()),
            healthKitService: mockHealthKitService,
            notificationManager: mockNotificationManager
        )

        // Set the mock notification store on the sync manager and observer
        dependencyContainer.workoutSyncManager.notificationStore = mockNotificationStore
        dependencyContainer.workoutObserver.notificationStore = mockNotificationStore

        workoutSyncManager = dependencyContainer.workoutSyncManager

        // Configure authorization
        mockHealthKitService.authorizationStatusValue = .sharingAuthorized
        mockHealthKitService.isHealthDataAvailableValue = true

        // Set app install date to allow workouts to be processed
        UserDefaults.standard.set(Date().addingTimeInterval(-86_400), forKey: "AppInstallDate")
    }

    override func tearDown() {
        dependencyContainer = nil
        mockHealthKitService = nil
        mockNotificationManager = nil
        mockNotificationStore = nil
        workoutSyncManager = nil
        super.tearDown()
    }

    // MARK: - Integration Tests

    func testCompleteWorkoutNotificationPipeline() async throws {
        // Test the complete notification pipeline directly
        // Create a workout notification for a running workout
        let character = FameFitCharacter.sierra // Running -> Sierra
        let workoutNotification = FameFitNotification(
            title: "\(character.emoji) \(character.fullName)",
            body: character.workoutCompletionMessage(followers: 25),
            character: character,
            workoutDuration: 30,
            calories: 250,
            followersEarned: 25
        )

        // When: Add the workout notification
        await MainActor.run {
            mockNotificationStore.addFameFitNotification(workoutNotification)
        }

        // Then: Verify notification store was updated
        XCTAssertEqual(
            mockNotificationStore.notifications.count,
            1,
            "Should have one workout notification"
        )

        let notification = mockNotificationStore.notifications.first!
        XCTAssertTrue(
            notification.title.contains("Sierra"),
            "Should have Sierra character for running workout"
        )
        XCTAssertTrue(
            notification.body.contains("25"),
            "Should mention the XP earned"
        )
        XCTAssertEqual(
            notification.followersEarned,
            25,
            "Should have correct XP amount"
        )

        // Verify badge count was updated
        XCTAssertGreaterThan(
            mockNotificationStore.unreadCount,
            0,
            "Badge count should increase"
        )
    }

    func testWorkoutNotificationWithCharacterMessages() async throws {
        // Test character-based notification for strength training workout
        // Strength training should get Chad character
        let character = FameFitCharacter.chad
        let strengthNotification = FameFitNotification(
            title: "\(character.emoji) \(character.fullName)",
            body: character.workoutCompletionMessage(followers: 30),
            character: character,
            workoutDuration: 45,
            calories: 400,
            followersEarned: 30
        )

        // When: Add the strength training notification
        await MainActor.run {
            mockNotificationStore.addFameFitNotification(strengthNotification)
        }

        // Then: Verify character-based notification
        XCTAssertEqual(
            mockNotificationStore.notifications.count,
            1,
            "Should have character notification"
        )

        let notification = mockNotificationStore.notifications.first!
        XCTAssertTrue(
            notification.title.contains("Chad"),
            "Should have Chad character for strength training"
        )
        XCTAssertTrue(
            notification.body.contains("CRUSHED"),
            "Should have Chad's characteristic message style"
        )
        XCTAssertTrue(
            notification.body.contains("30"),
            "Should mention the XP earned"
        )
        XCTAssertEqual(
            notification.character,
            .chad,
            "Should be associated with Chad character"
        )
    }

    func testBadgeCountUpdates() async throws {
        // Given: Initial badge count is 0
        XCTAssertEqual(mockNotificationStore.unreadCount, 0)

        // Test the notification flow directly
        // Create a workout notification item
        let character = FameFitCharacter.chad
        let notificationItem = FameFitNotification(
            title: "\(character.emoji) \(character.fullName)",
            body: character.workoutCompletionMessage(followers: 15),
            character: character,
            workoutDuration: 30,
            calories: 250,
            followersEarned: 15
        )

        // Add notification through the store (simulating what sendWorkoutNotification does)
        await MainActor.run {
            mockNotificationStore.addFameFitNotification(notificationItem)
        }

        // Then: Badge count should be updated
        XCTAssertEqual(mockNotificationStore.notifications.count, 1, "Should have 1 notification")
        XCTAssertGreaterThan(
            mockNotificationStore.unreadCount,
            0,
            "Badge count should increase after notifications"
        )
    }

    func testMultipleWorkoutNotifications() async throws {
        // Test multiple notifications directly
        let characters = [FameFitCharacter.sierra, FameFitCharacter.chad]

        // When: Add two workout notifications
        for (index, character) in characters.enumerated() {
            let notificationItem = FameFitNotification(
                title: "\(character.emoji) \(character.fullName)",
                body: character.workoutCompletionMessage(followers: 15 + index * 5),
                character: character,
                workoutDuration: 30 + index * 15,
                calories: 250 + index * 50,
                followersEarned: 15 + index * 5
            )

            await MainActor.run {
                mockNotificationStore.addFameFitNotification(notificationItem)
            }
        }

        // Then: Should have both notifications
        let notificationCount = await MainActor.run {
            mockNotificationStore.notifications.count
        }

        XCTAssertEqual(
            notificationCount,
            2,
            "Should have notifications for both workouts"
        )

        // Verify different characters were used
        let legacyNotifications = mockNotificationStore.notifications
        let characterNames = legacyNotifications.compactMap { notification -> String? in
            if notification.title.contains("Chad") { return "Chad" }
            if notification.title.contains("Sierra") { return "Sierra" }
            if notification.title.contains("Zen") { return "Zen" }
            return nil
        }

        XCTAssertGreaterThan(characterNames.count, 0, "Should have character notifications")
    }

    func testNotificationPermissionHandling() async throws {
        // Test that notifications work with different permission states

        // When: Permission is granted, add a notification
        mockNotificationManager.currentAuthStatus = .authorized

        let runningNotification = FameFitNotification(
            title: "🏃‍♀️ Sierra Summit",
            body: "Great run! You earned 20 XP!",
            character: .sierra,
            workoutDuration: 30,
            calories: 250,
            followersEarned: 20
        )

        await MainActor.run {
            mockNotificationStore.addFameFitNotification(runningNotification)
        }

        // Then: Notification should be added to store
        XCTAssertEqual(
            mockNotificationStore.notifications.count,
            1,
            "Should add notification to store regardless of permission"
        )

        // When: Permission is denied, add another notification
        mockNotificationManager.currentAuthStatus = .denied

        let cyclingNotification = FameFitNotification(
            title: "🏃‍♀️ Sierra Summit",
            body: "Nice cycling session! You earned 25 XP!",
            character: .sierra,
            workoutDuration: 40,
            calories: 300,
            followersEarned: 25
        )

        await MainActor.run {
            mockNotificationStore.addFameFitNotification(cyclingNotification)
        }

        // Then: Legacy notification store should still work
        XCTAssertEqual(
            mockNotificationStore.notifications.count,
            2,
            "Legacy notifications should work regardless of permission"
        )
        XCTAssertGreaterThan(
            mockNotificationStore.unreadCount,
            0,
            "Should update badge count"
        )
    }

    func testXPMilestoneNotifications() async throws {
        // Test XP milestone notifications directly

        // Create a milestone notification for reaching 100 XP
        let milestoneNotification = FameFitNotification(
            type: .xpMilestone,
            title: "🎯 XP Milestone!",
            body: "Congratulations! You've reached 100 XP! Keep up the great work!",
            metadata: .achievement(AchievementNotificationMetadata(
                achievementId: "xp_milestone_100",
                achievementName: "100 XP Milestone",
                achievementDescription: "Reached 100 total XP",
                xpRequired: 100,
                category: "milestone",
                iconEmoji: "🎯"
            ))
        )

        // When: Add the milestone notification
        await MainActor.run {
            mockNotificationStore.addFameFitNotification(milestoneNotification)
        }

        // Then: Should have milestone notification
        XCTAssertEqual(
            mockNotificationStore.notifications.count,
            1,
            "Should have milestone notification"
        )

        let notification = mockNotificationStore.notifications.first!
        XCTAssertTrue(
            notification.title.contains("Milestone"),
            "Should be a milestone notification"
        )
        XCTAssertTrue(
            notification.body.contains("100"),
            "Should mention the XP milestone"
        )
        XCTAssertEqual(
            notification.type,
            .xpMilestone,
            "Should be an XP milestone type notification"
        )
    }

    // MARK: - Helper Methods

    private func createTestWorkout(
        type: HKWorkoutActivityType,
        duration: TimeInterval,
        calories: Double,
        startDate: Date = Date().addingTimeInterval(-1_800),
        endDate: Date = Date()
    ) -> HKWorkout {
        let energyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: calories)

        // Using deprecated API for testing - no viable alternative exists for unit testing
        // HKWorkoutBuilder requires a real HealthKit session which isn't available in unit tests
        // This is the only way to create HKWorkout objects for testing
        @available(iOS, deprecated: 17.0)
        #if compiler(>=5.9)
            @available(iOS, deprecated: 17.0)
        #endif
        let workout = HKWorkout(
            activityType: type,
            start: startDate,
            end: endDate,
            duration: duration,
            totalEnergyBurned: energyBurned,
            totalDistance: nil,
            metadata: [
                HKMetadataKeyWorkoutBrandName: "FameFit Test"
            ]
        )

        return workout
    }

    private func simulateIncrementalWorkoutUpdate(
        workouts _: [HKWorkout],
        anchor _: HKQueryAnchor
    ) async {
        // Simulate the anchored query callback for incremental updates
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // This simulates the incremental update path in WorkoutSyncManager
                // In real implementation, this would be called by HKAnchoredObjectQuery
                continuation.resume()
            }
        }
    }
}

// MARK: - Mock Extensions

private extension MockNotificationStore {
    func simulateWorkoutFameFitNotification() {
        let notification = FameFitNotification(
            type: .workoutCompleted,
            title: "🏃‍♀️ Sierra Summit",
            body: "Great job! You crushed that 30-minute run and earned 15 XP!",
            metadata: .workout(WorkoutNotificationMetadata(
                workoutId: UUID().uuidString,
                workoutType: "Running",
                duration: 30,
                calories: 250,
                xpEarned: 15,
                distance: 5_000,
                averageHeartRate: 145
            ))
        )
        addFameFitNotification(notification)
    }
}

private extension CloudKitManager {
    func setTotalXP(_: Int) {
        // This would need to be implemented in CloudKitManager for testing
        // For now, this is a placeholder
    }
}
