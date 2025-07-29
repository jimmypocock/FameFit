//
//  LeaderboardViewModel.swift
//  FameFit
//
//  View model for leaderboard with time filters and friend scopes
//

import Combine
import Foundation

@MainActor
final class LeaderboardViewModel: ObservableObject {
    @Published var entries: [LeaderboardEntry] = []
    @Published var currentUserEntry: LeaderboardEntry?
    @Published var isLoading = false
    @Published var error: String?

    private var userProfileService: UserProfileServicing?
    private var socialFollowingService: SocialFollowingServicing?
    private var currentUserId = ""
    private var cancellables = Set<AnyCancellable>()

    // Cache for friend IDs
    private var friendIds: Set<String> = []
    private var lastFriendsFetch: Date = .distantPast

    func configure(
        userProfileService: UserProfileServicing,
        socialFollowingService: SocialFollowingServicing,
        currentUserId: String
    ) {
        self.userProfileService = userProfileService
        self.socialFollowingService = socialFollowingService
        self.currentUserId = currentUserId
    }

    func loadLeaderboard(
        timeFilter: LeaderboardTimeFilter,
        scope: LeaderboardScope
    ) async {
        isLoading = true
        error = nil

        do {
            // Load friend IDs if needed
            if scope == .friends {
                await loadFriendIds()
            }

            // Fetch leaderboard data
            let profiles = try await fetchProfiles(for: scope)

            // Calculate stats for time period
            let entries = await calculateLeaderboardEntries(
                from: profiles,
                timeFilter: timeFilter,
                scope: scope
            )

            // Sort by XP earned
            let sortedEntries = entries.sorted { $0.xpEarned > $1.xpEarned }

            // Assign ranks
            self.entries = assignRanks(to: sortedEntries)

            // Find current user entry
            currentUserEntry = self.entries.first { $0.id == currentUserId }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Testing Support

    /// Force refresh of friends cache (for testing)
    func forceRefreshFriends() {
        lastFriendsFetch = .distantPast
        friendIds.removeAll()
    }

    // MARK: - Private Methods

    private func loadFriendIds() async {
        // Cache friend IDs for 5 minutes
        if Date().timeIntervalSince(lastFriendsFetch) < 300, !friendIds.isEmpty {
            return
        }

        guard let socialService = socialFollowingService else { return }

        do {
            let following = try await socialService.getFollowing(for: currentUserId, limit: 1_000)
            friendIds = Set(following.map(\.id))
            friendIds.insert(currentUserId) // Include self in friends view
            lastFriendsFetch = Date()
        } catch {
            print("Failed to load friends: \(error)")
        }
    }

    private func fetchProfiles(for scope: LeaderboardScope) async throws -> [UserProfile] {
        guard let profileService = userProfileService else {
            throw LeaderboardError.serviceNotAvailable
        }

        switch scope {
        case .global:
            // Fetch top users globally
            return try await profileService.fetchLeaderboard(limit: 100)

        case .friends:
            // Fetch profiles for friends only
            guard !friendIds.isEmpty else {
                return []
            }

            // Batch fetch friend profiles
            var profiles: [UserProfile] = []
            for friendId in friendIds {
                if let profile = try? await profileService.fetchProfile(userId: friendId) {
                    profiles.append(profile)
                }
            }
            return profiles
        }
    }

    private func calculateLeaderboardEntries(
        from profiles: [UserProfile],
        timeFilter: LeaderboardTimeFilter,
        scope _: LeaderboardScope
    ) async -> [LeaderboardEntry] {
        let dateRange = timeFilter.dateRange

        return profiles.compactMap { profile in
            // Calculate XP earned in time period
            let xpEarned = calculateXPForPeriod(
                profile: profile,
                dateRange: dateRange
            )

            // Skip if no XP earned in period
            guard xpEarned > 0 else { return nil }

            // Calculate workout stats
            let workoutStats = calculateWorkoutStats(
                profile: profile,
                dateRange: dateRange
            )

            return LeaderboardEntry(
                id: profile.id,
                rank: 0, // Will be assigned later
                profile: profile,
                xpEarned: xpEarned,
                workoutCount: workoutStats.count,
                totalDuration: workoutStats.duration,
                isCurrentUser: profile.id == currentUserId,
                rankChange: nil // Could track this with historical data
            )
        }
    }

    private func calculateXPForPeriod(
        profile: UserProfile,
        dateRange: DateInterval
    ) -> Int {
        // For now, estimate based on total XP and account age
        // In a real implementation, we'd query workout history

        if dateRange.duration > 365 * 24 * 3_600 {
            // All time - return total XP
            return profile.totalXP
        }

        // Estimate daily XP rate
        let accountAge = Date().timeIntervalSince(profile.joinedDate)
        let daysActive = max(1, accountAge / (24 * 3_600))
        let dailyXPRate = Double(profile.totalXP) / daysActive

        // Calculate XP for period
        let periodDays = dateRange.duration / (24 * 3_600)
        return Int(dailyXPRate * periodDays)
    }

    private func calculateWorkoutStats(
        profile: UserProfile,
        dateRange: DateInterval
    ) -> (count: Int, duration: TimeInterval) {
        // Estimate based on total stats and period
        // In a real implementation, we'd query workout history

        let periodRatio = dateRange.duration / Date().timeIntervalSince(profile.joinedDate)
        // Estimate based on workout count (since we don't have detailed history)
        let estimatedCount = Int(Double(profile.workoutCount) * periodRatio)
        // Estimate duration assuming average 30 min per workout
        let estimatedDuration = Double(estimatedCount) * 30 * 60 // 30 minutes in seconds

        return (count: estimatedCount, duration: estimatedDuration)
    }

    private func assignRanks(to entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
        var rankedEntries: [LeaderboardEntry] = []
        var currentRank = 1
        var previousXP: Int?

        for (index, entry) in entries.enumerated() {
            // Handle ties
            if let prevXP = previousXP, prevXP != entry.xpEarned {
                currentRank = index + 1
            }

            var rankedEntry = entry
            rankedEntry = LeaderboardEntry(
                id: entry.id,
                rank: currentRank,
                profile: entry.profile,
                xpEarned: entry.xpEarned,
                workoutCount: entry.workoutCount,
                totalDuration: entry.totalDuration,
                isCurrentUser: entry.isCurrentUser,
                rankChange: entry.rankChange
            )

            rankedEntries.append(rankedEntry)
            previousXP = entry.xpEarned
        }

        return rankedEntries
    }
}

// MARK: - Errors

enum LeaderboardError: LocalizedError {
    case serviceNotAvailable
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .serviceNotAvailable:
            "Leaderboard service is not available"
        case .fetchFailed:
            "Failed to fetch leaderboard data"
        }
    }
}
