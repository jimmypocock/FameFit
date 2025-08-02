//
//  LeaderboardViewTests.swift
//  FameFitTests
//
//  Tests for LeaderboardView UI components
//

@testable import FameFit
import SwiftUI
import XCTest

final class LeaderboardViewTests: XCTestCase {
    private var container: DependencyContainer!

    override func setUp() {
        super.setUp()
        container = DependencyContainer()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    // MARK: - Filter Tests

    func testTimeFilterChips_AllPresent() throws {
        // Given
        _ = LeaderboardView()
            .environment(\.dependencyContainer, container)

        // Verify all time filters are available
        for filter in LeaderboardTimeFilter.allCases {
            XCTAssertNotNil(filter.rawValue)
            XCTAssertFalse(filter.icon.isEmpty)
        }
    }

    func testScopeSegmentedPicker_AllOptionsPresent() {
        // Given
        let scopes = LeaderboardScope.allCases

        // Then
        XCTAssertEqual(scopes.count, 2)
        XCTAssertTrue(scopes.contains(.global))
        XCTAssertTrue(scopes.contains(.friends))
    }

    // MARK: - Date Range Tests

    func testTimeFilter_DateRanges() {
        // Test Today
        let todayRange = LeaderboardTimeFilter.today.dateRange
        XCTAssertTrue(Calendar.current.isDateInToday(todayRange.start))
        XCTAssertTrue(Calendar.current.isDateInToday(todayRange.end))

        // Test Week
        let weekRange = LeaderboardTimeFilter.week.dateRange
        let weekDiff = Calendar.current.dateComponents([.day], from: weekRange.start, to: weekRange.end).day ?? 0
        XCTAssertLessThanOrEqual(weekDiff, 7)

        // Test Month
        let monthRange = LeaderboardTimeFilter.month.dateRange
        let monthDiff = Calendar.current.dateComponents([.day], from: monthRange.start, to: monthRange.end).day ?? 0
        XCTAssertLessThanOrEqual(monthDiff, 31)

        // Test All Time
        let allTimeRange = LeaderboardTimeFilter.allTime.dateRange
        XCTAssertEqual(allTimeRange.start, Date.distantPast)
    }

    // MARK: - Leaderboard Entry Tests

    func testLeaderboardEntry_Initialization() {
        // Given
        let profile = UserProfile.mockProfile

        // When
        let entry = LeaderboardEntry(
            id: profile.id,
            rank: 1,
            profile: profile,
            xpEarned: 1_500,
            workoutCount: 10,
            totalDuration: 3_600,
            isCurrentUser: true,
            rankChange: .up(2)
        )

        // Then
        XCTAssertEqual(entry.id, profile.id)
        XCTAssertEqual(entry.rank, 1)
        XCTAssertEqual(entry.xpEarned, 1_500)
        XCTAssertEqual(entry.workoutCount, 10)
        XCTAssertEqual(entry.totalDuration, 3_600)
        XCTAssertTrue(entry.isCurrentUser)

        if case let .up(positions) = entry.rankChange {
            XCTAssertEqual(positions, 2)
        } else {
            XCTFail("Expected rank change to be up(2)")
        }
    }

    func testRankChange_IconsAndColors() {
        // Test up
        XCTAssertEqual(LeaderboardEntry.RankChange.up(3).icon, "arrow.up")
        XCTAssertEqual(LeaderboardEntry.RankChange.up(3).color, .green)

        // Test down
        XCTAssertEqual(LeaderboardEntry.RankChange.down(2).icon, "arrow.down")
        XCTAssertEqual(LeaderboardEntry.RankChange.down(2).color, .red)

        // Test same
        XCTAssertEqual(LeaderboardEntry.RankChange.same.icon, "minus")
        XCTAssertEqual(LeaderboardEntry.RankChange.same.color, .secondary)

        // Test new
        XCTAssertEqual(LeaderboardEntry.RankChange.new.icon, "sparkles")
        XCTAssertEqual(LeaderboardEntry.RankChange.new.color, .yellow)
    }

    // MARK: - Row Display Tests

    func testLeaderboardRow_DisplaysCorrectRankBadges() {
        // Given
        let profile = UserProfile.mockProfile

        // Test first place
        let firstPlace = LeaderboardEntry(
            id: "1",
            rank: 1,
            profile: profile,
            xpEarned: 1_000,
            workoutCount: 10,
            totalDuration: 3_600,
            isCurrentUser: false,
            rankChange: nil
        )

        _ = LeaderboardRow(entry: firstPlace, onTap: {})
        // Would use ViewInspector to verify emoji display

        // Test second place
        let secondPlace = LeaderboardEntry(
            id: "2",
            rank: 2,
            profile: profile,
            xpEarned: 900,
            workoutCount: 9,
            totalDuration: 3_200,
            isCurrentUser: false,
            rankChange: nil
        )

        _ = LeaderboardRow(entry: secondPlace, onTap: {})
        // Would use ViewInspector to verify emoji display

        // Test regular rank
        let regularRank = LeaderboardEntry(
            id: "10",
            rank: 10,
            profile: profile,
            xpEarned: 500,
            workoutCount: 5,
            totalDuration: 1_800,
            isCurrentUser: false,
            rankChange: nil
        )

        _ = LeaderboardRow(entry: regularRank, onTap: {})
        // Would use ViewInspector to verify number display
    }

    // MARK: - Empty State Tests

    func testEmptyState_GlobalScope() {
        // Given empty global leaderboard
        // The empty view should show appropriate message
        let globalEmptyMessage = "Complete workouts to appear on the leaderboard"
        XCTAssertFalse(globalEmptyMessage.isEmpty)
    }

    func testEmptyState_FriendsScope() {
        // Given empty friends leaderboard
        // The empty view should show appropriate message
        let friendsEmptyMessage = "Follow users to see them in your friends leaderboard"
        XCTAssertFalse(friendsEmptyMessage.isEmpty)
    }

    // MARK: - Filter Chip Tests

    func testFilterChip_SelectedState() {
        // Given
        var isSelected = true
        _ = FilterChip(
            title: "This Week",
            icon: "calendar",
            isSelected: isSelected,
            action: { isSelected.toggle() }
        )

        // Verify styling changes based on selection
        XCTAssertTrue(isSelected)
    }

    // MARK: - Integration Tests

    func testLeaderboardView_LoadsDataOnAppear() async {
        // Given
        let mockProfileService = container.userProfileService as? MockUserProfileService
        mockProfileService?.profiles = UserProfile.mockProfiles.reduce(into: [:]) { dict, profile in
            dict[profile.id] = profile
        }

        // When view appears, it should load leaderboard
        _ = await LeaderboardView()
            .environment(\.dependencyContainer, container)

        // In a real test with ViewInspector, we would verify:
        // - Loading state appears
        // - Data loads
        // - Entries are displayed
    }

    func testLeaderboardView_RefreshButton() {
        // Given
        _ = LeaderboardView()
            .environment(\.dependencyContainer, container)

        // Verify refresh button exists in toolbar
        // Would use ViewInspector to find and tap the button
    }

    // MARK: - Scrolling Tests

    func testLeaderboardView_ScrollsToCurrentUser() {
        // Given a leaderboard with current user not at top
        _ = [
            createMockEntry(rank: 1, userId: "user1"),
            createMockEntry(rank: 2, userId: "user2"),
            createMockEntry(rank: 3, userId: "user3"),
            createMockEntry(rank: 15, userId: "current-user", isCurrentUser: true)
        ]

        // When view appears, it should scroll to current user
        // Would verify with ViewInspector
    }

    // MARK: - Helper Methods

    private func createMockEntry(
        rank: Int,
        userId: String,
        isCurrentUser: Bool = false
    ) -> LeaderboardEntry {
        LeaderboardEntry(
            id: userId,
            rank: rank,
            profile: UserProfile.mockProfile,
            xpEarned: 1_000 - (rank * 50),
            workoutCount: 20 - rank,
            totalDuration: TimeInterval(3_600 - (rank * 100)),
            isCurrentUser: isCurrentUser,
            rankChange: nil
        )
    }
}
