//
//  SocialFollowingService.swift
//  FameFit
//
//  Social following service for managing user relationships
//

import CloudKit
import Combine
import Foundation

// MARK: - Social Following Service

final class SocialFollowingService: SocialFollowingServicing, @unchecked Sendable {
    // Dependencies
    private let cloudKitManager: CloudKitManager
    private let rateLimiter: RateLimitingServicing
    private let profileService: UserProfileServicing
    private let publicDatabase: CKDatabase

    // Published state
    @Published private var followersCounts: [String: Int] = [:]
    @Published private var followingCounts: [String: Int] = [:]
    private let relationshipUpdatesSubject = PassthroughSubject<UserRelationship, Never>()

    init(
        cloudKitManager: CloudKitManager,
        rateLimiter: RateLimitingServicing,
        profileService: UserProfileServicing
    ) {
        self.cloudKitManager = cloudKitManager
        self.rateLimiter = rateLimiter
        self.profileService = profileService
        publicDatabase = CKContainer.default().publicCloudDatabase
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

    func follow(userId targetUserId: String) async throws {
        // Rate limiting check
        _ = try await rateLimiter.checkLimit(for: .follow, userId: getCurrentUserId())

        // Check if already following
        let isAlreadyFollowing = try await isFollowing(userId: targetUserId)
        guard !isAlreadyFollowing else {
            throw SocialServiceError.invalidRequest
        }

        // Create relationship record
        let relationship = UserRelationship(
            id: UUID().uuidString,
            followerID: getCurrentUserId(),
            followingID: targetUserId,
            status: "active",
            notificationsEnabled: true
        )

        // Save to CloudKit
        let record = CKRecord(recordType: "UserRelationships")
        record["id"] = relationship.id
        record["followerID"] = relationship.followerID
        record["followingID"] = relationship.followingID
        record["status"] = relationship.status
        record["notificationsEnabled"] = relationship.notificationsEnabled ? 1 : 0

        _ = try await publicDatabase.save(record)

        // Record action for rate limiting
        await rateLimiter.recordAction(.follow, userId: getCurrentUserId())

        // Update cached counts
        await updateFollowingCount(for: getCurrentUserId(), increment: true)
        await updateFollowerCount(for: targetUserId, increment: true)

        // Notify subscribers
        relationshipUpdatesSubject.send(relationship)
    }

    func unfollow(userId targetUserId: String) async throws {
        // Rate limiting check
        _ = try await rateLimiter.checkLimit(for: .unfollow, userId: getCurrentUserId())

        // Find existing relationship
        let currentUserId = getCurrentUserId()
        let predicate = NSPredicate(
            format: "followerID == %@ AND followingID == %@ AND status == %@",
            currentUserId,
            targetUserId,
            "active"
        )

        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: 1)

        guard let (_, result) = results.matchResults.first,
              let record = try? result.get()
        else {
            throw SocialServiceError.invalidRequest
        }

        // Delete relationship
        _ = try await publicDatabase.deleteRecord(withID: record.recordID)

        // Record action for rate limiting
        await rateLimiter.recordAction(.unfollow, userId: currentUserId)

        // Update cached counts
        await updateFollowingCount(for: currentUserId, increment: false)
        await updateFollowerCount(for: targetUserId, increment: false)
    }

    // MARK: - Query Operations

    func isFollowing(userId targetUserId: String) async throws -> Bool {
        let currentUserId = getCurrentUserId()

        // Query CloudKit
        let predicate = NSPredicate(
            format: "followerID == %@ AND followingID == %@ AND status == %@",
            currentUserId,
            targetUserId,
            "active"
        )

        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: 1)

