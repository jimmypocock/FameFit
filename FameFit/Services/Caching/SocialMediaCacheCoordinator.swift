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

// MARK: - Cache Coordinator Protocol

protocol SocialMediaCacheCoordinating {
    // Feed management
    func refreshFeed(userId: String, userInitiated: Bool) async
    func loadFeedPage(userId: String, page: Int, userInitiated: Bool) async -> [FeedItem]?
    func preloadNextFeedPage(userId: String, currentPage: Int)
    
    // Social data management  
    func refreshUserProfile(userId: String, force: Bool) async -> UserProfile?
    func refreshSocialCounts(userId: String) async
    func handleSocialInteraction(type: SocialInteractionType, userId: String, targetId: String)
    
    // Lifecycle management
    func handleAppLaunch()
    func handleAppBecomeActive()
    func handleUserLogin(userId: String)
    func handleUserLogout()
    
    // Cache health
    func getCacheHealthReport() -> CacheHealthReport
    func optimizeCache()
}

// MARK: - Social Interaction Types

enum SocialInteractionType {
    case follow
    case unfollow
    case like
    case unlike
    case comment
    case deleteComment
    case share
    case block
    case unblock
}

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
final class SocialMediaCacheCoordinator: ObservableObject, SocialMediaCacheCoordinating {
    
    // MARK: - Dependencies
    
    private let cacheManager: CacheManaging
    private let socialFeedCache: SocialFeedCache
    private let smartRefreshManager: SmartRefreshManager
    private let socialDataCache: SocialDataCache
    private let networkMonitor = NetworkMonitor.shared
    
    // Service dependencies (injected)
    private let activityFeedService: ActivityFeedServicing
    private let userProfileService: UserProfileServicing
    private let socialFollowingService: SocialFollowingServicing
    
    // MARK: - State
    
    @Published private(set) var cacheStatus: CacheHealthReport?
    @Published private(set) var isOptimizing = false
    
    private var cancellables = Set<AnyCancellable>()
    private var currentUserId: String?
    
    // MARK: - Configuration
    
    private struct Config {
        static let maxFeedPages = 5
        static let profileCacheSize = 1000
        static let feedCacheSize = 2000
        static let optimalCacheUsage: Int64 = 100 * 1024 * 1024 // 100MB
    }
    
    // MARK: - Initialization
    
