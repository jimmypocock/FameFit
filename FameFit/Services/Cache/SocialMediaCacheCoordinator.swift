//
//  SocialMediaCacheCoordinator.swift
//  FameFit
//
//  Master coordinator that orchestrates all caching strategies for social media features
//  Implements Instagram/Twitter-level caching patterns and data freshness strategies
//

import Foundation
import Combine
import UIKit

// MARK: - Cache Coordinator Implementation

// MARK: - Cache Health Report

struct CacheHealthReport {
    let hitRate: Double
    let memoryUsage: Int64
    let diskUsage: Int64
    let expiredEntries: Int
    let mostActiveFeeds: [(String, Int)]
    let recommendedActions: [String]
}

// MARK: - Social Media Cache Coordinator

@MainActor
final class SocialMediaCacheCoordinator: ObservableObject, SocialMediaCacheCoordinatorProtocol {
    
    // MARK: - Dependencies
    
    private let cacheManager: CacheProtocol
    private let socialFeedCache: SocialFeedCache
    private let smartRefreshManager: SmartRefreshManager
    private let socialDataCache: SocialDataCache
    private let networkMonitor = NetworkMonitor.shared
    
    // Service dependencies (injected)
    private let activityFeedService: ActivityFeedProtocol
    private let userProfileService: UserProfileProtocol
    private let socialFollowingService: SocialFollowingProtocol
    
    // MARK: - State
    
    @Published private(set) var cacheStatus: CacheHealthReport?
    @Published private(set) var isOptimizing = false
    
    private var cancellables = Set<AnyCancellable>()
    private var currentUserID: String?
    
    // MARK: - Configuration
    
    private struct Config {
        static let maxFeedPages = 5
        static let profileCacheSize = 1000
        static let feedCacheSize = 2000
        static let optimalCacheUsage: Int64 = 100 * 1024 * 1024 // 100MB
    }
    
    // MARK: - Initialization
    
    init(
        cacheManager: CacheProtocol,
        socialFeedCache: SocialFeedCache,
        smartRefreshManager: SmartRefreshManager,
        socialDataCache: SocialDataCache,
        activityFeedService: ActivityFeedProtocol,
        userProfileService: UserProfileProtocol,
        socialFollowingService: SocialFollowingProtocol
    ) {
        self.cacheManager = cacheManager
        self.socialFeedCache = socialFeedCache
        self.smartRefreshManager = smartRefreshManager
        self.socialDataCache = socialDataCache
        self.activityFeedService = activityFeedService
        self.userProfileService = userProfileService
        self.socialFollowingService = socialFollowingService
        
        setupCacheCoordination()
    }
    
    // MARK: - Feed Management
    
    func refreshFeed(userID: String, userInitiated: Bool = false) async {
        print("🔄 Refreshing feed for user: \(userID), userInitiated: \(userInitiated)")
        
        smartRefreshManager.requestFeedRefresh(
            feedType: "activity",
            userID: userID,
            page: 0,
            type: [ActivityFeedItem].self,
            userInitiated: userInitiated
        ) {
            // Fetch fresh feed data
            let feedItems = try await self.fetchFeedItems(userID: userID, page: 0)
            
            // Update cache with real-time invalidation
            await self.updateFeedCacheWithInvalidation(
                userID: userID,
                page: 0,
                items: feedItems
            )
            
            return feedItems
        }
        
        // If user-initiated, also refresh profile and social counts
        if userInitiated {
            Task {
                _ = await refreshUserProfile(userID: userID, force: true)
                await refreshSocialCounts(userID: userID)
            }
        }
    }
    
    func loadFeedPage(userID: String, page: Int, userInitiated: Bool = false) async -> [ActivityFeedItem]? {
        print("📄 Loading feed page \(page) for user: \(userID)")
        
        // Try cache first
        let (cachedData, shouldRefresh, cacheStatus) = socialFeedCache.getFeedData(
            feedType: "activity",
            userID: userID,
            page: page,
            type: [ActivityFeedItem].self,
            strategy: userInitiated ? .immediate : .staleWhileRevalidate
        )
        
        // Return cached data if available and fresh enough
        if let data = cachedData, !shouldRefresh || !networkMonitor.isConnected {
            print("📋 Serving cached feed page \(page) - status: \(cacheStatus)")
            
            // Trigger background refresh if stale
            if shouldRefresh && networkMonitor.isConnected {
                Task {
                    await refreshFeedPage(userID: userID, page: page)
                }
            }
            
            return data
        }
        
        // Fetch fresh data
        do {
            let feedItems = try await fetchFeedItems(userID: userID, page: page)
            
            // Update cache
            socialFeedCache.setFeedPage(
                feedType: "activity",
                userID: userID,
                page: page,
                data: feedItems
            )
            
            print("✅ Loaded fresh feed page \(page) with \(feedItems.count) items")
            return feedItems
            
        } catch {
            print("❌ Failed to load feed page \(page): \(error)")
            
            // Return stale cache data if available
            return cachedData
        }
    }
    
