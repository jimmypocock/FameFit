//
//  SocialFeedView.swift
//  FameFit
//
//  Social feed showing activities from followed users
//

import SwiftUI

// MARK: - Feed Item Types
// Using FeedItem, FeedItemType, FeedContent from FeedModels.swift

// MARK: - Social Feed View

struct SocialFeedView: View {
    @Environment(\.dependencyContainer) var container
    @StateObject private var viewModel = SocialFeedViewModel()
    @Binding var showingFilters: Bool
    var onDiscoverTap: (() -> Void)?

    @State private var selectedUserId: String?
    @State private var showingProfile = false
    @State private var selectedWorkoutForComments: FeedItem?
    @State private var showingComments = false

    private var currentUserId: String? {
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
                if let userId = selectedUserId {
                    ProfileView(userId: userId)
                }
            }
            .sheet(isPresented: $showingFilters) {
                FeedFiltersView(filters: viewModel.filters) { newFilters in
                    viewModel.updateFilters(newFilters)
                }
            }
            .sheet(isPresented: $showingComments) {
                if let workout = selectedWorkoutForComments {
                    // Convert FeedItem to WorkoutHistoryItem for WorkoutCommentsView
                    WorkoutCommentsView(
                        workout: WorkoutHistoryItem(
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
                commentsService: container.workoutCommentsService,
                currentUserId: currentUserId ?? ""
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
                            selectedUserId = item.userID
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
    SocialFeedView(showingFilters: .constant(false), onDiscoverTap: nil)
        .environment(\.dependencyContainer, DependencyContainer())
}
