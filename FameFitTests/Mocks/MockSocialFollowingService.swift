//
//  MockSocialFollowingService.swift
//  FameFitTests
//
//  Mock implementation of SocialFollowingServicing for testing
//

import Combine
@testable import FameFit
import Foundation

final class MockSocialFollowingService: SocialFollowingServicing {
    // Mock data storage
    var relationships: [String: Set<String>] = [:] // userId -> Set of followingIds
    var blockedUsers: [String: Set<String>] = [:] // userId -> Set of blockedIds
    var followRequests: [FollowRequest] = []
    var shouldFail = false
    var shouldFailNextAction = false
    var mockError: SocialServiceError = .networkError(NSError(domain: "MockError", code: 0))
    var getFollowingCallCount = 0

    // Publishers
    private let followersCountSubject = CurrentValueSubject<[String: Int], Never>([:])
    private let followingCountSubject = CurrentValueSubject<[String: Int], Never>([:])
    private let relationshipUpdatesSubject = PassthroughSubject<UserRelationship, Never>()

    var followersCountPublisher: AnyPublisher<[String: Int], Never> {
        followersCountSubject.eraseToAnyPublisher()
    }

    var followingCountPublisher: AnyPublisher<[String: Int], Never> {
        followingCountSubject.eraseToAnyPublisher()
    }

    var relationshipUpdatesPublisher: AnyPublisher<UserRelationship, Never> {
        relationshipUpdatesSubject.eraseToAnyPublisher()
    }

    // Follow operations
    func follow(userId: String) async throws {
        if shouldFail || shouldFailNextAction {
            shouldFailNextAction = false
            throw mockError
        }

        let currentUserId = "mock-current-user"
        var following = relationships[currentUserId] ?? []
        following.insert(userId)
        relationships[currentUserId] = following

        // Emit relationship update
        let relationship = UserRelationship(
            id: UserRelationship.makeId(followerID: currentUserId, followingID: userId),
            followerID: currentUserId,
            followingID: userId,
            status: "active",
            notificationsEnabled: true
        )
        relationshipUpdatesSubject.send(relationship)

        updateCounts()
    }

    func unfollow(userId: String) async throws {
        if shouldFail { throw mockError }

        let currentUserId = "mock-current-user"
        relationships[currentUserId]?.remove(userId)

        updateCounts()
    }

    func requestFollow(userId: String, message: String?) async throws {
        if shouldFail { throw mockError }
        
        let request = FollowRequest(
            id: UUID().uuidString,
            requesterId: "mock-current-user",
            requesterProfile: nil,
            targetId: userId,
            status: "pending",
            createdTimestamp: Date(),
            expiresAt: Date().addingTimeInterval(604_800),
            message: message
        )
        followRequests.append(request)
    }

    func respondToFollowRequest(requestId _: String, accept _: Bool) async throws {
        if shouldFail { throw mockError }
        // Mock implementation - no-op
    }

    // Relationship queries
    func getFollowers(for userId: String, limit: Int) async throws -> [UserProfile] {
        if shouldFail { throw mockError }

        // Find all users who follow the given userId
        var followers: [String] = []
        for (followerId, followingSet) in relationships {
            if followingSet.contains(userId) {
                followers.append(followerId)
            }
        }

        return followers.prefix(limit).map { id in
            UserProfile(
                id: id,
                userID: id,
                username: "user\(id)",
                displayName: "Mock User \(id)",
                bio: "Mock bio",
                workoutCount: 10,
                totalXP: 100,
                joinedDate: Date(),
                lastUpdated: Date(),
                isVerified: false,
                privacyLevel: .publicProfile,
                profileImageURL: nil
            )
        }
    }

    func getFollowing(for userId: String, limit: Int) async throws -> [UserProfile] {
        getFollowingCallCount += 1

        if shouldFail || shouldFailNextAction {
            shouldFailNextAction = false
            throw mockError
        }

        let following = relationships[userId] ?? []
        return Array(following).prefix(limit).map { id in
            UserProfile(
                id: id,
                userID: id,
                username: "user\(id)",
                displayName: "Mock User \(id)",
                bio: "Mock bio",
                workoutCount: 10,
                totalXP: 100,
                joinedDate: Date(),
                lastUpdated: Date(),
                isVerified: false,
                privacyLevel: .publicProfile,
                profileImageURL: nil
            )
        }
    }

