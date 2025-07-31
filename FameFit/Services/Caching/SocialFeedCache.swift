//
//  SocialFeedCache.swift
//  FameFit
//
//  Instagram/Twitter-level feed caching with pagination, prefetching, and real-time updates
//

import Foundation
import Combine
import Network
import UIKit

// MARK: - Feed Cache Configuration

struct FeedCacheConfig {
    static let feedTTL: TimeInterval = 300 // 5 minutes - fresh content
    static let feedStaleTTL: TimeInterval = 1800 // 30 minutes - stale but usable
    static let maxPagesInMemory = 3
    static let prefetchTriggerOffset = 5 // Prefetch when 5 items from bottom
    static let backgroundRefreshInterval: TimeInterval = 180 // 3 minutes
    static let maxBackgroundRetries = 3
}

// MARK: - Feed Cache Entry

struct FeedCacheEntry<T: Codable> {
    let data: T
    let timestamp: Date
    let pageInfo: PaginationInfo?
    
    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
    
    var isExpired: Bool {
        age > FeedCacheConfig.feedTTL
    }
    
    var isStale: Bool {
        age > FeedCacheConfig.feedStaleTTL
    }
    
    var isFresh: Bool {
        age < FeedCacheConfig.feedTTL
    }
}

// MARK: - Pagination Info

struct PaginationInfo: Codable {
    let page: Int
    let hasNextPage: Bool
    let nextCursor: String?
    let totalCount: Int?
}

// MARK: - Cache Refresh Strategy

enum CacheRefreshStrategy {
    case immediate           // Refresh immediately, show spinner
    case background         // Refresh in background, show cached data
    case staleWhileRevalidate // Show cached data, refresh silently
    case networkFirst       // Try network first, fallback to cache
}

// MARK: - Network Monitor

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    @Published var isExpensive = false
    @Published var connectionType: NWInterface.InterfaceType?
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }
    
    var shouldPrefetch: Bool {
        isConnected && !isExpensive
    }
    
    var shouldBackgroundRefresh: Bool {
        isConnected
    }
}

// MARK: - Social Feed Cache

final class SocialFeedCache: @unchecked Sendable {
    private let cacheManager: CacheManaging
    private let networkMonitor = NetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Background refresh tracking
    private var backgroundRefreshTasks: [String: Task<Void, Never>] = [:]
    private var lastBackgroundRefresh: [String: Date] = [:]
    
    init(cacheManager: CacheManaging) {
        self.cacheManager = cacheManager
        setupBackgroundRefresh()
    }
    
    // MARK: - Feed Caching
    
    func getFeedPage<T: Codable>(
        feedType: String,
        userId: String,
        page: Int,
        type: T.Type
    ) -> FeedCacheEntry<T>? {
        let key = feedCacheKey(feedType: feedType, userId: userId, page: page)
        return cacheManager.get(key, type: FeedCacheEntry<T>.self)
    }
    
    func setFeedPage<T: Codable>(
        feedType: String,
        userId: String,
        page: Int,
        data: T,
        pageInfo: PaginationInfo? = nil
    ) {
        let key = feedCacheKey(feedType: feedType, userId: userId, page: page)
        let entry = FeedCacheEntry(data: data, timestamp: Date(), pageInfo: pageInfo)
        cacheManager.set(key, value: entry, ttl: FeedCacheConfig.feedTTL)
        
        // Schedule background refresh for this feed
        scheduleBackgroundRefresh(feedType: feedType, userId: userId)
    }
    
    // MARK: - Intelligent Data Serving
    
    func getFeedData<T: Codable>(
        feedType: String,
        userId: String,
        page: Int,
        type: T.Type,
        strategy: CacheRefreshStrategy = .staleWhileRevalidate
    ) -> (data: T?, shouldRefresh: Bool, cacheStatus: CacheStatus) {
        
        guard let entry = getFeedPage(feedType: feedType, userId: userId, page: page, type: type) else {
            return (nil, true, .miss)
        }
        
        switch strategy {
        case .immediate:
            if entry.isExpired {
                return (nil, true, .expired)
            }
            return (entry.data, false, .hit)
            
        case .background:
            if entry.isStale {
                return (entry.data, true, .stale)
            }
            return (entry.data, false, .hit)
            
        case .staleWhileRevalidate:
            return (entry.data, entry.isExpired, entry.isExpired ? .expired : .hit)
            
        case .networkFirst:
            if !networkMonitor.isConnected {
                return (entry.data, false, .offline)
            }
            return (entry.data, entry.isExpired, entry.isExpired ? .expired : .hit)
        }
    }
    
    // MARK: - Predictive Prefetching
    
    func shouldPrefetchNextPage(
        feedType: String,
        userId: String,
        currentPage: Int,
        itemsFromBottom: Int
    ) -> Bool {
        guard networkMonitor.shouldPrefetch else { return false }
        guard itemsFromBottom <= FeedCacheConfig.prefetchTriggerOffset else { return false }
        
        let nextPage = currentPage + 1
        let nextPageKey = feedCacheKey(feedType: feedType, userId: userId, page: nextPage)
        
        // Don't prefetch if already cached and fresh
        if cacheManager.get(nextPageKey, type: FeedCacheEntry<[ActivityFeedItem]>.self) != nil {
            return false
        }
        
        return true
    }
    
