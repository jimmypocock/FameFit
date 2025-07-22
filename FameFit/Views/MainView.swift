import SwiftUI
import Combine
import os.log

struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    @State private var showingNotifications = false
    @State private var showingWorkoutHistory = false
    @State private var showingProfile = false
    @State private var showingProfileCreation = false
    @State private var showingUserSearch = false
    @State private var showingSocialFeed = false
    @State private var showingWorkoutSharingPrompt = false
    @State private var workoutToShare: WorkoutHistoryItem?
    
    @Environment(\.dependencyContainer) var container
    @State private var cancellables = Set<AnyCancellable>()
    
    init(viewModel: MainViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Profile Card
                Button(action: {
                    if viewModel.hasProfile {
                        showingProfile = true
                    } else {
                        showingProfileCreation = true
                    }
                }) {
                    HStack(spacing: 16) {
                        // Profile Image
                        if let profile = viewModel.userProfile {
                            profileImage(for: profile)
                        } else {
                            defaultProfileImage
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome back,")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(viewModel.userName)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if let username = viewModel.userProfile?.username {
                                Text("@\(username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                }
                .buttonStyle(PlainButtonStyle())

                VStack(spacing: 20) {
                    XPProgressView(currentXP: viewModel.totalXP)

                    HStack {
                        Button(action: {
                            showingWorkoutHistory = true
                        }) {
                            StatCard(title: "Workouts", value: "\(viewModel.totalWorkouts)", icon: "figure.run")
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        StatCard(title: "Streak", value: "\(viewModel.currentStreak)", icon: "flame.fill")
                    }
                    
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Member Since")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let joinDate = viewModel.joinDate {
                                    Text(joinDate, style: .date)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                } else {
                                    Text("Today")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Last Workout")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let lastWorkout = viewModel.lastWorkoutDate {
                                    Text(lastWorkout, style: .relative)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                } else {
                                    Text("None yet")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(15)
                    }
                }

                Spacer()
            }
            .padding()
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
                                        .frame(width: max(18, CGFloat(String(viewModel.unreadNotificationCount).count) * 10 + 8), 
                                               height: 18)
                                        .shadow(color: .red.opacity(0.3), radius: 2, x: 0, y: 1)
                                    
                                    Text("\(viewModel.unreadNotificationCount)")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .offset(x: 10, y: -10)
                                .scaleEffect(viewModel.unreadNotificationCount > 0 ? 1.0 : 0.1)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: viewModel.unreadNotificationCount)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
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
        .sheet(isPresented: $showingProfile) {
            if let userId = viewModel.userProfile?.id {
                ProfileView(userId: userId)
            }
        }
        .sheet(isPresented: $showingProfileCreation) {
            ProfileCreationView()
                .interactiveDismissDisabled()
                .onDisappear {
                    // Refresh to load the new profile
                    viewModel.loadUserProfile()
                }
        }
        .sheet(isPresented: $showingUserSearch) {
            UserSearchView()
        }
        .sheet(isPresented: $showingSocialFeed) {
            SocialFeedView()
        }
        .sheet(isPresented: $showingWorkoutSharingPrompt) {
            if let workout = workoutToShare {
                WorkoutSharingPromptView(workoutHistory: workout) { privacy, includeDetails in
                    // Handle successful sharing
                    print("Workout shared with privacy: \(privacy), details: \(includeDetails)")
                }
            }
        }
        .onAppear {
            viewModel.refreshData()
            viewModel.loadUserProfile()
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
    
    // MARK: - Workout Sharing
    
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
    
    // MARK: - Helper Views
    
    private func profileImage(for profile: UserProfile) -> some View {
        Group {
            if let _ = profile.profileImageURL {
                // TODO: Load actual image
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
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
                        .frame(width: 50, height: 50)
                    
                    Text(profile.initials)
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var defaultProfileImage: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
            
            Image(systemName: "person.fill")
                .font(.title2)
                .foregroundColor(.gray)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

#Preview {
    let container = DependencyContainer()
    let viewModel = MainViewModel(
        authManager: container.authenticationManager,
        cloudKitManager: container.cloudKitManager,
        notificationStore: container.notificationStore,
        userProfileService: container.userProfileService
    )
    return MainView(viewModel: viewModel)
}
