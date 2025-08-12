//
//  LeaderboardIntegrationTests.swift
//  FameFitTests
//
//  Integration tests for leaderboard functionality
//

import Combine
@testable import FameFit
import XCTest

final class LeaderboardIntegrationTests: XCTestCase {
    private var container: DependencyContainer!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()

        // Create container with mock services
        let mockCloudKitService = MockCloudKitService()
        mockCloudKitService.currentUserID = "test-user"

        let mockUserProfileService = MockUserProfileService()

        // Add test profiles for leaderboard
        let testProfile = UserProfile(
            id: "test-user",
            userID: "test-user",
            username: "testuser",
            bio: "Test bio",
            workoutCount: 10,
            totalXP: 500,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockUserProfileService.profiles["test-user"] = testProfile

        // Add more profiles for leaderboard
        for index in 1 ... 5 {
            let profile = UserProfile(
                id: "user-\(index)",
                userID: "user-\(index)",
                username: "user\(index)",
                bio: "Bio \(index)",
                workoutCount: index * 5,
                totalXP: index * 1_000,
                joinedDate: Date(),
                lastUpdated: Date(),
                isVerified: index % 2 == 0,
                privacyLevel: .publicProfile,
                profileImageURL: nil
            )
            mockUserProfileService.profiles["user-\(index)"] = profile
        }

        let mockSocialFollowingService = MockSocialFollowingService()

        container = DependencyContainer(
            authenticationManager: AuthenticationService(cloudKitManager: mockCloudKitService),
            cloudKitManager: mockCloudKitService,
            workoutObserver: WorkoutObserver(
                cloudKitManager: mockCloudKitService,
                healthKitService: MockHealthKitService()
            ),
            userProfileService: mockUserProfileService,
            socialFollowingService: mockSocialFollowingService
        )

        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        container = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - End-to-End Tests

    @MainActor
    func testLeaderboardFlow_FromUserSearch() async {
        // Given - User navigates to discover users and switches to leaderboard
        _ = UserSearchView()
            .environment(\.dependencyContainer, container)

        // Simulate user tapping leaderboard tab
        // In real app, this would trigger LeaderboardView to load

        // Then - Verify leaderboard loads with correct data
        let viewModel = LeaderboardViewModel()
        viewModel.configure(
            userProfileService: container.userProfileService,
            socialFollowingService: container.socialFollowingService,
            currentUserId: "test-user"
        )

        await viewModel.loadLeaderboard(timeFilter: .week, scope: .global)

        XCTAssertFalse(viewModel.entries.isEmpty)
        XCTAssertNotNil(viewModel.currentUserEntry)
    }

    // MARK: - Real-time Update Tests

    @MainActor
    func testLeaderboard_UpdatesWhenProfileChanges() async {
        // Given - Leaderboard is loaded
        let viewModel = LeaderboardViewModel()
        viewModel.configure(
            userProfileService: container.userProfileService,
            socialFollowingService: container.socialFollowingService,
            currentUserId: "test-user"
        )

        await viewModel.loadLeaderboard(timeFilter: .allTime, scope: .global)
        _ = viewModel.entries.count

        // When - A profile's XP is updated
        let mockService = container.userProfileService as? MockUserProfileService
        let updatedProfile = UserProfile(
            id: "updated-user",
            userID: "updated-user",
            username: "updateduser",
            bio: "",
            workoutCount: 100,
            totalXP: 99_999, // Make them #1
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockService?.profiles[updatedProfile.id] = updatedProfile

        // Reload leaderboard
        await viewModel.loadLeaderboard(timeFilter: .allTime, scope: .global)

        // Then - Leaderboard should reflect the change
        XCTAssertEqual(viewModel.entries.first?.profile.id, updatedProfile.id)
        XCTAssertEqual(viewModel.entries.first?.profile.totalXP, 99_999)
    }

    // MARK: - Friends Leaderboard Integration

    @MainActor
    func testFriendsLeaderboard_UpdatesWhenFollowingChanges() async {
        // Given - User has some friends
        let mockSocialService = container.socialFollowingService as? MockSocialFollowingService
        let friend1 = UserProfile(
            id: "friend1",
            userID: "friend1",
            username: "friend1",
            bio: "",
            workoutCount: 50,
            totalXP: 2_500,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        let friend2 = UserProfile(
            id: "friend2",
            userID: "friend2",
            username: "friend2",
            bio: "",
            workoutCount: 30,
            totalXP: 1_500,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockSocialService?.relationships["test-user"] = [friend1.id, friend2.id]

        // Add friends to profile service
        let mockProfileService = container.userProfileService as? MockUserProfileService
        mockProfileService?.profiles[friend1.id] = friend1
        mockProfileService?.profiles[friend2.id] = friend2

        // Ensure current user profile exists
        let currentUserProfile = UserProfile(
            id: "test-user",
            userID: "test-user",
            username: "testuser",
            bio: "",
            workoutCount: 20,
            totalXP: 1_000,
            createdTimestamp: Date().addingTimeInterval(-30 * 24 * 3_600), // 30 days ago
            modifiedTimestamp: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockProfileService?.profiles["test-user"] = currentUserProfile

        let viewModel = LeaderboardViewModel()
        viewModel.configure(
            userProfileService: container.userProfileService,
            socialFollowingService: container.socialFollowingService,
            currentUserId: "test-user"
        )

        await viewModel.loadLeaderboard(timeFilter: .allTime, scope: .friends)
        let initialFriendCount = viewModel.entries.count
        print("DEBUG: Initial entries: \(viewModel.entries.map(\.profile.id))")
        print("DEBUG: Mock relationships: \(mockSocialService?.relationships["test-user"] ?? [])")
        XCTAssertEqual(initialFriendCount, 3, "Should have 3 entries initially (2 friends + current user)")

        // When - User follows someone new
        let newFriend = UserProfile(
            id: "friend3",
            userID: "friend3",
            username: "friend3",
            bio: "",
            workoutCount: 80,
            totalXP: 4_000,
            createdTimestamp: Date(),
            modifiedTimestamp: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockSocialService?.relationships["test-user"]?.insert(newFriend.id)

        // Add the new friend to the profile service
        mockProfileService?.profiles[newFriend.id] = newFriend

        // Force refresh of friends cache since it's cached for 5 minutes
        viewModel.forceRefreshFriends()

        // Reload friends leaderboard
        await viewModel.loadLeaderboard(timeFilter: .allTime, scope: .friends)

        // Debug logging after adding new friend
        print("DEBUG: After adding friend3, entries: \(viewModel.entries.map(\.profile.id))")
        print("DEBUG: Mock relationships after adding: \(mockSocialService?.relationships["test-user"] ?? [])")

        // Then - New friend should appear
        XCTAssertEqual(viewModel.entries.count, 4, "Should have 4 entries after adding new friend")
        XCTAssertTrue(viewModel.entries.contains { $0.id == newFriend.id })
    }

    // MARK: - Performance Tests

    @MainActor
    func testLeaderboard_PerformanceWithManyUsers() async {
        // Given - Many users in the system
        let mockService = container.userProfileService as? MockUserProfileService

        // Add 100 profiles
        for index in 1 ... 100 {
            let profile = UserProfile(
                id: "user-\(index)",
                userID: "user-\(index)",
                username: "user\(index)",
                bio: "",
                workoutCount: index,
                totalXP: Int.random(in: 100 ... 10_000),
                createdTimestamp: Date().addingTimeInterval(-Double(index) * 24 * 3_600),
                modifiedTimestamp: Date(),
                isVerified: false,
                privacyLevel: .publicProfile,
                profileImageURL: nil
            )
            mockService?.profiles[profile.id] = profile
        }

        let viewModel = LeaderboardViewModel()
        viewModel.configure(
            userProfileService: container.userProfileService,
            socialFollowingService: container.socialFollowingService,
            currentUserId: "test-user"
        )

        // When - Loading leaderboard
        let startTime = Date()
        await viewModel.loadLeaderboard(timeFilter: .allTime, scope: .global)
        let loadTime = Date().timeIntervalSince(startTime)

        // Then - Should load in reasonable time
        XCTAssertLessThan(loadTime, 1.0, "Leaderboard took too long to load")
        XCTAssertFalse(viewModel.entries.isEmpty)

        // Verify proper sorting
        for index in 0 ..< min(viewModel.entries.count - 1, 50) {
            XCTAssertGreaterThanOrEqual(
                viewModel.entries[index].profile.totalXP,
                viewModel.entries[index + 1].profile.totalXP,
                "Leaderboard not properly sorted"
            )
        }
    }

    // MARK: - Time Filter Integration Tests

    @MainActor
    func testTimeFilters_ShowCorrectData() async {
        // Given - Profiles with different activity dates
        let mockService = container.userProfileService as? MockUserProfileService

        // Today's active user
        let todayUser = createProfileWithDate(
            id: "today-user",
            modifiedTimestamp: Date(),
            xp: 1_000
        )

        // This week's active user
        let weekUser = createProfileWithDate(
            id: "week-user",
            modifiedTimestamp: Date().addingTimeInterval(-3 * 24 * 3_600),
            xp: 2_000
        )

        // Last month's active user
        let monthUser = createProfileWithDate(
            id: "month-user",
            modifiedTimestamp: Date().addingTimeInterval(-15 * 24 * 3_600),
            xp: 3_000
        )

        // Old user
        let oldUser = createProfileWithDate(
            id: "old-user",
            modifiedTimestamp: Date().addingTimeInterval(-60 * 24 * 3_600),
            xp: 4_000
        )

        mockService?.profiles = [
            todayUser.id: todayUser,
            weekUser.id: weekUser,
            monthUser.id: monthUser,
            oldUser.id: oldUser
        ]

        let viewModel = LeaderboardViewModel()
        viewModel.configure(
            userProfileService: container.userProfileService,
            socialFollowingService: container.socialFollowingService,
            currentUserId: "test-user"
        )

        // Test each filter
        await viewModel.loadLeaderboard(timeFilter: .today, scope: .global)
        let todayCount = viewModel.entries.count

        await viewModel.loadLeaderboard(timeFilter: .week, scope: .global)
        let weekCount = viewModel.entries.count

        await viewModel.loadLeaderboard(timeFilter: .month, scope: .global)
        let monthCount = viewModel.entries.count

        await viewModel.loadLeaderboard(timeFilter: .allTime, scope: .global)
        let allTimeCount = viewModel.entries.count

        // Verify counts increase with broader time ranges
        XCTAssertLessThanOrEqual(todayCount, weekCount)
        XCTAssertLessThanOrEqual(weekCount, monthCount)
        XCTAssertLessThanOrEqual(monthCount, allTimeCount)
    }

    // MARK: - Error Recovery Tests

    @MainActor
    func testLeaderboard_RecoverFromError() async {
        // Given - Service configured to fail
        let mockService = container.userProfileService as? MockUserProfileService
        mockService?.shouldFail = true

        let viewModel = LeaderboardViewModel()
        viewModel.configure(
            userProfileService: container.userProfileService,
            socialFollowingService: container.socialFollowingService,
            currentUserId: "test-user"
        )

        // When - First load fails
        await viewModel.loadLeaderboard(timeFilter: .allTime, scope: .global)
        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.entries.isEmpty)

        // When - Service recovers
        mockService?.shouldFail = false

        // And user retries
        await viewModel.loadLeaderboard(timeFilter: .allTime, scope: .global)

        // Then - Should load successfully
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.entries.isEmpty)
    }

    // MARK: - Helper Methods

    private func createProfileWithDate(
        id: String,
        modifiedTimestamp: Date,
        xp: Int
    ) -> UserProfile {
        UserProfile(
            id: id,
            userID: id,
            username: "user_\(id)",
            bio: "",
            workoutCount: xp / 100,
            totalXP: xp,
            createdTimestamp: Date().addingTimeInterval(-365 * 24 * 3_600),
            modifiedTimestamp: modifiedTimestamp,
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
    }
}
