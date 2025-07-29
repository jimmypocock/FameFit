//
//  NotificationManagerTests.swift
//  FameFitTests
//
//  Tests for NotificationManager coordination and message generation
//

@testable import FameFit
import UserNotifications
import XCTest

class NotificationManagerTests: XCTestCase {
    private var sut: NotificationManager!
    private var mockScheduler: MockNotificationScheduler!
    private var mockStore: MockNotificationStore!
    private var mockUnlockService: MockUnlockNotificationService!
    private var mockMessageProvider: MockMessageProvider!

    override func setUp() {
        super.setUp()
        // Clear UserDefaults to ensure clean state for each test
        UserDefaults.standard.removeObject(forKey: NotificationPreferences.storageKey)

        mockScheduler = MockNotificationScheduler()
        mockStore = MockNotificationStore()
        mockUnlockService = MockUnlockNotificationService()
        mockMessageProvider = MockMessageProvider()

        sut = NotificationManager(
            scheduler: mockScheduler,
            notificationStore: mockStore,
            unlockService: mockUnlockService,
            messageProvider: mockMessageProvider
        )
    }

    override func tearDown() {
        // Clear UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: NotificationPreferences.storageKey)
        sut = nil
        mockScheduler = nil
        mockStore = nil
        mockUnlockService = nil
        mockMessageProvider = nil
        super.tearDown()
    }

    // MARK: - Permission Tests

    func testRequestNotificationPermission_DelegatesToUnlockService() async {
        // Given
        mockUnlockService.mockPermissionResult = true

        // When
        let result = await sut.requestNotificationPermission()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(mockUnlockService.requestPermissionCalled)
    }

    func testCheckNotificationPermission_ReturnsCorrectStatus() async {
        // When
        let status = await sut.checkNotificationPermission()

        // Then
        // Status depends on system state - just verify we get a valid status
        XCTAssertTrue([.notDetermined, .denied, .authorized, .provisional, .ephemeral].contains(status))
    }

    // MARK: - Workout Notification Tests

    func testNotifyWorkoutCompleted_SchedulesNotificationWithCorrectContent() async {
        // Given
        let workout = WorkoutHistoryItem(
            id: UUID(),
            workoutType: "Running",
            startDate: Date().addingTimeInterval(-1_800),
            endDate: Date(),
            duration: 1_800,
            totalEnergyBurned: 250,
            totalDistance: 5_000,
            averageHeartRate: 145,
            followersEarned: 15, // Legacy parameter
            xpEarned: 100,
            source: "watch"
        )

        // When
        await sut.notifyWorkoutCompleted(workout)

        // Then
        XCTAssertTrue(mockMessageProvider.workoutEndMessageCalled)
        XCTAssertEqual(mockScheduler.scheduledRequests.count, 1)

        let request = mockScheduler.scheduledRequests.first!
        XCTAssertEqual(request.type, .workoutCompleted)
        XCTAssertEqual(request.title, "Workout Complete! 💪")
        XCTAssertEqual(request.body, "Test workout message")

        // Verify metadata
        if case let .workout(metadata) = request.metadata {
            XCTAssertEqual(metadata.workoutId, workout.id.uuidString)
            XCTAssertEqual(metadata.duration, 30) // 1800 seconds = 30 minutes
            XCTAssertEqual(metadata.calories, 250)
            XCTAssertEqual(metadata.xpEarned, 100)
        } else {
            XCTFail("Expected workout metadata")
        }
    }

    func testNotifyWorkoutCompleted_HandlesNilXPEarned() async {
        // Given
        let workout = WorkoutHistoryItem(
            id: UUID(),
            workoutType: "Yoga",
            startDate: Date().addingTimeInterval(-600),
            endDate: Date(),
            duration: 600,
            totalEnergyBurned: 50,
            totalDistance: 0,
            averageHeartRate: nil,
            followersEarned: 5, // Legacy parameter
            xpEarned: nil,
            source: "watch"
        )

        // When
        await sut.notifyWorkoutCompleted(workout)

        // Then
        let request = mockScheduler.scheduledRequests.first!
        if case let .workout(metadata) = request.metadata {
            XCTAssertEqual(metadata.xpEarned, 0)
        }
    }

