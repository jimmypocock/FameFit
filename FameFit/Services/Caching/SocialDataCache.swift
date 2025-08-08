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
    static func profile(userID: String) -> String {
        "profile:\(userID)"
    }
    
    static func profileByRecordID(_ recordID: String) -> String {
        "profile:record:\(recordID)"
    }
    
    // Count caching
    static func followerCount(userID: String) -> String {
        "follower_count:\(userID)"
    }
    
    static func followingCount(userID: String) -> String {
        "following_count:\(userID)"
    }
    
    // List caching
    static func followers(userID: String, page: Int = 0) -> String {
        "followers:\(userID):\(page)"
    }
    
    static func following(userID: String, page: Int = 0) -> String {
        "following:\(userID):\(page)"
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
    
    func getProfile(userID: String) -> UserProfile? {
        cacheManager.get(CacheKeys.profile(userID: userID), type: UserProfile.self)
    }
    
    func setProfile(_ profile: UserProfile) {
        // Cache by both user ID and record ID for flexibility
        cacheManager.set(CacheKeys.profile(userID: profile.userID), value: profile, ttl: CacheTTL.profile)
        cacheManager.set(CacheKeys.profileByRecordID(profile.id), value: profile, ttl: CacheTTL.profile)
    }
    
    func getProfileByRecordID(_ recordID: String) -> UserProfile? {
        cacheManager.get(CacheKeys.profileByRecordID(recordID), type: UserProfile.self)
    }
    
    // MARK: - Count Caching
    
    func getFollowerCount(userID: String) -> Int? {
        cacheManager.get(CacheKeys.followerCount(userID: userID), type: Int.self)
    }
    
    func setFollowerCount(userID: String, count: Int) {
        cacheManager.set(CacheKeys.followerCount(userID: userID), value: count, ttl: CacheTTL.followerCount)
    }
    
    func getFollowingCount(userID: String) -> Int? {
        cacheManager.get(CacheKeys.followingCount(userID: userID), type: Int.self)
    }
    
    func setFollowingCount(userID: String, count: Int) {
        cacheManager.set(CacheKeys.followingCount(userID: userID), value: count, ttl: CacheTTL.followingCount)
    }
    
    // MARK: - List Caching
    
    func getFollowers(userID: String, page: Int = 0) -> [UserProfile]? {
        cacheManager.get(CacheKeys.followers(userID: userID, page: page), type: [UserProfile].self)
    }
    
    func setFollowers(userID: String, followers: [UserProfile], page: Int = 0) {
        cacheManager.set(CacheKeys.followers(userID: userID, page: page), value: followers, ttl: CacheTTL.followersList)
    }
    
    func getFollowing(userID: String, page: Int = 0) -> [UserProfile]? {
        cacheManager.get(CacheKeys.following(userID: userID, page: page), type: [UserProfile].self)
    }
    
    func setFollowing(userID: String, following: [UserProfile], page: Int = 0) {
        cacheManager.set(CacheKeys.following(userID: userID, page: page), value: following, ttl: CacheTTL.followingList)
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
    func invalidateUser(_ userID: String) {
        // Invalidate counts
        cacheManager.remove(CacheKeys.followerCount(userID: userID))
        cacheManager.remove(CacheKeys.followingCount(userID: userID))
        
        // Invalidate lists (all pages)
        cacheManager.invalidate(matching: "followers:\(userID):")
        cacheManager.invalidate(matching: "following:\(userID):")
        
        // Invalidate relationships
        cacheManager.invalidate(matching: "relationship:\(userID):")
        cacheManager.invalidate(matching: "relationship:.*:\(userID)")
        
        // Invalidate profile
        cacheManager.remove(CacheKeys.profile(userID: userID))
    }
    
    /// Invalidate caches when a follow action occurs
    func invalidateFollowAction(follower: String, following: String) {
        // Invalidate counts for both users
        cacheManager.remove(CacheKeys.followerCount(userID: following))
        cacheManager.remove(CacheKeys.followingCount(userID: follower))
        
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
