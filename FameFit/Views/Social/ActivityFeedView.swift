//
//  ActivityFeedView.swift
//  FameFit
//
//  Activity feed showing activities from followed users
//

import SwiftUI

// MARK: - Feed Item Types  
// Using ActivityFeedItem, ActivityFeedItemType, and ActivityFeedContent from FeedModels.swift

// MARK: - Activity Feed View

struct ActivityFeedView: View {
    @Environment(\.dependencyContainer) var container
    @StateObject private var viewModel = ActivityFeedViewModel()
    @Binding var showingFilters: Bool
    var onDiscoverTap: (() -> Void)?

    @State private var selectedUserId: String?
    @State private var showingProfile = false
    @State private var selectedActivityForComments: ActivityFeedItem?
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
                ActivityFeedFiltersView(filters: viewModel.filters) { newFilters in
                    viewModel.updateFilters(newFilters)
                }
            }
            .sheet(isPresented: $showingComments) {
                if let feedItem = selectedActivityForComments {
                    ActivityCommentsView(feedItem: feedItem)
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
                            selectedActivityForComments = feedItem
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

// MARK: - Feed Item View

struct ActivityFeedItemView: View {
    let item: ActivityFeedItem
    let onProfileTap: () -> Void
    let onKudosTap: (ActivityFeedItem) async -> Void
    let onCommentsTap: (ActivityFeedItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                // Profile image
                Button(action: onProfileTap) {
                    profileImage
                }

                // User info and time
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.userProfile?.username ?? "Unknown User")
                            .font(.body)
                            .fontWeight(.medium)

                        if item.userProfile?.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }

                    Text(item.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Activity type icon
                Image(systemName: item.type.icon)
                    .foregroundColor(item.type.color)
                    .font(.title3)
            }

            // Content
            contentView
        }
        .padding()
    }

    private var profileImage: some View {
        Group {
            if let profile = item.userProfile, profile.profileImageURL != nil {
                // TODO: Implement async image loading
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            } else if let profile = item.userProfile {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(profile.initials)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    )
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            }
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(item.content.title)
                .font(.body)
                .fontWeight(.medium)

            // Subtitle if available
            if let subtitle = item.content.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Type-specific content
            switch item.type {
            case .workout:
                workoutDetails
            case .achievement:
                achievementDetails
            case .levelUp:
                levelUpDetails
            case .milestone:
                milestoneDetails
            case .challenge:
                challengeDetails
            case .groupWorkout:
                groupWorkoutDetails
            }
        }
    }

    private var workoutDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                if let duration = item.content.duration {
                    DetailBadge(
                        icon: "clock",
                        value: formatDuration(duration),
                        color: .blue
                    )
                }

                if let calories = item.content.calories {
                    DetailBadge(
                        icon: "flame",
                        value: "\(Int(calories)) cal",
                        color: .orange
                    )
                }

                if let xp = item.content.xpEarned {
                    DetailBadge(
                        icon: "star.fill",
                        value: "+\(xp) XP",
                        color: .yellow
                    )
                }

                Spacer()
            }

            // Kudos and Comments buttons for workout items
            if item.type == .workout {
                HStack(spacing: 12) {
                    KudosButton(
                        workoutId: item.id,
                        ownerId: item.userID,
                        kudosSummary: item.kudosSummary,
                        onTap: {
                            await onKudosTap(item)
                        }
                    )

                    CommentsButton(
                        workoutId: item.id,
                        commentCount: item.commentCount,
                        onTap: {
                            onCommentsTap(item)
                        }
                    )

                    Spacer()
                }
            }
        }
        .padding(.top, 4)
    }

    private var achievementDetails: some View {
        HStack {
            if let icon = item.content.achievementIcon {
                Image(systemName: icon)
                    .foregroundColor(.yellow)
                    .font(.title2)
            }

            Text("Unlocked!")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.yellow)

            Spacer()
        }
        .padding(.top, 4)
    }

    private var levelUpDetails: some View {
        HStack {
            if let level = item.content.newLevel {
                Text("Level \(level)")
                    .font(.headline)
                    .foregroundColor(.purple)
            }

            if let title = item.content.newTitle {
                Text("•")
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    private var milestoneDetails: some View {
        EmptyView() // Milestone details are in the title/subtitle
    }
    
    private var challengeDetails: some View {
        HStack {
            if let icon = item.content.details["challengeIcon"] {
                Image(systemName: icon)
                    .foregroundColor(.green)
                    .font(.title2)
            }
            
            Text("Challenge Active")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
            
            Spacer()
        }
        .padding(.top, 4)
    }
    
    private var groupWorkoutDetails: some View {
        HStack {
            Image(systemName: "person.3.fill")
                .foregroundColor(.cyan)
                .font(.title2)
            
            if let participantCount = item.content.details["participantCount"] {
                Text("\(participantCount) participants")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.cyan)
            }
            
            Spacer()
        }
        .padding(.top, 4)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Detail Badge Component

struct DetailBadge: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)

            Text(value)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}


// MARK: - Preview

#Preview {
    ActivityFeedView(showingFilters: .constant(false), onDiscoverTap: nil)
        .environment(\.dependencyContainer, DependencyContainer())
}