    func testNotifyXPMilestone_DelegatesToUnlockService() async {
        // When
        await sut.notifyXPMilestone(previousXP: 900, currentXP: 1_100)

        // Then
        XCTAssertTrue(mockUnlockService.checkForNewUnlocksCalled)
        XCTAssertEqual(mockUnlockService.lastPreviousXP, 900)
        XCTAssertEqual(mockUnlockService.lastCurrentXP, 1_100)
    }

    func testNotifyStreakUpdate_AtRisk_SchedulesHighPriorityNotification() async {
        // When
        await sut.notifyStreakUpdate(streak: 7, isAtRisk: true)

        // Then
        XCTAssertEqual(mockScheduler.scheduledRequests.count, 1)
        let request = mockScheduler.scheduledRequests.first!
        XCTAssertEqual(request.type, .streakAtRisk)
        XCTAssertEqual(request.priority, .high)
        XCTAssertTrue(request.title.contains("Streak at Risk"))
        XCTAssertTrue(request.body.contains("7-day streak"))
    }

    func testNotifyStreakUpdate_Maintained_SchedulesMediumPriorityNotification() async {
        // When
        await sut.notifyStreakUpdate(streak: 30, isAtRisk: false)

        // Then
        XCTAssertEqual(mockScheduler.scheduledRequests.count, 1)
        let request = mockScheduler.scheduledRequests.first!
        XCTAssertEqual(request.type, .streakMaintained)
        XCTAssertEqual(request.priority, .medium)
        XCTAssertTrue(request.title.contains("Streak Maintained"))
        XCTAssertTrue(request.body.contains("30-day"))
    }

    // MARK: - Social Notification Tests

    func testNotifyNewFollower_SchedulesNotificationWithUserInfo() async {
        // Given
        let user = UserProfile(
            id: "profile123",
            userID: "user123",
            username: "fitguru",
            displayName: "Fitness Guru",
            bio: "Love fitness",
            workoutCount: 10,
            totalXP: 500,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: "https://example.com/image.jpg",
            headerImageURL: nil
        )

        // When
        await sut.notifyNewFollower(from: user)

        // Then
        XCTAssertEqual(mockScheduler.scheduledRequests.count, 1)
        let request = mockScheduler.scheduledRequests.first!
        XCTAssertEqual(request.type, .newFollower)
        XCTAssertTrue(request.body.contains("Fitness Guru"))
        XCTAssertTrue(request.body.contains("@fitguru"))

        // Verify metadata
        if case let .social(metadata) = request.metadata {
            XCTAssertEqual(metadata.userID, "user123")
            XCTAssertEqual(metadata.username, "fitguru")
            XCTAssertEqual(metadata.displayName, "Fitness Guru")
        } else {
            XCTFail("Expected social metadata")
        }
    }

    func testNotifyFollowRequest_SchedulesImmediatePriorityWithActions() async {
        // Given
        let user = UserProfile(
            id: "profile456",
            userID: "user456",
            username: "gymrat",
            displayName: "Gym Rat",
            bio: "",
            workoutCount: 15,
            totalXP: 750,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .privateProfile,
            profileImageURL: nil,
            headerImageURL: nil
        )

        // When
        await sut.notifyFollowRequest(from: user)

        // Then
        let request = mockScheduler.scheduledRequests.first!
        XCTAssertEqual(request.type, .followRequest)
        XCTAssertEqual(request.priority, .immediate)
        XCTAssertEqual(request.actions, [.accept, .decline])
    }

    func testNotifyWorkoutKudos_GroupsNotificationsByWorkout() async {
        // Given
        let user = UserProfile(
            id: "profile789",
            userID: "user789",
            username: "supporter",
            displayName: "Supportive Friend",
            bio: "",
            workoutCount: 25,
            totalXP: 1_200,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        )
        let workoutId = "workout123"

        // When
        await sut.notifyWorkoutKudos(from: user, for: workoutId)

        // Then
        let request = mockScheduler.scheduledRequests.first!
        XCTAssertEqual(request.type, .workoutKudos)
        XCTAssertEqual(request.groupId, "kudos_\(workoutId)")
        XCTAssertTrue(request.body.contains("Supportive Friend"))
    }

