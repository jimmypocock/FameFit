//
//  SocialMediaCacheProtocol.swift
//  FameFit
//
//  Protocol for social media cache coordination operations
//

import Foundation

protocol SocialMediaCacheProtocol {
    // Feed management
    func refreshFeed(userID: String, userInitiated: Bool) async
    func loadFeedPage(userID: String, page: Int, userInitiated: Bool) async -> [ActivityFeedItem]?
    func preloadNextFeedPage(userID: String, currentPage: Int)
    
    // Social data management  
    func refreshUserProfile(userID: String, force: Bool) async -> UserProfile?
    func refreshSocialCounts(userID: String) async
    func handleSocialInteraction(type: SocialInteractionType, userID: String, targetID: String)
    
    // Lifecycle management
    func handleAppLaunch()
    func handleAppBecomeActive()
    func handleUserLogin(userID: String)
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