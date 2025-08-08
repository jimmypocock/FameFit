//
//  SmartRefreshManager.swift
//  FameFit
//
//  Intelligent refresh management that prevents over-fetching while ensuring fresh data
//  Implements patterns similar to Instagram, Twitter, and other social media apps
//

import Foundation
import Combine
import UIKit

// MARK: - Refresh Priority

enum RefreshPriority: Int, CaseIterable {
    case critical = 0     // User's own profile, current feed page
    case high = 1        // Visible content, recent interactions
    case medium = 2      // Next page prefetch, background updates
    case low = 3         // Analytics, non-visible content
    
    var debounceInterval: TimeInterval {
        switch self {
        case .critical: return 0.1
        case .high: return 0.5
        case .medium: return 2.0
        case .low: return 5.0
        }
    }
    
    var maxRetries: Int {
        switch self {
        case .critical: return 3
        case .high: return 2
        case .medium: return 1
        case .low: return 0
        }
    }
}

// MARK: - Refresh Request

struct RefreshRequest {
    let id: String
    let priority: RefreshPriority
    let operation: () async throws -> Void
    let timestamp: Date
    let userInitiated: Bool
    
    init(
        id: String,
        priority: RefreshPriority,
        userInitiated: Bool = false,
        operation: @escaping () async throws -> Void
    ) {
        self.id = id
        self.priority = priority
        self.userInitiated = userInitiated
        self.operation = operation
        self.timestamp = Date()
    }
}

// MARK: - Refresh State

enum RefreshState {
    case idle
    case refreshing(progress: Double)
    case completed
    case failed(Error)
    
    var isRefreshing: Bool {
        if case .refreshing = self { return true }
        return false
    }
}

// MARK: - Smart Refresh Manager

