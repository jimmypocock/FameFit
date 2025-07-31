//
//  SocialDataCache.swift
//  FameFit
//
//  Specialized cache for social following data with proper TTLs
//

import Foundation

// MARK: - Cache TTL Constants

enum CacheTTL {
    static let profile: TimeInterval = 300 // 5 minutes
    static let followerCount: TimeInterval = 120 // 2 minutes
    static let followingCount: TimeInterval = 120 // 2 minutes
    static let followersList: TimeInterval = 60 // 1 minute
    static let followingList: TimeInterval = 60 // 1 minute
    static let relationshipStatus: TimeInterval = 30 // 30 seconds
    static let userSearch: TimeInterval = 300 // 5 minutes
}

// MARK: - Cache Key Generation

enum CacheKeys {
    // Profile caching
    static func profile(userId: String) -> String {
        "profile:\(userId)"
    }
    
    static func profileByRecordId(_ recordId: String) -> String {
        "profile:record:\(recordId)"
    }
    
    // Count caching
    static func followerCount(userId: String) -> String {
        "follower_count:\(userId)"
    }
    
    static func followingCount(userId: String) -> String {
        "following_count:\(userId)"
    }
    
    // List caching
    static func followers(userId: String, page: Int = 0) -> String {
        "followers:\(userId):\(page)"
    }
    
    static func following(userId: String, page: Int = 0) -> String {
        "following:\(userId):\(page)"
    }
    
    // Relationship caching
    static func relationship(from: String, to: String) -> String {
        "relationship:\(from):\(to)"
    }
    
    // Search caching
    static func searchResults(query: String) -> String {
        "search:\(query.lowercased())"
    }
}

// MARK: - Social Data Cache

final class SocialDataCache: @unchecked Sendable {
    private let cacheManager: CacheManaging
    
    init(cacheManager: CacheManaging) {
        self.cacheManager = cacheManager
    }
    
    // MARK: - Profile Caching
    
    func getProfile(userId: String) -> UserProfile? {
        cacheManager.get(CacheKeys.profile(userId: userId), type: UserProfile.self)
    }
    
    func setProfile(_ profile: UserProfile) {
        // Cache by both user ID and record ID for flexibility
        cacheManager.set(CacheKeys.profile(userId: profile.userID), value: profile, ttl: CacheTTL.profile)
        cacheManager.set(CacheKeys.profileByRecordId(profile.id), value: profile, ttl: CacheTTL.profile)
    }
    
    func getProfileByRecordId(_ recordId: String) -> UserProfile? {
        cacheManager.get(CacheKeys.profileByRecordId(recordId), type: UserProfile.self)
    }
    
    // MARK: - Count Caching
    
    func getFollowerCount(userId: String) -> Int? {
        cacheManager.get(CacheKeys.followerCount(userId: userId), type: Int.self)
    }
    
    func setFollowerCount(userId: String, count: Int) {
        cacheManager.set(CacheKeys.followerCount(userId: userId), value: count, ttl: CacheTTL.followerCount)
    }
    
    func getFollowingCount(userId: String) -> Int? {
        cacheManager.get(CacheKeys.followingCount(userId: userId), type: Int.self)
    }
    
    func setFollowingCount(userId: String, count: Int) {
        cacheManager.set(CacheKeys.followingCount(userId: userId), value: count, ttl: CacheTTL.followingCount)
    }
    
    // MARK: - List Caching
    
    func getFollowers(userId: String, page: Int = 0) -> [UserProfile]? {
        cacheManager.get(CacheKeys.followers(userId: userId, page: page), type: [UserProfile].self)
    }
    
    func setFollowers(userId: String, followers: [UserProfile], page: Int = 0) {
        cacheManager.set(CacheKeys.followers(userId: userId, page: page), value: followers, ttl: CacheTTL.followersList)
    }
    
    func getFollowing(userId: String, page: Int = 0) -> [UserProfile]? {
        cacheManager.get(CacheKeys.following(userId: userId, page: page), type: [UserProfile].self)
    }
    
    func setFollowing(userId: String, following: [UserProfile], page: Int = 0) {
        cacheManager.set(CacheKeys.following(userId: userId, page: page), value: following, ttl: CacheTTL.followingList)
    }
    
    // MARK: - Relationship Caching
    
    func getRelationshipStatus(from: String, to: String) -> RelationshipStatus? {
        cacheManager.get(CacheKeys.relationship(from: from, to: to), type: RelationshipStatus.self)
    }
    
    func setRelationshipStatus(from: String, to: String, status: RelationshipStatus) {
        cacheManager.set(CacheKeys.relationship(from: from, to: to), value: status, ttl: CacheTTL.relationshipStatus)
    }
    
    // MARK: - Search Caching
    
    func getSearchResults(query: String) -> [UserProfile]? {
        cacheManager.get(CacheKeys.searchResults(query: query), type: [UserProfile].self)
    }
    
    func setSearchResults(query: String, results: [UserProfile]) {
        cacheManager.set(CacheKeys.searchResults(query: query), value: results, ttl: CacheTTL.userSearch)
    }
    
    // MARK: - Cache Invalidation
    
    /// Invalidate all caches for a specific user
    func invalidateUser(_ userId: String) {
        // Invalidate counts
        cacheManager.remove(CacheKeys.followerCount(userId: userId))
        cacheManager.remove(CacheKeys.followingCount(userId: userId))
        
        // Invalidate lists (all pages)
        cacheManager.invalidate(matching: "followers:\(userId):")
        cacheManager.invalidate(matching: "following:\(userId):")
        
        // Invalidate relationships
        cacheManager.invalidate(matching: "relationship:\(userId):")
        cacheManager.invalidate(matching: "relationship:.*:\(userId)")
        
        // Invalidate profile
        cacheManager.remove(CacheKeys.profile(userId: userId))
    }
    
    /// Invalidate caches when a follow action occurs
    func invalidateFollowAction(follower: String, following: String) {
        // Invalidate counts for both users
        cacheManager.remove(CacheKeys.followerCount(userId: following))
        cacheManager.remove(CacheKeys.followingCount(userId: follower))
        
        // Invalidate lists for both users
        cacheManager.invalidate(matching: "followers:\(following):")
        cacheManager.invalidate(matching: "following:\(follower):")
        
        // Invalidate relationship status
        cacheManager.remove(CacheKeys.relationship(from: follower, to: following))
        cacheManager.remove(CacheKeys.relationship(from: following, to: follower))
    }
    
    /// Invalidate all social caches
    func invalidateAll() {
        cacheManager.invalidate(matching: "profile:")
        cacheManager.invalidate(matching: "follower_count:")
        cacheManager.invalidate(matching: "following_count:")
        cacheManager.invalidate(matching: "followers:")
        cacheManager.invalidate(matching: "following:")
        cacheManager.invalidate(matching: "relationship:")
        cacheManager.invalidate(matching: "search:")
    }
}