    func checkRelationship(between userId: String, and targetId: String) async throws -> RelationshipStatus {
        if shouldFail { throw mockError }

        if blockedUsers[userId]?.contains(targetId) == true {
            return .blocked
        }

        let userFollowsTarget = relationships[userId]?.contains(targetId) == true
        let targetFollowsUser = relationships[targetId]?.contains(userId) == true

        if userFollowsTarget && targetFollowsUser {
            return .mutualFollow
        } else if userFollowsTarget {
            return .following
        }

        return .notFollowing
    }

    func getMutualFollowers(with _: String, limit _: Int) async throws -> [UserProfile] {
        if shouldFail { throw mockError }
        return []
    }

    // Counts
    func getFollowerCount(for userId: String) async throws -> Int {
        if shouldFail { throw mockError }

        var count = 0
        for (_, followingSet) in relationships {
            if followingSet.contains(userId) {
                count += 1
            }
        }
        return count
    }

    func getFollowingCount(for userId: String) async throws -> Int {
        if shouldFail { throw mockError }
        return relationships[userId]?.count ?? 0
    }

    // Block/Mute operations
    func blockUser(_ userId: String) async throws {
        if shouldFail { throw mockError }

        let currentUserId = "mock-current-user"
        var blocked = blockedUsers[currentUserId] ?? []
        blocked.insert(userId)
        blockedUsers[currentUserId] = blocked

        // Also unfollow if following
        relationships[currentUserId]?.remove(userId)
        relationships[userId]?.remove(currentUserId)
    }

    func unblockUser(_ userId: String) async throws {
        if shouldFail { throw mockError }

        let currentUserId = "mock-current-user"
        blockedUsers[currentUserId]?.remove(userId)
    }

    func muteUser(_: String) async throws {
        if shouldFail { throw mockError }
        // Mock implementation - no-op
    }

    func unmuteUser(_: String) async throws {
        if shouldFail { throw mockError }
        // Mock implementation - no-op
    }

    func getBlockedUsers() async throws -> [String] {
        if shouldFail { throw mockError }
        return Array(blockedUsers["mock-current-user"] ?? [])
    }

    func getMutedUsers() async throws -> [String] {
        if shouldFail { throw mockError }
        return []
    }

    // Follow requests
    func getPendingFollowRequests() async throws -> [FollowRequest] {
        if shouldFail { throw mockError }
        return []
    }

    func getSentFollowRequests() async throws -> [FollowRequest] {
        if shouldFail { throw mockError }
        return followRequests.filter { $0.requesterId == "mock-current-user" }
    }

    func cancelFollowRequest(requestId _: String) async throws {
        if shouldFail { throw mockError }
        // Mock implementation - no-op
    }

    // Caching
    func clearRelationshipCache() {
        // Mock implementation - no-op
    }

    func preloadRelationships(for _: [String]) async {
        // Mock implementation - no-op
    }
    
    func refreshCounts(for userId: String) async throws -> (followers: Int, following: Int) {
        if shouldFail { throw mockError }
        
        // Calculate counts directly from relationships
        var followers = 0
        var following = 0
        
        // Count following (users this userId follows)
        following = relationships[userId]?.count ?? 0
        
        // Count followers (users who follow this userId)
        for (_, followingSet) in relationships {
            if followingSet.contains(userId) {
                followers += 1
            }
        }
        
        return (followers, following)
    }

    // Test helpers
    func reset() {
        relationships.removeAll()
        blockedUsers.removeAll()
        followRequests.removeAll()
        shouldFail = false
        shouldFailNextAction = false
        getFollowingCallCount = 0
        updateCounts()
    }

    private func updateCounts() {
        var followerCounts: [String: Int] = [:]
        var followingCounts: [String: Int] = [:]

        for (userId, following) in relationships {
            followingCounts[userId] = following.count

            for followedId in following {
                followerCounts[followedId] = (followerCounts[followedId] ?? 0) + 1
            }
        }

        followersCountSubject.send(followerCounts)
        followingCountSubject.send(followingCounts)
    }
}
