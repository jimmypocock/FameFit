//
//  TabMainView.swift
//  FameFit
//
//  Main tabbed interface with activity feed as home
//

import Combine
import SwiftUI

struct TabMainView: View {
    @StateObject private var viewModel: MainViewModel
    @State private var selectedTab = 0
    @State private var showingNotifications = false
    @State private var showingWorkoutHistory = false
    @State private var showingEditProfile = false
    @State private var showingUserSearch = false
    @State private var showingWorkoutSharingPrompt = false
    @State private var showingNotificationDebug = false
    @State private var workoutToShare: WorkoutHistoryItem?

    @Environment(\.dependencyContainer) var container
    @State private var cancellables = Set<AnyCancellable>()

    init(viewModel: MainViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Activity Feed - Primary home screen
            NavigationView {
                SocialFeedView()
                    .navigationTitle("Activity")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            notificationButton
                        }

                        ToolbarItem(placement: .navigationBarTrailing) {
                            discoverButton
                        }
                    }
            }
            .tabItem {
                Image(systemName: "newspaper")
                Text("Feed")
            }
            .tag(0)

            // Workout History
            NavigationView {
                WorkoutHistoryView()
                    .navigationTitle("Workouts")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Image(systemName: "figure.run")
                Text("Workouts")
            }
            .tag(1)

            // Group Workouts
            NavigationView {
                GroupWorkoutsView()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Image(systemName: "person.3")
                Text("Groups")
            }
            .tag(2)

            // Challenges
            NavigationView {
                ChallengesView()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Image(systemName: "trophy")
                Text("Challenges")
            }
            .tag(3)

            // Profile
            NavigationView {
                if let currentUserId = container.cloudKitManager.currentUserID {
                    ProfileView(userId: currentUserId)
                        .navigationTitle("Profile")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                profileMenu
                            }
                        }
                } else {
                    ProgressView("Loading profile...")
                        .navigationTitle("Profile")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .tabItem {
                Image(systemName: "person.circle")
                Text("Profile")
            }
            .tag(4)
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
        .onAppear {
            viewModel.refreshData()
            viewModel.loadUserProfile()
            viewModel.loadFollowerCounts()
            setupWorkoutSharingListener()

            #if DEBUG
                // Add test notifications for manual verification of notification pipeline
                if container.notificationStore.notifications.isEmpty {
                    container.addTestNotifications()
                    // Test notification settings integration
                    container.testNotificationSettingsIntegration()
                }
            #endif
        }
    }

    // MARK: - Toolbar Components

    private var notificationButton: some View {
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
                                width: max(18, CGFloat(String(viewModel.unreadNotificationCount).count) * 10 + 8),
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

    private var discoverButton: some View {
        Button(action: {
            showingUserSearch = true
        }) {
            Image(systemName: "magnifyingglass")
        }
    }

    private var profileMenu: some View {
        Menu {
            if viewModel.hasProfile {
                Button(action: {
                    showingEditProfile = true
                }) {
                    Label("Edit Profile", systemImage: "pencil")
                }

                Divider()
            }

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
    return TabMainView(viewModel: viewModel)
}
