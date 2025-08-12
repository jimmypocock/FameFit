//
//  DataRefreshCoordinator.swift
//  FameFit
//
//  Coordinates data refresh across all services to prevent stale data
//

import Foundation
import Combine

final class DataRefreshCoordinator: DataRefreshProtocol {
    private let cacheManager: CacheProtocol
    private let cloudKitManager: any CloudKitProtocol
    private let userProfileService: UserProfileProtocol
    private let socialFollowingService: SocialFollowingProtocol
    private let workoutSyncManager: WorkoutSyncService?
    
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    private var lastRefreshTime: Date?
    
    init(
        cacheManager: CacheProtocol,
        cloudKitManager: any CloudKitProtocol,
        userProfileService: UserProfileProtocol,
        socialFollowingService: SocialFollowingProtocol,
        workoutSyncManager: WorkoutSyncService? = nil
    ) {
        self.cacheManager = cacheManager
        self.cloudKitManager = cloudKitManager
        self.userProfileService = userProfileService
        self.socialFollowingService = socialFollowingService
        self.workoutSyncManager = workoutSyncManager
    }
    
    func refreshAllUserData() async {
        print("🔄 DataRefreshCoordinator: Starting full user data refresh")
        
        // Refresh in parallel where possible
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.refreshProfile()
            }
            
            group.addTask { [weak self] in
                await self?.refreshWorkouts()
            }
            
            group.addTask { [weak self] in
                await self?.refreshSocialData()
            }
        }
        
        lastRefreshTime = Date()
        print("✅ DataRefreshCoordinator: Full refresh completed")
    }
    
    func refreshProfile() async {
        // Force CloudKit to fetch fresh user record
        cloudKitManager.fetchUserRecord()
        
        // Fetch fresh profile data
        do {
            let profile = try await userProfileService.fetchCurrentUserProfile()
            print("✅ Profile refreshed: @\(profile.username)")
        } catch {
            print("❌ Failed to refresh profile: \(error)")
        }
    }
    
    func refreshWorkouts() async {
        // Restart workout sync to fetch latest data
        await workoutSyncManager?.stopSync()
        await workoutSyncManager?.startReliableSync()
    }
    
    func refreshSocialData() async {
        guard cloudKitManager.currentUserID != nil else { return }
        
        // Clear relationship cache to force fresh data
        socialFollowingService.clearRelationshipCache()
    }
    
    func invalidateAllCaches() {
        print("🧹 DataRefreshCoordinator: Invalidating all caches")
        
        // Clear centralized cache
        cacheManager.removeAll()
        
        // Clear service-specific caches
        userProfileService.clearCache()
        socialFollowingService.clearRelationshipCache()
        
        lastRefreshTime = nil
    }
    
    func needsRefresh() -> Bool {
        guard let lastRefresh = lastRefreshTime else { return true }
        return Date().timeIntervalSince(lastRefresh) > refreshInterval
    }
}

// MARK: - App Lifecycle Integration

extension DataRefreshCoordinator {
    /// Call when app enters foreground
    func handleAppDidBecomeActive() {
        if needsRefresh() {
            Task {
                await refreshAllUserData()
            }
        }
    }
    
    func handleAppWillResignActive() {
        // Save any pending state if needed
        // Currently no action required
    }
    
    func handleAppDidEnterBackground() {
        // Clean up resources or pause refresh timers if needed
        // Currently no action required
    }
    
    /// Call when user signs in or profile changes
    func handleUserChange() {
        invalidateAllCaches()
        Task {
            await refreshAllUserData()
        }
    }
    
    /// Call when receiving push notification about data changes
    func handleRemoteDataChange(recordType: String) {
        Task {
            switch recordType {
            case "UserProfiles":
                await refreshProfile()
            case "Workouts":
                await refreshWorkouts()
            case "UserRelationships":
                await refreshSocialData()
            default:
                // Refresh all if unknown type
                await refreshAllUserData()
            }
        }
    }
}
