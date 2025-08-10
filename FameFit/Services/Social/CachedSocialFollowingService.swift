//
//  CachedSocialFollowingService.swift
//  FameFit
//
//  Social following service with proper ID handling and TTL-based caching
//

import CloudKit
import Combine
import Foundation

// MARK: - Cached Social Following Service

final class CachedSocialFollowingService: SocialFollowingProtocol, @unchecked Sendable {
    // Dependencies
    private let cloudKitManager: CloudKitService
    private let rateLimiter: RateLimitingProtocol
    private let profileService: UserProfileProtocol
    private let notificationManager: NotificationProtocol?
    private let publicDatabase: CKDatabase
    private let cacheManager: FollowingCacheManager
    
    // Published state
    @Published private var followersCounts: [String: Int] = [:]
    @Published private var followingCounts: [String: Int] = [:]
    private let relationshipUpdatesSubject = PassthroughSubject<UserRelationship, Never>()
    
    init(
        cloudKitManager: CloudKitService,
        rateLimiter: RateLimitingProtocol,
        profileService: UserProfileProtocol,
        notificationManager: NotificationProtocol? = nil
    ) {
        self.cloudKitManager = cloudKitManager
        self.rateLimiter = rateLimiter
        self.profileService = profileService
        self.notificationManager = notificationManager
        self.publicDatabase = CKContainer.default().publicCloudDatabase
        self.cacheManager = FollowingCacheManager()
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
    
    // MARK: - Follow/Unfollow Operations
    
    func follow(userID targetUserID: String) async throws {
        // Validate we're using CloudKit user IDs
        guard isValidCloudKitUserID(targetUserID) else {
            throw SocialServiceError.invalidUserID
        }
        
        let currentUserID = try getCurrentUserID()
        
        // Prevent self-follow
        guard currentUserID != targetUserID else {
            throw SocialServiceError.cannotFollowSelf
        }
        
        // Rate limiting check
        _ = try await rateLimiter.checkLimit(for: .follow, userID: currentUserID)
        
        // Check if already following (check cache first)
        let isAlreadyFollowing = try await isFollowing(userID: targetUserID)
        guard !isAlreadyFollowing else {
            throw SocialServiceError.alreadyFollowing
        }
        
        // Create relationship record
        let relationshipID = "\(currentUserID)_follows_\(targetUserID)"
        let relationship = UserRelationship(
            id: relationshipID,
            followerID: currentUserID,
            followingID: targetUserID,
            status: "active",
            notificationsEnabled: true
        )
        
        // Save to CloudKit
        let record = CKRecord(recordType: "UserRelationships", recordID: CKRecord.ID(recordName: relationshipID))
        record["id"] = relationshipID
        record["followerID"] = currentUserID
        record["followingID"] = targetUserID
        record["status"] = "active"
        record["notificationsEnabled"] = 1
        
        _ = try await publicDatabase.save(record)
        
        // Record action for rate limiting
        await rateLimiter.recordAction(.follow, userID: currentUserID)
        
        // Update caches
        await updateCachesAfterFollow(currentUserID: currentUserID, targetUserID: targetUserID)
        
        // Send notification to the followed user
        if let notificationManager = notificationManager,
           let followerProfile = try? await profileService.fetchProfile(userID: currentUserID) {
            await notificationManager.notifyNewFollower(from: followerProfile)
        }
        
        // Notify subscribers
        relationshipUpdatesSubject.send(relationship)
    }
    
    func unfollow(userID targetUserID: String) async throws {
        // Validate we're using CloudKit user IDs
        guard isValidCloudKitUserID(targetUserID) else {
            throw SocialServiceError.invalidUserID
        }
        
        let currentUserID = try getCurrentUserID()
        
        // Rate limiting check
        _ = try await rateLimiter.checkLimit(for: .unfollow, userID: currentUserID)
        
        // Find existing relationship
        let relationshipID = "\(currentUserID)_follows_\(targetUserID)"
        let recordID = CKRecord.ID(recordName: relationshipID)
        
        do {
            // Try to delete by known ID first (faster)
            _ = try await publicDatabase.deleteRecord(withID: recordID)
        } catch {
            // Fallback to query if direct delete fails
            let predicate = NSPredicate(
                format: "followerID == %@ AND followingID == %@ AND status == %@",
                currentUserID,
                targetUserID,
                "active"
            )
            
            let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
            let results = try await publicDatabase.records(matching: query, resultsLimit: 1)
            
            guard let (_, result) = results.matchResults.first,
                  let record = try? result.get()
            else {
                throw SocialServiceError.notFollowing
            }
            
            _ = try await publicDatabase.deleteRecord(withID: record.recordID)
        }
        
        // Record action for rate limiting
        await rateLimiter.recordAction(.unfollow, userID: currentUserID)
        
        // Update caches
        await updateCachesAfterUnfollow(currentUserID: currentUserID, targetUserID: targetUserID)
    }
    
    // MARK: - Query Operations
    
    func isFollowing(userID targetUserID: String) async throws -> Bool {
        let currentUserID = try getCurrentUserID()
        
        // Check cache first
        if let cachedStatus = cacheManager.getRelationship(from: currentUserID, to: targetUserID) {
            return cachedStatus == .following
        }
        
        // Query CloudKit using known record ID pattern
        let relationshipID = "\(currentUserID)_follows_\(targetUserID)"
        let recordID = CKRecord.ID(recordName: relationshipID)
        
        do {
            let record = try await publicDatabase.record(for: recordID)
            let status = record["status"] as? String ?? ""
            let relationshipStatus: RelationshipStatus = status == "active" ? .following : .notFollowing
            
            // Cache the result
            cacheManager.setRelationship(relationshipStatus, from: currentUserID, to: targetUserID)
            
            return relationshipStatus == .following
        } catch {
            // Record doesn't exist, not following
            cacheManager.setRelationship(.notFollowing, from: currentUserID, to: targetUserID)
            return false
        }
    }
    
    func getFollowers(for userID: String, limit: Int) async throws -> [UserProfile] {
        // Validate user ID
        guard isValidCloudKitUserID(userID) else {
            throw SocialServiceError.invalidUserID
        }
        
        // Check cache first (using page 0 for initial load)
        if let cachedProfiles = cacheManager.getFollowersList(for: userID, page: 0) {
            return Array(cachedProfiles.prefix(limit))
        }
        
        // Query CloudKit
        let predicate = NSPredicate(
            format: "followingID == %@ AND status == %@",
            userID,
            "active"
        )
        
        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: limit)
        
        // Extract follower IDs
        let followerUserIDs = results.matchResults.compactMap { _, result in
            try? result.get()["followerID"] as? String
        }
        
        // Fetch profiles using user IDs
        var profiles: [UserProfile] = []
        for followerUserID in followerUserIDs {
            if let profile = try? await profileService.fetchProfileByUserID(followerUserID) {
                profiles.append(profile)
            }
        }
        
        // Cache the results
        cacheManager.setFollowersList(profiles, for: userID, page: 0)
        
        return profiles
    }
    
