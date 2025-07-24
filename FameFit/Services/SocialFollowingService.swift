//
//  SocialFollowingService.swift
//  FameFit
//
//  Service for managing social following relationships with security
//

import Foundation
import Combine
import CloudKit

// MARK: - Social Following Service Implementation

final class SocialFollowingService: SocialFollowingServicing {
    // Dependencies
    private let cloudKitManager: any CloudKitManaging
    private let rateLimiter: any RateLimitingServicing
    private let profileService: any UserProfileServicing
    private let container: CKContainer
    
    // Publishers
    @Published private var followersCounts: [String: Int] = [:]
    @Published private var followingCounts: [String: Int] = [:]
    private let relationshipUpdatesSubject = PassthroughSubject<UserRelationship, Never>()
    
    // Caching
    private let relationshipCache = NSCache<NSString, CachedRelationship>()
    private let cacheQueue = DispatchQueue(label: "com.famefit.socialcache", attributes: .concurrent)
    
    private class CachedRelationship {
        let relationship: UserRelationship?
        let timestamp: Date
        
        init(relationship: UserRelationship?, timestamp: Date) {
            self.relationship = relationship
            self.timestamp = timestamp
        }
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 300 // 5 minutes
        }
    }
    
    // MARK: - Initialization
    
    init(cloudKitManager: any CloudKitManaging,
         rateLimiter: any RateLimitingServicing,
         profileService: any UserProfileServicing,
         container: CKContainer = .default()) {
        self.cloudKitManager = cloudKitManager
        self.rateLimiter = rateLimiter
        self.profileService = profileService
        self.container = container
        
        setupCache()
    }
    
    // MARK: - Publishers
    
    var followersCountPublisher: AnyPublisher<[String: Int], Never> {
        $followersCounts.eraseToAnyPublisher()
    }
    
    var followingCountPublisher: AnyPublisher<[String: Int], Never> {
        $followingCounts.eraseToAnyPublisher()
    }
    
    var relationshipUpdatesPublisher: AnyPublisher<UserRelationship, Never> {
        relationshipUpdatesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Follow Operations
    
    func follow(userId: String) async throws {
        // Security checks
        guard let currentUserId = cloudKitManager.currentUserID else {
            throw SocialServiceError.unauthorized
        }
        
        guard currentUserId != userId else {
            throw SocialServiceError.selfFollowAttempt
        }
        
        // Rate limiting
        _ = try await rateLimiter.checkLimit(for: .follow, userId: currentUserId)
        
        // Check if already following
        let existingStatus = try await checkRelationship(between: currentUserId, and: userId)
        guard existingStatus == .notFollowing else {
            if existingStatus == .blocked {
                throw SocialServiceError.userBlocked
            }
            throw SocialServiceError.duplicateRelationship
        }
        
        // Check target user's privacy settings
        let targetProfile = try await profileService.fetchProfile(userId: userId)
        
        if targetProfile.privacyLevel == .privateProfile {
            // Create follow request instead
            try await createFollowRequest(to: userId, message: nil)
            return
        }
        
        // Create relationship
        let relationship = UserRelationship(
            id: UserRelationship.makeId(followerID: currentUserId, followingID: userId),
            followerID: currentUserId,
            followingID: userId,
            createdTimestamp: Date(),
            status: "active",
            notificationsEnabled: true
        )
        
        // Save to CloudKit
        try await saveRelationship(relationship)
        
        // Record action for rate limiting
        await rateLimiter.recordAction(.follow, userId: currentUserId)
        
        // Update counts
        await updateCounts(for: [currentUserId, userId])
        
        // Notify subscribers
        relationshipUpdatesSubject.send(relationship)
        
        // Clear cache
        clearRelationshipCache(for: currentUserId, and: userId)
    }
    
    func unfollow(userId: String) async throws {
        guard let currentUserId = cloudKitManager.currentUserID else {
            throw SocialServiceError.unauthorized
        }
        
        // Rate limiting
        _ = try await rateLimiter.checkLimit(for: .unfollow, userId: currentUserId)
        
        // Find and delete relationship
        let relationshipId = UserRelationship.makeId(followerID: currentUserId, followingID: userId)
        
        let database = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: relationshipId)
        
        do {
            try await database.deleteRecord(withID: recordID)
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                // Relationship doesn't exist, that's ok
                return
            }
            throw SocialServiceError.networkError(error)
        }
        
        // Record action
        await rateLimiter.recordAction(.unfollow, userId: currentUserId)
        
        // Update counts
        await updateCounts(for: [currentUserId, userId])
        
        // Clear cache
        clearRelationshipCache(for: currentUserId, and: userId)
    }
    
    func requestFollow(userId: String, message: String?) async throws {
        guard let currentUserId = cloudKitManager.currentUserID else {
            throw SocialServiceError.unauthorized
        }
        
        guard currentUserId != userId else {
            throw SocialServiceError.selfFollowAttempt
        }
        
        // Rate limiting
        _ = try await rateLimiter.checkLimit(for: .followRequest, userId: currentUserId)
        
        // Create follow request
        try await createFollowRequest(to: userId, message: message)
        
        // Record action
        await rateLimiter.recordAction(.followRequest, userId: currentUserId)
    }
    
    // MARK: - Relationship Queries
    
    func getFollowers(for userId: String, limit: Int) async throws -> [UserProfile] {
        let database = container.publicCloudDatabase
        
        // Query for relationships where this user is being followed
        let predicate = NSPredicate(format: "followingID == %@ AND status == %@", userId, "active")
        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]
        
        do {
            let results = try await database.records(matching: query, resultsLimit: limit)
            
            // Extract follower IDs
            let followerIds = results.matchResults.compactMap { _, result in
                try? result.get()["followerID"] as? String
            }
            
            // Fetch profiles
            var profiles: [UserProfile] = []
            for followerId in followerIds {
                if let profile = try? await profileService.fetchProfile(userId: followerId) {
                    profiles.append(profile)
                }
            }
            
            return profiles
        } catch {
            throw SocialServiceError.networkError(error)
        }
    }
    
    func getFollowing(for userId: String, limit: Int) async throws -> [UserProfile] {
        let database = container.publicCloudDatabase
        
        // Query for relationships where this user is following others
        let predicate = NSPredicate(format: "followerID == %@ AND status == %@", userId, "active")
        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]
        
        do {
            let results = try await database.records(matching: query, resultsLimit: limit)
            
            // Extract following IDs
            let followingIds = results.matchResults.compactMap { _, result in
                try? result.get()["followingID"] as? String
            }
            
            // Fetch profiles
            var profiles: [UserProfile] = []
            for followingId in followingIds {
                if let profile = try? await profileService.fetchProfile(userId: followingId) {
                    profiles.append(profile)
                }
            }
            
            return profiles
        } catch {
            throw SocialServiceError.networkError(error)
        }
    }
    
    func checkRelationship(between userId: String, and targetId: String) async throws -> RelationshipStatus {
        // Check cache first
        let cacheKey = "\(userId)_\(targetId)"
        if let cached = getCachedRelationship(for: cacheKey), !cached.isExpired {
            if let relationship = cached.relationship {
                switch relationship.status {
                case "active":
                    // Check if mutual
                    let reverseKey = "\(targetId)_\(userId)"
                    if let reverseCached = getCachedRelationship(for: reverseKey),
                       !reverseCached.isExpired,
                       reverseCached.relationship?.status == "active" {
                        return .mutualFollow
                    }
                    return .following
                case "blocked":
                    return .blocked
                case "muted":
                    return .muted
                default:
                    return .notFollowing
                }
            } else {
                return .notFollowing
            }
        }
        
        // Query CloudKit
        let relationshipId = UserRelationship.makeId(followerID: userId, followingID: targetId)
        let database = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: relationshipId)
        
        do {
            let record = try await database.record(for: recordID)
            let status = record["status"] as? String ?? "active"
            
            // Cache the result
            let relationship = UserRelationship(
                id: relationshipId,
                followerID: userId,
                followingID: targetId,
                createdTimestamp: record.creationDate ?? Date(),
                status: status,
                notificationsEnabled: record["notificationsEnabled"] as? Int64 == 1
            )
            cacheRelationship(relationship, for: cacheKey)
            
            // Determine status
            switch status {
            case "active":
                // Check for mutual follow
                let reverseStatus = try? await checkRelationship(between: targetId, and: userId)
                if reverseStatus == .following {
                    return .mutualFollow
                }
                return .following
            case "blocked":
                return .blocked
            case "muted":
                return .muted
            default:
                return .notFollowing
            }
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                // No relationship exists
                cacheRelationship(nil, for: cacheKey)
                return .notFollowing
            }
            throw SocialServiceError.networkError(error)
        }
    }
    
    // MARK: - Block/Mute Operations
    
    func blockUser(_ userId: String) async throws {
        guard let currentUserId = cloudKitManager.currentUserID else {
            throw SocialServiceError.unauthorized
        }
        
        // First unfollow if following
        _ = try? await unfollow(userId: userId)
        
        // Create or update relationship with blocked status
        let relationship = UserRelationship(
            id: UserRelationship.makeId(followerID: currentUserId, followingID: userId),
            followerID: currentUserId,
            followingID: userId,
            createdTimestamp: Date(),
            status: "blocked",
            notificationsEnabled: false
        )
        
        try await saveRelationship(relationship)
        
        // Also remove them as follower
        let reverseId = UserRelationship.makeId(followerID: userId, followingID: currentUserId)
        let database = container.publicCloudDatabase
        let reverseRecordID = CKRecord.ID(recordName: reverseId)
        
        _ = try? await database.deleteRecord(withID: reverseRecordID)
        
        // Update user settings with blocked list
        var settings = try await profileService.fetchSettings(userId: currentUserId)
        if !settings.blockedUsers.contains(userId) {
            settings.blockedUsers.insert(userId)
            _ = try await profileService.updateSettings(settings)
        }
        
        // Clear cache
        clearRelationshipCache(for: currentUserId, and: userId)
        clearRelationshipCache(for: userId, and: currentUserId)
    }
    
    // MARK: - Private Helper Methods
    
    private func saveRelationship(_ relationship: UserRelationship) async throws {
        let database = container.publicCloudDatabase
        let record = CKRecord(recordType: "UserRelationships", recordID: CKRecord.ID(recordName: relationship.id))
        
        record["followerID"] = relationship.followerID
        record["followingID"] = relationship.followingID
        record["status"] = relationship.status
        record["notificationsEnabled"] = relationship.notificationsEnabled ? 1 : 0
        
        do {
            _ = try await database.save(record)
        } catch {
            throw SocialServiceError.networkError(error)
        }
    }
    
    private func createFollowRequest(to userId: String, message: String?) async throws {
        guard let currentUserId = cloudKitManager.currentUserID else { return }
        
        let request = FollowRequest(
            id: UUID().uuidString,
            requesterId: currentUserId,
            requesterProfile: nil,
            targetId: userId,
            status: "pending",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(604800), // 7 days
            message: message
        )
        
        let database = container.privateCloudDatabase
        let record = CKRecord(recordType: "FollowRequests", recordID: CKRecord.ID(recordName: request.id))
        
        record["requesterId"] = request.requesterId
        record["targetId"] = request.targetId
        record["status"] = request.status
        record["createdAt"] = request.createdAt
        record["expiresAt"] = request.expiresAt
        if let message = request.message {
            record["message"] = message
        }
        
        _ = try await database.save(record)
    }
    
    private func updateCounts(for userIds: [String]) async {
        for userId in userIds {
            Task {
                if let followerCount = try? await getFollowerCount(for: userId) {
                    followersCounts[userId] = followerCount
                }
                if let followingCount = try? await getFollowingCount(for: userId) {
                    followingCounts[userId] = followingCount
                }
            }
        }
    }
    
    // MARK: - Caching
    
    private func setupCache() {
        relationshipCache.countLimit = 1000
        relationshipCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    private func getCachedRelationship(for key: String) -> CachedRelationship? {
        cacheQueue.sync {
            relationshipCache.object(forKey: key as NSString)
        }
    }
    
    private func cacheRelationship(_ relationship: UserRelationship?, for key: String) {
        cacheQueue.async(flags: .barrier) {
            let cached = CachedRelationship(relationship: relationship, timestamp: Date())
            self.relationshipCache.setObject(cached, forKey: key as NSString)
        }
    }
    
    private func clearRelationshipCache(for userId: String, and targetId: String) {
        cacheQueue.async(flags: .barrier) {
            let key1 = "\(userId)_\(targetId)"
            let key2 = "\(targetId)_\(userId)"
            self.relationshipCache.removeObject(forKey: key1 as NSString)
            self.relationshipCache.removeObject(forKey: key2 as NSString)
        }
    }
    
    func clearRelationshipCache() {
        cacheQueue.async(flags: .barrier) {
            self.relationshipCache.removeAllObjects()
        }
    }
    
    // MARK: - Unimplemented Methods (TODO)
    
    func respondToFollowRequest(requestId: String, accept: Bool) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }
    
    func getMutualFollowers(with userId: String, limit: Int) async throws -> [UserProfile] {
        // TODO: Implement
        return []
    }
    
    func getFollowerCount(for userId: String) async throws -> Int {
        // TODO: Implement proper count query
        let followers = try await getFollowers(for: userId, limit: 1000)
        return followers.count
    }
    
    func getFollowingCount(for userId: String) async throws -> Int {
        // TODO: Implement proper count query
        let following = try await getFollowing(for: userId, limit: 1000)
        return following.count
    }
    
    func unblockUser(_ userId: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }
    
    func muteUser(_ userId: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }
    
    func unmuteUser(_ userId: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }
    
    func getBlockedUsers() async throws -> [String] {
        // TODO: Implement
        return []
    }
    
    func getMutedUsers() async throws -> [String] {
        // TODO: Implement
        return []
    }
    
    func getPendingFollowRequests() async throws -> [FollowRequest] {
        // TODO: Implement
        return []
    }
    
    func getSentFollowRequests() async throws -> [FollowRequest] {
        // TODO: Implement
        return []
    }
    
    func cancelFollowRequest(requestId: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }
    
    func preloadRelationships(for userIds: [String]) async {
        // TODO: Implement batch preloading
    }
}