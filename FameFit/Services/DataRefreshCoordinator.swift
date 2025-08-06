//
//  DataRefreshCoordinator.swift
//  FameFit
//
//  Coordinates data refresh across all services to prevent stale data
//

import Foundation
import Combine

protocol DataRefreshCoordinating {
    /// Refresh all user-related data
    func refreshAllUserData() async
    
    /// Refresh specific data types
    func refreshProfile() async
    func refreshWorkouts() async
    func refreshSocialData() async
    
    /// Mark all caches as stale
    func invalidateAllCaches()
    
    /// Check if any data needs refreshing
    func needsRefresh() -> Bool
    
    /// App lifecycle handlers
    func handleAppDidBecomeActive()
    func handleUserChange()
}

final class DataRefreshCoordinator: DataRefreshCoordinating {
    private let cacheManager: CacheManaging
    private let cloudKitManager: any CloudKitManaging
    private let userProfileService: UserProfileServicing
    private let socialFollowingService: SocialFollowingServicing
    private let workoutSyncManager: WorkoutSyncManager?
    
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    private var lastRefreshTime: Date?
    
    init(
        cacheManager: CacheManaging,
        cloudKitManager: any CloudKitManaging,
        userProfileService: UserProfileServicing,
        socialFollowingService: SocialFollowingServicing,
        workoutSyncManager: WorkoutSyncManager? = nil
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