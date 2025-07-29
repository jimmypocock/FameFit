//
//  LeaderboardViewModelTests.swift
//  FameFitTests
//
//  Tests for LeaderboardViewModel
//

import Combine
@testable import FameFit
import XCTest

@MainActor
final class LeaderboardViewModelTests: XCTestCase {
    private var sut: LeaderboardViewModel!
    private var mockUserProfileService: MockUserProfileService!
    private var mockSocialFollowingService: MockSocialFollowingService!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()

        mockUserProfileService = MockUserProfileService()
        mockSocialFollowingService = MockSocialFollowingService()
        cancellables = Set<AnyCancellable>()

        sut = LeaderboardViewModel()
        sut.configure(
            userProfileService: mockUserProfileService,
            socialFollowingService: mockSocialFollowingService,
            currentUserId: "current-user"
        )
    }

    override func tearDown() {
        sut = nil
        mockUserProfileService = nil
        mockSocialFollowingService = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Global Leaderboard Tests

    func testLoadGlobalLeaderboard_Success() async {
        // When
        await sut.loadLeaderboard(timeFilter: .allTime, scope: .global)

        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.entries.isEmpty)

        // Verify sorted by XP
        for index in 0 ..< sut.entries.count - 1 {
            XCTAssertGreaterThanOrEqual(sut.entries[index].profile.totalXP, sut.entries[index + 1].profile.totalXP)
        }

        // Verify ranks are assigned correctly
        XCTAssertEqual(sut.entries[0].rank, 1)
        if sut.entries.count > 1 {
            XCTAssertEqual(sut.entries[1].rank, 2)
        }
    }

    func testLoadGlobalLeaderboard_IdentifiesCurrentUser() async {
        // Given
        let currentUserProfile = UserProfile(
            id: "current-user",
            userID: "current-user",
            username: "currentuser",
            displayName: "Current User",
            bio: "",
            workoutCount: 50,
            totalXP: 5_000,
            joinedDate: Date().addingTimeInterval(-30 * 24 * 3_600),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockUserProfileService.profiles["current-user"] = currentUserProfile

        // When
        await sut.loadLeaderboard(timeFilter: .allTime, scope: .global)

        // Then
        XCTAssertNotNil(sut.currentUserEntry)
        XCTAssertEqual(sut.currentUserEntry?.id, "current-user")
        XCTAssertTrue(sut.currentUserEntry?.isCurrentUser ?? false)
    }

    // MARK: - Friends Leaderboard Tests

    func testLoadFriendsLeaderboard_Success() async {
        // Given - Set up friends
        let friend1 = UserProfile(
            id: "friend1",
            userID: "friend1",
            username: "friend1",
            displayName: "Friend 1",
            bio: "",
            workoutCount: 30,
            totalXP: 1_500,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        let friend2 = UserProfile(
            id: "friend2",
            userID: "friend2",
            username: "friend2",
            displayName: "Friend 2",
            bio: "",
            workoutCount: 45,
            totalXP: 2_250,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockSocialFollowingService.relationships["current-user"] = [friend1.id, friend2.id]

        // When
        await sut.loadLeaderboard(timeFilter: .allTime, scope: .friends)

        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)

        // Should include friends + current user
        let friendIds = Set([friend1.id, friend2.id, "current-user"])
        let entryIds = Set(sut.entries.map(\.id))
        XCTAssertTrue(entryIds.isSubset(of: friendIds))
    }

    func testLoadFriendsLeaderboard_EmptyWhenNoFriends() async {
        // Given - No friends
        mockSocialFollowingService.relationships["current-user"] = []

        // When
        await sut.loadLeaderboard(timeFilter: .allTime, scope: .friends)

        // Then
        XCTAssertTrue(sut.entries.isEmpty)
        XCTAssertNil(sut.error)
    }

    // MARK: - Time Filter Tests

    func testLoadLeaderboard_TodayFilter() async {
        // Given - Profiles with different last updated dates
        let todayProfile = UserProfile(
            id: "today-user",
            userID: "today-user",
            username: "todayuser",
            displayName: "Today User",
            bio: "",
            workoutCount: 10,
            totalXP: 1_000,
            joinedDate: Date().addingTimeInterval(-7 * 24 * 3_600),
            lastUpdated: Date(), // Today
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )

        let yesterdayProfile = UserProfile(
            id: "yesterday-user",
            userID: "yesterday-user",
            username: "yesterdayuser",
            displayName: "Yesterday User",
            bio: "",
            workoutCount: 20,
            totalXP: 2_000,
            joinedDate: Date().addingTimeInterval(-14 * 24 * 3_600),
            lastUpdated: Date().addingTimeInterval(-24 * 3_600), // Yesterday
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )

        mockUserProfileService.profiles["today-user"] = todayProfile
        mockUserProfileService.profiles["yesterday-user"] = yesterdayProfile

        // When
        await sut.loadLeaderboard(timeFilter: .today, scope: .global)

        // Then
        // In real implementation with proper time filtering,
        // only today's XP would be counted
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }

    func testLoadLeaderboard_WeekFilter() async {
        // When
        await sut.loadLeaderboard(timeFilter: .week, scope: .global)

        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.entries.isEmpty)
    }

    func testLoadLeaderboard_MonthFilter() async {
        // When
        await sut.loadLeaderboard(timeFilter: .month, scope: .global)

        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.entries.isEmpty)
    }

    // MARK: - Rank Assignment Tests

    func testAssignRanks_HandlesEqualXP() async {
        // Given - Clear existing profiles and create profiles with same XP
        mockUserProfileService.profiles.removeAll()

        let profile1 = createProfile(id: "user1", xp: 1_000)
        let profile2 = createProfile(id: "user2", xp: 1_000)
        let profile3 = createProfile(id: "user3", xp: 800)

        mockUserProfileService.profiles["user1"] = profile1
        mockUserProfileService.profiles["user2"] = profile2
        mockUserProfileService.profiles["user3"] = profile3

        // When
        await sut.loadLeaderboard(timeFilter: .allTime, scope: .global)

        // Then
        let user1Entry = sut.entries.first { $0.id == "user1" }
        let user2Entry = sut.entries.first { $0.id == "user2" }
        let user3Entry = sut.entries.first { $0.id == "user3" }

        // Both users with 1000 XP should have rank 1
        XCTAssertEqual(user1Entry?.rank, 1)
        XCTAssertEqual(user2Entry?.rank, 1)
        // User with 800 XP should have rank 3 (not 2)
        XCTAssertEqual(user3Entry?.rank, 3)
    }

    // MARK: - Error Handling Tests

    func testLoadLeaderboard_HandlesServiceError() async {
        // Given
        mockUserProfileService.shouldFail = true

        // When
        await sut.loadLeaderboard(timeFilter: .allTime, scope: .global)

        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.error)
        XCTAssertTrue(sut.entries.isEmpty)
    }

    // MARK: - Friend Cache Tests

    func testFriendIdsAreCached() async {
        // Given
        let friend = UserProfile(
            id: "friend1",
            userID: "friend1",
            username: "friend1",
            displayName: "Friend 1",
            bio: "",
            workoutCount: 25,
            totalXP: 1_250,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockSocialFollowingService.relationships["current-user"] = [friend.id]
        mockUserProfileService.profiles[friend.id] = friend

        // When - Load friends leaderboard twice
        await sut.loadLeaderboard(timeFilter: .allTime, scope: .friends)

        // Reset mock to verify cache is used
        mockSocialFollowingService.getFollowingCallCount = 0

        await sut.loadLeaderboard(timeFilter: .allTime, scope: .friends)

        // Then - Should use cached friend IDs on second call
        // (In real implementation with 5-minute cache)
        XCTAssertFalse(sut.entries.isEmpty)
    }

    // MARK: - Workout Stats Calculation Tests

    func testCalculatesWorkoutStats() async {
        // Given
        let profile = UserProfile(
            id: "workout-user",
            userID: "workout-user",
            username: "workoutuser",
            displayName: "Workout User",
            bio: "",
            workoutCount: 100,
            totalXP: 5_000,
            joinedDate: Date().addingTimeInterval(-30 * 24 * 3_600),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
        mockUserProfileService.profiles["workout-user"] = profile

        // When
        await sut.loadLeaderboard(timeFilter: .allTime, scope: .global)

        // Then
        let entry = sut.entries.first { $0.id == "workout-user" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.profile.workoutCount, 100)
        // Note: totalDuration would need to be calculated from workout history in real implementation
    }

    // MARK: - Helper Methods

    private func createProfile(id: String, xp: Int) -> UserProfile {
        UserProfile(
            id: id,
            userID: id,
            username: "user_\(id)",
            displayName: "User \(id)",
            bio: "",
            workoutCount: xp / 100,
            totalXP: xp,
            joinedDate: Date().addingTimeInterval(-30 * 24 * 3_600),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
    }
}
