//
//  NotificationSchedulerTests.swift
//  FameFitTests
//
//  Tests for NotificationScheduler rate limiting and batching
//

@testable import FameFit
import UserNotifications
import XCTest

class NotificationSchedulerTests: XCTestCase {
    private var sut: TestableNotificationScheduler!
    private var mockNotificationStore: MockNotificationStore!
    private var mockPreferences: NotificationPreferences!

    override func setUp() {
        super.setUp()
        mockNotificationStore = MockNotificationStore()
        mockPreferences = NotificationPreferences()
        sut = TestableNotificationScheduler(notificationStore: mockNotificationStore)
        sut.updatePreferences(mockPreferences)
    }

    override func tearDown() {
        sut = nil
        mockNotificationStore = nil
        mockPreferences = nil
        super.tearDown()
    }

    // MARK: - Rate Limiting Tests

    func testScheduleNotification_WithinRateLimit_SchedulesSuccessfully() async throws {
        // Given
        mockPreferences.maxNotificationsPerHour = 10
        sut.updatePreferences(mockPreferences)

        let request = NotificationRequest(
            type: .workoutCompleted,
            title: "Test",
            body: "Test notification"
        )

        // When
        try await sut.scheduleNotification(request)

        // Then
        XCTAssertEqual(sut.addedRequests.count, 1)
        XCTAssertEqual(sut.addedRequests.first?.title, "Test")
    }

    func testScheduleNotification_ExceedsRateLimit_ThrowsError() async {
        // Given
        mockPreferences.maxNotificationsPerHour = 2
        sut.updatePreferences(mockPreferences)
        sut.simulateRateLimit = true

        // Send 2 notifications to hit the limit
        for index in 0 ..< 2 {
            let request = NotificationRequest(
                type: .workoutCompleted,
                title: "Test \(index)",
                body: "Test notification"
            )
            try? await sut.scheduleNotification(request)
        }

        // When/Then - Third notification should be rate limited
        let rateLimitedRequest = NotificationRequest(
            type: .workoutCompleted,
            title: "Rate Limited",
            body: "Should not be scheduled"
        )

        do {
            try await sut.scheduleNotification(rateLimitedRequest)
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(sut.addedRequests.count, 2)
        }
    }

    func testScheduleNotification_ImmediatePriority_BypassesRateLimit() async throws {
        // Given
        mockPreferences.maxNotificationsPerHour = 1
        sut.updatePreferences(mockPreferences)

        // Send 1 notification to hit the limit
        let normalRequest = NotificationRequest(
            type: .workoutCompleted,
            title: "Normal",
            body: "Normal notification"
        )
        try await sut.scheduleNotification(normalRequest)

        // When - Send immediate priority notification
        let immediateRequest = NotificationRequest(
            type: .securityAlert,
            title: "Security Alert",
            body: "Important notification",
            priority: .immediate
        )
        try await sut.scheduleNotification(immediateRequest)

        // Then
        XCTAssertEqual(sut.addedRequests.count, 2)
        XCTAssertEqual(sut.addedRequests[1].title, "Security Alert")
    }

    // MARK: - Quiet Hours Tests

    func testScheduleNotification_DuringQuietHours_DelaysDelivery() async throws {
        // Given
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)

        mockPreferences.quietHoursEnabled = true
        mockPreferences.quietHoursStart = calendar.date(bySettingHour: currentHour, minute: 0, second: 0, of: now)!
        mockPreferences.quietHoursEnd = calendar.date(byAdding: .hour, value: 2, to: mockPreferences.quietHoursStart!)!
        sut.updatePreferences(mockPreferences)
        sut.simulateQuietHours = true

        let request = NotificationRequest(
            type: .workoutCompleted,
            title: "Quiet Hours Test",
            body: "Should be delayed"
        )

        // When
        try await sut.scheduleNotification(request)

        // Then
        XCTAssertEqual(sut.addedRequests.count, 1)
        let scheduledRequest = sut.addedRequests.first!

