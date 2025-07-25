//
//  SocialFeedViewModelTests.swift
//  FameFitTests
//
//  Unit tests for social feed view model
//

import Combine
@testable import FameFit
import XCTest

@MainActor
final class SocialFeedViewModelTests: XCTestCase {
    private var viewModel: SocialFeedViewModel!
    private var mockSocialService: MockSocialFollowingService!
    private var mockProfileService: MockUserProfileService!
    private var mockActivityFeedService: MockActivityFeedService!
    private var mockKudosService: MockWorkoutKudosService!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        viewModel = SocialFeedViewModel()
        mockSocialService = MockSocialFollowingService()
        mockProfileService = MockUserProfileService()
        mockActivityFeedService = MockActivityFeedService()
        mockKudosService = MockWorkoutKudosService()
        cancellables = Set<AnyCancellable>()

        // Configure the view model with mock services
        viewModel.configure(
            socialService: mockSocialService,
            profileService: mockProfileService,
            activityFeedService: mockActivityFeedService,
            kudosService: mockKudosService,
            commentsService: MockWorkoutCommentsService(),
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

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertEqual(viewModel.feedItems.count, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertTrue(viewModel.hasMoreItems)
        XCTAssertTrue(viewModel.filters.showWorkouts)
        XCTAssertTrue(viewModel.filters.showAchievements)
        XCTAssertTrue(viewModel.filters.showLevelUps)
        XCTAssertTrue(viewModel.filters.showMilestones)
        XCTAssertEqual(viewModel.filters.timeRange, .all)
    }

    // MARK: - Load Feed Tests

    func testLoadInitialFeed_Success() async {
        // Given
        let mockProfile = UserProfile(
            id: "mock-user-1",
            userID: "mock-user-1",
            username: "testuser",
            displayName: "Test User",
            bio: "Test bio",
            workoutCount: 10,
            totalXP: 500,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockProfileService.profiles["mock-user-1"] = mockProfile

        // When
        await viewModel.loadInitialFeed()

        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertGreaterThan(viewModel.feedItems.count, 0)
    }

    func testLoadInitialFeed_Failure() async {
        // Given
        mockSocialService.shouldFailNextAction = true
        mockSocialService.mockError = .userNotFound

        // When
        await viewModel.loadInitialFeed()

        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.error, "Failed to load feed")
        XCTAssertEqual(viewModel.feedItems.count, 0)
    }

    func testRefreshFeed() async {
        // Given - Add some initial items
        await viewModel.loadInitialFeed()
        let initialCount = viewModel.feedItems.count

        // When
        await viewModel.refreshFeed()

        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertGreaterThanOrEqual(viewModel.feedItems.count, initialCount)
    }

    func testLoadMoreItems_WithMoreItems() async {
        // Given
        await viewModel.loadInitialFeed()
        let initialCount = viewModel.feedItems.count

        // When
        await viewModel.loadMoreItems()

        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertGreaterThanOrEqual(viewModel.feedItems.count, initialCount)
    }

    func testLoadMoreItems_NoMoreItems() async {
        // Given
        viewModel.hasMoreItems = false
        let initialCount = viewModel.feedItems.count

        // When
        await viewModel.loadMoreItems()

        // Then
        XCTAssertEqual(viewModel.feedItems.count, initialCount)
    }

    func testLoadMoreItems_WhileLoading() async {
        // Given
        viewModel.isLoading = true
        let initialCount = viewModel.feedItems.count

        // When
        await viewModel.loadMoreItems()

        // Then
        XCTAssertEqual(viewModel.feedItems.count, initialCount)
    }

    // MARK: - Filter Tests

    func testFilteredFeedItems_WorkoutFilter() async {
        // Given
        await viewModel.loadInitialFeed()
        let allItems = viewModel.feedItems.count

        // When
        var newFilters = viewModel.filters
        newFilters.showWorkouts = false
        viewModel.updateFilters(newFilters)

        // Then
        let filteredItems = viewModel.filteredFeedItems.count
        XCTAssertLessThanOrEqual(filteredItems, allItems)

        // Verify no workout items in filtered results
        let workoutItems = viewModel.filteredFeedItems.filter { $0.type == .workout }
        XCTAssertEqual(workoutItems.count, 0)
    }

    func testFilteredFeedItems_AchievementFilter() async {
        // Given
        await viewModel.loadInitialFeed()

        // When
        var newFilters = viewModel.filters
        newFilters.showAchievements = false
        viewModel.updateFilters(newFilters)

        // Then
        let achievementItems = viewModel.filteredFeedItems.filter { $0.type == .achievement }
        XCTAssertEqual(achievementItems.count, 0)
    }

    func testFilteredFeedItems_LevelUpFilter() async {
        // Given
        await viewModel.loadInitialFeed()

        // When
        var newFilters = viewModel.filters
        newFilters.showLevelUps = false
        viewModel.updateFilters(newFilters)

        // Then
        let levelUpItems = viewModel.filteredFeedItems.filter { $0.type == .levelUp }
        XCTAssertEqual(levelUpItems.count, 0)
    }

    func testFilteredFeedItems_MilestoneFilter() async {
        // Given
        await viewModel.loadInitialFeed()

        // When
        var newFilters = viewModel.filters
        newFilters.showMilestones = false
        viewModel.updateFilters(newFilters)

        // Then
        let milestoneItems = viewModel.filteredFeedItems.filter { $0.type == .milestone }
        XCTAssertEqual(milestoneItems.count, 0)
    }

    func testFilteredFeedItems_TimeRangeFilter_Today() async {
        // Given
        await viewModel.loadInitialFeed()

        // When
        var newFilters = viewModel.filters
        newFilters.timeRange = .today
        viewModel.updateFilters(newFilters)

        // Then
        let todayItems = viewModel.filteredFeedItems.filter {
            Calendar.current.isDateInToday($0.timestamp)
        }
        XCTAssertEqual(viewModel.filteredFeedItems.count, todayItems.count)
    }

    func testFilteredFeedItems_TimeRangeFilter_Week() async {
        // Given
        await viewModel.loadInitialFeed()

        // When
        var newFilters = viewModel.filters
        newFilters.timeRange = .week
        viewModel.updateFilters(newFilters)

        // Then
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let weekItems = viewModel.filteredFeedItems.filter { $0.timestamp > weekAgo }
        XCTAssertEqual(viewModel.filteredFeedItems.count, weekItems.count)
    }

    func testFilteredFeedItems_TimeRangeFilter_Month() async {
        // Given
        await viewModel.loadInitialFeed()

        // When
        var newFilters = viewModel.filters
        newFilters.timeRange = .month
        viewModel.updateFilters(newFilters)

        // Then
        let monthAgo = Date().addingTimeInterval(-30 * 24 * 3600)
        let monthItems = viewModel.filteredFeedItems.filter { $0.timestamp > monthAgo }
        XCTAssertEqual(viewModel.filteredFeedItems.count, monthItems.count)
    }

    func testFilteredFeedItems_AllFiltersOff() async {
        // Given
        await viewModel.loadInitialFeed()

        // When
        var newFilters = viewModel.filters
        newFilters.showWorkouts = false
        newFilters.showAchievements = false
        newFilters.showLevelUps = false
        newFilters.showMilestones = false
        viewModel.updateFilters(newFilters)

        // Then
        XCTAssertEqual(viewModel.filteredFeedItems.count, 0)
    }

    // MARK: - Content Filtering Tests

    func testContentFiltering_InappropriateContent() async {
        // Given - Mock profile service will return profiles
        let mockProfile = UserProfile(
            id: "test-user",
            userID: "test-user",
            username: "testuser",
            displayName: "Test User",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockProfileService.profiles["test-user"] = mockProfile

        // When
        await viewModel.loadInitialFeed()

        // Then - Should not contain inappropriate content
        for item in viewModel.feedItems {
            XCTAssertFalse(item.content.title.lowercased().contains("spam"))
            XCTAssertFalse(item.content.title.lowercased().contains("inappropriate"))
            XCTAssertFalse(item.content.title.lowercased().contains("offensive"))

            if let subtitle = item.content.subtitle {
                XCTAssertFalse(subtitle.lowercased().contains("spam"))
                XCTAssertFalse(subtitle.lowercased().contains("inappropriate"))
                XCTAssertFalse(subtitle.lowercased().contains("offensive"))
            }
        }
    }

    // MARK: - Following Users Tests

    func testLoadFeed_IncludesFollowingUsers() async {
        // Given
        mockSocialService.relationships["test-current-user"] = ["user1", "user2"]

        let profile1 = UserProfile(
            id: "user1",
            userID: "user1",
            username: "user1",
            displayName: "User 1",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )

        let profile2 = UserProfile(
            id: "user2",
            userID: "user2",
            username: "user2",
            displayName: "User 2",
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )

        mockProfileService.profiles["user1"] = profile1
        mockProfileService.profiles["user2"] = profile2

        // When
        await viewModel.loadInitialFeed()

        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }

    // MARK: - Feed Item Sorting Tests

    func testFeedItems_AreSortedByTimestamp() async {
        // Given
        await viewModel.loadInitialFeed()

        // When
        let items = viewModel.feedItems

        // Then
        guard items.count > 1 else {
            // Skip test if there are 0 or 1 items
            return
        }

        for index in 0 ..< (items.count - 1) {
            XCTAssertGreaterThanOrEqual(
                items[index].timestamp,
                items[index + 1].timestamp,
                "Feed items should be sorted by timestamp (newest first)"
            )
        }
    }
}
