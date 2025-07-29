//
//  UserSearchView.swift
//  FameFit
//
//  View for searching and discovering users with privacy controls
//

import SwiftUI

struct UserSearchView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container

    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var searchResults: [UserProfile] = []
    @State private var isSearching = false
    @State private var error: String?
    @State private var selectedUserId: String?
    @State private var showingProfile = false

    // Rate limiting
    @State private var lastSearchTime = Date.distantPast
    @State private var searchDebounceTimer: Timer?
    @State private var remainingSearches = 20

    private var profileService: UserProfileServicing {
        container.userProfileService
    }

    private var rateLimiter: RateLimitingServicing {
        container.rateLimitingService
    }

    private var currentUserId: String? {
        container.cloudKitManager.currentUserID
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Search").tag(0)
                    Text("Leaderboard").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                if selectedTab == 0 {
                    // Search tab
                    VStack(spacing: 0) {
                        // Search bar
                        searchBar
                            .padding(.horizontal)
                            .padding(.vertical, 8)

                        // Rate limit info
                        if remainingSearches < 10 {
                            rateLimitWarning
                        }

                        // Content
                        if isSearching {
                            ProgressView("Searching...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if searchResults.isEmpty, !searchText.isEmpty {
                            emptyState
                        } else if !searchResults.isEmpty {
                            searchResultsList
                        } else {
                            suggestedUsersView
                        }
                    }
                } else {
                    // Leaderboard tab
                    LeaderboardView()
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Search Error", isPresented: .constant(error != nil)) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error {
                    Text(error)
                }
            }
            .sheet(isPresented: $showingProfile) {
                if let userId = selectedUserId {
                    ProfileView(userId: userId)
                }
            }
        }
        .task {
            await updateRemainingSearches()
            await loadSuggestedUsers()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search by username or name", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onChange(of: searchText) { _, newValue in
                    debounceSearch(newValue)
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Rate Limit Warning

    private var rateLimitWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text("\(remainingSearches) searches remaining this hour")
                .font(.caption)
                .foregroundColor(.orange)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No users found")
                .font(.headline)

            Text("Try searching with a different term")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchResults) { profile in
                    UserSearchRow(profile: profile)
                        .onTapGesture {
                            selectedUserId = profile.id
                            showingProfile = true
                        }

                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
    }

    // MARK: - Suggested Users

    @State private var suggestedUsers: [UserProfile] = []
    @State private var isLoadingSuggestions = true

    private var suggestedUsersView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Leaderboard section
                leaderboardSection

                Divider()

                // Recently active section
                recentlyActiveSection
            }
            .padding(.vertical)
        }
    }

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Performers")
                .font(.headline)
                .padding(.horizontal)

            if isLoadingSuggestions {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(suggestedUsers.prefix(5)) { profile in
                    UserSearchRow(profile: profile, showRank: true)
                        .onTapGesture {
                            selectedUserId = profile.id
                            showingProfile = true
                        }

                    if profile.id != suggestedUsers.prefix(5).last?.id {
                        Divider()
                            .padding(.leading, 76)
                    }
                }
            }
        }
    }

    private var recentlyActiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Active")
                .font(.headline)
                .padding(.horizontal)

            Text("Coming soon...")
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helper Methods

    private func debounceSearch(_ query: String) {
        searchDebounceTimer?.invalidate()

        guard !query.isEmpty else {
            searchResults = []
            return
        }

        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task {
                await performSearch(query)
            }
        }
    }

    private func performSearch(_ query: String) async {
        guard let currentUserId else { return }

        isSearching = true
        error = nil

        do {
            // Check rate limit
            _ = try await rateLimiter.checkLimit(for: .search, userId: currentUserId)

            // Perform search
            let results = try await profileService.searchProfiles(query: query, limit: 20)

            // Filter out self and apply privacy filters
            searchResults = results.filter { profile in
                profile.id != currentUserId &&
                    profile.privacyLevel != .privateProfile
            }

            // Record action
            await rateLimiter.recordAction(.search, userId: currentUserId)

            // Update remaining searches
            await updateRemainingSearches()
        } catch let socialError as SocialServiceError {
            self.error = socialError.localizedDescription
            searchResults = []
        } catch {
            self.error = "Search failed: \(error.localizedDescription)"
            searchResults = []
        }

        isSearching = false
    }

    private func updateRemainingSearches() async {
        guard let currentUserId else { return }
        remainingSearches = await rateLimiter.getRemainingActions(for: .search, userId: currentUserId)
    }

    private func loadSuggestedUsers() async {
        isLoadingSuggestions = true

        do {
            suggestedUsers = try await profileService.fetchLeaderboard(limit: 10)
        } catch {
            // Silently fail, suggestions are not critical
        }

        isLoadingSuggestions = false
    }
}

// MARK: - User Search Row

struct UserSearchRow: View {
    let profile: UserProfile
    var showRank: Bool = false

    @Environment(\.dependencyContainer) var container

    private var rank: Int? {
        guard showRank else { return nil }
        // This would be calculated based on leaderboard position
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            if let rank {
                Text("#\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                    .frame(width: 30)
            }

            // Profile image
            profileImage

            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.displayName)
                        .font(.body)
                        .fontWeight(.medium)

                    if profile.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }

                Text("@\(profile.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if showRank {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption2)

                        Text(formatNumber(profile.totalXP) + " XP")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.caption2)

                        Text("\(profile.workoutCount) workouts")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Privacy indicator
            if profile.privacyLevel == .friendsOnly {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var profileImage: some View {
        ZStack {
            if profile.profileImageURL != nil {
                // TODO: Implement async image loading
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
            } else {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(profile.initials)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    )
            }
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Preview

#Preview {
    UserSearchView()
        .environment(\.dependencyContainer, DependencyContainer())
}
