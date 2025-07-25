//
//  SocialFeedView.swift
//  FameFit
//
//  Social feed showing activities from followed users
//

import SwiftUI

// MARK: - Feed Item Types

enum FeedItemType: String {
    case workout
    case achievement
    case levelUp = "level_up"
    case milestone

    var icon: String {
        switch self {
        case .workout:
            "figure.run"
        case .achievement:
            "trophy.fill"
        case .levelUp:
            "arrow.up.circle.fill"
        case .milestone:
            "star.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .workout:
            .blue
        case .achievement:
            .yellow
        case .levelUp:
            .purple
        case .milestone:
            .orange
        }
    }
}

struct FeedItem: Identifiable {
    let id: String
    let userID: String
    let userProfile: UserProfile?
    let type: FeedItemType
    let timestamp: Date
    let content: FeedContent
    var kudosSummary: WorkoutKudosSummary? // For workout items
    var commentCount: Int = 0 // For workout items

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var workoutId: String? {
        // For workout feed items, the id is the workout ID
        type == .workout ? id : nil
    }
}

struct FeedContent: Codable {
    let title: String
    let subtitle: String?
    let details: [String: String] // Changed from Any to String for Codable compliance

    // Workout specific
    var workoutType: String? {
        details["workoutType"]
    }

    var duration: TimeInterval? {
        if let durationString = details["duration"] {
            return TimeInterval(durationString)
        }
        return nil
    }

    var calories: Double? {
        if let caloriesString = details["calories"] {
            return Double(caloriesString)
        }
        return nil
    }

    var xpEarned: Int? {
        if let xpString = details["xpEarned"] {
            return Int(xpString)
        }
        return nil
    }

    // Achievement specific
    var achievementName: String? {
        details["achievementName"]
    }

    var achievementIcon: String? {
        details["achievementIcon"]
    }

    // Level up specific
    var newLevel: Int? {
        if let levelString = details["newLevel"] {
            return Int(levelString)
        }
        return nil
    }

    var newTitle: String? {
        details["newTitle"]
    }
}

// MARK: - Social Feed View

struct SocialFeedView: View {
    @Environment(\.dependencyContainer) var container
    @StateObject private var viewModel = SocialFeedViewModel()

    @State private var selectedUserId: String?
    @State private var showingProfile = false
    @State private var showingFilters = false
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
            .navigationTitle("Activity Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingFilters = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
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
                            totalEnergyBurned: workout.content.calories ?? 0,
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
                    FeedItemView(
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
                // TODO: Navigate to user search
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Feed Item View

struct FeedItemView: View {
    let item: FeedItem
    let onProfileTap: () -> Void
    let onKudosTap: (FeedItem) async -> Void
    let onCommentsTap: (FeedItem) -> Void

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
                        Text(item.userProfile?.displayName ?? "Unknown User")
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

// MARK: - Feed Filters View

struct FeedFilters {
    var showWorkouts = true
    var showAchievements = true
    var showLevelUps = true
    var showMilestones = true
    var timeRange: TimeRange = .all

    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }
}

struct FeedFiltersView: View {
    @Environment(\.dismiss) var dismiss
    @State private var filters: FeedFilters
    let onApply: (FeedFilters) -> Void

    init(filters: FeedFilters, onApply: @escaping (FeedFilters) -> Void) {
        _filters = State(initialValue: filters)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity Types") {
                    Toggle("Workouts", isOn: $filters.showWorkouts)
                    Toggle("Achievements", isOn: $filters.showAchievements)
                    Toggle("Level Ups", isOn: $filters.showLevelUps)
                    Toggle("Milestones", isOn: $filters.showMilestones)
                }

                Section("Time Range") {
                    Picker("Show activities from", selection: $filters.timeRange) {
                        ForEach(FeedFilters.TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                }
            }
            .navigationTitle("Filter Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply(filters)
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SocialFeedView()
        .environment(\.dependencyContainer, DependencyContainer())
}