@MainActor
final class SmartRefreshManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var refreshState: RefreshState = .idle
    @Published private(set) var backgroundRefreshesInProgress = 0
    @Published private(set) var lastRefreshTime: Date?
    
    // MARK: - Private Properties
    
    private let networkMonitor = NetworkMonitor.shared
    private let socialFeedCache: SocialFeedCache
    
    // Request management
    private var pendingRequests: [RefreshPriority: [RefreshRequest]] = [:]
    private var debounceTasks: [String: Task<Void, Never>] = [:]
    private var activeRefreshes: Set<String> = []
    
    // Rate limiting
    private var requestCounts: [String: (count: Int, resetTime: Date)] = [:]
    private let maxRequestsPerMinute = 30
    
    // Background processing
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var cancellables = Set<AnyCancellable>()
    
    init(socialFeedCache: SocialFeedCache) {
        self.socialFeedCache = socialFeedCache
        setupAppLifecycleHandling()
        setupPeriodicMaintenance()
    }
    
    // MARK: - Public Interface
    
    /// Request a refresh with intelligent debouncing and prioritization
    func requestRefresh(
        id: String,
        priority: RefreshPriority,
        userInitiated: Bool = false,
        operation: @escaping () async throws -> Void
    ) {
        // Check rate limiting
        if !userInitiated && isRateLimited(id: id) {
            print("⚠️ Refresh request rate limited: \(id)")
            return
        }
        
        let request = RefreshRequest(
            id: id,
            priority: priority,
            userInitiated: userInitiated,
            operation: operation
        )
        
        // Cancel existing debounce for this request
        debounceTasks[id]?.cancel()
        
        // Add to pending requests
        if pendingRequests[priority] == nil {
            pendingRequests[priority] = []
        }
        
        // Remove any existing request with same ID
        for priority in RefreshPriority.allCases {
            pendingRequests[priority]?.removeAll { $0.id == id }
        }
        
        pendingRequests[priority]?.append(request)
        
        // User-initiated requests are processed immediately
        if userInitiated {
            processRequest(request)
        } else {
            // Debounce non-user requests
            debounceTasks[id] = Task {
                do {
                    try await Task.sleep(nanoseconds: UInt64(priority.debounceInterval * 1_000_000_000))
                    
                    guard !Task.isCancelled else { return }
                    processRequest(request)
                } catch {
                    // Task was cancelled - this is normal
                    return
                }
            }
        }
    }
    
    /// Request refresh for feed data with smart caching
    func requestFeedRefresh<T: Codable>(
        feedType: String,
        userID: String,
        page: Int,
        type: T.Type,
        userInitiated: Bool = false,
        fetchOperation: @escaping () async throws -> T
    ) {
        let id = "feed:\(feedType):\(userID):\(page)"
        
        // Check if we need to refresh based on cache state
        let (_, shouldRefresh, cacheStatus) = socialFeedCache.getFeedData(
            feedType: feedType,
            userID: userID,
            page: page,
            type: type,
            strategy: userInitiated ? .immediate : .staleWhileRevalidate
        )
        
        // If we have fresh data and it's not user-initiated, skip
        if !shouldRefresh && !userInitiated {
            return
        }
        
        let priority: RefreshPriority = userInitiated ? .critical : 
                                      (cacheStatus == .miss) ? .high : .medium
        
        requestRefresh(id: id, priority: priority, userInitiated: userInitiated) {
            let data = try await fetchOperation()
            self.socialFeedCache.setFeedPage(
                feedType: feedType,
                userID: userID,
                page: page,
                data: data
            )
        }
    }
    
    /// Force refresh all critical data (pull-to-refresh scenario)
    func refreshCriticalData() async {
        refreshState = .refreshing(progress: 0.0)
        
        do {
            // Process all critical requests
            let criticalRequests = pendingRequests[.critical] ?? []
            let highRequests = pendingRequests[.high] ?? []
            let allRequests = criticalRequests + highRequests
            
            for (index, request) in allRequests.enumerated() {
                let progress = Double(index) / Double(allRequests.count)
                refreshState = .refreshing(progress: progress)
                
                try await request.operation()
                
                // Small delay to prevent overwhelming the server
                if index < allRequests.count - 1 {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
            }
            
            refreshState = .completed
            lastRefreshTime = Date()
            
            // Clear processed requests
            pendingRequests[.critical] = []
            pendingRequests[.high] = []
        } catch {
            refreshState = .failed(error)
            print("❌ Critical data refresh failed: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func processRequest(_ request: RefreshRequest) {
        guard !activeRefreshes.contains(request.id) else {
            print("⚠️ Refresh already in progress: \(request.id)")
            return
        }
        
        guard networkMonitor.isConnected else {
            print("📡 No network connection - skipping refresh: \(request.id)")
            return
        }
        
        activeRefreshes.insert(request.id)
        
        if !request.userInitiated {
            backgroundRefreshesInProgress += 1
        }
        
        Task {
            await executeRefreshRequest(request)
            
            await MainActor.run {
                activeRefreshes.remove(request.id)
                
                if !request.userInitiated {
                    backgroundRefreshesInProgress = max(0, backgroundRefreshesInProgress - 1)
                }
            }
        }
    }
    
    private func executeRefreshRequest(_ request: RefreshRequest) async {
        var retryCount = 0
        let maxRetries = request.maxRetries
        
        while retryCount <= maxRetries {
            do {
                try await request.operation()
                
                // Track successful request for rate limiting
                updateRequestCount(id: request.id)
                
                print("✅ Refresh completed: \(request.id)")
                return
            } catch {
                retryCount += 1
                
                if retryCount > maxRetries {
                    print("❌ Refresh failed after \(retryCount) attempts: \(request.id) - \(error)")
                    return
                }
                
                // Exponential backoff
                let delay = pow(2.0, Double(retryCount)) * 0.5
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    // If sleep fails, just continue with retry (no delay)
                }
                
                print("🔄 Retrying refresh (\(retryCount)/\(maxRetries)): \(request.id)")
            }
        }
    }
    
    private func isRateLimited(id: String) -> Bool {
        let now = Date()
        
        if let (count, resetTime) = requestCounts[id] {
            if now >= resetTime {
                // Reset the count
                requestCounts[id] = (1, now.addingTimeInterval(60))
                return false
            } else if count >= maxRequestsPerMinute {
                return true
            } else {
                requestCounts[id] = (count + 1, resetTime)
                return false
            }
        } else {
            requestCounts[id] = (1, now.addingTimeInterval(60))
            return false
        }
    }
    
    private func updateRequestCount(id: String) {
        // This is handled in isRateLimited, but we could add success tracking here
    }
    
    // MARK: - App Lifecycle
    
    private func setupAppLifecycleHandling() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppDidBecomeActive()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppDidBecomeActive() async {
        print("📱 App became active - processing pending refreshes")
        
        // Process high-priority requests that accumulated while app was in background
        await processPendingRequests(maxPriority: .high)
    }
    
    private func handleAppDidEnterBackground() {
        print("📱 App entered background - starting background task")
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask {
            // Background task expired
            UIApplication.shared.endBackgroundTask(self.backgroundTaskIdentifier)
            self.backgroundTaskIdentifier = .invalid
        }
        
        // Complete any critical background refreshes
        Task {
            await processPendingRequests(maxPriority: .medium)
            
            await MainActor.run {
                if self.backgroundTaskIdentifier != .invalid {
                    UIApplication.shared.endBackgroundTask(self.backgroundTaskIdentifier)
                    self.backgroundTaskIdentifier = .invalid
                }
            }
        }
    }
    
    private func processPendingRequests(maxPriority: RefreshPriority) async {
        for priority in RefreshPriority.allCases {
            if priority.rawValue > maxPriority.rawValue { break }
            
            let requests = pendingRequests[priority] ?? []
            for request in requests {
                await executeRefreshRequest(request)
            }
            
            pendingRequests[priority] = []
        }
    }
    
    // MARK: - Maintenance
    
    private func setupPeriodicMaintenance() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performMaintenance()
            }
        }
    }
    
    private func performMaintenance() async {
        // Clean up old debounce tasks
        debounceTasks = debounceTasks.filter { !$0.value.isCancelled }
        
        // Clean up old rate limiting data
        let now = Date()
        requestCounts = requestCounts.filter { $0.value.resetTime > now }
        
        // Process any low-priority background requests
        if networkMonitor.shouldBackgroundRefresh {
            await processPendingRequests(maxPriority: .low)
        }
    }
}

// MARK: - Extensions

private extension RefreshRequest {
    var maxRetries: Int {
        priority.maxRetries
    }
}
