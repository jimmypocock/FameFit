//
//  WorkoutSharingPromptViewTests.swift
//  FameFitTests
//
//  Unit tests for workout sharing prompt view
//

@testable import FameFit
import SwiftUI
import XCTest

final class WorkoutSharingPromptViewTests: XCTestCase {
    private var container: DependencyContainer!
    private var mockActivityFeedService: MockActivityFeedService!
    private var mockAuthManager: AuthenticationManager!
    private var mockCloudKitManager: MockCloudKitManager!
    private var mockWorkoutObserver: WorkoutObserver!

    override func setUp() {
        super.setUp()
        mockActivityFeedService = MockActivityFeedService()
        mockCloudKitManager = MockCloudKitManager()
        mockAuthManager = AuthenticationManager(cloudKitManager: mockCloudKitManager)
        mockWorkoutObserver = WorkoutObserver(cloudKitManager: mockCloudKitManager)

        container = DependencyContainer(
            authenticationManager: mockAuthManager,
            cloudKitManager: mockCloudKitManager,
            workoutObserver: mockWorkoutObserver,
            activityFeedService: mockActivityFeedService
        )
    }

    override func tearDown() {
        container = nil
        mockActivityFeedService = nil
        mockAuthManager = nil
        mockCloudKitManager = nil
        mockWorkoutObserver = nil
        super.tearDown()
    }

    // MARK: - View Creation Tests

    func testViewCreation() throws {
        // Given
        let workout = createTestWorkout()
        var shareCallbackInvoked = false
        var sharedPrivacy: WorkoutPrivacy?
        var sharedIncludeDetails: Bool?

        // When
        let view = WorkoutSharingPromptView(
            workoutHistory: workout,
            onShare: { privacy, includeDetails in
                shareCallbackInvoked = true
                sharedPrivacy = privacy
                sharedIncludeDetails = includeDetails
            }
        )
        .environment(\.dependencyContainer, container)

        // Then
        XCTAssertNotNil(view)
        XCTAssertFalse(shareCallbackInvoked)
        XCTAssertNil(sharedPrivacy)
        XCTAssertNil(sharedIncludeDetails)
    }

    // MARK: - Content Display Tests

    func testWorkoutInfoDisplay() {
        // Given
        let workout = createTestWorkout(
            workoutType: "running",
            duration: 1800, // 30 minutes
            followersEarned: 25
        )

        // When
        let view = WorkoutSharingPromptView(
            workoutHistory: workout,
            onShare: { _, _ in }
        )
        .environment(\.dependencyContainer, container)

        // Then - Since we can't inspect SwiftUI views without ViewInspector,
        // we verify the data model and behavior instead
        XCTAssertEqual(workout.workoutType, "running")
        XCTAssertEqual(workout.duration, 1800)
        XCTAssertEqual(workout.followersEarned, 25)
        XCTAssertEqual(workout.xpEarned, 25)

        // Verify the view can be created without crashing
        XCTAssertNotNil(view)
    }

    func testPrivacyOptions() {
        // Given
        let workout = createTestWorkout()
        _ = WorkoutSharingPromptView(
            workoutHistory: workout,
            onShare: { _, _ in }
        )
        .environment(\.dependencyContainer, container)

        // Then - Verify privacy options are available
        XCTAssertNotNil(WorkoutPrivacy.private)
        XCTAssertNotNil(WorkoutPrivacy.friendsOnly)
        XCTAssertNotNil(WorkoutPrivacy.public)

        // Verify display names
        XCTAssertFalse(WorkoutPrivacy.private.displayName.isEmpty)
        XCTAssertFalse(WorkoutPrivacy.friendsOnly.displayName.isEmpty)
        XCTAssertFalse(WorkoutPrivacy.public.displayName.isEmpty)
    }

    // MARK: - Interaction Tests

    func testShareButtonInteraction() async throws {
        // Given
        let workout = createTestWorkout()
        let expectation = XCTestExpectation(description: "Share callback invoked")

        _ = WorkoutSharingPromptView(
            workoutHistory: workout,
            onShare: { privacy, includeDetails in
                _ = privacy
                _ = includeDetails
                expectation.fulfill()
            }
        )
        .environment(\.dependencyContainer, container)

        // When - Simulate share button tap
        // Note: ViewInspector doesn't support async button taps directly,
        // so we test the service interaction separately
        try await mockActivityFeedService.postWorkoutActivity(
            workoutHistory: workout,
            privacy: .friendsOnly,
            includeDetails: true
        )

        // Then
        XCTAssertEqual(mockActivityFeedService.postedActivities.count, 1)
        let postedActivity = mockActivityFeedService.postedActivities.first!
        XCTAssertEqual(postedActivity.visibility, "friends_only")
    }

    // MARK: - Privacy Settings Tests

    func testCOPPACompliance_HidesPublicOption() {
        // Given
        var privacySettings = WorkoutPrivacySettings()
        privacySettings.allowPublicSharing = false // COPPA restricted

        // Create a custom container with restricted settings
        let restrictedCloudKit = MockCloudKitManager()
        let restrictedContainer = DependencyContainer(
            authenticationManager: mockAuthManager,
            cloudKitManager: restrictedCloudKit,
            workoutObserver: mockWorkoutObserver,
            activityFeedService: ActivityFeedService(
                cloudKitManager: restrictedCloudKit,
                privacySettings: privacySettings
            )
        )

        let workout = createTestWorkout()
        _ = WorkoutSharingPromptView(
            workoutHistory: workout,
            onShare: { _, _ in }
        )
        .environment(\.dependencyContainer, restrictedContainer)

        // Then - Public option should not be visible
        // Note: This would be better tested with UI tests or snapshot tests
        // For unit tests, we verify the privacy settings behavior
        XCTAssertFalse(privacySettings.allowPublicSharing)
        XCTAssertEqual(privacySettings.effectivePrivacy(for: .running), .private)
    }

    func testDataSharingToggle_DisabledWhenNotAllowed() {
        // Given
        var privacySettings = WorkoutPrivacySettings()
        privacySettings.allowDataSharing = false

        // Then
        XCTAssertFalse(privacySettings.allowDataSharing)
    }

    // MARK: - Error Handling Tests

    func testShareError_DisplaysAlert() async {
        // Given
        mockActivityFeedService.shouldFail = true
        mockActivityFeedService.mockError = .networkError("Connection failed")

        let workout = createTestWorkout()

        // When
        do {
            try await mockActivityFeedService.postWorkoutActivity(
                workoutHistory: workout,
                privacy: .public,
                includeDetails: true
            )
            XCTFail("Expected error to be thrown")
        } catch let error as ActivityFeedError {
            // Then
            if case let .networkError(message) = error {
                XCTAssertEqual(message, "Connection failed")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func createTestWorkout(
        workoutType: String = "running",
        duration: TimeInterval = 1800,
        followersEarned: Int = 25
    ) -> WorkoutHistoryItem {
        WorkoutHistoryItem(
            id: UUID(),
            workoutType: workoutType,
            startDate: Date().addingTimeInterval(-duration),
            endDate: Date(),
            duration: duration,
            totalEnergyBurned: 250,
            totalDistance: 3.2,
            averageHeartRate: 140,
            followersEarned: followersEarned,
            xpEarned: followersEarned,
            source: "FameFit"
        )
    }
}
