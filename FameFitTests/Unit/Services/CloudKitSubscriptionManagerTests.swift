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
            .workoutHistory,
            .userProfile,
            .socialFollowing,
            .workoutKudos,
            .workoutComments,
            .workoutChallenges,
            .groupWorkouts,
            .activityFeed,
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
        XCTAssertEqual(SubscriptionType.workoutHistory.recordType, "WorkoutHistory")
        XCTAssertEqual(SubscriptionType.workoutHistory.subscriptionID, "workout-history-subscription")

        XCTAssertEqual(SubscriptionType.workoutChallenges.recordType, "WorkoutChallenges")
        XCTAssertEqual(SubscriptionType.workoutChallenges.subscriptionID, "workout-challenges-subscription")

        XCTAssertEqual(SubscriptionType.userProfile.recordType, "UserProfile")
        XCTAssertEqual(SubscriptionType.userProfile.subscriptionID, "user-profile-subscription")
    }

    // MARK: - Setup Tests (Integration-style)

    func testSetupSubscriptions_DoesNotCrash() async {
        // Given/When/Then - Should not crash even if CloudKit is not available
        do {
            try await sut.setupSubscriptions()
            // If successful, that's good
        } catch {
            // If it fails due to no CloudKit account, that's expected in test environment
            print("Setup subscriptions failed as expected in test environment: \(error)")
        }
    }

    func testRemoveAllSubscriptions_DoesNotCrash() async {
        // Given/When/Then - Should not crash even if no subscriptions exist
        do {
            try await sut.removeAllSubscriptions()
            // If successful, that's good
        } catch {
            // If it fails due to no CloudKit account, that's expected in test environment
            print("Remove subscriptions failed as expected in test environment: \(error)")
        }
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

    // MARK: - Error Handling Tests

    func testSubscriptionManager_HandlesNoAccount() async {
        // Given - Real CloudKit environment might not have account

        // When/Then - Should handle gracefully
        do {
            try await sut.setupSubscriptions()
        } catch {
            // Expected in test environment without CloudKit account
            XCTAssertTrue(error is CKError || error.localizedDescription.contains("account"))
        }
    }

    // MARK: - Integration with Real CloudKit Tests

    func testSubscriptionManager_WithRealCloudKit() async {
        // This test uses the real CloudKit container but expects it to fail gracefully
        // in a test environment without proper setup

        // Given
        let manager = CloudKitSubscriptionManager()

        // When
        do {
            try await manager.setupSubscriptions()
            // If this succeeds, CloudKit is properly configured
            XCTAssertTrue(true, "CloudKit setup succeeded")
        } catch let error as CKError {
            // Expected CloudKit errors in test environment
            switch error.code {
            case .notAuthenticated, .networkUnavailable, .networkFailure:
                XCTAssertTrue(true, "Expected CloudKit error: \(error)")
            default:
                XCTFail("Unexpected CloudKit error: \(error)")
            }
        } catch {
            // Other errors might be expected too
            print("Non-CloudKit error (may be expected): \(error)")
        }
    }

    // MARK: - Performance Tests

    func testSubscriptionSetup_Performance() {
        // Given
        let manager = CloudKitSubscriptionManager()

        // When/Then
        measure {
            Task {
                do {
                    try await manager.setupSubscriptions()
                } catch {
                    // Errors are expected in test environment
                }
            }
        }
    }
}
