//
//  FollowingCacheManager.swift
//  FameFit
//
//  Manages caching for the social following system with proper ID handling
//

import Foundation
import Combine
import UIKit

// MARK: - Following Cache Manager

final class FollowingCacheManager {
    // MARK: - Cache Keys
    
    private enum CacheKey {
        case followerCount(userID: String)
        case followingCount(userID: String)
        case followersList(userID: String, page: Int)
        case followingList(userID: String, page: Int)
        case relationship(fromUserID: String, toUserID: String)
        case profileByUserID(userID: String)
        
        var key: String {
            switch self {
            case .followerCount(let userID):
                return "follower_count:\(userID)"
            case .followingCount(let userID):
                return "following_count:\(userID)"
            case .followersList(let userID, let page):
                return "followers:\(userID):\(page)"
            case .followingList(let userID, let page):
                return "following:\(userID):\(page)"
            case .relationship(let fromUserID, let toUserID):
                return "relationship:\(fromUserID):\(toUserID)"
            case .profileByUserID(let userID):
                return "profile_by_userid:\(userID)"
            }
        }
    }
    
    // MARK: - Properties
    
    private let cache = NSCache<NSString, AnyObject>()
    private let queue = DispatchQueue(label: "com.famefit.followingcache", attributes: .concurrent)
    
    // TTL Configuration
    private let countTTL: TimeInterval = 120 // 2 minutes
    private let listTTL: TimeInterval = 60 // 1 minute
    private let relationshipTTL: TimeInterval = 30 // 30 seconds
    private let profileTTL: TimeInterval = 300 // 5 minutes
    
    init() {
        cache.countLimit = 500
        cache.totalCostLimit = 10_000_000 // 10MB
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // MARK: - Count Caching
    
    func getFollowerCount(for userID: String) -> Int? {
        let key = CacheKey.followerCount(userID: userID)
        return getValue(for: key.key)
    }
    
    func setFollowerCount(_ count: Int, for userID: String) {
        let key = CacheKey.followerCount(userID: userID)
        setValue(count, for: key.key, ttl: countTTL)
    }
    
    func getFollowingCount(for userID: String) -> Int? {
        let key = CacheKey.followingCount(userID: userID)
        return getValue(for: key.key)
    }
    
    func setFollowingCount(_ count: Int, for userID: String) {
        let key = CacheKey.followingCount(userID: userID)
        setValue(count, for: key.key, ttl: countTTL)
    }
    
    // MARK: - List Caching
    
    func getFollowersList(for userID: String, page: Int) -> [UserProfile]? {
        let key = CacheKey.followersList(userID: userID, page: page)
        return getValue(for: key.key)
    }
    
    func setFollowersList(_ profiles: [UserProfile], for userID: String, page: Int) {
        let key = CacheKey.followersList(userID: userID, page: page)
        setValue(profiles, for: key.key, ttl: listTTL)
    }
    
    func getFollowingList(for userID: String, page: Int) -> [UserProfile]? {
        let key = CacheKey.followingList(userID: userID, page: page)
        return getValue(for: key.key)
    }
    
    func setFollowingList(_ profiles: [UserProfile], for userID: String, page: Int) {
        let key = CacheKey.followingList(userID: userID, page: page)
        setValue(profiles, for: key.key, ttl: listTTL)
    }
    
    // MARK: - Relationship Caching
    
    func getRelationship(from fromUserID: String, to toUserID: String) -> RelationshipStatus? {
        let key = CacheKey.relationship(fromUserID: fromUserID, toUserID: toUserID)
        return getValue(for: key.key)
    }
    
    func setRelationship(_ status: RelationshipStatus, from fromUserID: String, to toUserID: String) {
        let key = CacheKey.relationship(fromUserID: fromUserID, toUserID: toUserID)
        setValue(status, for: key.key, ttl: relationshipTTL)
    }
    
    // MARK: - Profile Caching by UserID
    
    func getProfile(byUserID userID: String) -> UserProfile? {
        let key = CacheKey.profileByUserID(userID: userID)
        return getValue(for: key.key)
    }
    
    func setProfile(_ profile: UserProfile, byUserID userID: String) {
        let key = CacheKey.profileByUserID(userID: userID)
        setValue(profile, for: key.key, ttl: profileTTL)
    }
    
    // MARK: - Cache Invalidation
    
    func invalidateFollowerData(for userID: String) {
        queue.async(flags: .barrier) {
            // Invalidate counts
            self.cache.removeObject(forKey: CacheKey.followerCount(userID: userID).key as NSString)
            
            // Invalidate all follower list pages
            for page in 0..<10 {
                self.cache.removeObject(forKey: CacheKey.followersList(userID: userID, page: page).key as NSString)
            }
        }
    }
    
    func invalidateFollowingData(for userID: String) {
        queue.async(flags: .barrier) {
            // Invalidate counts
            self.cache.removeObject(forKey: CacheKey.followingCount(userID: userID).key as NSString)
            
            // Invalidate all following list pages
            for page in 0..<10 {
                self.cache.removeObject(forKey: CacheKey.followingList(userID: userID, page: page).key as NSString)
            }
        }
    }
    
    func invalidateRelationship(from fromUserID: String, to toUserID: String) {
        queue.async(flags: .barrier) {
            self.cache.removeObject(forKey: CacheKey.relationship(fromUserID: fromUserID, toUserID: toUserID).key as NSString)
        }
    }
    
    func invalidateAllRelationships(for userID: String) {
        queue.async(flags: .barrier) {
            // This requires iterating through all cache keys, which NSCache doesn't support directly
            // In practice, we'd need to maintain a separate set of keys or use a different cache implementation
            // For now, we'll just clear the entire cache (not ideal but ensures consistency)
            self.cache.removeAllObjects()
        }
    }
    
    func clearAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
        }
    }
    
    // MARK: - Private Helpers
    
    private func getValue<T>(for key: String) -> T? {
        queue.sync {
            guard let entry = cache.object(forKey: key as NSString) as? CacheEntry<T> else {
                return nil
            }
            
            if entry.isExpired {
                cache.removeObject(forKey: key as NSString)
                return nil
            }
            
            return entry.value
        }
    }
    
    private func setValue<T>(_ value: T, for key: String, ttl: TimeInterval) {
        queue.async(flags: .barrier) {
            let entry = CacheEntry(value: value, ttl: ttl)
            self.cache.setObject(entry as AnyObject, forKey: key as NSString)
        }
    }
    
    @objc private func handleMemoryWarning() {
        clearAll()
    }
}