    nonisolated func preloadNextFeedPage(userID: String, currentPage: Int) {
        Task { @MainActor in
            guard networkMonitor.shouldPrefetch else { return }
        
        let nextPage = currentPage + 1
        
        // Check if prefetch is needed
        if socialFeedCache.shouldPrefetchNextPage(
            feedType: "activity",
            userID: userID,
            currentPage: currentPage,
            itemsFromBottom: 3 // Trigger when 3 items from bottom
        ) {
            print("📥 Preloading feed page \(nextPage)")
            
            socialFeedCache.prefetchNextPage(
                feedType: "activity",
                userID: userID,
                currentPage: currentPage
            ) { page in
                return try await self.fetchFeedItems(userID: userID, page: page)
            }
        }
        }
    }
    
    // MARK: - Social Data Management
    
    func refreshUserProfile(userID: String, force: Bool = false) async -> UserProfile? {
        // Check cache first if not forcing
        if !force, let cachedProfile = socialDataCache.getProfile(userID: userID) {
            return cachedProfile
        }
        
        return await smartRefreshManager.requestRefresh(
            id: "profile:\(userID)",
            priority: .high,
            userInitiated: force
        ) {
            let profile = try await self.userProfileService.fetchProfile(userID: userID)
            self.socialDataCache.setProfile(profile)
            return profile
        }
    }
    
    func refreshSocialCounts(userID: String) async {
        await withTaskGroup(of: Void.self) { group in
            // Refresh follower count
            group.addTask {
                await self.smartRefreshManager.requestRefresh(
                    id: "followerCount:\(userID)",
                    priority: .medium
                ) {
                    let count = try await self.socialFollowingService.getFollowerCount(for: userID)
                    self.socialDataCache.setFollowerCount(userID: userID, count: count)
                }
            }
            
            // Refresh following count
            group.addTask {
                await self.smartRefreshManager.requestRefresh(
                    id: "followingCount:\(userID)",
                    priority: .medium
                ) {
                    let count = try await self.socialFollowingService.getFollowingCount(for: userID)
                    self.socialDataCache.setFollowingCount(userID: userID, count: count)
                }
            }
        }
    }
    
    nonisolated func handleSocialInteraction(type: SocialInteractionType, userID: String, targetID: String) {
        print("💬 Handling social interaction: \(type) from \(userID) to \(targetID)")
        
        Task { @MainActor in
            switch type {
            case .follow, .unfollow:
                handleFollowInteraction(type: type, followerID: userID, followingID: targetID)
                
            case .like, .unlike:
                handleLikeInteraction(type: type, userID: userID, postID: targetID)
                
            case .comment, .deleteComment:
                handleCommentInteraction(type: type, userID: userID, postID: targetID)
                
            case .share:
                handleShareInteraction(userID: userID, postID: targetID)
                
            case .block, .unblock:
                handleBlockInteraction(type: type, userID: userID, blockedID: targetID)
            }
        }
    }
    
    // MARK: - Lifecycle Management
    
    nonisolated func handleAppLaunch() {
        print("🚀 App launched - initializing cache coordinator")
        
        // Perform initial cache cleanup
        Task { @MainActor in
            optimizeCache()
        }
    }
    
    nonisolated func handleAppBecomeActive() {
        print("📱 App became active - refreshing critical data")
        
        Task { @MainActor in
            guard let userID = currentUserID else { return }
            
            // Refresh most important data
            await refreshFeed(userID: userID, userInitiated: false)
            _ = await refreshUserProfile(userID: userID, force: false)
        }
    }
    
    nonisolated func handleUserLogin(userID: String) {
        print("👤 User logged in: \(userID)")
        
        Task { @MainActor in
            currentUserID = userID
            
            // Pre-warm cache with user's data
            await prewarmUserCache(userID: userID)
        }
    }
    
    nonisolated func handleUserLogout() {
        print("👋 User logged out - clearing user-specific caches")
        
        Task { @MainActor in
            if let userID = currentUserID{
                socialDataCache.invalidateUser(userID)
                socialFeedCache.invalidateOnNewPost(userID: userID)
            }
            
            currentUserID = nil
        }
    }
    
    // MARK: - Cache Health
    
    nonisolated func getCacheHealthReport() -> CacheHealthReport {
        return MainActor.assumeIsolated {
            let stats = cacheManager.statistics
            
            return CacheHealthReport(
                hitRate: stats.hitRate,
                memoryUsage: Int64(stats.totalSize),
                diskUsage: 0, // Would need disk cache implementation
                expiredEntries: 0, // Would need tracking
                mostActiveFeeds: [], // Would need analytics
                recommendedActions: generateRecommendations(stats: stats)
            )
        }
    }
    
