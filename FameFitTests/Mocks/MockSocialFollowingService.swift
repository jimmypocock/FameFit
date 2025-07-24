//
//  MockSocialFollowingService.swift
//  FameFitTests
//
//  Mock implementation of social following service for testing
//

import Foundation
import Combine
@testable import FameFit

final class MockSocialFollowingService: SocialFollowingServicing {
    // Mock state
    var relationships: [String: Set<String>] = [:] // userId -> Set of following
    var blockedUsers: [String: Set<String>] = [:] // userId -> Set of blocked
    var followRequests: [FollowRequest] = []
    var shouldFailNextAction = false
    var mockError: SocialServiceError?
    
    // Publishers
    @Published private var followersCounts: [String: Int] = [:]
    @Published private var followingCounts: [String: Int] = [:]
    private let relationshipUpdatesSubject = PassthroughSubject<UserRelationship, Never>()
    
    // Publisher conformance
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
        if shouldFailNextAction {
            shouldFailNextAction = false
            throw mockError ?? SocialServiceError.networkError(NSError(domain: "MockError", code: 1))
        }
        
        let currentUserId = "mock-current-user"
        
        // Add to relationships
        if relationships[currentUserId] == nil {
            relationships[currentUserId] = []
        }
        relationships[currentUserId]?.insert(userId)
        
        // Update counts
        await updateCounts()
        
