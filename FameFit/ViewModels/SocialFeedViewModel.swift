//
//  SocialFeedViewModel.swift
//  FameFit
//
//  View model for social feed with content filtering
//

import CloudKit
import Combine
import Foundation

@MainActor
final class SocialFeedViewModel: ObservableObject {
    @Published var feedItems: [ActivityFeedItem] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var filters = ActivityFeedFilters()
    @Published var hasMoreItems = true

    private var socialService: SocialFollowingServicing?
    private var profileService: UserProfileServicing?
    private var activityFeedService: ActivityFeedServicing?
    private var kudosService: WorkoutKudosServicing?
    private var commentsService: WorkoutCommentsServicing?
    private var currentUserId = ""
    private var followingUsers: Set<String> = []
    private var lastFetchedDate: Date?
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()

    // Content filtering
    private let inappropriateWords = Set([
        // This would be a comprehensive list in production
        "spam", "inappropriate", "offensive"
    ])

    var filteredFeedItems: [ActivityFeedItem] {
        feedItems.filter { item in
            // Filter by type
            switch item.type {
            case .workout where !filters.showWorkouts:
                return false
            case .achievement where !filters.showAchievements:
                return false
            case .levelUp where !filters.showLevelUps:
                return false
            case .milestone where !filters.showMilestones:
                return false
            default:
                break
            }

            // Filter by time range
            switch filters.timeRange {
            case .today:
                return Calendar.current.isDateInToday(item.timestamp)
            case .week:
                return item.timestamp > Date().addingTimeInterval(-7 * 24 * 3_600)
            case .month:
                return item.timestamp > Date().addingTimeInterval(-30 * 24 * 3_600)
            case .all:
                return true
            }
        }
    }

    func configure(
        socialService: SocialFollowingServicing,
        profileService: UserProfileServicing,
        activityFeedService: ActivityFeedServicing,
        kudosService: WorkoutKudosServicing,
        commentsService: WorkoutCommentsServicing,
        currentUserId: String
    ) {
        self.socialService = socialService
        self.profileService = profileService
        self.kudosService = kudosService
        self.commentsService = commentsService
        self.activityFeedService = activityFeedService
        self.currentUserId = currentUserId

        // Subscribe to kudos updates
        setupKudosListener()

        // Start real-time updates
        startRealTimeUpdates()
    }

    func loadInitialFeed() async {
        isLoading = true
        error = nil
        feedItems = []

        do {
            // First, get the list of users we're following
            guard let socialService else { return }
            let following = try await socialService.getFollowing(for: currentUserId, limit: 1_000)
            followingUsers = Set(following.map(\.id))

            // Add self to see own activities
            followingUsers.insert(currentUserId)

            // Load feed items
            await loadFeedItems()
        } catch {
            self.error = "Failed to load feed"
        }

        isLoading = false
    }

    func refreshFeed() async {
        // Clear and reload
        feedItems = []
        lastFetchedDate = nil
        hasMoreItems = true
        await loadInitialFeed()
    }

    func loadMoreItems() async {
        guard !isLoading, hasMoreItems else { return }

        isLoading = true
        await loadFeedItems()
        isLoading = false
    }

    func updateFilters(_ newFilters: ActivityFeedFilters) {
        filters = newFilters
    }

    // MARK: - Real-time Updates

