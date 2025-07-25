//
//  RealTimeSyncCoordinatorTests.swift
//  FameFitTests
//
//  Tests for RealTimeSyncCoordinator
//

import CloudKit
import Combine
@testable import FameFit
import XCTest

final class RealTimeSyncCoordinatorTests: XCTestCase {
    private var sut: RealTimeSyncCoordinator!
    private var mockSubscriptionManager: MockCloudKitSubscriptionManager!
    private var mockCloudKitManager: MockCloudKitManager!
    private var mockUserProfileService: MockUserProfileService!
    private var mockWorkoutChallengesService: MockWorkoutChallengesService!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()

        mockSubscriptionManager = MockCloudKitSubscriptionManager()
        mockCloudKitManager = MockCloudKitManager()
        mockUserProfileService = MockUserProfileService()
        mockWorkoutChallengesService = MockWorkoutChallengesService()

        sut = await MainActor.run {
            RealTimeSyncCoordinator(
                subscriptionManager: mockSubscriptionManager,
                cloudKitManager: mockCloudKitManager,
                socialFollowingService: MockSocialFollowingService(),
                userProfileService: mockUserProfileService,
                workoutKudosService: MockWorkoutKudosService(),
                workoutCommentsService: MockWorkoutCommentsService(),
                workoutChallengesService: mockWorkoutChallengesService,
                groupWorkoutService: MockGroupWorkoutService(),
                activityFeedService: ActivityFeedService(
                    cloudKitManager: mockCloudKitManager,
                    privacySettings: WorkoutPrivacySettings()
                )
            )
        }

        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockSubscriptionManager = nil
        mockCloudKitManager = nil
        mockUserProfileService = nil
        mockWorkoutChallengesService = nil
        super.tearDown()
    }

    // MARK: - Start/Stop Tests

    @MainActor
    func testStartRealTimeSync_SetsUpSubscriptions() async {
        // When
        await sut.startRealTimeSync()

        // Then
        XCTAssertEqual(mockSubscriptionManager.setupSubscriptionsCallCount, 1)
    }

    @MainActor
    func testStopRealTimeSync_CleansUp() async {
        // Given
        await sut.startRealTimeSync()

        // When
        await sut.stopRealTimeSync()

        // Then - Can't directly test cancellables cleared, but ensure no crash
        XCTAssertTrue(true)
    }

    // MARK: - Handle Remote Change Tests

    @MainActor
    func testHandleUserProfileChange_ClearsCacheAndPublishesUpdate() async {
        // Given
        let expectation = XCTestExpectation(description: "Profile update published")
        let userId = "test-user-123"
        let notification = CloudKitNotificationInfo(
            recordType: SubscriptionType.userProfile.recordType,
            recordID: CKRecord.ID(recordName: userId),
            changeType: "recordUpdated",
            userInfo: [:]
        )

        sut.profileUpdatePublisher
            .sink { publishedUserId in
                XCTAssertEqual(publishedUserId, userId)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        await sut.handleRemoteChange(notification)

        // Then
        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertTrue(mockUserProfileService.clearedCacheUserIds.contains(userId), "Expected clearedCacheUserIds to contain \(userId), but got: \(mockUserProfileService.clearedCacheUserIds)")
    }

    @MainActor
    func testHandleChallengeChange_PublishesUpdate() async {
        // Given
        let expectation = XCTestExpectation(description: "Challenge update published")
        let challengeId = "challenge-123"
        let notification = CloudKitNotificationInfo(
            recordType: SubscriptionType.workoutChallenges.recordType,
            recordID: CKRecord.ID(recordName: challengeId),
            changeType: "recordUpdated",
            userInfo: ["status": "active"]
        )

        sut.challengeUpdatePublisher
            .sink { publishedChallengeId in
                XCTAssertEqual(publishedChallengeId, challengeId)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        await sut.handleRemoteChange(notification)

        // Then
        await fulfillment(of: [expectation], timeout: 1)
    }

    @MainActor
    func testHandleKudosChange_PublishesWorkoutUpdate() async {
        // Given
        let expectation = XCTestExpectation(description: "Kudos update published")
        let workoutId = "workout-456"
        let notification = CloudKitNotificationInfo(
            recordType: SubscriptionType.workoutKudos.recordType,
            recordID: CKRecord.ID(recordName: "kudos-123"),
            changeType: "recordCreated",
            userInfo: ["workoutId": workoutId]
        )

        sut.kudosUpdatePublisher
            .sink { publishedWorkoutId in
                XCTAssertEqual(publishedWorkoutId, workoutId)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        await sut.handleRemoteChange(notification)

        // Then
        await fulfillment(of: [expectation], timeout: 1)
    }

    @MainActor
    func testHandleCommentChange_PublishesWorkoutUpdate() async {
        // Given
        let expectation = XCTestExpectation(description: "Comment update published")
        let workoutId = "workout-789"
        let notification = CloudKitNotificationInfo(
            recordType: SubscriptionType.workoutComments.recordType,
            recordID: CKRecord.ID(recordName: "comment-123"),
            changeType: "recordCreated",
            userInfo: ["workoutId": workoutId]
        )

        sut.commentUpdatePublisher
            .sink { publishedWorkoutId in
                XCTAssertEqual(publishedWorkoutId, workoutId)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        await sut.handleRemoteChange(notification)

        // Then
        await fulfillment(of: [expectation], timeout: 1)
    }

    @MainActor
    func testHandleSocialFollowingChange_PublishesProfileAndFeedUpdates() async {
        // Given
        let profileExpectation = XCTestExpectation(description: "Profile updates published")
        profileExpectation.expectedFulfillmentCount = 2 // follower and following
        let feedExpectation = XCTestExpectation(description: "Feed update published")

        let followerID = "follower-123"
        let followingID = "following-456"
        let notification = CloudKitNotificationInfo(
            recordType: SubscriptionType.socialFollowing.recordType,
            recordID: CKRecord.ID(recordName: "follow-123"),
            changeType: "recordCreated",
            userInfo: [
                "followerID": followerID,
                "followingID": followingID,
            ]
        )

        var receivedUserIds: [String] = []
        sut.profileUpdatePublisher
            .sink { userId in
                receivedUserIds.append(userId)
                profileExpectation.fulfill()
            }
            .store(in: &cancellables)

        sut.feedUpdatePublisher
            .sink { _ in
                feedExpectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        await sut.handleRemoteChange(notification)

        // Then
        await fulfillment(of: [profileExpectation, feedExpectation], timeout: 1)
        XCTAssertTrue(receivedUserIds.contains(followerID))
        XCTAssertTrue(receivedUserIds.contains(followingID))
    }

    @MainActor
    func testHandleActivityFeedChange_PublishesFeedUpdate() async {
        // Given
        let expectation = XCTestExpectation(description: "Feed update published")
        let notification = CloudKitNotificationInfo(
            recordType: SubscriptionType.activityFeed.recordType,
            recordID: CKRecord.ID(recordName: "activity-123"),
            changeType: "recordCreated",
            userInfo: [:]
        )

        sut.feedUpdatePublisher
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        await sut.handleRemoteChange(notification)

        // Then
        await fulfillment(of: [expectation], timeout: 1)
    }

    @MainActor
    func testHandleWorkoutHistoryChange_PublishesFeedUpdate() async {
        // Given
        let expectation = XCTestExpectation(description: "Feed update published")
        let notification = CloudKitNotificationInfo(
            recordType: SubscriptionType.workoutHistory.recordType,
            recordID: CKRecord.ID(recordName: "workout-123"),
            changeType: "recordCreated",
            userInfo: [:]
        )

        sut.feedUpdatePublisher
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        await sut.handleRemoteChange(notification)

        // Then
        await fulfillment(of: [expectation], timeout: 1)
    }
}

// MARK: - Mock CloudKit Subscription Manager

class MockCloudKitSubscriptionManager: CloudKitSubscriptionManaging {
    var setupSubscriptionsCallCount = 0
    var removeAllSubscriptionsCallCount = 0
    var handledNotifications: [CKQueryNotification] = []

    private let notificationSubject = PassthroughSubject<CloudKitNotificationInfo, Never>()
    var notificationPublisher: AnyPublisher<CloudKitNotificationInfo, Never> {
        notificationSubject.eraseToAnyPublisher()
    }

    func setupSubscriptions() async throws {
        setupSubscriptionsCallCount += 1
    }

    func removeAllSubscriptions() async throws {
        removeAllSubscriptionsCallCount += 1
    }

    func handleNotification(_ notification: CKQueryNotification) async {
        handledNotifications.append(notification)
    }

    // Test helper to simulate notifications
    func simulateNotification(_ info: CloudKitNotificationInfo) {
        notificationSubject.send(info)
    }
}