        // Send update
        let relationship = UserRelationship(
            id: UserRelationship.makeId(followerID: currentUserId, followingID: userId),
            followerID: currentUserId,
            followingID: userId,
            createdTimestamp: Date(),
            status: "active",
            notificationsEnabled: true
        )
        relationshipUpdatesSubject.send(relationship)
    }
    
    func unfollow(userId: String) async throws {
        if shouldFailNextAction {
            shouldFailNextAction = false
            throw mockError ?? SocialServiceError.networkError(NSError(domain: "MockError", code: 1))
        }
        
        let currentUserId = "mock-current-user"
        relationships[currentUserId]?.remove(userId)
        
        await updateCounts()
    }
    
    func requestFollow(userId: String, message: String?) async throws {
        if shouldFailNextAction {
            shouldFailNextAction = false
            throw mockError ?? SocialServiceError.networkError(NSError(domain: "MockError", code: 1))
        }
        
        let request = FollowRequest(
            id: UUID().uuidString,
            requesterId: "mock-current-user",
            requesterProfile: nil,
            targetId: userId,
            status: "pending",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(604800),
            message: message
        )
        followRequests.append(request)
    }
    
    func respondToFollowRequest(requestId: String, accept: Bool) async throws {
        if let index = followRequests.firstIndex(where: { $0.id == requestId }) {
            followRequests[index] = FollowRequest(
                id: followRequests[index].id,
                requesterId: followRequests[index].requesterId,
                requesterProfile: followRequests[index].requesterProfile,
                targetId: followRequests[index].targetId,
                status: accept ? "accepted" : "rejected",
                createdAt: followRequests[index].createdAt,
                expiresAt: followRequests[index].expiresAt,
                message: followRequests[index].message
            )
            
            if accept {
                // Add to relationships
                let requesterId = followRequests[index].requesterId
                let targetId = followRequests[index].targetId
                if relationships[requesterId] == nil {
                    relationships[requesterId] = []
                }
                relationships[requesterId]?.insert(targetId)
            }
        }
    }
    
    // MARK: - Relationship Queries
    
    func getFollowers(for userId: String, limit: Int) async throws -> [UserProfile] {
        // Find all users who follow this user
        var followers: [UserProfile] = []
        
        for (followerId, following) in relationships {
            if following.contains(userId) {
                followers.append(UserProfile.mockProfile.with(id: followerId))
            }
        }
        
        return Array(followers.prefix(limit))
    }
    
    func getFollowing(for userId: String, limit: Int) async throws -> [UserProfile] {
        if shouldFailNextAction {
            shouldFailNextAction = false
            throw mockError ?? SocialServiceError.networkError(NSError(domain: "MockError", code: 1))
        }
        
        let followingIds = relationships[userId] ?? []
        let profiles = followingIds.map { UserProfile.mockProfile.with(id: $0) }
        return Array(profiles.prefix(limit))
    }
    
    func checkRelationship(between userId: String, and targetId: String) async throws -> RelationshipStatus {
        if blockedUsers[userId]?.contains(targetId) == true {
            return .blocked
        }
        
        let isFollowing = relationships[userId]?.contains(targetId) == true
        let isFollowedBy = relationships[targetId]?.contains(userId) == true
        
        if isFollowing && isFollowedBy {
            return .mutualFollow
        } else if isFollowing {
            return .following
        } else if followRequests.contains(where: { $0.requesterId == userId && $0.targetId == targetId && $0.status == "pending" }) {
            return .pending
        } else {
            return .notFollowing
        }
    }
    
    func getMutualFollowers(with userId: String, limit: Int) async throws -> [UserProfile] {
        // Mock implementation
        return []
    }
    
    // MARK: - Counts
    
    func getFollowerCount(for userId: String) async throws -> Int {
        var count = 0
        for (_, following) in relationships {
            if following.contains(userId) {
                count += 1
            }
        }
        return count
    }
    
    func getFollowingCount(for userId: String) async throws -> Int {
        return relationships[userId]?.count ?? 0
    }
    
    // MARK: - Block/Mute Operations
    
    func blockUser(_ userId: String) async throws {
        let currentUserId = "mock-current-user"
        
        // Remove from following
        relationships[currentUserId]?.remove(userId)
        relationships[userId]?.remove(currentUserId)
        
        // Add to blocked
        if blockedUsers[currentUserId] == nil {
            blockedUsers[currentUserId] = []
        }
        blockedUsers[currentUserId]?.insert(userId)
    }
    
    func unblockUser(_ userId: String) async throws {
        let currentUserId = "mock-current-user"
        blockedUsers[currentUserId]?.remove(userId)
    }
    
    func muteUser(_ userId: String) async throws {
        // Mock implementation
    }
    
    func unmuteUser(_ userId: String) async throws {
        // Mock implementation
    }
    
    func getBlockedUsers() async throws -> [String] {
        return Array(blockedUsers["mock-current-user"] ?? [])
    }
    
    func getMutedUsers() async throws -> [String] {
        return []
    }
    
    // MARK: - Follow Requests
    
    func getPendingFollowRequests() async throws -> [FollowRequest] {
        return followRequests.filter { $0.targetId == "mock-current-user" && $0.status == "pending" }
    }
    
    func getSentFollowRequests() async throws -> [FollowRequest] {
        return followRequests.filter { $0.requesterId == "mock-current-user" && $0.status == "pending" }
    }
    
    func cancelFollowRequest(requestId: String) async throws {
        followRequests.removeAll { $0.id == requestId }
    }
    
    // MARK: - Caching
    
    func clearRelationshipCache() {
        // No-op for mock
    }
    
    func preloadRelationships(for userIds: [String]) async {
        // No-op for mock
    }
    
    // MARK: - Helper Methods
    
    private func updateCounts() async {
        // Update follower counts for all users
        var newFollowersCounts: [String: Int] = [:]
        var newFollowingCounts: [String: Int] = [:]
        
        for (userId, _) in relationships {
            newFollowingCounts[userId] = try? await getFollowingCount(for: userId)
            newFollowersCounts[userId] = try? await getFollowerCount(for: userId)
        }
        
        followersCounts = newFollowersCounts
        followingCounts = newFollowingCounts
    }
}

// Helper extension for testing
extension UserProfile {
    func with(id: String) -> UserProfile {
        return UserProfile(
            id: id,
            userID: "user-\(id)",
            username: "user_\(id)",
            displayName: "User \(id)",
            bio: bio,
            workoutCount: workoutCount,
            totalXP: totalXP,
            joinedDate: joinedDate,
            lastUpdated: lastUpdated,
            isVerified: isVerified,
            privacyLevel: privacyLevel,
            profileImageURL: profileImageURL,
            headerImageURL: headerImageURL
        )
    }
}