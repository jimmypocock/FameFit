//
//  ActivityFeedViewModelExtendedTests.swift
//  FameFitTests
//
//  Extended unit tests for social feed view model (error handling, pagination, performance, etc.)
//

import Combine
@testable import FameFit
import XCTest

// Type alias to avoid ambiguity
typealias MockKudosService = MockWorkoutKudosService

@MainActor
final class ActivityFeedViewModelExtendedTests: XCTestCase {
    private var viewModel: ActivityFeedViewModel!
    private var mockSocialService: MockSocialFollowingService!
    private var mockProfileService: MockUserProfileService!
    private var mockActivityFeedService: MockActivityFeedService!
    private var mockKudosService: MockKudosService!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        viewModel = ActivityFeedViewModel()
        mockSocialService = MockSocialFollowingService()
        mockProfileService = MockUserProfileService()
        mockActivityFeedService = MockActivityFeedService()
        mockKudosService = MockKudosService()
        cancellables = Set<AnyCancellable>()

        // Configure the view model with mock services
        viewModel.configure(
            socialService: mockSocialService,
            profileService: mockProfileService,
            activityFeedService: mockActivityFeedService,
            kudosService: mockKudosService,
            commentsService: MockActivityFeedCommentsService(),
            currentUserId: "test-current-user"
        )
    }

    override func tearDown() {
        viewModel = nil
        mockSocialService = nil
        mockProfileService = nil
        mockActivityFeedService = nil
        mockKudosService = nil
        cancellables = nil

        super.tearDown()
    }

    // MARK: - Error Handling Tests

    func testErrorHandling_SocialServiceError() async {
        // Given
        mockSocialService.shouldFailNextAction = true
        // Use a simpler error without NSError
        mockSocialService.mockError = .userNotFound

        // When
        await viewModel.loadInitialFeed()

        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.error, "Failed to load feed")
        XCTAssertEqual(viewModel.feedItems.count, 0)
    }

    func testErrorHandling_ProfileServiceError() async {
        // Given
        mockProfileService.shouldFail = true

        // When
        await viewModel.loadInitialFeed()

        // Then - Should still complete without crashing
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Pagination Tests

    func testPagination_HasMoreItems() async {
        // Given
        await viewModel.loadInitialFeed()
        let initialCount = viewModel.feedItems.count

        // Then - Should have loaded some items
        XCTAssertGreaterThan(initialCount, 0, "Should load some items on initial load")

        // When - Try to load more items
        if viewModel.hasMoreItems {
            await viewModel.loadMoreItems()
            let newCount = viewModel.feedItems.count

            // Then - Should either load more items or indicate no more items
            if newCount == initialCount {
                XCTAssertFalse(viewModel.hasMoreItems, "hasMoreItems should be false when no new items are loaded")
            } else {
                XCTAssertGreaterThan(newCount, initialCount, "Should load more items when available")
            }
        } else {
            // If no more items after initial load, that's valid too
            // (happens when initial load returns less than pageSize items)
            XCTAssertLessThan(initialCount, 20, "Should have less than pageSize items when hasMoreItems is false")
        }
    }

    // MARK: - Performance Tests

    func testLoadFeedPerformance() async {
        let startTime = CFAbsoluteTimeGetCurrent()

        await viewModel.loadInitialFeed()

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Load feed performance: \(timeElapsed) seconds")

        // Assert reasonable performance
        XCTAssertLessThan(timeElapsed, 2.0, "Initial feed load should complete in under 2 seconds")
    }

    func testFilteringPerformance() {
        // This test needs to be synchronous for measure block
        let expectation = XCTestExpectation(description: "Feed loaded")

        Task { @MainActor in
            await viewModel.loadInitialFeed()
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        // When/Then - Measure filtering performance
        measure {
            var newFilters = viewModel.filters
            newFilters.showWorkouts = false
            viewModel.updateFilters(newFilters)
            _ = viewModel.filteredFeedItems

            newFilters.showWorkouts = true
            newFilters.showAchievements = false
            viewModel.updateFilters(newFilters)
            _ = viewModel.filteredFeedItems
        }
    }

    // MARK: - Feed Content Validation Tests

    func testFeedItems_HaveValidContent() async {
        // Given
        await viewModel.loadInitialFeed()

        // When/Then
        for item in viewModel.feedItems {
            XCTAssertFalse(item.id.isEmpty, "Feed item should have valid ID")
            XCTAssertFalse(item.userID.isEmpty, "Feed item should have valid user ID")
            XCTAssertFalse(item.content.title.isEmpty, "Feed item should have title")

            // Type-specific validations
            switch item.type {
            case .workout:
                XCTAssertNotNil(item.content.workoutType, "Workout item should have workout type")
            case .achievement:
                XCTAssertNotNil(item.content.achievementName, "Achievement item should have achievement name")
            case .levelUp:
                XCTAssertNotNil(item.content.newLevel, "Level up item should have new level")
            case .milestone:
                // Milestone validation - title should contain relevant info
                XCTAssertTrue(!item.content.title.isEmpty)
            }
        }
    }

    // MARK: - Mock Feed Item Creation Tests

    func testMockFeedItemCreation() async {
        // Given
        let profile = UserProfile(
            id: "test-user",
            userID: "test-user",
            username: "testuser",
            displayName: "Test User",
            bio: "",
            workoutCount: 10,
            totalXP: 500,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockProfileService.profiles["test-user"] = profile

        // When
        await viewModel.loadInitialFeed()

        // Then
        XCTAssertGreaterThan(viewModel.feedItems.count, 0)

        // Check that different types of feed items are created
        let workoutItems = viewModel.feedItems.filter { $0.type == .workout }
        let achievementItems = viewModel.feedItems.filter { $0.type == .achievement }
        let levelUpItems = viewModel.feedItems.filter { $0.type == .levelUp }

        // Should have at least some variety in feed items
        XCTAssertTrue(!workoutItems.isEmpty || !achievementItems.isEmpty || !levelUpItems.isEmpty)
    }

    // MARK: - Activity Feed Integration Tests

    func testLoadFeed_WithActivityFeedService() async {
        // Given - Create some test activities
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

        // Post some activities
        try? await mockActivityFeedService.postWorkoutActivity(
            workoutHistory: workout,
            privacy: .public,
            includeDetails: true
        )

        try? await mockActivityFeedService.postAchievementActivity(
            achievementName: "First Workout",
            xpEarned: 50,
            privacy: .friendsOnly
        )

        // Setup following relationship
        mockSocialService.relationships["test-current-user"] = ["mock-user"]

        // When
        await viewModel.loadInitialFeed()

        // Then - Should convert activity feed items to feed items
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }

    func testActivityFeedItem_ConvertedToFeedItem() async {
        // Given
        let testUserId = "test-user-123"
        let profile = UserProfile(
            id: testUserId,
            userID: testUserId,
            username: "testuser",
            displayName: "Test User",
            bio: "",
            workoutCount: 10,
            totalXP: 500,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: true,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockProfileService.profiles[testUserId] = profile

        // Create activity
        let workout = WorkoutItem(
            id: UUID(),
            workoutType: "cycling",
            startDate: Date().addingTimeInterval(-3_600),
            endDate: Date(),
            duration: 3_600,
            totalEnergyBurned: 450,
            totalDistance: 25.0,
            averageHeartRate: 150,
            followersEarned: 60,
            xpEarned: 60,
            source: "FameFit"
        )

        // Post activity with specific user
        mockActivityFeedService.postedActivities = []
        let activity = ActivityFeedItem(
            id: UUID().uuidString,
            userID: testUserId,
            activityType: "workout",
            workoutId: workout.id.uuidString,
            content: try! String(data: JSONEncoder().encode(FeedContent(
                title: "Completed a Cycling workout",
                subtitle: "Great job on that 60-minute session! 💪",
                details: [
                    "workoutType": "cycling",
                    "duration": "3600",
                    "calories": "450",
                    "distance": "25.0",
                    "xpEarned": "60"
                ]
            )), encoding: .utf8)!,
            visibility: "public",
            createdTimestamp: Date(),
            expiresAt: Date().addingTimeInterval(30 * 24 * 3_600),
            xpEarned: 60,
            achievementName: nil
        )
        mockActivityFeedService.postedActivities = [activity]

        // Setup following
        mockSocialService.relationships["test-current-user"] = [testUserId]

        // When
        await viewModel.loadInitialFeed()

        // Then
        XCTAssertGreaterThan(viewModel.feedItems.count, 0)

        // Find the converted workout item
        if let workoutItem = viewModel.feedItems.first(where: { $0.type == .workout && $0.userID == testUserId }) {
            XCTAssertEqual(workoutItem.userID, testUserId)
            XCTAssertEqual(workoutItem.userProfile?.displayName, "Test User")
            XCTAssertTrue(workoutItem.userProfile?.isVerified ?? false)
            XCTAssertEqual(workoutItem.content.workoutType, "cycling")
            XCTAssertEqual(workoutItem.content.duration, 3_600)
            XCTAssertEqual(workoutItem.content.calories, 450)
            XCTAssertEqual(workoutItem.content.xpEarned, 60)
        } else {
            XCTFail("Expected to find converted workout item")
        }
    }

    func testActivityFeed_RealTimeUpdates() async {
        // Given
        // Setup following
        mockSocialService.relationships["test-current-user"] = ["mock-user"]

        // Create initial activity
        let initialWorkout = WorkoutItem(
            id: UUID(),
            workoutType: "running",
            startDate: Date().addingTimeInterval(-4_800),
            endDate: Date().addingTimeInterval(-3_600),
            duration: 1_200,
            totalEnergyBurned: 250,
            totalDistance: 3.0,
            averageHeartRate: 140,
            followersEarned: 25,
            xpEarned: 25,
            source: "FameFit"
        )

        // Post initial activity
        try? await mockActivityFeedService.postWorkoutActivity(
            workoutHistory: initialWorkout,
            privacy: .friendsOnly,
            includeDetails: true
        )

        // Load initial feed
        await viewModel.loadInitialFeed()

        // Then - Verify initial feed loaded
        XCTAssertEqual(viewModel.feedItems.count, 1)

        // When - Post a new activity and reload
        let workout = WorkoutItem(
            id: UUID(),
            workoutType: "yoga",
            startDate: Date().addingTimeInterval(-2_400),
            endDate: Date(),
            duration: 2_400,
            totalEnergyBurned: 180,
            totalDistance: nil,
            averageHeartRate: 95,
            followersEarned: 20,
            xpEarned: 20,
            source: "FameFit"
        )

        try? await mockActivityFeedService.postWorkoutActivity(
            workoutHistory: workout,
            privacy: .friendsOnly,
            includeDetails: true
        )

        // Reload to get the new activity
        await viewModel.loadInitialFeed()

        // Then - Verify feed updated
        XCTAssertEqual(viewModel.feedItems.count, 2)
    }

    // MARK: - Kudos Tests

    func testToggleKudos_Success() async {
        // Given
        let workoutId = "workout123"
        let feedItem = FeedItem(
            id: workoutId,
            userID: "owner456",
            userProfile: nil,
            type: .workout,
            timestamp: Date(),
            content: FeedContent(
                title: "Morning Run",
                subtitle: nil,
                details: ["workoutType": "Running"]
            )
        )

        // Pre-configure mock kudos service
        mockKudosService.simulateKudos(for: workoutId, count: 5, hasUserKudos: false)

        // When
        await viewModel.toggleKudos(for: feedItem)

        // Then
        XCTAssertTrue(mockKudosService.toggleKudosCalled)
        XCTAssertEqual(mockKudosService.lastToggledWorkoutId, workoutId)
        XCTAssertEqual(mockKudosService.lastToggledOwnerId, "owner456")
        XCTAssertNil(viewModel.error)
    }

    func testToggleKudos_NonWorkoutItem() async {
        // Given
        let feedItem = FeedItem(
            id: "achievement123",
            userID: "user456",
            userProfile: nil,
            type: .achievement,
            timestamp: Date(),
            content: FeedContent(
                title: "First Workout Achievement",
                subtitle: nil,
                details: ["achievementName": "First Workout"]
            )
        )

        // When
        await viewModel.toggleKudos(for: feedItem)

        // Then
        XCTAssertFalse(mockKudosService.toggleKudosCalled)
    }

    func testToggleKudos_Failure() async {
        // Given
        let workoutId = "workout123"
        let feedItem = FeedItem(
            id: workoutId,
            userID: "owner456",
            userProfile: nil,
            type: .workout,
            timestamp: Date(),
            content: FeedContent(
                title: "Morning Run",
                subtitle: nil,
                details: ["workoutType": "Running"]
            )
        )

        mockKudosService.shouldFailToggleKudos = true

        // When
        await viewModel.toggleKudos(for: feedItem)

        // Then
        XCTAssertTrue(mockKudosService.toggleKudosCalled)
        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.error?.contains("Failed to update kudos") ?? false)
    }

    func testLoadFeed_WithKudosSummaries() async {
        // Given
        // Setup mock profiles
        let profile1 = UserProfile(
            id: "user1",
            userID: "user1",
            username: "user1",
            displayName: "User 1",
            bio: "",
            workoutCount: 10,
            totalXP: 500,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockProfileService.profiles["user1"] = profile1

        // Setup following relationship
        mockSocialService.relationships["test-current-user"] = ["user1"]

        // Setup mock workout activity
        let workout = WorkoutItem(
            id: UUID(),
            workoutType: "running",
            startDate: Date().addingTimeInterval(-3_600),
            endDate: Date(),
            duration: 3_600,
            totalEnergyBurned: 450,
            totalDistance: 10.0,
            averageHeartRate: 150,
            followersEarned: 60,
            xpEarned: 60,
            source: "FameFit"
        )

        let activity = ActivityFeedItem(
            id: workout.id.uuidString,
            userID: "user1",
            activityType: "workout",
            workoutId: workout.id.uuidString,
            content: try! String(data: JSONEncoder().encode(FeedContent(
                title: "Completed a Running workout",
                subtitle: "Great run!",
                details: [
                    "workoutType": "running",
                    "duration": "3600",
                    "calories": "450",
                    "xpEarned": "60"
                ]
            )), encoding: .utf8)!,
            visibility: "public",
            createdTimestamp: Date(),
            expiresAt: Date().addingTimeInterval(30 * 24 * 3_600),
            xpEarned: 60,
            achievementName: nil
        )
        mockActivityFeedService.postedActivities = [activity]

        // Pre-configure kudos for the workout
        mockKudosService.simulateKudos(
            for: workout.id.uuidString,
            count: 10,
            hasUserKudos: true,
            recentUsers: [
                WorkoutKudosSummary.KudosUser(
                    userID: "user2",
                    username: "user2",
                    displayName: "User 2",
                    profileImageURL: nil
                )
            ]
        )

        // When
        await viewModel.loadInitialFeed()

        // Then
        XCTAssertTrue(mockKudosService.getKudosSummariesCalled)
        XCTAssertFalse(viewModel.isLoading)

        // Find the workout item and verify kudos summary
        if let workoutItem = viewModel.feedItems.first(where: { $0.type == .workout }) {
            XCTAssertNotNil(workoutItem.kudosSummary)
            XCTAssertEqual(workoutItem.kudosSummary?.totalCount, 10)
            XCTAssertTrue(workoutItem.kudosSummary?.hasUserKudos ?? false)
            XCTAssertEqual(workoutItem.kudosSummary?.recentUsers.count, 1)
        } else {
            XCTFail("Expected to find workout item with kudos summary")
        }
    }

    func testKudosRealTimeUpdates() async {
        // Given
        let workoutId = "workout123"

        // Setup initial feed item
        let feedItem = FeedItem(
            id: workoutId,
            userID: "owner456",
            userProfile: nil,
            type: .workout,
            timestamp: Date(),
            content: FeedContent(
                title: "Morning Run",
                subtitle: nil,
                details: ["workoutType": "Running"]
            ),
            kudosSummary: WorkoutKudosSummary(
                workoutId: workoutId,
                totalCount: 5,
                hasUserKudos: false,
                recentUsers: []
            )
        )

        // Add item to view model
        viewModel.feedItems = [feedItem]

        // Setup kudos update subscription
        var receivedUpdate: KudosUpdate?
        mockKudosService.kudosUpdates
            .sink { update in
                receivedUpdate = update
            }
            .store(in: &cancellables)

        // When - Emit kudos update
        let update = KudosUpdate(
            workoutId: workoutId,
            action: .added,
            userID: "test-current-user",
            newCount: 6
        )
        mockKudosService.emitKudosUpdate(update)

        // Allow time for async update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        // Then
        XCTAssertNotNil(receivedUpdate)
        XCTAssertEqual(receivedUpdate?.workoutId, workoutId)
        XCTAssertEqual(receivedUpdate?.action, .added)
        XCTAssertEqual(receivedUpdate?.newCount, 6)
    }

    func testToggleKudos_UpdatesFeedItem() async {
        // Given
        let workoutId = "workout123"
        let initialKudosSummary = WorkoutKudosSummary(
            workoutId: workoutId,
            totalCount: 5,
            hasUserKudos: false,
            recentUsers: []
        )

        let feedItem = FeedItem(
            id: workoutId,
            userID: "owner456",
            userProfile: nil,
            type: .workout,
            timestamp: Date(),
            content: FeedContent(
                title: "Morning Run",
                subtitle: nil,
                details: ["workoutType": "Running"]
            ),
            kudosSummary: initialKudosSummary
        )

        viewModel.feedItems = [feedItem]

        // Pre-configure mock
        mockKudosService.simulateKudos(for: workoutId, count: 5, hasUserKudos: false)

        // When
        await viewModel.toggleKudos(for: feedItem)

        // Allow time for async update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        // Then
        XCTAssertTrue(mockKudosService.toggleKudosCalled)
        // The mock service should have updated its internal state
        let updatedSummary = try? await mockKudosService.getKudosSummary(for: workoutId)
        XCTAssertEqual(updatedSummary?.totalCount, 6)
        XCTAssertTrue(updatedSummary?.hasUserKudos ?? false)
    }
}