    func getFollowing(for userID: String, limit: Int) async throws -> [UserProfile] {
        // Validate user ID
        guard isValidCloudKitUserID(userID) else {
            throw SocialServiceError.invalidUserID
        }
        
        // Check cache first
        if let cachedProfiles = cacheManager.getFollowingList(for: userID, page: 0) {
            return Array(cachedProfiles.prefix(limit))
        }
        
        // Query CloudKit
        let predicate = NSPredicate(
            format: "followerID == %@ AND status == %@",
            userID,
            "active"
        )
        
        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: limit)
        
        // Extract following IDs
        let followingUserIDs = results.matchResults.compactMap { _, result in
            try? result.get()["followingID"] as? String
        }
        
        // Fetch profiles using user IDs
        var profiles: [UserProfile] = []
        for followingUserID in followingUserIDs {
            if let profile = try? await profileService.fetchProfileByUserID(followingUserID) {
                profiles.append(profile)
            }
        }
        
        // Cache the results
        cacheManager.setFollowingList(profiles, for: userID, page: 0)
        
        return profiles
    }
    
    // MARK: - Count Operations
    
    func getFollowerCount(for userID: String) async throws -> Int {
        // Validate user ID
        guard isValidCloudKitUserID(userID) else {
            throw SocialServiceError.invalidUserID
        }
        
        // Check cache first
        if let cachedCount = cacheManager.getFollowerCount(for: userID) {
            return cachedCount
        }
        
        // Query CloudKit for count
        let predicate = NSPredicate(
            format: "followingID == %@ AND status == %@",
            userID,
            "active"
        )
        
        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)
        let count = results.matchResults.count
        
        // Update cache
        cacheManager.setFollowerCount(count, for: userID)
        followersCounts[userID] = count
        
        return count
    }
    
    func getFollowingCount(for userID: String) async throws -> Int {
        // Validate user ID
        guard isValidCloudKitUserID(userID) else {
            throw SocialServiceError.invalidUserID
        }
        
        // Check cache first
        if let cachedCount = cacheManager.getFollowingCount(for: userID) {
            return cachedCount
        }
        
        // Query CloudKit for count
        let predicate = NSPredicate(
            format: "followerID == %@ AND status == %@",
            userID,
            "active"
        )
        
        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)
        let count = results.matchResults.count
        
        // Update cache
        cacheManager.setFollowingCount(count, for: userID)
        followingCounts[userID] = count
        
        return count
    }
    
    // MARK: - Private Helpers
    
    private func getCurrentUserID() throws -> String {
        guard let userID = cloudKitManager.currentUserID else {
            throw SocialServiceError.notAuthenticated
        }
        return userID
    }
    
    private func isValidCloudKitUserID(_ userID: String) -> Bool {
        // CloudKit user IDs start with underscore and are 32 characters of hex
        let pattern = "^_[a-f0-9]{32}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: userID.utf16.count)
        return regex?.firstMatch(in: userID, options: [], range: range) != nil
    }
    
    private func updateCachesAfterFollow(currentUserID: String, targetUserID: String) async {
        // Invalidate relationship cache
        cacheManager.invalidateRelationship(from: currentUserID, to: targetUserID)
        cacheManager.setRelationship(.following, from: currentUserID, to: targetUserID)
        
        // Invalidate count caches
        cacheManager.invalidateFollowingData(for: currentUserID)
        cacheManager.invalidateFollowerData(for: targetUserID)
        
        // Update published counts
        if let currentCount = followingCounts[currentUserID] {
            followingCounts[currentUserID] = currentCount + 1
        }
        if let targetCount = followersCounts[targetUserID] {
            followersCounts[targetUserID] = targetCount + 1
        }
    }
    
    private func updateCachesAfterUnfollow(currentUserID: String, targetUserID: String) async {
        // Invalidate relationship cache
        cacheManager.invalidateRelationship(from: currentUserID, to: targetUserID)
        cacheManager.setRelationship(.notFollowing, from: currentUserID, to: targetUserID)
        
        // Invalidate count caches
        cacheManager.invalidateFollowingData(for: currentUserID)
        cacheManager.invalidateFollowerData(for: targetUserID)
        
        // Update published counts
        if let currentCount = followingCounts[currentUserID] {
            followingCounts[currentUserID] = max(0, currentCount - 1)
        }
        if let targetCount = followersCounts[targetUserID] {
            followersCounts[targetUserID] = max(0, targetCount - 1)
        }
    }
    
    // MARK: - Additional Protocol Methods (delegating to existing service)
    
    func blockUser(_ userID: String) async throws {
        // Validate user ID
        guard isValidCloudKitUserID(userID) else {
            throw SocialServiceError.invalidUserID
        }
        
        let currentUserID = try getCurrentUserID()
        
        // Rate limiting check
        _ = try await rateLimiter.checkLimit(for: .follow, userID: currentUserID)
        
        // Create block record
        let blockRecord = CKRecord(recordType: "BlockedUsers")
        blockRecord["blockerID"] = currentUserID
        blockRecord["blockedID"] = userID
        // creationDate is managed by CloudKit automatically
        
        // Save to CloudKit
        _ = try await publicDatabase.save(blockRecord)
        
        // Remove any existing relationships
        if try await isFollowing(userID: userID) {
            try await unfollow(userID: userID)
        }
        
        // Remove them as follower if they're following us
        let relationshipID = "\(userID)_follows_\(currentUserID)"
        let recordID = CKRecord.ID(recordName: relationshipID)
        
        do {
            _ = try await publicDatabase.deleteRecord(withID: recordID)
            await updateCachesAfterUnfollow(currentUserID: userID, targetUserID: currentUserID)
        } catch {
            // Relationship might not exist, ignore
        }
        
        // Record action for rate limiting
        await rateLimiter.recordAction(.follow, userID: currentUserID)
        
        // Invalidate all caches related to this user
        cacheManager.invalidateAllRelationships(for: userID)
    }
    
    func removeFollower(userID: String) async throws {
        // Validate user ID
        guard isValidCloudKitUserID(userID) else {
            throw SocialServiceError.invalidUserID
        }
        
        let currentUserID = try getCurrentUserID()
        
        // Rate limiting check
        _ = try await rateLimiter.checkLimit(for: .follow, userID: currentUserID)
        
        // Remove the relationship where this user follows us
        let relationshipID = "\(userID)_follows_\(currentUserID)"
        let recordID = CKRecord.ID(recordName: relationshipID)
        
        do {
            _ = try await publicDatabase.deleteRecord(withID: recordID)
        } catch {
            throw SocialServiceError.userNotFound
        }
        
        // Record action for rate limiting
        await rateLimiter.recordAction(.follow, userID: currentUserID)
        
        // Update caches
        await updateCachesAfterUnfollow(currentUserID: userID, targetUserID: currentUserID)
    }
    
    func checkRelationship(between userID: String, and targetID: String) async throws -> RelationshipStatus {
        // Validate user IDs
        guard isValidCloudKitUserID(userID), isValidCloudKitUserID(targetID) else {
            throw SocialServiceError.invalidUserID
        }
        
        // Check cache first
        if let cachedStatus = cacheManager.getRelationship(from: userID, to: targetID) {
            return cachedStatus
        }
        
        // Query CloudKit using known record ID pattern
        let relationshipID = "\(userID)_follows_\(targetID)"
        let recordID = CKRecord.ID(recordName: relationshipID)
        
        do {
            let record = try await publicDatabase.record(for: recordID)
            let status = record["status"] as? String ?? ""
            
            let relationshipStatus: RelationshipStatus
            switch status {
            case "active":
                relationshipStatus = .following
            case "blocked":
                relationshipStatus = .blocked
            case "muted":
                relationshipStatus = .muted
            default:
                relationshipStatus = .notFollowing
            }
            
            // Cache the result
            cacheManager.setRelationship(relationshipStatus, from: userID, to: targetID)
            
            return relationshipStatus
        } catch {
            // Record doesn't exist
            cacheManager.setRelationship(.notFollowing, from: userID, to: targetID)
            return .notFollowing
        }
    }
    
    func clearRelationshipCache() {
        cacheManager.clearAll()
        followersCounts.removeAll()
        followingCounts.removeAll()
    }
    
    // MARK: - Unimplemented Protocol Methods
    
    func requestFollow(userID: String, message: String?) async throws {
        // Check if target user has a private profile
        let targetProfile = try await profileService.fetchProfile(userID: userID)
        
        // If public profile, follow directly
        if targetProfile.privacyLevel == .publicProfile {
            try await follow(userID: userID)
        } else {
            // For private profiles, create a follow request
            let currentUserID = try getCurrentUserID()
            
            // Create follow request record (would need FollowRequests table in CloudKit)
            // For now, we'll send a notification and follow directly
            
            // Send follow request notification
            if let notificationManager = notificationManager,
               let requesterProfile = try? await profileService.fetchProfile(userID: currentUserID) {
                await notificationManager.notifyFollowRequest(from: requesterProfile)
            }
            
            // TODO: When FollowRequests table is implemented, create pending request instead
            // For MVP, just follow directly
            try await follow(userID: userID)
        }
    }
    
    func respondToFollowRequest(requestID: String, accept: Bool) async throws {
        // Parse the request ID format: "requesterID_targetID_timestamp"
        let components = requestID.split(separator: "_")
        guard components.count >= 2 else {
            throw SocialServiceError.invalidRequest
        }
        
        let requesterID = String(components[0])
        let targetID = components.count > 1 ? String(components[1]) : try getCurrentUserID()
        
        // Verify the current user is the target of this request
        let currentUserID = try getCurrentUserID()
        guard targetID == currentUserID else {
            throw SocialServiceError.unauthorized
        }
        
        if accept {
            // Create the follow relationship (requester follows current user)
            try await follow(userID: requesterID)
            
            // Send acceptance notification
            if let notificationManager = notificationManager,
               let accepterProfile = try? await profileService.fetchProfile(userID: currentUserID) {
                await notificationManager.notifyFollowAccepted(by: accepterProfile)
            }
        }
        
        // Update cache for both users
        cacheManager.invalidateFollowerData(for: currentUserID)
        cacheManager.invalidateFollowingData(for: requesterID)
    }
    
    func getMutualFollowers(with userID: String, limit: Int) async throws -> [UserProfile] {
        // TODO: Implement
        []
    }
    
    func unblockUser(_ userID: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }
    
    func muteUser(_ userID: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }
    
    func unmuteUser(_ userID: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }
    
    func getBlockedUsers() async throws -> [String] {
        // TODO: Implement
        []
    }
    
    func getMutedUsers() async throws -> [String] {
        // TODO: Implement
        []
    }
    
    func getPendingFollowRequests() async throws -> [FollowRequest] {
        // TODO: Implement
        []
    }
    
    func getSentFollowRequests() async throws -> [FollowRequest] {
        // TODO: Implement
        []
    }
    
    func acceptFollowRequest(_ requestID: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }
    
    func rejectFollowRequest(_ requestID: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }
    
    func cancelFollowRequest(requestID: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }
    
    func preloadRelationships(for userIDs: [String]) async {
        // TODO: Implement batch preloading
    }
}

// MARK: - Error Types

extension SocialServiceError {
    static let invalidUserID = SocialServiceError.invalidRequest
    static let notAuthenticated = SocialServiceError.authenticationRequired
    static let cannotFollowSelf = SocialServiceError.invalidRequest
    static let alreadyFollowing = SocialServiceError.invalidRequest
    static let notFollowing = SocialServiceError.invalidRequest
}