    init(
        cacheManager: CacheManaging,
        socialFeedCache: SocialFeedCache,
        smartRefreshManager: SmartRefreshManager,
        socialDataCache: SocialDataCache,
        activityFeedService: ActivityFeedServicing,
        userProfileService: UserProfileServicing,
        socialFollowingService: SocialFollowingServicing
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
    
    func refreshFeed(userId: String, userInitiated: Bool = false) async {
        print("🔄 Refreshing feed for user: \(userId), userInitiated: \(userInitiated)")
        
        smartRefreshManager.requestFeedRefresh(
            feedType: "activity",
            userId: userId,
            page: 0,
            type: [FeedItem].self,
            userInitiated: userInitiated
        ) {
            // Fetch fresh feed data
            let feedItems = try await self.fetchFeedItems(userId: userId, page: 0)
            
            // Update cache with real-time invalidation
            await self.updateFeedCacheWithInvalidation(
                userId: userId,
                page: 0,
                items: feedItems
            )
            
            return feedItems
        }
        
        // If user-initiated, also refresh profile and social counts
        if userInitiated {
            Task {
                _ = await refreshUserProfile(userId: userId, force: true)
                await refreshSocialCounts(userId: userId)
            }
        }
    }
    
    func loadFeedPage(userId: String, page: Int, userInitiated: Bool = false) async -> [FeedItem]? {
        print("📄 Loading feed page \(page) for user: \(userId)")
        
        // Try cache first
        let (cachedData, shouldRefresh, cacheStatus) = socialFeedCache.getFeedData(
            feedType: "activity",
            userId: userId,
            page: page,
            type: [FeedItem].self,
            strategy: userInitiated ? .immediate : .staleWhileRevalidate
        )
        
        // Return cached data if available and fresh enough
        if let data = cachedData, !shouldRefresh || !networkMonitor.isConnected {
            print("📋 Serving cached feed page \(page) - status: \(cacheStatus)")
            
            // Trigger background refresh if stale
            if shouldRefresh && networkMonitor.isConnected {
                Task {
                    await refreshFeedPage(userId: userId, page: page)
                }
            }
            
            return data
        }
        
        // Fetch fresh data
        do {
            let feedItems = try await fetchFeedItems(userId: userId, page: page)
            
            // Update cache
            socialFeedCache.setFeedPage(
                feedType: "activity",
                userId: userId,
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
    
    nonisolated func preloadNextFeedPage(userId: String, currentPage: Int) {
        Task { @MainActor in
            guard networkMonitor.shouldPrefetch else { return }
        
        let nextPage = currentPage + 1
        
        // Check if prefetch is needed
        if socialFeedCache.shouldPrefetchNextPage(
            feedType: "activity",
            userId: userId,
            currentPage: currentPage,
            itemsFromBottom: 3 // Trigger when 3 items from bottom
        ) {
            print("📥 Preloading feed page \(nextPage)")
            
            socialFeedCache.prefetchNextPage(
                feedType: "activity",
                userId: userId,
                currentPage: currentPage
            ) { page in
                return try await self.fetchFeedItems(userId: userId, page: page)
            }
        }
        }
    }
    
    // MARK: - Social Data Management
    
    func refreshUserProfile(userId: String, force: Bool = false) async -> UserProfile? {
        // Check cache first if not forcing
        if !force, let cachedProfile = socialDataCache.getProfile(userId: userId) {
            return cachedProfile
        }
        
        return await smartRefreshManager.requestRefresh(
            id: "profile:\(userId)",
            priority: .high,
            userInitiated: force
        ) {
            let profile = try await self.userProfileService.fetchProfile(userId: userId)
            self.socialDataCache.setProfile(profile)
            return profile
        }
    }
    
    func refreshSocialCounts(userId: String) async {
        await withTaskGroup(of: Void.self) { group in
            // Refresh follower count
            group.addTask {
                await self.smartRefreshManager.requestRefresh(
                    id: "followerCount:\(userId)",
                    priority: .medium
                ) {
                    let count = try await self.socialFollowingService.getFollowerCount(for: userId)
                    self.socialDataCache.setFollowerCount(userId: userId, count: count)
                }
            }
            
            // Refresh following count
            group.addTask {
                await self.smartRefreshManager.requestRefresh(
                    id: "followingCount:\(userId)",
                    priority: .medium
                ) {
                    let count = try await self.socialFollowingService.getFollowingCount(for: userId)
                    self.socialDataCache.setFollowingCount(userId: userId, count: count)
                }
            }
        }
    }
    
    nonisolated func handleSocialInteraction(type: SocialInteractionType, userId: String, targetId: String) {
        print("💬 Handling social interaction: \(type) from \(userId) to \(targetId)")
        
        Task { @MainActor in
            switch type {
            case .follow, .unfollow:
                handleFollowInteraction(type: type, followerId: userId, followingId: targetId)
                
            case .like, .unlike:
                handleLikeInteraction(type: type, userId: userId, postId: targetId)
                
            case .comment, .deleteComment:
                handleCommentInteraction(type: type, userId: userId, postId: targetId)
                
            case .share:
                handleShareInteraction(userId: userId, postId: targetId)
                
            case .block, .unblock:
                handleBlockInteraction(type: type, userId: userId, blockedId: targetId)
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
            guard let userId = currentUserId else { return }
            
            // Refresh most important data
            await refreshFeed(userId: userId, userInitiated: false)
            _ = await refreshUserProfile(userId: userId, force: false)
        }
    }
    
    nonisolated func handleUserLogin(userId: String) {
        print("👤 User logged in: \(userId)")
        
        Task { @MainActor in
            currentUserId = userId
            
            // Pre-warm cache with user's data
            await prewarmUserCache(userId: userId)
        }
    }
    
    nonisolated func handleUserLogout() {
        print("👋 User logged out - clearing user-specific caches")
        
        Task { @MainActor in
            if let userId = currentUserId {
                socialDataCache.invalidateUser(userId)
                socialFeedCache.invalidateOnNewPost(userId: userId)
            }
            
            currentUserId = nil
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
    
    private func fetchFeedItems(userId: String, page: Int) async throws -> [FeedItem] {
        // This would call the actual feed service
        // For now, return empty array - would be implemented with real service calls
        return []
    }
    
    private func updateFeedCacheWithInvalidation(userId: String, page: Int, items: [FeedItem]) async {
        // Update the cache
        socialFeedCache.setFeedPage(
            feedType: "activity",
            userId: userId,
            page: page,
            data: items
        )
        
        // If this is page 0 (first page), it might affect other users' feeds
        if page == 0 {
            socialFeedCache.invalidateOnNewPost(userId: userId)
        }
    }
    
    private func refreshFeedPage(userId: String, page: Int) async {
        smartRefreshManager.requestFeedRefresh(
            feedType: "activity",
            userId: userId,
            page: page,
            type: [FeedItem].self,
            userInitiated: false
        ) {
            return try await self.fetchFeedItems(userId: userId, page: page)
        }
    }
    
    private func handleFollowInteraction(type: SocialInteractionType, followerId: String, followingId: String) {
        // Invalidate relevant caches
        socialFeedCache.invalidateOnFollow(followerId: followerId, followingId: followingId)
        socialDataCache.invalidateFollowAction(follower: followerId, following: followingId)
        
        // Refresh affected data in background
        Task {
            await refreshSocialCounts(userId: followerId)
            await refreshSocialCounts(userId: followingId)
        }
    }
    
    private func handleLikeInteraction(type: SocialInteractionType, userId: String, postId: String) {
        socialFeedCache.invalidateOnInteraction(postId: postId, interactionType: "like")
    }
    
    private func handleCommentInteraction(type: SocialInteractionType, userId: String, postId: String) {
        socialFeedCache.invalidateOnInteraction(postId: postId, interactionType: "comment")
    }
    
    private func handleShareInteraction(userId: String, postId: String) {
        socialFeedCache.invalidateOnInteraction(postId: postId, interactionType: "share")
    }
    
    private func handleBlockInteraction(type: SocialInteractionType, userId: String, blockedId: String) {
        // Block interactions require more aggressive cache invalidation
        socialDataCache.invalidateUser(userId)
        socialDataCache.invalidateUser(blockedId)
    }
    
    private func prewarmUserCache(userId: String) async {
        print("🔥 Pre-warming cache for user: \(userId)")
        
        // Load critical user data
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = await self.refreshUserProfile(userId: userId, force: false)
            }
            
            group.addTask {
                await self.refreshFeed(userId: userId, userInitiated: false)
            }
            
            group.addTask {
                await self.refreshSocialCounts(userId: userId)
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
    
    private func handleBackgroundRefreshFameFitNotification(_ notification: FameFitNotification) {
        guard let userInfo = notification.userInfo,
              let _ = userInfo["feedType"] as? String,
              let userId = userInfo["userId"] as? String else { return }
        
        Task {
            await refreshFeedPage(userId: userId, page: 0)
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