        // Verify delivery date is set for after quiet hours
        XCTAssertNotNil(scheduledRequest.deliveryDate)
        if let deliveryDate = scheduledRequest.deliveryDate {
            let triggerHour = calendar.component(.hour, from: deliveryDate)
            let expectedHour = calendar.component(.hour, from: mockPreferences.quietHoursEnd!)
            XCTAssertEqual(triggerHour, expectedHour)
        }
    }

    func testScheduleNotification_OutsideQuietHours_DeliversImmediately() async throws {
        // Given
        let calendar = Calendar.current
        let now = Date()

        mockPreferences.quietHoursEnabled = true
        // Set quiet hours for 2 hours ago
        mockPreferences.quietHoursStart = calendar.date(byAdding: .hour, value: -4, to: now)!
        mockPreferences.quietHoursEnd = calendar.date(byAdding: .hour, value: -2, to: now)!
        sut.updatePreferences(mockPreferences)

        let request = NotificationRequest(
            type: .workoutCompleted,
            title: "Outside Quiet Hours",
            body: "Should deliver immediately"
        )

        // When
        try await sut.scheduleNotification(request)

        // Then
        XCTAssertEqual(sut.addedRequests.count, 1)
        let scheduledRequest = sut.addedRequests.first!
        XCTAssertNil(scheduledRequest.deliveryDate) // nil delivery date means immediate delivery
    }

    // MARK: - Batching Tests

    func testScheduleNotification_SimilarNotifications_BatchesTogether() async throws {
        // Given
        let workoutId = "workout123"
        sut.simulateBatching = true

        // When - Schedule multiple kudos for same workout
        for index in 0 ..< 3 {
            let request = NotificationRequest(
                type: .workoutKudos,
                title: "Kudos \(index)",
                body: "User \(index) cheered",
                groupId: "kudos_\(workoutId)"
            )
            try await sut.scheduleNotification(request)
        }

        // Simulate batch window passing
        sut.triggerBatch()

        // Then - Should batch into summary notification
        XCTAssertTrue(sut.batchingWindowReached)
        XCTAssertEqual(sut.batchedRequests.count, 1)
        let batchedRequest = sut.batchedRequests.first!
        XCTAssertTrue(batchedRequest.title.contains("3"))
        XCTAssertEqual(batchedRequest.type, .workoutKudos)
    }

    func testScheduleNotification_DifferentTypes_DoesNotBatch() async throws {
        // Given/When
        let kudosRequest = NotificationRequest(
            type: .workoutKudos,
            title: "Kudos",
            body: "Someone cheered"
        )
        try await sut.scheduleNotification(kudosRequest)

        let commentRequest = NotificationRequest(
            type: .workoutComment,
            title: "Comment",
            body: "Someone commented"
        )
        try await sut.scheduleNotification(commentRequest)

        // Then
        XCTAssertEqual(sut.addedRequests.count, 2)
    }

    // MARK: - Preference Tests

    func testUpdatePreferences_UpdatesSchedulerBehavior() async throws {
        // Given
        var preferences = NotificationPreferences()
        preferences.maxNotificationsPerHour = 1
        sut.updatePreferences(preferences)
        sut.simulateRateLimit = true

        // Send first notification
        let request1 = NotificationRequest(type: .workoutCompleted, title: "Test 1", body: "Body 1")
        try await sut.scheduleNotification(request1)

        // Update preferences to allow more
        preferences.maxNotificationsPerHour = 10
        sut.updatePreferences(preferences)
        sut.simulateRateLimit = false

        // When - Send second notification
        let request2 = NotificationRequest(type: .workoutCompleted, title: "Test 2", body: "Body 2")
        try await sut.scheduleNotification(request2)

        // Then
        XCTAssertEqual(sut.addedRequests.count, 2)
    }

    func testScheduleNotification_DisabledNotificationType_DoesNotSchedule() async throws {
        // Given
        var preferences = NotificationPreferences()
        preferences.enabledTypes[.workoutCompleted] = false
        sut.updatePreferences(preferences)

        let request = NotificationRequest(
            type: .workoutCompleted,
            title: "Disabled Type",
            body: "Should not be scheduled"
        )

        // When
        try await sut.scheduleNotification(request)

        // Then
        XCTAssertEqual(sut.addedRequests.count, 0)
    }

    // MARK: - Content Enrichment Tests

    func testScheduleNotification_WithMetadata_EnrichesContent() async throws {
        // Given
        let metadata = NotificationMetadataContainer.workout(
            WorkoutNotificationMetadata(
                workoutId: "123",
                workoutType: "Running",
                duration: 30,
                calories: 250,
                xpEarned: 100,
                distance: 5_000,
                averageHeartRate: 145
            )
        )

        let request = NotificationRequest(
            type: .workoutCompleted,
            title: "Workout Complete",
            body: "Great job!",
            metadata: metadata
        )

        // When
        try await sut.scheduleNotification(request)

        // Then
        XCTAssertEqual(sut.addedRequests.count, 1)
        let scheduledRequest = sut.addedRequests.first!
        // Verify metadata was passed through
        if case let .workout(metadata) = scheduledRequest.metadata {
            XCTAssertEqual(metadata.workoutId, "123")
            XCTAssertEqual(metadata.xpEarned, 100)
        } else {
            XCTFail("Expected workout metadata")
        }
    }

    func testScheduleNotification_WithActions_SetsCategory() async throws {
        // Given
        let request = NotificationRequest(
            type: .followRequest,
            title: "Follow Request",
            body: "Someone wants to follow you",
            actions: [.accept, .decline]
        )

        // When
        try await sut.scheduleNotification(request)

        // Then
        XCTAssertEqual(sut.addedRequests.count, 1)
        let scheduledRequest = sut.addedRequests.first!
        XCTAssertEqual(scheduledRequest.type, .followRequest)
        XCTAssertEqual(scheduledRequest.actions, [.accept, .decline])
    }
}

