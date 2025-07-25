//
//  LeaderboardView.swift
//  FameFit
//
//  Comprehensive leaderboard view with time filters and friend-only options
//

import SwiftUI

// MARK: - Leaderboard Types

enum LeaderboardTimeFilter: String, CaseIterable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case allTime = "All Time"

    var icon: String {
        switch self {
        case .today:
            "calendar.day.timeline.left"
        case .week:
            "calendar"
        case .month:
            "calendar.badge.clock"
        case .allTime:
            "infinity"
        }
    }

    var dateRange: DateInterval {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return DateInterval(start: startOfDay, end: now)

        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return DateInterval(start: startOfWeek, end: now)

        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return DateInterval(start: startOfMonth, end: now)

        case .allTime:
            return DateInterval(start: Date.distantPast, end: now)
        }
    }
}

enum LeaderboardScope: String, CaseIterable {
    case global = "Global"
    case friends = "Friends"
    case nearby = "Nearby" // Future feature

    var icon: String {
        switch self {
        case .global:
            "globe"
        case .friends:
            "person.2"
        case .nearby:
            "location"
        }
    }
}

// MARK: - Leaderboard Entry

struct LeaderboardEntry: Identifiable {
    let id: String
    let rank: Int
    let profile: UserProfile
    let xpEarned: Int
    let workoutCount: Int
    let totalDuration: TimeInterval // in seconds
    let isCurrentUser: Bool
    let rankChange: RankChange?

    enum RankChange {
        case up(Int)
        case down(Int)
        case same
        case new

        var icon: String {
            switch self {
            case .up:
                "arrow.up"
            case .down:
                "arrow.down"
            case .same:
                "minus"
            case .new:
                "sparkles"
            }
        }

        var color: Color {
            switch self {
            case .up:
                .green
            case .down:
                .red
            case .same:
                .secondary
            case .new:
                .yellow
            }
        }
    }
}

// MARK: - Main View

struct LeaderboardView: View {
    @Environment(\.dependencyContainer) var container
    @StateObject private var viewModel = LeaderboardViewModel()

    @State private var selectedTimeFilter: LeaderboardTimeFilter = .week
    @State private var selectedScope: LeaderboardScope = .global
    @State private var showingProfile = false
    @State private var selectedUserId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters
                filterSection

                // Content
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else if viewModel.entries.isEmpty {
                    emptyView
                } else {
                    leaderboardContent
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .sheet(isPresented: $showingProfile) {
                if let userId = selectedUserId {
                    ProfileView(userId: userId)
                }
            }
            .task {
                viewModel.configure(
                    userProfileService: container.userProfileService,
                    socialFollowingService: container.socialFollowingService,
                    currentUserId: container.cloudKitManager.currentUserID ?? ""
                )
                await viewModel.loadLeaderboard(
                    timeFilter: selectedTimeFilter,
                    scope: selectedScope
                )
            }
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(spacing: 16) {
            // Time filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LeaderboardTimeFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            icon: filter.icon,
                            isSelected: selectedTimeFilter == filter
                        ) {
                            selectedTimeFilter = filter
                            Task {
                                await viewModel.loadLeaderboard(
                                    timeFilter: filter,
                                    scope: selectedScope
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Scope filter
            Picker("Scope", selection: $selectedScope) {
                ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                    Label(scope.rawValue, systemImage: scope.icon)
                        .tag(scope)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .disabled(selectedScope == .nearby) // Nearby not implemented yet
            .onChange(of: selectedScope) {
                Task {
                    await viewModel.loadLeaderboard(
                        timeFilter: selectedTimeFilter,
                        scope: selectedScope
                    )
                }
            }

            Divider()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Leaderboard Content

    private var leaderboardContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Current user position (if not in top entries)
                    if let currentUserEntry = viewModel.currentUserEntry,
                       !viewModel.entries.contains(where: { $0.id == currentUserEntry.id })
                    {
                        VStack(spacing: 0) {
                            LeaderboardRow(entry: currentUserEntry) {
                                // Current user - no navigation
                            }
                            .background(Color.accentColor.opacity(0.1))

                            HStack {
                                Text("...")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)

                            Divider()
                        }
                    }

                    // Top entries
                    ForEach(viewModel.entries) { entry in
                        LeaderboardRow(entry: entry) {
                            if !entry.isCurrentUser {
                                selectedUserId = entry.id
                                showingProfile = true
                            }
                        }
                        .id(entry.id)
                        .background(entry.isCurrentUser ? Color.accentColor.opacity(0.1) : Color.clear)

                        if entry.id != viewModel.entries.last?.id {
                            Divider()
                                .padding(.leading, 76)
                        }
                    }
                }
            }
            .onAppear {
                // Scroll to current user if in list
                if let currentEntry = viewModel.entries.first(where: { $0.isCurrentUser }) {
                    withAnimation {
                        proxy.scrollTo(currentEntry.id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Supporting Views

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Loading leaderboard...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text("Failed to Load Leaderboard")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                Task {
                    await viewModel.loadLeaderboard(
                        timeFilter: selectedTimeFilter,
                        scope: selectedScope
                    )
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: selectedScope == .friends ? "person.2.slash" : "trophy.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text(selectedScope == .friends ? "No Friends Yet" : "No Data Available")
                .font(.headline)

            Text(selectedScope == .friends
                ? "Follow users to see them in your friends leaderboard"
                : "Complete workouts to appear on the leaderboard"
            )
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var refreshButton: some View {
        Button(action: {
            Task {
                await viewModel.loadLeaderboard(
                    timeFilter: selectedTimeFilter,
                    scope: selectedScope
                )
            }
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoading)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption)
                .fontWeight(isSelected ? .medium : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let onTap: () -> Void

    private var rankDisplay: String {
        switch entry.rank {
        case 1:
            "🥇"
        case 2:
            "🥈"
        case 3:
            "🥉"
        default:
            "\(entry.rank)"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Rank
                ZStack {
                    if entry.rank <= 3 {
                        Text(rankDisplay)
                            .font(.title2)
                    } else {
                        Text(rankDisplay)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .frame(width: 40)
                    }
                }
                .frame(width: 40)

                // Profile
                HStack(spacing: 12) {
                    // Avatar
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(entry.profile.initials)
                                .font(.callout)
                                .fontWeight(.medium)
                        )

                    // Name and username
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.profile.displayName)
                                .font(.body)
                                .fontWeight(entry.isCurrentUser ? .semibold : .medium)

                            if entry.profile.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }

                        Text("@\(entry.profile.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Stats
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("\(entry.xpEarned)")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("XP")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Text("\(entry.workoutCount)")
                                .font(.caption)
                            Image(systemName: "figure.run")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Rank change
                    if let rankChange = entry.rankChange {
                        VStack {
                            Image(systemName: rankChange.icon)
                                .font(.caption)
                                .foregroundColor(rankChange.color)

                            if case let .up(positions) = rankChange {
                                Text("+\(positions)")
                                    .font(.caption2)
                                    .foregroundColor(rankChange.color)
                            } else if case let .down(positions) = rankChange {
                                Text("-\(positions)")
                                    .font(.caption2)
                                    .foregroundColor(rankChange.color)
                            }
                        }
                        .frame(width: 30)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        LeaderboardView()
            .environment(\.dependencyContainer, DependencyContainer())
    }
}
