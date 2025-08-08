//
//  ProfileView.swift
//  FameFit
//
//  View for displaying user profiles
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container

    @State private var profile: UserProfile?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showEditProfile = false
    @State private var relationshipStatus: RelationshipStatus = .notFollowing
    @State private var isFollowActionInProgress = false
    @State private var showFollowError = false
    @State private var followError: String?
    @State private var followerCount = 0
    @State private var followingCount = 0
    @State private var showingFollowersList = false
    @State private var selectedFollowTab: FollowListTab = .followers
    @State private var showUnfollowConfirmation = false
    @State private var isVerifyingStats = false
    @State private var statsVerificationMessage: String?

    let userID: String

    private var profileService: UserProfileServicing {
        container.userProfileService
    }

    private var socialService: SocialFollowingServicing {
        container.socialFollowingService
    }

    private var isOwnProfile: Bool {
        userID == container.cloudKitManager.currentUserID
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading profile...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red)

                    Text("Error Loading Profile")
                        .font(.headline)

                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Try Again") {
                        loadProfile()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let profile {
                profileContent(profile)
            }
        }
        .task {
            loadProfile()
            loadRelationshipStatus()
            loadFollowerCounts()
        }
        .alert("Follow Error", isPresented: $showFollowError) {
            Button("OK") {
                followError = nil
            }
        } message: {
            if let error = followError {
                Text(error)
            }
        }
        .sheet(isPresented: $showEditProfile) {
            if let profile {
                EditProfileView(profile: profile) { updatedProfile in
                    self.profile = updatedProfile
                }
            }
        }
        .sheet(isPresented: $showingFollowersList) {
            FollowersListView(userID: userID, initialTab: selectedFollowTab)
        }
    }

    // MARK: - Profile Content

    private func profileContent(_ profile: UserProfile) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                profileHeader(profile)

                // Stats Grid with refresh capability for own profile
                statsGrid(profile)
                
                // Refresh Stats button for own profile
                if isOwnProfile {
                    refreshStatsSection
                }

                // Bio Section
                if !profile.bio.isEmpty {
                    bioSection(profile)
                }

                // Privacy Info
                privacyInfo(profile)

                // Member Since
                memberInfo(profile)
            }
            .padding()
        }
        .refreshable {
            await refreshProfile()
        }
    }

    private func profileHeader(_ profile: UserProfile) -> some View {
        VStack(spacing: 16) {
            // Profile Image or Initials
            if profile.profileImageURL != nil {
                // TODO: Implement async image loading
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text("Photo")
                            .foregroundColor(.gray)
                    )
            } else {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)

                    Text(profile.initials)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            // Name and Username
            VStack(spacing: 4) {
                Text(profile.username)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("@\(profile.username)")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            // Verified Badge
            if profile.isVerified {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                    Text("Verified")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            // Follow/Unfollow button
            if !isOwnProfile {
                followButton
            }
        }
    }

    private var followButton: some View {
        Button(action: {
            if relationshipStatus == .following || relationshipStatus == .mutualFollow {
                // Show confirmation for unfollow
                showUnfollowConfirmation = true
            } else {
                // Direct follow action
                Task {
                    await handleFollowAction()
                }
            }
        }) {
            HStack {
                if isFollowActionInProgress {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: followButtonIcon)
                    Text(followButtonTitle)
                }
            }
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(followButtonForegroundColor)
            .frame(minWidth: 120)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(followButtonBackground)
            .cornerRadius(20)
        }
        .disabled(isFollowActionInProgress || relationshipStatus == .blocked)
        .confirmationDialog(
            "Unfollow @\(profile?.username ?? "")?",
            isPresented: $showUnfollowConfirmation,
            titleVisibility: .visible
        ) {
            Button("Unfollow", role: .destructive) {
                Task {
                    await handleFollowAction()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will no longer see their workouts in your feed.")
        }
    }

    private var followButtonIcon: String {
        switch relationshipStatus {
        case .following, .mutualFollow:
            "checkmark"
        case .blocked:
            "xmark.shield.fill"
        case .pending:
            "clock"
        default:
            "plus"
        }
    }

    private var followButtonTitle: String {
        switch relationshipStatus {
        case .following:
            "Following"
        case .mutualFollow:
            "Friends"
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

    private func statsGrid(_ profile: UserProfile) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            // Followers count - clickable
            Button(action: {
                selectedFollowTab = .followers
                showingFollowersList = true
            }) {
                ProfileStatCard(
                    title: "Followers",
                    value: formatNumber(followerCount),
                    icon: "person.2.fill",
                    color: .blue
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Following count - clickable
            Button(action: {
                selectedFollowTab = .following
                showingFollowersList = true
            }) {
                ProfileStatCard(
                    title: "Following",
                    value: formatNumber(followingCount),
                    icon: "person.crop.circle.fill.badge.plus",
                    color: .purple
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            ProfileStatCard(
                title: "Workouts",
                value: "\(profile.workoutCount)",
                icon: "figure.run",
                color: .orange
            )

            ProfileStatCard(
                title: "Influencer XP",
                value: formatNumber(profile.totalXP),
                icon: "star.fill",
                color: .yellow
            )

            if profile.isActive {
                ProfileStatCard(
                    title: "Status",
                    value: "Active",
                    icon: "bolt.fill",
                    color: .green
                )
            } else {
                ProfileStatCard(
                    title: "Status",
                    value: "Inactive",
                    icon: "moon.zzz.fill",
                    color: .gray
                )
            }

            ProfileStatCard(
                title: "Level",
                value: "\(XPCalculator.getLevel(for: profile.totalXP).level)",
                icon: "chart.line.uptrend.xyaxis",
                color: .purple
            )
        }
    }

    private func bioSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)

            Text(profile.bio)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func privacyInfo(_ profile: UserProfile) -> some View {
        HStack {
            Image(systemName: privacyIcon(for: profile.privacyLevel))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Privacy Setting")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(profile.privacyLevel.displayName)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func memberInfo(_ profile: UserProfile) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.purple)

            Text(profile.formattedJoinDate)
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Helper Methods

    private func loadProfile() {
        isLoading = true
        error = nil

        Task {
            do {
                let loadedProfile: UserProfile = if isOwnProfile {
                    // Use the same method as MainViewModel for current user
                    try await profileService.fetchCurrentUserProfile()
                } else {
                    // For other users, we need to use the correct method (this should be fixed in ProfileService)
                    try await profileService.fetchProfile(userID: userID)
                }
                await MainActor.run {
                    profile = loadedProfile
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func privacyIcon(for level: ProfilePrivacyLevel) -> String {
        switch level {
        case .publicProfile:
            "globe"
        case .friendsOnly:
            "person.2.fill"
        case .privateProfile:
            "lock.fill"
        }
    }

    // MARK: - Social Methods

    private func loadRelationshipStatus() {
        guard !isOwnProfile,
              let currentUserID = container.cloudKitManager.currentUserID else { return }

        Task {
            do {
                relationshipStatus = try await socialService.checkRelationship(
                    between: currentUserID,
                    and: userID
                )
            } catch {
                // Default to not following on error
                relationshipStatus = .notFollowing
            }
        }
    }

    private func handleFollowAction() async {
        guard let profile else { return }

        isFollowActionInProgress = true
        followError = nil

        do {
            switch relationshipStatus {
            case .following, .mutualFollow:
                // Unfollow
                try await socialService.unfollow(userID: userID)
                relationshipStatus = .notFollowing

            case .notFollowing:
                // Follow or request follow
                if profile.privacyLevel == .privateProfile {
                    try await socialService.requestFollow(userID: userID, message: nil)
                    relationshipStatus = .pending
                } else {
                    try await socialService.follow(userID: userID)
                    // Check if mutual
                    let newStatus = try await socialService.checkRelationship(
                        between: container.cloudKitManager.currentUserID ?? "",
                        and: userID
                    )
                    relationshipStatus = newStatus
                }

            case .pending:
                // Cancel request (not implemented yet)
                followError = "Cannot cancel follow request yet"
                showFollowError = true

            case .blocked, .muted:
                // Cannot follow blocked/muted users
                followError = "Cannot follow this user"
                showFollowError = true
            }
        } catch let socialError as SocialServiceError {
            followError = socialError.localizedDescription
            showFollowError = true
        } catch {
            followError = "Failed to update follow status"
            showFollowError = true
        }

        isFollowActionInProgress = false

        // Update counts after follow action
        loadFollowerCounts()
    }

    private func loadFollowerCounts() {
        Task {
            do {
                // Load counts in parallel
                async let followers = socialService.getFollowerCount(for: userID)
                async let following = socialService.getFollowingCount(for: userID)

                followerCount = try await followers
                followingCount = try await following
            } catch {
                // Silently fail, counts are not critical
                print("Failed to load follower counts: \(error)")
            }
        }
    }
    
    // MARK: - Refresh Stats Section
    
    private var refreshStatsSection: some View {
        VStack(spacing: 12) {
            if let message = statsVerificationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                Task {
                    await verifyStats()
                }
            }) {
                HStack {
                    if isVerifyingStats {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text("Verify Stats")
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .disabled(isVerifyingStats)
            
            if let lastVerified = profile?.countsLastVerified {
                Text("Last verified: \(lastVerified, formatter: relativeDateFormatter)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var relativeDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }
    
    // MARK: - Refresh Methods
    
    private func refreshProfile() async {
        // Pull-to-refresh action
        loadProfile()
        loadFollowerCounts()
        
        // Also verify stats if it's own profile
        if isOwnProfile {
            await verifyStats()
        }
    }
    
    private func verifyStats() async {
        guard isOwnProfile else { return }
        
        isVerifyingStats = true
        statsVerificationMessage = nil
        
        do {
            let result = try await container.countVerificationService.verifyAllCounts()
            
            if result.hadCorrections {
                statsVerificationMessage = "Stats updated: \(result.summary)"
                
                // Reload profile to show new counts
                loadProfile()
            } else {
                statsVerificationMessage = "All stats verified ✓"
            }
            
            // Clear message after delay
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                statsVerificationMessage = nil
            }
        } catch {
            print("❌ Verification error: \(error)")
            statsVerificationMessage = "Verification failed: \(error.localizedDescription)"
            
            // Clear message after delay
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds to read error
                statsVerificationMessage = nil
            }
        }
        
        isVerifyingStats = false
    }
}

// MARK: - Profile Stat Card Component

struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview("Own Profile") {
    ProfileView(userID: "mock-user-1")
        .environment(\.dependencyContainer, {
            let container = DependencyContainer()
            // Set up mock data
            return container
        }())
}

#Preview("Other User Profile") {
    ProfileView(userID: "other-user")
        .environment(\.dependencyContainer, DependencyContainer())
}
