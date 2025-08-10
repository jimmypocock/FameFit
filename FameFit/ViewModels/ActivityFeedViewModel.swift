//
//  ActivityFeedViewModel.swift
//  FameFit
//
//  View model for activity feed with content filtering
//

import CloudKit
import Combine
import Foundation

@MainActor
final class ActivityFeedViewModel: ObservableObject {
    @Published var feedItems: [ActivityFeedItem] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var filters = ActivityFeedFilters()
    @Published var hasMoreItems = true

    private var socialService: SocialFollowingProtocol?
    private var profileService: UserProfileProtocol?
    private var activityFeedService: ActivityFeedProtocol?
    private var kudosService: WorkoutKudosProtocol?
    private var commentsService: ActivityFeedCommentsProtocol?
    private var currentUserID = ""
    private var followingUsers: Set<String> = []
    private var lastFetchedDate: Date?
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()
    private var isLoadingInitial = false // Prevent duplicate initial loads
    
    // Cache key for persisting feed state
    private let feedCacheKey = "cached_activity_feed_items"
    private let feedCacheTimestampKey = "cached_activity_feed_timestamp"
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes

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
        socialService: SocialFollowingProtocol,
        profileService: UserProfileProtocol,
        activityFeedService: ActivityFeedProtocol,
        kudosService: WorkoutKudosProtocol,
        commentsService: ActivityFeedCommentsProtocol,
        currentUserID: String
    ) {
        self.socialService = socialService
        self.profileService = profileService
        self.kudosService = kudosService
        self.commentsService = commentsService
        self.activityFeedService = activityFeedService
        self.currentUserID = currentUserID

        // Subscribe to kudos updates
        setupKudosListener()

        // Start real-time updates
        startRealTimeUpdates()
    }

    func loadInitialFeed() async {
        // Prevent multiple simultaneous initial loads
        guard !isLoadingInitial else {
            FameFitLogger.info("⏭️ Initial feed load already in progress, skipping", category: FameFitLogger.social)
            return
        }
        
        isLoadingInitial = true
        isLoading = true
        error = nil
        
        defer {
            isLoadingInitial = false
            isLoading = false
        }
        
        // Try to load cached feed first for instant display
        if loadCachedFeed() {
            // We have cached items, show them immediately
            // But still fetch fresh data in the background
            Task {
                await loadFreshFeed()
            }
        } else {
            // No cache, load fresh
            feedItems = []
            await loadFreshFeed()
        }
    }
    
    private func loadFreshFeed() async {
        do {
            // First, get the list of users we're following
            if let socialService {
                let following = try await socialService.getFollowing(for: currentUserID, limit: 1_000)
                followingUsers = Set(following.map(\.id))
                FameFitLogger.info("📋 Found \(following.count) following users", category: FameFitLogger.social)
            } else {
                FameFitLogger.warning("⚠️ No social service available - will show only own activities", category: FameFitLogger.social)
                followingUsers = []
            }

            // ALWAYS add self to see own activities, even with no social service
            if !currentUserID.isEmpty {
                followingUsers.insert(currentUserID)
            }
            FameFitLogger.info("📋 Loading feed for \(followingUsers.count) users (including self)", category: FameFitLogger.social)

            // Load feed items even if only showing own activities
            if !followingUsers.isEmpty {
                await loadFeedItems()
            } else {
                FameFitLogger.warning("⚠️ No users to load feed for (not even current user)", category: FameFitLogger.social)
            }
        } catch {
            FameFitLogger.error("❌ Failed to load feed: \(error)", category: FameFitLogger.social)
            self.error = "Failed to load feed"
        }
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
        // More intelligent polling strategy - start frequent, then slow down
        let intervals: [TimeInterval] = [10, 20, 30, 60] // Start with 10s, gradually increase to 60s
        var currentIntervalIndex = 0
        
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .scan(0) { count, _ in count + 1 }
            .sink { [weak self] secondsElapsed in
                guard let self = self else { return }
                
                // Determine current interval based on how long app has been running
                if secondsElapsed < 60 {
                    currentIntervalIndex = 0 // 10s intervals for first minute
                } else if secondsElapsed < 180 {
                    currentIntervalIndex = 1 // 20s intervals for next 2 minutes
                } else if secondsElapsed < 600 {
                    currentIntervalIndex = 2 // 30s intervals for next 7 minutes
                } else {
                    currentIntervalIndex = 3 // 60s intervals after 10 minutes
                }
                
                let interval = intervals[min(currentIntervalIndex, intervals.count - 1)]
                
                // Check if it's time to poll based on current interval
                if secondsElapsed % Int(interval) == 0 {
                    Task { [weak self] in
                        await self?.checkForNewItems()
                    }
                }
            }
            .store(in: &cancellables)
    }

    func checkForNewItems() async {
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

        // Remove duplicates - only add items that aren't already in the feed
        let existingIDs = Set(feedItems.map(\.id))
        let newItems = filteredItems.filter { !existingIDs.contains($0.id) }
        
        guard !newItems.isEmpty else { return }

        // Sort by timestamp (newest first)
        let sortedItems = newItems.sorted { $0.timestamp > $1.timestamp }

        // Insert at the beginning of the feed
        feedItems.insert(contentsOf: sortedItems, at: 0)

        // Load kudos for any new workout items
        await loadKudosForNewItems(sortedItems)
        
        // Update cache with new items
        saveFeedToCache()
    }

    private func loadKudosForNewItems(_ items: [ActivityFeedItem]) async {
        guard let kudosService else { return }

        let workoutIDs = items
            .filter { $0.type == .workout }
            .map(\.id)

        guard !workoutIDs.isEmpty else { return }

        do {
            let kudosSummaries = try await kudosService.getKudosSummaries(for: workoutIDs)

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

    // MARK: - Cache Management
    
    private func loadCachedFeed() -> Bool {
        // Check if we have cached data that's not expired
        guard let cacheTimestamp = UserDefaults.standard.object(forKey: feedCacheTimestampKey) as? Date,
              Date().timeIntervalSince(cacheTimestamp) < cacheExpirationTime,
              let cachedData = UserDefaults.standard.data(forKey: feedCacheKey),
              let cachedItems = try? JSONDecoder().decode([ActivityFeedItem].self, from: cachedData) else {
            return false
        }
        
        feedItems = cachedItems
        FameFitLogger.info("📦 Loaded \(cachedItems.count) cached feed items", category: FameFitLogger.social)
        return true
    }
    
    private func saveFeedToCache() {
        // Only cache the first page of items
        let itemsToCache = Array(feedItems.prefix(pageSize))
        
        if let data = try? JSONEncoder().encode(itemsToCache) {
            UserDefaults.standard.set(data, forKey: feedCacheKey)
            UserDefaults.standard.set(Date(), forKey: feedCacheTimestampKey)
            FameFitLogger.info("💾 Cached \(itemsToCache.count) feed items", category: FameFitLogger.social)
        }
    }
    
    private func clearFeedCache() {
        UserDefaults.standard.removeObject(forKey: feedCacheKey)
        UserDefaults.standard.removeObject(forKey: feedCacheTimestampKey)
    }

    // MARK: - Private Methods

    private func loadFeedItems() async {
        guard let activityFeedService else {
            FameFitLogger.warning("⚠️ No activity feed service available - using mock data", category: FameFitLogger.social)
            let mockItems = await createMockFeedItems()
            await processFeedItems(mockItems)
            return
        }

        do {
            FameFitLogger.info("🔍 Fetching feed for users: \(followingUsers)", category: FameFitLogger.social)
            let activityItems = try await activityFeedService.fetchFeed(
                for: followingUsers,
                since: lastFetchedDate,
                limit: pageSize
            )
            
            FameFitLogger.info("📥 Received \(activityItems.count) items from CloudKit", category: FameFitLogger.social)

            // Convert ActivityFeedRecord to ActivityFeedItem
            let feedItems = await convertActivityItemsToFeedItems(activityItems)
            FameFitLogger.info("✅ Converted to \(feedItems.count) feed items", category: FameFitLogger.social)
            await processFeedItems(feedItems)
        } catch {
            FameFitLogger.error("❌ Failed to fetch feed: \(error)", category: FameFitLogger.social)
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

        // Remove duplicates - only add items that aren't already in the feed
        let existingIDs = Set(feedItems.map(\.id))
        let newItems = sortedItems.filter { !existingIDs.contains($0.id) }
        
        // Append only new items
        feedItems.append(contentsOf: newItems)

        // Load kudos for workout items
        await loadKudosForWorkouts()

        // Update pagination state
        if sortedItems.count < pageSize {
            hasMoreItems = false
        }
        lastFetchedDate = sortedItems.last?.timestamp
        
        // Save to cache for quick loading next time
        saveFeedToCache()
    }

    private func convertActivityItemsToFeedItems(_ activityItems: [ActivityFeedRecord]) async -> [ActivityFeedItem] {
        var feedItems: [ActivityFeedItem] = []

        for activityItem in activityItems {
            // Get user profile for the activity
            let userProfile = try? await profileService?.fetchProfile(userID: activityItem.userID)

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
                username: activityItem.username,  // Use username directly from record
                userProfile: userProfile,
                type: feedItemType,
                timestamp: activityItem.creationDate,
                content: content,
                workoutID: feedItemType == .workout ? activityItem.id : nil,
                kudosCount: 0,
                commentCount: 0,
                hasKudoed: false
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
        if let profile = try? await profileService?.fetchProfile(userID: "mock-user-1") {
            items.append(ActivityFeedItem(
                id: UUID().uuidString,
                userID: profile.id,
                username: profile.username,
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
                workoutID: UUID().uuidString,
                kudosCount: 5,
                commentCount: 2,
                hasKudoed: false
            ))

            items.append(ActivityFeedItem(
                id: UUID().uuidString,
                userID: profile.id,
                username: profile.username,
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
                workoutID: nil,
                kudosCount: 0,
                commentCount: 0,
                hasKudoed: false
            ))
        }

        // Mock level up
        if let profile2 = try? await profileService?.fetchProfile(userID: "mock-user-2") {
            items.append(ActivityFeedItem(
                id: UUID().uuidString,
                userID: profile2.id,
                username: profile2.username,
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
                workoutID: nil,
                kudosCount: 0,
                commentCount: 0,
                hasKudoed: false
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
        guard let index = feedItems.firstIndex(where: { $0.id == update.workoutID }) else {
            return
        }

        // Update the kudos count
        var updatedItem = feedItems[index]
        if var kudosSummary = updatedItem.kudosSummary {
            kudosSummary = WorkoutKudosSummary(
                workoutID: kudosSummary.workoutID,
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
            _ = try await kudosService.toggleKudos(for: item.id, ownerID: item.userID)
        } catch {
            self.error = "Failed to update kudos: \(error.localizedDescription)"
        }
    }

    func loadKudosForWorkouts() async {
        guard let kudosService else { return }

        // Get workout IDs from feed
        let workoutIDs = feedItems
            .filter { $0.type == .workout }
            .map(\.id)

        guard !workoutIDs.isEmpty else { return }

        do {
            let kudosSummaries = try await kudosService.getKudosSummaries(for: workoutIDs)

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

// Note: ActivityFeedProtocol and ActivityFeedItem are now defined in ActivityFeedService.swift
