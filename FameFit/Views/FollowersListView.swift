//
//  FollowersListView.swift
//  FameFit
//
//  View for displaying followers and following lists
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
            tabPicker

            // Search bar
            if !currentList.isEmpty {
                searchBar
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }

            // Content
            ZStack {
                if isCurrentlyLoading {
                    loadingView
                } else if let error = currentError {
                    errorView(error)
                } else if filteredList.isEmpty {
                    emptyView
                } else {
                    listContent
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
                profile.displayName.lowercased().contains(query)
        }
    }

    private var isCurrentlyLoading: Bool {
        selectedTab == .followers ? isLoadingFollowers : isLoadingFollowing
    }

    private var currentError: String? {
        selectedTab == .followers ? followersError : followingError
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("List Type", selection: $selectedTab) {
            ForEach(FollowListTab.allCases, id: \.self) { tab in
                if tab == .followers {
                    Text("Followers (\(followerCount))").tag(tab)
                } else {
                    Text("Following (\(followingCount))").tag(tab)
                }
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .onChange(of: selectedTab) { _, newTab in
            searchText = ""
            Task {
                if newTab == .following && following.isEmpty {
                    await loadFollowing()
                } else if newTab == .followers && followers.isEmpty {
                    await loadFollowers()
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search \(selectedTab.rawValue.lowercased())...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Content Views

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredList) { profile in
                    FollowerRow(
                        profile: profile,
                        relationshipStatus: followingStatuses[profile.id] ?? .notFollowing,
                        isProcessing: pendingActions.contains(profile.id),
                        showFollowButton: currentUserId != nil && profile.id != currentUserId
                    ) {
                        await handleFollowAction(for: profile)
                    } onTap: {
                        // Navigate to profile
                    }

                    if profile.id != filteredList.last?.id {
                        Divider()
                            .padding(.leading, 76)
                    }
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Loading \(selectedTab.rawValue.lowercased())...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text("Error Loading \(selectedTab.rawValue)")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                Task {
                    await refreshCurrentTab()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: selectedTab == .followers ? "person.2.slash" : "person.crop.circle.badge.xmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(emptyTitle)
                .font(.headline)

            Text(emptyMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyTitle: String {
        if !searchText.isEmpty {
            return "No Results"
        }

        if selectedTab == .followers {
            return isOwnProfile ? "No Followers Yet" : "No Followers"
        } else {
            return isOwnProfile ? "Not Following Anyone" : "Not Following Anyone"
        }
    }

    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "Try searching with a different term"
        }

        if selectedTab == .followers {
            return isOwnProfile ? "When people follow you, they'll appear here" : "This user has no followers yet"
        } else {
            return isOwnProfile ? "Discover users to follow" : "This user isn't following anyone yet"
        }
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

    // MARK: - Follow Actions

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
}

// MARK: - Follower Row Component

struct FollowerRow: View {
    let profile: UserProfile
    let relationshipStatus: RelationshipStatus
    let isProcessing: Bool
    let showFollowButton: Bool
    let onFollowAction: () async -> Void
    let onTap: () -> Void

    @State private var showingProfile = false

    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            profileImage
                .onTapGesture {
                    showingProfile = true
                }

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

                    if relationshipStatus == .mutualFollow {
                        Text("Friends")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                }

                Text("@\(profile.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if profile.workoutCount > 0 {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.run")
                                .font(.caption2)
                            Text("\(profile.workoutCount)")
                                .font(.caption2)
                        }

                        Text("•")
                            .font(.caption2)

                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption2)
                            Text(formatNumber(profile.totalXP))
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Follow button
            if showFollowButton {
                followButton
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            showingProfile = true
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView(userId: profile.id)
        }
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

    private var followButton: some View {
        Button(action: {
            Task {
                await onFollowAction()
            }
        }) {
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 90, height: 32)
            } else {
                Text(followButtonTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(followButtonForegroundColor)
                    .frame(width: 90, height: 32)
                    .background(followButtonBackground)
                    .cornerRadius(16)
            }
        }
        .disabled(isProcessing || relationshipStatus == .blocked)
    }

    private var followButtonTitle: String {
        switch relationshipStatus {
        case .following, .mutualFollow:
            "Following"
        case .blocked:
            "Blocked"
        case .pending:
            "Requested"
        default:
            "Follow"
        }
    }

    private var followButtonForegroundColor: Color {
        switch relationshipStatus {
        case .following, .mutualFollow:
            .primary
        case .blocked:
            .red
        default:
            .white
        }
    }

    private var followButtonBackground: Color {
        switch relationshipStatus {
        case .following, .mutualFollow:
            Color(.systemGray5)
        case .blocked:
            Color.red.opacity(0.1)
        case .pending:
            Color.orange.opacity(0.2)
        default:
            .blue
        }
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000.0)
        }
        return "\(number)"
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
