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
    @State private var showingFilters = false
    @State private var activeSheet: SheetType?
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
                SocialFeedView(
                    showingFilters: $showingFilters,
                    onDiscoverTap: {
                        selectedTab = 1 // Switch to Discover tab
                    }
                )
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Image("AppIconTitle")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 30)
                        }
                        
                        ToolbarItem(placement: .navigationBarLeading) {
                            profileButton
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            filterButton
                        }
                    }
            }
            .tabItem {
                Image(systemName: "house.fill")
            }
            .tag(0)

            // Discover Users
            NavigationView {
                UserSearchView()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
            }
            .tag(1)

            // Workouts
            NavigationView {
                WorkoutsContainerView()
                    .navigationTitle("Workouts")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Image(systemName: "figure.run")
            }
            .tag(2)
            
            // Group Workouts
            NavigationView {
                GroupWorkoutsView()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Image(systemName: "person.3")
            }
            .tag(3)

            // Challenges
            NavigationView {
                ChallengesView()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Image(systemName: "trophy")
            }
            .tag(4)
        }
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .profile:
                NavigationView {
                    if let currentUserId = container.cloudKitManager.currentUserID {
                        ProfileView(userId: currentUserId)
                            .navigationTitle("Profile")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    notificationButton
                                }
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
            case .notifications:
                NotificationCenterView()
            case .workoutHistory:
                WorkoutHistoryView()
            case .editProfile:
                if let profile = viewModel.userProfile {
                    EditProfileView(profile: profile) { updatedProfile in
                        viewModel.userProfile = updatedProfile
                    }
                }
            case .workoutSharing(let workout):
                WorkoutSharingPromptView(workoutHistory: workout) { privacy, includeDetails in
                    // Handle successful sharing
                    print("Workout shared with privacy: \(privacy), details: \(includeDetails)")
                }
            case .notificationDebug:
                NotificationDebugView()
            #if DEBUG
            case .developerMenu:
                DeveloperMenu()
            #endif
            }
        }
        .onAppear {
            viewModel.refreshData()
            viewModel.loadUserProfile()
            viewModel.loadFollowerCounts()
            setupWorkoutSharingListener()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ClearAllCaches"))) { _ in
            // Refresh all data with fresh fetch when cache is cleared
            viewModel.refreshUserProfile()
            viewModel.loadFollowerCounts()
        }
        #if DEBUG
        .onShake {
            activeSheet = .developerMenu
        }
        #endif
    }

    // MARK: - Toolbar Components

    private var notificationButton: some View {
        Button(action: {
            activeSheet = .notifications
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
    
    private var profileButton: some View {
        Button(action: {
            activeSheet = .profile
        }) {
            Image(systemName: "person.circle")
        }
    }
    
    private var filterButton: some View {
        Button(action: {
            showingFilters = true
        }) {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    private var profileMenu: some View {
        Menu {
            if viewModel.hasProfile {
                Button(action: {
                    activeSheet = .editProfile
                }) {
                    Label("Edit Profile", systemImage: "pencil")
                }

                Divider()
            }

            #if DEBUG
                Button(action: {
                    activeSheet = .notificationDebug
                }) {
                    Label("Debug Notifications", systemImage: "bell.badge.waveform")
                }
                
                Button(action: {
                    activeSheet = .developerMenu
                }) {
                    Label("Developer Menu", systemImage: "hammer")
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
        activeSheet = .workoutSharing(workout)
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