        return !results.matchResults.isEmpty
    }

    func getFollowers(for userId: String, limit: Int) async throws -> [UserProfile] {
        let predicate = NSPredicate(
            format: "followingID == %@ AND status == %@",
            userId,
            "active"
        )

        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        // Note: Sorting disabled until CloudKit indexes are updated to mark creationDate as SORTABLE
        // query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let results = try await publicDatabase.records(matching: query, resultsLimit: limit)
        return try await processFollowerResults(results)
    }
    
    private func processFollowerResults(_ results: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)) async throws -> [UserProfile] {
        // Extract follower IDs
        let followerIds = results.matchResults.compactMap { _, result in
            try? result.get()["followerID"] as? String
        }

        // Fetch profiles in batch
        await profileService.preloadProfiles(followerIds)

        // Fetch individual profiles
        var profiles: [UserProfile] = []
        for followerId in followerIds {
            if let profile = try? await profileService.fetchProfile(userId: followerId) {
                profiles.append(profile)
            }
        }
        
        return profiles
    }

    func getFollowing(for userId: String, limit: Int) async throws -> [UserProfile] {
        let predicate = NSPredicate(
            format: "followerID == %@ AND status == %@",
            userId,
            "active"
        )

        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        // Note: Sorting disabled until CloudKit indexes are updated to mark creationDate as SORTABLE
        // query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let results = try await publicDatabase.records(matching: query, resultsLimit: limit)

        // Extract following IDs
        let followingIds = results.matchResults.compactMap { _, result in
            try? result.get()["followingID"] as? String
        }

        // Fetch profiles in batch
        await profileService.preloadProfiles(followingIds)

        // Fetch individual profiles
        var profiles: [UserProfile] = []
        for followingId in followingIds {
            if let profile = try? await profileService.fetchProfile(userId: followingId) {
                profiles.append(profile)
            }
        }
        
        return profiles
    }

    // MARK: - Blocking Operations

    func removeFollower(userId: String) async throws {
        // Rate limiting check
        _ = try await rateLimiter.checkLimit(for: .follow, userId: getCurrentUserId())

        let currentUserId = getCurrentUserId()

        // Find the relationship where this user follows us
        let predicate = NSPredicate(
            format: "followerID == %@ AND followingID == %@ AND status == %@",
            userId,
            currentUserId,
            "active"
        )

        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: 1)

        guard let (_, result) = results.matchResults.first,
              let record = try? result.get()
        else {
            throw SocialServiceError.userNotFound
        }

        // Delete the relationship
        _ = try await publicDatabase.deleteRecord(withID: record.recordID)

        // Record action for rate limiting
        await rateLimiter.recordAction(.follow, userId: currentUserId)

        // Update cached counts
        await updateFollowerCount(for: currentUserId, increment: false)
        await updateFollowingCount(for: userId, increment: false)
    }

    func blockUser(_ userId: String) async throws {
        // Rate limiting check
        _ = try await rateLimiter.checkLimit(for: .follow, userId: getCurrentUserId())

        let currentUserId = getCurrentUserId()

        // Create block record
        let blockRecord = CKRecord(recordType: "BlockedUsers")
        blockRecord["blockerID"] = currentUserId
        blockRecord["blockedID"] = userId
        blockRecord["createdTimestamp"] = Date()

        // Save to CloudKit
        _ = try await publicDatabase.save(blockRecord)

        // Remove any existing relationships
        // 1. Unfollow them if we're following
        if try await isFollowing(userId: userId) {
            try await unfollow(userId: userId)
        }

        // 2. Remove them as follower if they're following us
        let followerPredicate = NSPredicate(
            format: "followerID == %@ AND followingID == %@ AND status == %@",
            userId,
            currentUserId,
            "active"
        )

        let query = CKQuery(recordType: "UserRelationships", predicate: followerPredicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: 1)

        if let (_, result) = results.matchResults.first,
           let record = try? result.get() {
            _ = try await publicDatabase.deleteRecord(withID: record.recordID)
            await updateFollowerCount(for: currentUserId, increment: false)
            await updateFollowingCount(for: userId, increment: false)
        }

        // Record action for rate limiting
        await rateLimiter.recordAction(.follow, userId: currentUserId)
    }

    // MARK: - Count Operations

    func getFollowerCount(for userId: String) async throws -> Int {
        // Return cached value if available
        if let count = followersCounts[userId] {
            return count
        }

        // Query CloudKit for count
        let predicate = NSPredicate(
            format: "followingID == %@ AND status == %@",
            userId,
            "active"
        )

        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: 1_000)
        let count = results.matchResults.count

        // Update cache
        followersCounts[userId] = count

        return count
    }

    func getFollowingCount(for userId: String) async throws -> Int {
        // Return cached value if available
        if let count = followingCounts[userId] {
            return count
        }

        // Query CloudKit for count
        let predicate = NSPredicate(
            format: "followerID == %@ AND status == %@",
            userId,
            "active"
        )

        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: 1_000)
        let count = results.matchResults.count

        // Update cache
        followingCounts[userId] = count

        return count
    }

    // MARK: - Private Helpers

    private func getCurrentUserId() -> String {
        cloudKitManager.currentUserID ?? "unknown"
    }

    private func updateFollowerCount(for userId: String, increment: Bool) async {
        let currentCount = followersCounts[userId] ?? 0
        followersCounts[userId] = increment ? currentCount + 1 : max(0, currentCount - 1)
    }

    private func updateFollowingCount(for userId: String, increment: Bool) async {
        let currentCount = followingCounts[userId] ?? 0
        followingCounts[userId] = increment ? currentCount + 1 : max(0, currentCount - 1)
    }

    // MARK: - Additional Protocol Methods

    func requestFollow(userId: String, message _: String?) async throws {
        // For now, just call follow directly
        // In future, this could create a follow request record for private accounts
        try await follow(userId: userId)
    }

    func respondToFollowRequest(requestId _: String, accept _: Bool) async throws {
        // TODO: Implement when follow requests are supported
        throw SocialServiceError.invalidRequest
    }

    func checkRelationship(between userId: String, and targetId: String) async throws -> RelationshipStatus {
        // Check if userId follows targetId
        let predicate = NSPredicate(
            format: "followerID == %@ AND followingID == %@",
            userId,
            targetId
        )

        let query = CKQuery(recordType: "UserRelationships", predicate: predicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: 1)

        if let (_, result) = results.matchResults.first,
           let record = try? result.get(),
           let status = record["status"] as? String {
            switch status {
            case "active":
                return .following
            case "blocked":
                return .blocked
            case "muted":
                return .muted
            default:
                return .notFollowing
            }
        }

        return .notFollowing
    }

    func clearRelationshipCache() {
        followersCounts.removeAll()
        followingCounts.removeAll()
    }

    // MARK: - Unimplemented Protocol Methods

    func getMutualFollowers(with _: String, limit _: Int) async throws -> [UserProfile] {
        // TODO: Implement
        []
    }

    func unblockUser(_: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }

    func muteUser(_: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }

    func unmuteUser(_: String) async throws {
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

    func acceptFollowRequest(_: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }

    func rejectFollowRequest(_: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }

    func cancelFollowRequest(requestId _: String) async throws {
        // TODO: Implement
        throw SocialServiceError.invalidRequest
    }

    func preloadRelationships(for _: [String]) async {
        // TODO: Implement batch preloading
    }
}
