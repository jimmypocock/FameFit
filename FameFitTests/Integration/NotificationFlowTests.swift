//
//  NotificationFlowTests.swift
//  FameFitTests
//
//  Integration tests for complete notification flows
//

@testable import FameFit
import UserNotifications
import XCTest

class NotificationFlowTests: XCTestCase {
    private var notificationManager: NotificationManager!
    private var mockScheduler: IntegrationTestScheduler!
    private var mockStore: MockNotificationStore!
    private var mockUnlockService: IntegrationTestUnlockService!
    private var mockMessageProvider: MockMessageProvider!

    override func setUp() {
        super.setUp()

        // Set up mock dependencies
        mockScheduler = IntegrationTestScheduler()
        mockStore = MockNotificationStore()
        mockUnlockService = IntegrationTestUnlockService()
        mockMessageProvider = MockMessageProvider()

        notificationManager = NotificationManager(
            scheduler: mockScheduler,
            notificationStore: mockStore,
            unlockService: mockUnlockService,
            messageProvider: mockMessageProvider
        )
    }

    override func tearDown() {
        notificationManager = nil
        mockScheduler = nil
        mockStore = nil
        mockUnlockService = nil
        mockMessageProvider = nil
        super.tearDown()
    }

    // MARK: - Complete Workout Flow Tests

    func testCompleteWorkoutFlow_GeneratesAllExpectedNotifications() async {
        // Given - Configure preferences
        var preferences = NotificationPreferences()
        preferences.enabledTypes[.workoutCompleted] = true
        preferences.enabledTypes[.xpMilestone] = true
        notificationManager.updatePreferences(preferences)

        // Mock unlock service to trigger XP milestone
        mockUnlockService.shouldTriggerUnlock = true

        let workout = WorkoutItem(
            id: UUID(),
            workoutType: "Running",
            startDate: Date().addingTimeInterval(-1_800),
            endDate: Date(),
            duration: 1_800,
            totalEnergyBurned: 250,
            totalDistance: 5_000,
            averageHeartRate: 145,
            followersEarned: 10,
            xpEarned: 200,
            source: "watch"
        )

        // When
        await notificationManager.notifyWorkoutCompleted(workout)
        await notificationManager.notifyXPMilestone(previousXP: 900, currentXP: 1_100)

        // Then
        XCTAssertEqual(mockScheduler.scheduledRequests.count, 1) // Only workout notification
        XCTAssertTrue(mockUnlockService.checkForNewUnlocksCalled)

        let workoutNotification = mockScheduler.scheduledRequests.first!
        XCTAssertEqual(workoutNotification.type, .workoutCompleted)
        XCTAssertTrue(workoutNotification.body.contains("Test workout message"))
    }

    // MARK: - Social Interaction Flow Tests

    func testSocialInteractionFlow_BatchesMultipleKudos() async {
        // Given
        let workoutId = "workout123"
        let users = [
            createTestUser(id: "1", username: "user1"),
            createTestUser(id: "2", username: "user2"),
            createTestUser(id: "3", username: "user3")
        ]

        // When - Multiple users give kudos to same workout
        for user in users {
            await notificationManager.notifyWorkoutKudos(from: user, for: workoutId)
        }

        // Then - Should batch notifications
        XCTAssertEqual(mockScheduler.scheduledRequests.count, 3)

        // All should have same group ID for batching
        let groupIds = mockScheduler.scheduledRequests.map(\.groupId)
        XCTAssertTrue(groupIds.allSatisfy { $0 == "kudos_\(workoutId)" })
    }

    func testFollowRequestFlow_RequiresImmediateAction() async {
        // Given
        let requester = createTestUser(
            id: "requester",
            username: "fitfan"
        )

        // When
        await notificationManager.notifyFollowRequest(from: requester)

        // Then
        XCTAssertEqual(mockScheduler.scheduledRequests.count, 1)
        let request = mockScheduler.scheduledRequests.first!
        XCTAssertEqual(request.type, .followRequest)
        XCTAssertEqual(request.priority, .immediate)
        XCTAssertEqual(request.actions, [.accept, .decline])
    }

    // MARK: - Rate Limiting Flow Tests

    func testRateLimitingFlow_PreventsSocialNotificationSpam() async {
        // Given - Set low rate limit
        var preferences = NotificationPreferences()
        preferences.maxNotificationsPerHour = 3
        notificationManager.updatePreferences(preferences)
        mockScheduler.respectRateLimit = true

        let user = createTestUser(id: "spammer", username: "spammer")

        // When - Try to send many notifications
        for index in 0 ..< 5 {
            await notificationManager.notifyWorkoutKudos(
                from: user,
                for: "workout\(index)"
            )
        }

        // Then - Only 3 should be scheduled
        XCTAssertEqual(mockScheduler.scheduledRequests.count, 3)
    }