    nonisolated func optimizeCache() {
        Task { @MainActor in
            guard !isOptimizing else { return }
            
            isOptimizing = true
        }
        
        Task {
            print("🧹 Starting cache optimization")
            
            // Remove expired entries
            await MainActor.run {
                cacheManager.removeExpired()
            }
            
            // Check memory usage and clean if needed
            let stats = await MainActor.run {
                cacheManager.statistics
            }
            if Int64(stats.totalSize) > Config.optimalCacheUsage {
                await performAggressiveCleanup()
            }
            
            await MainActor.run {
                self.isOptimizing = false
                self.cacheStatus = self.getCacheHealthReport()
            }
            
            print("✨ Cache optimization completed")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupCacheCoordination() {
        // Monitor cache health periodically
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cacheStatus = self?.getCacheHealthReport()
            }
        }
        
        // Listen for background refresh notifications
        NotificationCenter.default.publisher(for: .backgroundRefreshAvailable)
            .sink { [weak self] notification in
                self?.handleBackgroundRefreshFameFitNotification(notification)
            }
            .store(in: &cancellables)
    }
    
    private func fetchFeedItems(userID: String, page: Int) async throws -> [ActivityFeedItem] {
        // This would call the actual feed service
        // For now, return empty array - would be implemented with real service calls
        return []
    }
    
    private func updateFeedCacheWithInvalidation(userID: String, page: Int, items: [ActivityFeedItem]) async {
        // Update the cache
        socialFeedCache.setFeedPage(
            feedType: "activity",
            userID: userID,
            page: page,
            data: items
        )
        
        // If this is page 0 (first page), it might affect other users' feeds
        if page == 0 {
            socialFeedCache.invalidateOnNewPost(userID: userID)
        }
    }
    
    private func refreshFeedPage(userID: String, page: Int) async {
        smartRefreshManager.requestFeedRefresh(
            feedType: "activity",
            userID: userID,
            page: page,
            type: [ActivityFeedItem].self,
            userInitiated: false
        ) {
            return try await self.fetchFeedItems(userID: userID, page: page)
        }
    }
    
    private func handleFollowInteraction(type: SocialInteractionType, followerID: String, followingID: String) {
        // Invalidate relevant caches
        socialFeedCache.invalidateOnFollow(followerID: followerID, followingID: followingID)
        socialDataCache.invalidateFollowAction(follower: followerID, following: followingID)
        
        // Refresh affected data in background
        Task {
            await refreshSocialCounts(userID: followerID)
            await refreshSocialCounts(userID: followingID)
        }
    }
    
    private func handleLikeInteraction(type: SocialInteractionType, userID: String, postID: String) {
        socialFeedCache.invalidateOnInteraction(postID: postID, interactionType: "like")
    }
    
    private func handleCommentInteraction(type: SocialInteractionType, userID: String, postID: String) {
        socialFeedCache.invalidateOnInteraction(postID: postID, interactionType: "comment")
    }
    
    private func handleShareInteraction(userID: String, postID: String) {
        socialFeedCache.invalidateOnInteraction(postID: postID, interactionType: "share")
    }
    
    private func handleBlockInteraction(type: SocialInteractionType, userID: String, blockedID: String) {
        // Block interactions require more aggressive cache invalidation
        socialDataCache.invalidateUser(userID)
        socialDataCache.invalidateUser(blockedID)
    }
    
    private func prewarmUserCache(userID: String) async {
        print("🔥 Pre-warming cache for user: \(userID)")
        
        // Load critical user data
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = await self.refreshUserProfile(userID: userID, force: false)
            }
            
            group.addTask {
                await self.refreshFeed(userID: userID, userInitiated: false)
            }
            
            group.addTask {
                await self.refreshSocialCounts(userID: userID)
            }
        }
    }
    
    private func performAggressiveCleanup() async {
        print("🧽 Performing aggressive cache cleanup")
        
        await MainActor.run {
            // Remove expired entries
            cacheManager.removeExpired()
            
            // Remove low-priority cached data
            cacheManager.invalidate(matching: "search:")
            cacheManager.invalidate(matching: "prefetch:")
            
            // Keep only recent feed pages
            for page in 3...10 {
                cacheManager.invalidate(matching: "activity:.*:page:\(page)")
            }
        }
    }
    
    private func generateRecommendations(stats: CacheStatistics) -> [String] {
        var recommendations: [String] = []
        
        if stats.hitRate < 0.7 {
            recommendations.append("Consider increasing cache TTL for better hit rates")
        }
        
        if stats.evictionCount > 100 {
            recommendations.append("High eviction count - consider increasing cache size")
        }
        
        if !NetworkMonitor.shared.isConnected {
            recommendations.append("Offline mode - serving cached data only")
        }
        
        return recommendations
    }
    
    private func handleBackgroundRefreshFameFitNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let _ = userInfo["feedType"] as? String,
              let userID = userInfo["userID"] as? String else { return }
        
        Task {
            await refreshFeedPage(userID: userID, page: 0)
        }
    }
}

// MARK: - Extensions

extension SmartRefreshManager {
    func requestRefresh<T>(
        id: String,
        priority: RefreshPriority,
        userInitiated: Bool = false,
        operation: @escaping () async throws -> T
    ) async -> T? {
        var result: T?
        
        await withCheckedContinuation { continuation in
            requestRefresh(id: id, priority: priority, userInitiated: userInitiated) {
                do {
                    result = try await operation()
                } catch {
                    print("❌ Refresh operation failed: \(error)")
                }
                continuation.resume()
            }
        }
        
        return result
    }
}