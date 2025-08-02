//
//  FollowersListView.swift
//  FameFit
//
//  Main view for displaying followers and following lists with tabs
//

import SwiftUI

enum FollowListTab: String, CaseIterable {
    case followers = "Followers"
    case following = "Following"

    var systemImage: String {
        switch self {
        case .followers:
            "person.2.fill"
        case .following:
            "person.crop.circle.fill.badge.plus"
        }
    }
}

struct FollowersListView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container

    let userId: String
    let initialTab: FollowListTab

    @State private var selectedTab: FollowListTab
    @State private var followers: [UserProfile] = []
    @State private var following: [UserProfile] = []
    @State private var isLoadingFollowers = true
    @State private var isLoadingFollowing = true
    @State private var followersError: String?
    @State private var followingError: String?
    @State private var searchText = ""
    @State private var followingStatuses: [String: RelationshipStatus] = [:]
    @State private var pendingActions: Set<String> = []

    // Counts
    @State private var followerCount = 0
    @State private var followingCount = 0

    private var socialService: SocialFollowingServicing {
        container.socialFollowingService
    }

    private var profileService: UserProfileServicing {
        container.userProfileService
    }

    private var currentUserId: String? {
        container.cloudKitManager.currentUserID
    }

    private var isOwnProfile: Bool {
        userId == currentUserId
    }

    init(userId: String, initialTab: FollowListTab = .followers) {
        self.userId = userId
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            FollowersTabPicker(
                selectedTab: $selectedTab,
                followerCount: followerCount,
                followingCount: followingCount,
                searchText: $searchText,
                onTabChanged: handleTabChange
            )

            // Search bar
            if !currentList.isEmpty {
                FollowersSearchBar(searchText: $searchText, selectedTab: selectedTab)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }

            // Content
            ZStack {
                if isCurrentlyLoading {
                    FollowersLoadingView(selectedTab: selectedTab)
                } else if let error = currentError {
                    FollowersErrorView(error: error, selectedTab: selectedTab) {
                        Task { await refreshCurrentTab() }
                    }
                } else if filteredList.isEmpty {
                    FollowersEmptyView(
                        selectedTab: selectedTab,
                        searchText: searchText,
                        isOwnProfile: isOwnProfile
                    )
                } else {
                    FollowersListContent(
                        profiles: filteredList,
                        followingStatuses: followingStatuses,
                        pendingActions: pendingActions,
                        currentUserId: currentUserId,
                        onFollowAction: handleFollowAction
                    )
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task {
            await loadInitialData()
        }
        .refreshable {
            await refreshCurrentTab()
        }
    }

    // MARK: - Computed Properties

    private var navigationTitle: String {
        if isOwnProfile {
            selectedTab == .followers ? "My Followers" : "Following"
        } else {
            selectedTab == .followers ? "Followers" : "Following"
        }
    }

    private var currentList: [UserProfile] {
        selectedTab == .followers ? followers : following
    }

    private var filteredList: [UserProfile] {
        if searchText.isEmpty {
            return currentList
        }

        let query = searchText.lowercased()
        return currentList.filter { profile in
            profile.username.lowercased().contains(query) ||
                profile.username.lowercased().contains(query)
        }
    }

    private var isCurrentlyLoading: Bool {
        selectedTab == .followers ? isLoadingFollowers : isLoadingFollowing
    }

    private var currentError: String? {
        selectedTab == .followers ? followersError : followingError
    }

    // MARK: - Actions

    private func handleTabChange(_ newTab: FollowListTab) {
        Task {
            if newTab == .following && following.isEmpty {
                await loadFollowing()
            } else if newTab == .followers && followers.isEmpty {
                await loadFollowers()
            }
        }
    }

    private func handleFollowAction(for profile: UserProfile) async {
        guard let currentUserId else { return }

        pendingActions.insert(profile.id)

        do {
            let currentStatus = followingStatuses[profile.id] ?? .notFollowing

            switch currentStatus {
            case .following, .mutualFollow:
                try await socialService.unfollow(userId: profile.id)
                followingStatuses[profile.id] = .notFollowing

            case .notFollowing:
                if profile.privacyLevel == .privateProfile {
                    try await socialService.requestFollow(userId: profile.id, message: nil)
                    followingStatuses[profile.id] = .pending
                } else {
                    try await socialService.follow(userId: profile.id)
                    // Check if mutual
                    let newStatus = try await socialService.checkRelationship(
                        between: currentUserId,
                        and: profile.id
                    )
                    followingStatuses[profile.id] = newStatus
                }

            default:
                break
            }
        } catch {
            // Revert status on error
            await loadFollowingStatuses(for: [profile])
        }

        pendingActions.remove(profile.id)
    }

    // MARK: - Data Loading

    private func loadInitialData() async {
        // Load the initially selected tab
        if initialTab == .followers {
            await loadFollowers()
        } else {
            await loadFollowing()
        }

        // Load following statuses if viewing own profile
        if isOwnProfile {
            await loadFollowingStatuses()
        }
    }

    private func loadFollowers() async {
        isLoadingFollowers = true
        followersError = nil

        do {
            print("Loading followers for userId: \(userId)")
            followers = try await socialService.getFollowers(for: userId, limit: 1_000)
            print("Loaded \(followers.count) followers")
            followerCount = try await socialService.getFollowerCount(for: userId)
            print("Follower count: \(followerCount)")

            // Load following statuses for these users
            if currentUserId != nil {
                await loadFollowingStatuses(for: followers)
            }
        } catch {
            print("Error loading followers: \(error)")
            followersError = "Failed to load followers: \(error.localizedDescription)"
        }

        isLoadingFollowers = false
    }

    private func loadFollowing() async {
        isLoadingFollowing = true
        followingError = nil

        do {
            print("Loading following for userId: \(userId)")
            following = try await socialService.getFollowing(for: userId, limit: 1_000)
            print("Loaded \(following.count) following")
            followingCount = try await socialService.getFollowingCount(for: userId)
            print("Following count: \(followingCount)")

            // All following relationships are active
            for profile in following {
                followingStatuses[profile.id] = .following
            }
        } catch {
            print("Error loading following: \(error)")
            followingError = "Failed to load following: \(error.localizedDescription)"
        }

        isLoadingFollowing = false
    }

    private func loadFollowingStatuses(for profiles: [UserProfile]? = nil) async {
        guard let currentUserId else { return }

        let profilesToCheck = profiles ?? currentList

        await withTaskGroup(of: (String, RelationshipStatus?).self) { group in
            for profile in profilesToCheck {
                group.addTask {
                    let status = try? await socialService.checkRelationship(
                        between: currentUserId,
                        and: profile.id
                    )
                    return (profile.id, status)
                }
            }

            for await (profileId, status) in group {
                if let status {
                    followingStatuses[profileId] = status
                }
            }
        }
    }

    private func refreshCurrentTab() async {
        if selectedTab == .followers {
            await loadFollowers()
        } else {
            await loadFollowing()
        }
    }
}

// MARK: - Preview

#Preview("Followers") {
    FollowersListView(userId: "mock-user-1", initialTab: .followers)
        .environment(\.dependencyContainer, DependencyContainer())
}

#Preview("Following") {
    FollowersListView(userId: "mock-user-1", initialTab: .following)
        .environment(\.dependencyContainer, DependencyContainer())
}