    private func startRealTimeUpdates() {
        // Set up a timer to periodically check for new items
        Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.checkForNewItems()
                }
            }
            .store(in: &cancellables)
    }

    private func checkForNewItems() async {
        guard !isLoading,
              let activityFeedService,
              !followingUsers.isEmpty
        else {
            return
        }

        // Get the timestamp of our most recent item
        guard let mostRecentTimestamp = feedItems.first?.timestamp else {
            return
        }

        do {
            // Check for items newer than our most recent
            let newItems = try await activityFeedService.fetchFeed(
                for: followingUsers,
                since: mostRecentTimestamp,
                limit: 50 // Check up to 50 new items
            )

            if !newItems.isEmpty {
                let feedItems = await convertActivityItemsToFeedItems(newItems)
                await insertNewItems(feedItems)
            }
        } catch {
            // Silently fail for background updates
            print("Failed to check for new items: \(error)")
        }
    }

    private func insertNewItems(_ items: [ActivityFeedItem]) async {
        // Filter inappropriate content
        let filteredItems = items.filter { item in
            !containsInappropriateContent(item.content.title) &&
                (item.content.subtitle == nil || !containsInappropriateContent(item.content.subtitle!))
        }

        guard !filteredItems.isEmpty else { return }

        // Sort by timestamp (newest first)
        let sortedItems = filteredItems.sorted { $0.timestamp > $1.timestamp }

        // Insert at the beginning of the feed
        feedItems.insert(contentsOf: sortedItems, at: 0)

        // Load kudos for any new workout items
        await loadKudosForNewItems(sortedItems)
    }

    private func loadKudosForNewItems(_ items: [ActivityFeedItem]) async {
        guard let kudosService else { return }

        let workoutIds = items
            .filter { $0.type == .workout }
            .map(\.id)

        guard !workoutIds.isEmpty else { return }

        do {
            let kudosSummaries = try await kudosService.getKudosSummaries(for: workoutIds)

            // Update the new items with kudos data
            for (index, item) in feedItems.enumerated() {
                if items.contains(where: { $0.id == item.id }),
                   let summary = kudosSummaries[item.id] {
                    feedItems[index].kudosSummary = summary
                }
            }
        } catch {
            print("Failed to load kudos for new items: \(error)")
        }
    }

    // MARK: - Private Methods

    private func loadFeedItems() async {
        guard let activityFeedService else {
            // Fallback to mock data if no activity feed service
            let mockItems = await createMockFeedItems()
            await processFeedItems(mockItems)
            return
        }

        do {
            let activityItems = try await activityFeedService.fetchFeed(
                for: followingUsers,
                since: lastFetchedDate,
                limit: pageSize
            )

            // Convert ActivityFeedRecord to ActivityFeedItem
            let feedItems = await convertActivityItemsToFeedItems(activityItems)
            await processFeedItems(feedItems)
        } catch {
            // Fall back to mock data on error
            let mockItems = await createMockFeedItems()
            await processFeedItems(mockItems)
        }
    }

    private func processFeedItems(_ items: [ActivityFeedItem]) async {
        // Filter inappropriate content
        let filteredItems = items.filter { item in
            !containsInappropriateContent(item.content.title) &&
                (item.content.subtitle == nil || !containsInappropriateContent(item.content.subtitle!))
        }

        // Sort by timestamp
        let sortedItems = filteredItems.sorted { $0.timestamp > $1.timestamp }

        // Append to existing items
        feedItems.append(contentsOf: sortedItems)

        // Load kudos for workout items
        await loadKudosForWorkouts()

        // Update pagination state
        if sortedItems.count < pageSize {
            hasMoreItems = false
        }
        lastFetchedDate = sortedItems.last?.timestamp
    }

    private func convertActivityItemsToFeedItems(_ activityItems: [ActivityFeedItem]) async -> [ActivityFeedItem] {
        var feedItems: [ActivityFeedItem] = []

        for activityItem in activityItems {
            // Get user profile for the activity
            let userProfile = try? await profileService?.fetchProfile(userId: activityItem.userID)

            // Convert activity type
            let feedItemType: ActivityFeedItemType = switch activityItem.activityType {
            case "workout":
                .workout
            case "achievement":
                .achievement
            case "level_up":
                .levelUp
            default:
                .milestone
            }

            // Parse content
            let content = activityItem.contentData ?? ActivityFeedContent(
                title: "Activity",
                subtitle: nil,
                details: [:]
            )

            var feedItem = ActivityFeedItem(
                id: activityItem.id,
                userID: activityItem.userID,
                userProfile: userProfile,
                type: feedItemType,
                timestamp: activityItem.createdTimestamp,
                content: content,
                workoutId: activityItem.workoutId,
                kudosCount: 0,
                commentCount: 0,
                hasKudoed: false,
                kudosSummary: nil
            )

            // For workout items, get kudos and comment counts
            if feedItemType == .workout {
                // Get kudos summary
                if let kudosService {
                    feedItem.kudosSummary = try? await kudosService.getKudosSummary(for: activityItem.id)
                }

                // Get comment count
                if let commentsService {
                    feedItem.commentCount = await (try? commentsService.fetchCommentCount(for: activityItem.id)) ?? 0
                }
            }

            feedItems.append(feedItem)
        }

        return feedItems
    }

    private func containsInappropriateContent(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return inappropriateWords.contains { lowercased.contains($0) }
    }

    private func createMockFeedItems() async -> [ActivityFeedItem] {
        // This would be replaced with actual CloudKit queries
        var items: [ActivityFeedItem] = []

        // Mock workout activities
        if let profile = try? await profileService?.fetchProfile(userId: "mock-user-1") {
            items.append(ActivityFeedItem(
                id: UUID().uuidString,
                userID: profile.id,
                userProfile: profile,
                type: .workout,
                timestamp: Date().addingTimeInterval(-3_600),
                content: ActivityFeedContent(
                    title: "Completed a High Intensity Interval Training",
                    subtitle: "Crushed another workout! 💪",
                    details: [
                        "workoutType": "High Intensity Interval Training",
                        "duration": "1800",
                        "calories": "450",
                        "xpEarned": "45"
                    ]
                ),
                workoutId: UUID().uuidString,
                kudosCount: 15,
                commentCount: 5,
                hasKudoed: false,
                kudosSummary: nil
            ))

            items.append(ActivityFeedItem(
                id: UUID().uuidString,
                userID: profile.id,
                userProfile: profile,
                type: .achievement,
                timestamp: Date().addingTimeInterval(-7_200),
                content: ActivityFeedContent(
                    title: "Earned the 'Workout Warrior' badge",
                    subtitle: "Completed 50 workouts!",
                    details: [
                        "achievementName": "Workout Warrior",
                        "achievementIcon": "medal.fill"
                    ]
                ),
                workoutId: nil,
                kudosCount: 0,
                commentCount: 0,
                hasKudoed: false,
                kudosSummary: nil
            ))
        }

        // Mock level up
        if let profile2 = try? await profileService?.fetchProfile(userId: "mock-user-2") {
            items.append(ActivityFeedItem(
                id: UUID().uuidString,
                userID: profile2.id,
                userProfile: profile2,
                type: .levelUp,
                timestamp: Date().addingTimeInterval(-10_800),
                content: ActivityFeedContent(
                    title: "Reached Level 5!",
                    subtitle: nil,
                    details: [
                        "newLevel": "5",
                        "newTitle": "Fitness Enthusiast"
                    ]
                ),
                workoutId: nil,
                kudosCount: 0,
                commentCount: 0,
                hasKudoed: false,
                kudosSummary: nil
            ))
        }

        return items
    }

    // MARK: - Kudos Management

    private func setupKudosListener() {
        kudosService?.kudosUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handleKudosUpdate(update)
            }
            .store(in: &cancellables)
    }

    private func handleKudosUpdate(_ update: KudosUpdate) {
        // Find the feed item for this workout
        guard let index = feedItems.firstIndex(where: { $0.id == update.workoutId }) else {
            return
        }

        // Update the kudos count
        var updatedItem = feedItems[index]
        if var kudosSummary = updatedItem.kudosSummary {
            kudosSummary = WorkoutKudosSummary(
                workoutId: kudosSummary.workoutId,
                totalCount: update.newCount,
                hasUserKudos: update.action == .added,
                recentUsers: kudosSummary.recentUsers
            )
            updatedItem.kudosSummary = kudosSummary
            feedItems[index] = updatedItem
        }
    }

    func toggleKudos(for item: ActivityFeedItem) async {
        guard let kudosService,
              item.type == .workout
        else {
            return
        }

        do {
            _ = try await kudosService.toggleKudos(for: item.id, ownerId: item.userID)
        } catch {
            self.error = "Failed to update kudos: \(error.localizedDescription)"
        }
    }

    func loadKudosForWorkouts() async {
        guard let kudosService else { return }

        // Get workout IDs from feed
        let workoutIds = feedItems
            .filter { $0.type == .workout }
            .map(\.id)

        guard !workoutIds.isEmpty else { return }

        do {
            let kudosSummaries = try await kudosService.getKudosSummaries(for: workoutIds)

            // Update feed items with kudos data
            for (index, item) in feedItems.enumerated() {
                if let summary = kudosSummaries[item.id] {
                    feedItems[index].kudosSummary = summary
                }
            }
        } catch {
            print("Failed to load kudos: \(error)")
        }
    }
}

// MARK: - Legacy Mock Protocol (kept for compatibility)

// Note: ActivityFeedServicing and ActivityFeedItem are now defined in ActivityFeedService.swift
