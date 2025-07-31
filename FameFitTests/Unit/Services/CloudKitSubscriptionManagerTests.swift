//
//  CloudKitSubscriptionManagerTests.swift
//  FameFitTests
//
//  Tests for CloudKitSubscriptionManager
//

import CloudKit
import Combine
@testable import FameFit
import XCTest

final class CloudKitSubscriptionManagerTests: XCTestCase {
    private var sut: CloudKitSubscriptionManager!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        // Use default container since CKContainer subclassing is complex
        sut = CloudKitSubscriptionManager()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        sut = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Basic Tests

    func testCloudKitSubscriptionManagerInitialization() {
        // Given/When
        let manager = CloudKitSubscriptionManager()

        // Then
        XCTAssertNotNil(manager)
    }

    func testNotificationPublisher_IsAvailable() {
        // Given/When
        let publisher = sut.notificationPublisher

        // Then
        XCTAssertNotNil(publisher)
    }

    // MARK: - Subscription Type Tests

    func testSubscriptionTypes_ContainExpectedValues() {
        // Given
        let expectedTypes: [SubscriptionType] = [
            .workouts,
            .userProfile,
            .socialFollowing,
            .workoutKudos,
            .workoutComments,
            .workoutChallenges,
            .groupWorkouts,
            .activityFeed
        ]

        // When
        let allTypes = SubscriptionType.allCases

        // Then
        XCTAssertEqual(allTypes.count, expectedTypes.count)
        for expectedType in expectedTypes {
            XCTAssertTrue(allTypes.contains(expectedType))
        }
    }

    func testSubscriptionType_PropertiesAreCorrect() {
        // Test a few key subscription types
        XCTAssertEqual(SubscriptionType.workouts.recordType, "Workouts")
        XCTAssertEqual(SubscriptionType.workouts.subscriptionID, "workouts-subscription")

        XCTAssertEqual(SubscriptionType.workoutChallenges.recordType, "WorkoutChallenges")
        XCTAssertEqual(SubscriptionType.workoutChallenges.subscriptionID, "workout-challenges-subscription")

        XCTAssertEqual(SubscriptionType.userProfile.recordType, "UserProfile")
        XCTAssertEqual(SubscriptionType.userProfile.subscriptionID, "user-profile-subscription")
    }


    // MARK: - Notification Handling Tests

    func testNotificationPublisher_CanReceiveSubscriptions() async {
        // Given
        let expectation = XCTestExpectation(description: "Notification received")
        expectation.isInverted = true // We expect NOT to receive anything in short time

        var receivedNotification: CloudKitNotificationInfo?
        sut.notificationPublisher
            .sink { info in
                receivedNotification = info
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When - Short wait to see if anything comes through
        await fulfillment(of: [expectation], timeout: 0.1)

        // Then - Should not have received anything without actual CloudKit notifications
        XCTAssertNil(receivedNotification)
    }

    // MARK: - CloudKitNotificationInfo Tests

    func testCloudKitNotificationInfo_Initialization() {
        // Given
        let recordID = CKRecord.ID(recordName: "test-record")
        let changeType = "recordCreated"
        let userInfo = ["key": "value"]

        // When
        let notificationInfo = CloudKitNotificationInfo(
            recordType: "TestRecord",
            recordID: recordID,
            changeType: changeType,
            userInfo: userInfo
        )

        // Then
        XCTAssertEqual(notificationInfo.recordType, "TestRecord")
        XCTAssertEqual(notificationInfo.recordID, recordID)
        XCTAssertEqual(notificationInfo.changeType, changeType)
        XCTAssertEqual(notificationInfo.userInfo["key"] as? String, "value")
    }

}
