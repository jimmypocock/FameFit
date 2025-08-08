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
    @StateObject private var viewModel = ActivityFeedViewModel()
    @Binding var showingFilters: Bool
    var onDiscoverTap: (() -> Void)?

    @State private var selectedUserID: String?
    @State private var showingProfile = false
    @State private var selectedWorkoutForComments: ActivityFeedItem?
    @State private var showingComments = false

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
                            id: UUID(uuidString: workout.id) ?? UUID(),
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
            viewModel.configure(
                socialService: container.socialFollowingService,
                profileService: container.userProfileService,
                activityFeedService: container.activityFeedService,
                kudosService: container.workoutKudosService,
                commentsService: container.activityCommentsService,
                currentUserID: currentUserID ?? ""
            )
            await viewModel.loadInitialFeed()
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