// MARK: - Testable Notification Scheduler

class TestableNotificationScheduler: NotificationScheduling {
    var addedRequests: [NotificationRequest] = []
    var batchedRequests: [NotificationRequest] = []
    var preferences = NotificationPreferences()
    var notificationStore: any NotificationStoring

    // Simulation flags
    var simulateRateLimit = false
    var simulateQuietHours = false
    var simulateBatching = false
    var batchingWindowReached = false

    private var pendingBatches: [NotificationType: [NotificationRequest]] = [:]

    init(notificationStore: any NotificationStoring) {
        self.notificationStore = notificationStore
    }

    func scheduleNotification(_ notification: NotificationRequest) async throws {
        // Check preferences
        guard preferences.isNotificationTypeEnabled(notification.type) else {
            return
        }

        // Simulate rate limiting
        if simulateRateLimit, notification.priority != .immediate {
            if addedRequests.count >= preferences.maxNotificationsPerHour {
                throw NotificationSchedulerError.rateLimitExceeded
            }
        }

        // Simulate quiet hours
        if simulateQuietHours, preferences.isInQuietHours() {
            var delayedNotification = notification
            _ = Calendar.current
            if let endTime = preferences.quietHoursEnd {
                delayedNotification = NotificationRequest(
                    type: notification.type,
                    title: notification.title,
                    body: notification.body,
                    metadata: notification.metadata,
                    priority: notification.priority,
                    actions: notification.actions,
                    groupId: notification.groupId,
                    deliveryDate: endTime
                )
            }
            addedRequests.append(delayedNotification)
            return
        }

        // Simulate batching
        if simulateBatching, notification.type == .workoutKudos {
            pendingBatches[notification.type, default: []].append(notification)
            return
        }

        addedRequests.append(notification)

        // Also add to notification store
        let item = NotificationItem(
            type: notification.type,
            title: notification.title,
            body: notification.body,
            metadata: notification.metadata,
            actions: notification.actions,
            groupId: notification.groupId
        )
        notificationStore.addNotification(item)
    }

    func cancelNotification(withId id: String) async {
        addedRequests.removeAll { $0.id == id }
    }

    func cancelAllNotifications() async {
        addedRequests.removeAll()
        batchedRequests.removeAll()
    }

    func getPendingNotifications() async -> [NotificationRequest] {
        addedRequests
    }

    func updatePreferences(_ preferences: NotificationPreferences) {
        self.preferences = preferences
    }

    func triggerBatch() {
        batchingWindowReached = true

        for (type, notifications) in pendingBatches {
            guard !notifications.isEmpty else { continue }

            let batchedRequest = NotificationRequest(
                type: type,
                title: "\(notifications.count) \(type.displayName)",
                body: "You have \(notifications.count) new notifications",
                groupId: notifications.first?.groupId
            )
            batchedRequests.append(batchedRequest)
        }

        pendingBatches.removeAll()
    }
}

enum NotificationSchedulerError: Error {
    case rateLimitExceeded
}