    func testRateLimitingFlow_AllowsImportantNotifications() async {
        // Given - Rate limit reached
        var preferences = NotificationPreferences()
        preferences.maxNotificationsPerHour = 1
        notificationManager.updatePreferences(preferences)
        mockScheduler.respectRateLimit = true

        // Use up rate limit
        let user = createTestUser(id: "user", username: "user")
        await notificationManager.notifyNewFollower(from: user)

        // When - Security alert (immediate priority)
        await notificationManager.notifySecurityAlert(
            title: "Security Alert",
            message: "Suspicious activity detected"
        )

        // Then - Both notifications scheduled (immediate bypasses rate limit)
        XCTAssertEqual(mockScheduler.scheduledRequests.count, 2)
        XCTAssertEqual(mockScheduler.scheduledRequests[1].priority, .immediate)
    }

    // MARK: - Quiet Hours Flow Tests

    func testQuietHoursFlow_DelaysNonUrgentNotifications() async {
        // Given - Enable quiet hours for current time
        var preferences = NotificationPreferences()
        preferences.quietHoursEnabled = true
        let calendar = Calendar.current
        let now = Date()
        preferences.quietHoursStart = calendar.date(byAdding: .hour, value: -1, to: now)
        preferences.quietHoursEnd = calendar.date(byAdding: .hour, value: 1, to: now)
        notificationManager.updatePreferences(preferences)
        mockScheduler.respectQuietHours = true

        let user = createTestUser(id: "quiet", username: "quiet", displayName: "Quiet User")

        // When
        await notificationManager.notifyNewFollower(from: user)

        // Then
        XCTAssertEqual(mockScheduler.scheduledRequests.count, 1)
        XCTAssertTrue(mockScheduler.lastRequestWasDelayed)
    }

    // MARK: - User Preference Flow Tests

    func testUserPreferenceFlow_RespectsDisabledNotificationTypes() async {
        // Given - Disable specific notification types
        var preferences = NotificationPreferences()
        preferences.enabledTypes[.workoutCompleted] = false
        preferences.enabledTypes[.newFollower] = true
        preferences.enabledTypes[.workoutKudos] = false
        notificationManager.updatePreferences(preferences)
        mockScheduler.respectPreferences = true

        let workout = createTestWorkout()
        let user = createTestUser(id: "test", username: "test", displayName: "Test")

        // When
        await notificationManager.notifyWorkoutCompleted(workout)
        await notificationManager.notifyNewFollower(from: user)
        await notificationManager.notifyWorkoutKudos(from: user, for: "workout123")

        // Then - Only new follower notification should be scheduled
        XCTAssertEqual(mockScheduler.scheduledRequests.count, 1)
        XCTAssertEqual(mockScheduler.scheduledRequests.first?.type, .newFollower)
    }

    // MARK: - Helper Methods

    private func createTestUser(
        id: String,
        username: String
    ) -> UserProfile {
        UserProfile(
            id: id,
            userID: id,
            username: username,
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        )
    }

    private func createTestWorkout() -> WorkoutItem {
        WorkoutItem(
            id: UUID(),
            workoutType: "Running",
            startDate: Date().addingTimeInterval(-1_800),
            endDate: Date(),
            duration: 1_800,
            totalEnergyBurned: 250,
            totalDistance: 5_000,
            averageHeartRate: 145,
            followersEarned: 5,
            xpEarned: 100,
            source: "watch"
        )
    }
}

// MARK: - Enhanced Mock Scheduler for Integration Tests

class IntegrationTestScheduler: MockNotificationScheduler {
    var respectRateLimit: Bool = false
    var respectQuietHours: Bool = false
    var respectPreferences: Bool = false
    var lastRequestWasDelayed: Bool = false

    private var rateLimitCount: Int {
        currentPreferences?.maxNotificationsPerHour ?? 10
    }

    override func scheduleFameFitNotification(_ request: NotificationRequest) async throws {
        // Simulate rate limiting
        if respectRateLimit, request.priority != .immediate {
            if scheduledRequests.count >= rateLimitCount {
                throw NotificationError.rateLimitExceeded
            }
        }

        // Simulate quiet hours
        if respectQuietHours, currentPreferences?.isInQuietHours() == true {
            if request.priority != .immediate {
                lastRequestWasDelayed = true
            }
        }

        // Simulate preference filtering
        if respectPreferences {
            if let prefs = currentPreferences,
               !prefs.isNotificationTypeEnabled(request.type) {
                return // Don't schedule
            }
        }

        try await super.scheduleFameFitNotification(request)
    }
}

// MARK: - Enhanced Mock Unlock Service for Integration Tests

class IntegrationTestUnlockService: MockUnlockNotificationService {
    var shouldTriggerUnlock: Bool = false

    override func checkForNewUnlocks(previousXP: Int, currentXP: Int) async {
        await super.checkForNewUnlocks(previousXP: previousXP, currentXP: currentXP)

        if shouldTriggerUnlock {
            // Simulate unlock notification - would be implemented based on actual milestone structure
        }
    }
}

enum NotificationError: Error {
    case rateLimitExceeded
}
