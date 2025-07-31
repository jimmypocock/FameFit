import Combine
import os.log
import SwiftUI

struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    @State private var showingNotifications = false
    @State private var showingWorkoutHistory = false
    @State private var showingEditProfile = false
    @State private var showingUserSearch = false
    @State private var showingSocialFeed = false
    @State private var showingWorkoutSharingPrompt = false
    @State private var showingNotificationDebug = false
    @State private var showingFollowersList = false
    @State private var selectedFollowTab: FollowListTab = .followers
    @State private var workoutToShare: WorkoutHistoryItem?

    @Environment(\.dependencyContainer) var container
    @State private var cancellables = Set<AnyCancellable>()

    init(viewModel: MainViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header Section
                    if viewModel.hasProfile {
                        profileHeaderSection
                    } else {
                        loadingProfileSection
                    }

                    // XP Progress - Featured prominently
                    if viewModel.hasProfile {
                        XPProgressView(currentXP: viewModel.totalXP)
                            .padding(.horizontal)
                    }

                    // Stats Grid
                    if viewModel.hasProfile {
                        statsGrid
                            .padding(.horizontal)
                    }

                    // Bio Section
                    if let profile = viewModel.userProfile, !profile.bio.isEmpty {
                        bioSection(profile)
                            .padding(.horizontal)
                    }

                    // Additional Info
                    if viewModel.hasProfile {
                        VStack(spacing: 12) {
                            // Privacy Settings
                            if let profile = viewModel.userProfile {
                                privacyInfo(profile)
                            }

                            // Member Info
                            memberInfoSection

                            // Last Workout
                            lastWorkoutSection
                        }
                        .padding(.horizontal)
                    }

                    // Bottom padding for scroll content
                    Color.clear.frame(height: 20)
                }
                .padding(.top)
            }
            .navigationTitle("FameFit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingNotifications = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")

                            if viewModel.unreadNotificationCount > 0 {
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(
                                            width: max(
                                                18,
                                                CGFloat(String(viewModel.unreadNotificationCount).count) * 10 + 8
                                            ),
                                            height: 18
                                        )
                                        .shadow(color: .red.opacity(0.3), radius: 2, x: 0, y: 1)

                                    Text("\(viewModel.unreadNotificationCount)")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .offset(x: 10, y: -10)
                                .scaleEffect(viewModel.unreadNotificationCount > 0 ? 1.0 : 0.1)
                                .animation(
                                    .spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0),
                                    value: viewModel.unreadNotificationCount
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if viewModel.hasProfile {
                            Button(action: {
                                showingEditProfile = true
                            }) {
                                Label("Edit Profile", systemImage: "pencil")
                            }

                            Divider()
                        }

                        Button(action: {
                            showingSocialFeed = true
                        }) {
                            Label("Activity Feed", systemImage: "newspaper")
                        }

                        Button(action: {
                            showingUserSearch = true
                        }) {
                            Label("Discover Users", systemImage: "magnifyingglass")
                        }

                        Divider()

                        #if DEBUG
                            Button(action: {
                                showingNotificationDebug = true
                            }) {
                                Label("Debug Notifications", systemImage: "bell.badge.waveform")
                            }

                            Divider()
                        #endif

                        Button(action: {
                            viewModel.signOut()
                        }) {
                            Label("Sign Out", systemImage: "arrow.right.square")
                                .foregroundColor(.red)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationCenterView()
        }
        .sheet(isPresented: $showingWorkoutHistory) {
            WorkoutHistoryView()
        }
        .sheet(isPresented: $showingEditProfile) {
            if let profile = viewModel.userProfile {
                EditProfileView(profile: profile) { updatedProfile in
                    viewModel.userProfile = updatedProfile
                }
            }
        }
        .sheet(isPresented: $showingUserSearch) {
            UserSearchView()
        }
        .sheet(isPresented: $showingSocialFeed) {
            SocialFeedView(showingFilters: .constant(false), onDiscoverTap: nil)
        }
        .sheet(isPresented: $showingWorkoutSharingPrompt) {
            if let workout = workoutToShare {
                WorkoutSharingPromptView(workoutHistory: workout) { privacy, includeDetails in
                    // Handle successful sharing
                    print("Workout shared with privacy: \(privacy), details: \(includeDetails)")
                }
            }
        }
        .sheet(isPresented: $showingNotificationDebug) {
            NotificationDebugView()
        }
        .sheet(isPresented: $showingFollowersList) {
            if let userId = viewModel.userProfile?.id {
                FollowersListView(userId: userId, initialTab: selectedFollowTab)
            }
        }
        .onAppear {
            viewModel.refreshData()
            viewModel.loadUserProfile()
            viewModel.loadFollowerCounts()
            setupWorkoutSharingListener()
        }
    }

    // MARK: - Profile Header Section

    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Profile Image
            if let profile = viewModel.userProfile {
                profileImage(for: profile)
                    .frame(width: 120, height: 120)
            }

            // Name and Username
            VStack(spacing: 4) {
                Text(viewModel.userProfile?.username ?? viewModel.userName)
                    .font(.title2)
                    .fontWeight(.bold)

                if let username = viewModel.userProfile?.username {
                    Text("@\(username)")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }

            // Verified Badge
            if viewModel.userProfile?.isVerified == true {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                    Text("Verified")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            // Level and Title
            let levelInfo = XPCalculator.getLevel(for: viewModel.totalXP)
            VStack(spacing: 4) {
                Text("Level \(levelInfo.level)")
                    .font(.headline)
                    .foregroundColor(.purple)
                Text(levelInfo.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var loadingProfileSection: some View {
        VStack(spacing: 20) {
            if !container.cloudKitManager.isAvailable {
                // CloudKit not signed in
                Image(systemName: "icloud.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("iCloud Required")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 8) {
                    Text("Please sign in to iCloud to access your profile and sync your data.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Go to Settings → [Your Name] → iCloud")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                }
            } else {
                // CloudKit signed in but profile loading
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))

                Text("Loading Profile...")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Your fitness journey is loading")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .padding()
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            // Followers - Clickable
            Button(action: {
                selectedFollowTab = .followers
                showingFollowersList = true
            }) {
                StatCard(
                    title: "Followers",
                    value: formatNumber(viewModel.followerCount),
                    icon: "person.2.fill",
                    color: .blue
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Following - Clickable
            Button(action: {
                selectedFollowTab = .following
                showingFollowersList = true
            }) {
                StatCard(
                    title: "Following",
                    value: formatNumber(viewModel.followingCount),
                    icon: "person.crop.circle.fill.badge.plus",
                    color: .purple
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Workouts - Clickable
            Button(action: {
                showingWorkoutHistory = true
            }) {
                StatCard(
                    title: "Workouts",
                    value: "\(viewModel.totalWorkouts)",
                    icon: "figure.run",
                    color: .orange
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("workouts-button")
            .accessibilityLabel("\(viewModel.totalWorkouts), Workouts")

            // Streak
            StatCard(
                title: "Streak",
                value: "\(viewModel.currentStreak)",
                icon: "flame.fill",
                color: .red
            )

            // Total XP
            StatCard(
                title: "Total XP",
                value: formatNumber(viewModel.totalXP),
                icon: "star.fill",
                color: .yellow
            )

            // Status
            if viewModel.userProfile?.isActive == true {
                StatCard(
                    title: "Status",
                    value: "Active",
                    icon: "bolt.fill",
                    color: .green
                )
            } else {
                StatCard(
                    title: "Status",
                    value: "Inactive",
                    icon: "moon.zzz.fill",
                    color: .gray
                )
            }
        }
    }

    // MARK: - Bio Section

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

    // MARK: - Additional Info Sections

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

    private var memberInfoSection: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.purple)

            VStack(alignment: .leading, spacing: 4) {
                Text("Member Since")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let joinDate = viewModel.joinDate {
                    Text(joinDate, style: .date)
                        .font(.body)
                        .fontWeight(.medium)
                } else {
                    Text("Today")
                        .font(.body)
                        .fontWeight(.medium)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var lastWorkoutSection: some View {
        HStack {
            Image(systemName: "figure.run")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Last Workout")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let lastWorkout = viewModel.lastWorkoutDate {
                    Text(lastWorkout, style: .relative)
                        .font(.body)
                        .fontWeight(.medium)
                } else {
                    Text("No workouts yet")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Helper Methods

    private func setupWorkoutSharingListener() {
        container.workoutObserver.workoutCompletedPublisher
            .receive(on: DispatchQueue.main)
            .sink { workoutHistory in
                showWorkoutSharingPrompt(for: workoutHistory)
            }
            .store(in: &cancellables)
    }

    private func showWorkoutSharingPrompt(for workout: WorkoutHistoryItem) {
        // Only show prompt if user is authenticated and has a profile
        guard viewModel.hasProfile else { return }

        workoutToShare = workout
        showingWorkoutSharingPrompt = true
    }

    private func profileImage(for profile: UserProfile) -> some View {
        Group {
            if profile.profileImageURL != nil {
                // TODO: Load actual image
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Text("Photo")
                            .font(.caption)
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

                    Text(profile.initials)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
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
}

// MARK: - Stat Card Component

struct StatCard: View {
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
                    .accessibilityIdentifier("\(title.lowercased().replacingOccurrences(of: " ", with: "-"))-value")

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier(title)
                    .accessibilityLabel(title)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityHidden(false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityIdentifier("\(title.lowercased().replacingOccurrences(of: " ", with: "-"))-stat")
    }
}

#Preview {
    let container = DependencyContainer()
    let viewModel = MainViewModel(
        authManager: container.authenticationManager,
        cloudKitManager: container.cloudKitManager,
        notificationStore: container.notificationStore,
        userProfileService: container.userProfileService,
        socialFollowingService: container.socialFollowingService
    )
    return MainView(viewModel: viewModel)
}
