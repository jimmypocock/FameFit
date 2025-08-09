//
//  ActivityFeedView.swift
//  FameFit
//
//  Activity feed showing activities from followed users
//

import SwiftUI

// MARK: - Feed Item Types
// Using ActivityFeedItem, ActivityFeedItemType, ActivityFeedContent from FeedModels.swift

// MARK: - Activity Feed View

struct ActivityFeedView: View {
    @Environment(\.dependencyContainer) var container
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = ActivityFeedViewModel()
    @Binding var showingFilters: Bool
    var onDiscoverTap: (() -> Void)?

    @State private var selectedUserID: String?
    @State private var showingProfile = false
    @State private var selectedWorkoutForComments: ActivityFeedItem?
    @State private var showingComments = false
    @State private var lastRefreshTime = Date()
    @State private var hasAppeared = false

    private var currentUserID: String? {
        container.cloudKitManager.currentUserID
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading, viewModel.feedItems.isEmpty {
                    loadingView
                } else if viewModel.feedItems.isEmpty {
                    emptyView
                } else {
                    feedContent
                }
            }
            .refreshable {
                await viewModel.refreshFeed()
            }
            .sheet(isPresented: $showingProfile) {
                if let userID = selectedUserID {
                    ProfileView(userID: userID)
                }
            }
            .sheet(isPresented: $showingFilters) {
                ActivityFeedFiltersView(filters: viewModel.filters) { newFilters in
                    viewModel.updateFilters(newFilters)
                }
            }
            .sheet(isPresented: $showingComments) {
                if let workout = selectedWorkoutForComments {
                    // Convert ActivityFeedItem to Workout for WorkoutCommentsView
                    WorkoutCommentsView(
                        workout: Workout(
                            id: workout.id,
                            workoutType: workout.content.workoutType ?? "Unknown",
                            startDate: workout.timestamp,
                            endDate: workout.timestamp.addingTimeInterval(workout.content.duration ?? 0),
                            duration: workout.content.duration ?? 0,
                            totalEnergyBurned: Double(workout.content.calories ?? 0),
                            totalDistance: 0, // Not available in feed item
                            averageHeartRate: 0, // Not available in feed item
                            followersEarned: 0, // Deprecated
                            xpEarned: workout.content.xpEarned ?? 0,
                            source: "healthkit"
                        ),
                        workoutOwner: workout.userProfile
                    )
                }
            }
        }
        .task {
            // Only configure on first appearance
            if !hasAppeared {
                // Wait for CloudKit to be ready and user ID to be available
                await waitForCloudKitReady()
                
                // Only proceed if we have a valid user ID
                guard let userID = currentUserID, !userID.isEmpty else {
                    FameFitLogger.warning("⚠️ No user ID available for feed", category: FameFitLogger.social)
                    return
                }
                
                viewModel.configure(
                    socialService: container.socialFollowingService,
                    profileService: container.userProfileService,
                    activityFeedService: container.activityFeedService,
                    kudosService: container.workoutKudosService,
                    commentsService: container.activityCommentsService,
                    currentUserID: userID
                )
                await viewModel.loadInitialFeed()
                hasAppeared = true
                lastRefreshTime = Date()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Refresh when app becomes active after being in background
            if newPhase == .active {
                let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
                // Refresh if it's been more than 30 seconds since last refresh
                if timeSinceLastRefresh > 30 {
                    Task {
                        await viewModel.checkForNewItems()
                        lastRefreshTime = Date()
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WorkoutCompleted"))) { _ in
            // Refresh feed when a new workout is completed
            Task {
                await viewModel.checkForNewItems()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshActivityFeed"))) { _ in
            // Allow other parts of the app to trigger feed refresh
            Task {
                await viewModel.refreshFeed()
                lastRefreshTime = Date()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CloudKitUserIDAvailable"))) { _ in
            // Try to load feed when user ID becomes available
            if !hasAppeared, let userID = currentUserID, !userID.isEmpty {
                Task {
                    viewModel.configure(
                        socialService: container.socialFollowingService,
                        profileService: container.userProfileService,
                        activityFeedService: container.activityFeedService,
                        kudosService: container.workoutKudosService,
                        commentsService: container.activityCommentsService,
                        currentUserID: userID
                    )
                    await viewModel.loadInitialFeed()
                    hasAppeared = true
                    lastRefreshTime = Date()
                }
            }
        }
    }

    // MARK: - Helper Methods
    
    private func waitForCloudKitReady() async {
        // Wait for CloudKit to initialize (max 3 seconds)
        let maxWaitTime: TimeInterval = 3.0
        let startTime = Date()
        
        while container.cloudKitManager.currentUserID == nil || 
              container.cloudKitManager.currentUserID?.isEmpty == true {
            // Check if we've exceeded max wait time
            if Date().timeIntervalSince(startTime) > maxWaitTime {
                FameFitLogger.warning("⏱️ CloudKit initialization timeout", category: FameFitLogger.social)
                break
            }
            
            // Wait a bit before checking again
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Give CloudKit a moment to fully initialize after user ID is available
        if container.cloudKitManager.currentUserID != nil {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
    }

    // MARK: - Content Views

    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredFeedItems) { item in
                    EnhancedFeedItemView(
                        item: item,
                        onProfileTap: {
                            selectedUserID = item.userID
                            showingProfile = true
                        },
                        onKudosTap: { feedItem in
                            await viewModel.toggleKudos(for: feedItem)
                        },
                        onCommentsTap: { feedItem in
                            selectedWorkoutForComments = feedItem
                            showingComments = true
                        }
                    )

                    if item.id != viewModel.filteredFeedItems.last?.id {
                        Divider()
                            .padding(.horizontal)
                    }
                }

                // Load more indicator
                if viewModel.hasMoreItems, !viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .onAppear {
                        Task {
                            await viewModel.loadMoreItems()
                        }
                    }
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Loading activity feed...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "newspaper")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Activities Yet")
                .font(.headline)

            Text("Follow users to see their workout activities here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Discover Users") {
                onDiscoverTap?()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}


// MARK: - Preview

#Preview {
    ActivityFeedView(showingFilters: .constant(false), onDiscoverTap: nil)
        .environment(\.dependencyContainer, DependencyContainer())
}
