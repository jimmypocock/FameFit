//
//  DataRefreshCoordinatorProtocol.swift
//  FameFit
//
//  Protocol for data refresh coordination operations
//

import Foundation

protocol DataRefreshCoordinatorProtocol {
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
    func handleAppWillResignActive()
    func handleAppDidEnterBackground()
}