    func testNotifyWorkoutComment_TruncatesLongComments() async {
        // Given
        let user = UserProfile(
            id: "profile999",
            userID: "user999",
            username: "commenter",
            displayName: "Chatty User",
            bio: "",
            workoutCount: 5,
            totalXP: 200,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        )
        let longComment = String(repeating: "Great workout! ", count: 10)

        // When
        await sut.notifyWorkoutComment(from: user, comment: longComment, for: "workout456")

        // Then
        let request = mockScheduler.scheduledRequests.first!
        XCTAssertEqual(request.type, .workoutComment)
        XCTAssertTrue(request.body.count <= 50)
        XCTAssertTrue(request.body.hasSuffix("..."))
        XCTAssertEqual(request.actions, [.view, .reply])
    }

    // MARK: - System Notification Tests

    func testNotifySecurityAlert_SchedulesImmediatePriorityNotification() async {
        // When
        await sut.notifySecurityAlert(
            title: "Suspicious Login",
            message: "Login attempt from new device"
        )

        // Then
        let request = mockScheduler.scheduledRequests.first!
        XCTAssertEqual(request.type, .securityAlert)
        XCTAssertEqual(request.priority, .immediate)
        XCTAssertEqual(request.title, "Suspicious Login")

        if case let .system(metadata) = request.metadata {
            XCTAssertEqual(metadata.severity, "critical")
            XCTAssertTrue(metadata.requiresAction)
        }
    }

    func testNotifyFeatureAnnouncement_SchedulesLowPriorityNotification() async {
        // When
        await sut.notifyFeatureAnnouncement(
            feature: "Social Feed",
            description: "Connect with other fitness enthusiasts"
        )

        // Then
        let request = mockScheduler.scheduledRequests.first!
        XCTAssertEqual(request.type, .featureAnnouncement)
        XCTAssertEqual(request.priority, .low)
        XCTAssertTrue(request.title.contains("Social Feed"))
    }

    // MARK: - Preference Management Tests

    func testUpdatePreferences_UpdatesSchedulerPreferences() {
        // Given
        var preferences = NotificationPreferences()
        preferences.pushNotificationsEnabled = true
        preferences.maxNotificationsPerHour = 5
        preferences.quietHoursEnabled = true

        // When
        sut.updatePreferences(preferences)

        // Then
        XCTAssertTrue(mockScheduler.updatePreferencesCalled)
        XCTAssertEqual(mockScheduler.currentPreferences?.maxNotificationsPerHour, 5)
    }

    func testGetPreferences_ReturnsStoredPreferences() {
        // When
        let preferences = sut.getPreferences()

        // Then
        XCTAssertNotNil(preferences)
        XCTAssertTrue(preferences.pushNotificationsEnabled) // Default value
    }
}

// MARK: - Mock Notification Scheduler

class MockNotificationScheduler: NotificationScheduling {
    var scheduledRequests: [NotificationRequest] = []
    var updatePreferencesCalled = false
    var currentPreferences: NotificationPreferences?

    func scheduleNotification(_ request: NotificationRequest) async throws {
        scheduledRequests.append(request)
    }

    func cancelNotification(withId id: String) async {
        scheduledRequests.removeAll { $0.id == id }
    }

    func cancelAllNotifications() async {
        scheduledRequests.removeAll()
    }

    func getPendingNotifications() async -> [NotificationRequest] {
        scheduledRequests
    }

    func updatePreferences(_ preferences: NotificationPreferences) {
        updatePreferencesCalled = true
        currentPreferences = preferences
    }
}

// MARK: - Mock Unlock Notification Service

class MockUnlockNotificationService: UnlockNotificationServiceProtocol {
    var mockPermissionResult = true
    var requestPermissionCalled = false
    var checkForNewUnlocksCalled = false
    var lastPreviousXP: Int?
    var lastCurrentXP: Int?
    var levelUpCalled = false
    var lastLevel: Int?
    var lastTitle: String?

    func requestNotificationPermission() async -> Bool {
        requestPermissionCalled = true
        return mockPermissionResult
    }

    func checkForNewUnlocks(previousXP: Int, currentXP: Int) async {
        checkForNewUnlocksCalled = true
        lastPreviousXP = previousXP
        lastCurrentXP = currentXP
    }

    func notifyLevelUp(newLevel: Int, title: String) async {
        levelUpCalled = true
        lastLevel = newLevel
        lastTitle = title
    }
}