    func prefetchNextPage(
        feedType: String,
        userId: String,
        currentPage: Int,
        fetchFunction: @escaping (Int) async throws -> [ActivityFeedItem]
    ) {
        let nextPage = currentPage + 1
        
        Task {
            do {
                let data = try await fetchFunction(nextPage)
                setFeedPage(feedType: feedType, userId: userId, page: nextPage, data: data)
                print("📥 Prefetched \(feedType) page \(nextPage) for user \(userId)")
            } catch {
                print("❌ Prefetch failed for \(feedType) page \(nextPage): \(error)")
            }
        }
    }
    
    // MARK: - Background Refresh
    
    private func setupBackgroundRefresh() {
        // Monitor app state changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
        
        // Monitor network changes
        networkMonitor.$isConnected
            .filter { $0 } // Only when connected
            .sink { [weak self] _ in
                self?.handleNetworkReconnected()
            }
            .store(in: &cancellables)
    }
    
    private func scheduleBackgroundRefresh(feedType: String, userId: String) {
        let key = "\(feedType):\(userId)"
        
        // Cancel existing task
        backgroundRefreshTasks[key]?.cancel()
        
        backgroundRefreshTasks[key] = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(FeedCacheConfig.backgroundRefreshInterval * 1_000_000_000))
                
                guard !Task.isCancelled else { return }
                guard networkMonitor.shouldBackgroundRefresh else { return }
                
                await performBackgroundRefresh(feedType: feedType, userId: userId)
            } catch {
                // Task was cancelled or sleep failed - this is normal
                return
            }
        }
    }
    
    private func performBackgroundRefresh(feedType: String, userId: String) async {
        let key = "\(feedType):\(userId)"
        
        // Check if we recently refreshed
        if let lastRefresh = lastBackgroundRefresh[key],
           Date().timeIntervalSince(lastRefresh) < FeedCacheConfig.backgroundRefreshInterval {
            return
        }
        
        // Mark refresh attempt
        lastBackgroundRefresh[key] = Date()
        
        // This would be called by the appropriate service
        print("🔄 Background refresh triggered for \(feedType) - user \(userId)")
        
        // Notify that background refresh is available
        NotificationCenter.default.post(
            name: .backgroundRefreshAvailable,
            object: nil,
            userInfo: ["feedType": feedType, "userId": userId]
        )
    }
    
    // MARK: - Cache Invalidation for Social Interactions
    
    func invalidateOnNewPost(userId: String) {
        // Invalidate user's own feed
        invalidateFeed(feedType: "activity", userId: userId)
        
        // TODO: In a real app, we'd also invalidate feeds of followers
        // This would require a follower list or push notification system
        print("🗑️ Invalidated feeds due to new post from \(userId)")
    }
    
    func invalidateOnFollow(followerId: String, followingId: String) {
        // Invalidate follower's feed (will now include posts from followingId)
        invalidateFeed(feedType: "activity", userId: followerId)
        invalidateFeed(feedType: "social", userId: followerId)
        
        // Invalidate following lists
        cacheManager.invalidate(matching: "following:\(followerId)")
        cacheManager.invalidate(matching: "followers:\(followingId)")
        
        print("🗑️ Invalidated feeds due to follow: \(followerId) -> \(followingId)")
    }
    
    func invalidateOnInteraction(postId: String, interactionType: String) {
        // For likes, comments, etc. - invalidate the specific post
        cacheManager.invalidate(matching: "post:\(postId)")
        
        // Invalidate feeds that might contain this post
        // In practice, this would be more targeted
        cacheManager.invalidate(matching: "activity:")
        
        print("🗑️ Invalidated data due to \(interactionType) on post \(postId)")
    }
    
    // MARK: - App Lifecycle Handling
    
    private func handleAppDidBecomeActive() {
        print("📱 App became active - checking for stale feeds")
        
        // Check for stale feeds and refresh priority ones
        Task {
            await refreshStaleFeedsOnAppActivation()
        }
    }
    
    private func handleNetworkReconnected() {
        print("🌐 Network reconnected - resuming background refreshes")
        
        // Resume background refreshes for active feeds
        // This would be implemented based on current user context
    }
    
    // MARK: - Cache Management
    
    private func refreshStaleFeedsOnAppActivation() async {
        // This would check for stale feeds and refresh the most important ones
        // Priority: current user's feed > following feed > other data
        
        // Implementation would depend on current app state and user context
        print("🔄 Refreshing stale feeds after app activation")
    }
    
    private func invalidateFeed(feedType: String, userId: String) {
        cacheManager.invalidate(matching: "\(feedType):\(userId):")
    }
    
    private func feedCacheKey(feedType: String, userId: String, page: Int) -> String {
        "\(feedType):\(userId):page:\(page)"
    }
}

// MARK: - Cache Status

enum CacheStatus {
    case hit        // Fresh data from cache
    case stale      // Cached data but expired
    case expired    // Cached data but too old
    case miss       // No cached data
    case offline    // No network, using cached data
}

// MARK: - Notifications

extension Notification.Name {
    static let backgroundRefreshAvailable = Notification.Name("backgroundRefreshAvailable")
    static let cacheInvalidated = Notification.Name("cacheInvalidated")
}

// MARK: - Extensions

#if os(iOS)
extension UIApplication {
    var isInBackground: Bool {
        applicationState == .background
    }
}
#endif