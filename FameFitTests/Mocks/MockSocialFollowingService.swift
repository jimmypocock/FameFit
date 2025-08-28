//
//  MockSocialFollowingService.swift
//  FameFitTests
//
//  Mock implementation of SocialFollowingProtocol for testing
//

import Combine
import Foundation

@testable import FameFit

final class MockSocialFollowingService: SocialFollowingProtocol {
  // Mock data storage
  var relationships: [String: Set<String>] = [:]  // userID -> Set of followingIds
  var blockedUsers: [String: Set<String>] = [:]  // userID -> Set of blockedIds
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
  func follow(userID: String) async throws {
    if shouldFail || shouldFailNextAction {
      shouldFailNextAction = false
      throw mockError
    }

    let currentUserId = "mock-current-user"
    var following = relationships[currentUserId] ?? []
    following.insert(userID)
    relationships[currentUserId] = following

    // Emit relationship update
    let relationship = UserRelationship(
      id: "\(currentUserId)_\(userID)",
      followerID: currentUserId,
      followingID: userID,
      status: "active",
      notificationsEnabled: true
    )
    relationshipUpdatesSubject.send(relationship)

    updateCounts()
  }

  func unfollow(userID: String) async throws {
    if shouldFail { throw mockError }

    let currentUserId = "mock-current-user"
    relationships[currentUserId]?.remove(userID)

    updateCounts()
  }

  func requestFollow(userID: String, message: String?) async throws {
    if shouldFail { throw mockError }

    let request = FollowRequest(
      id: UUID().uuidString,
      requesterID: "mock-current-user",
      requesterProfile: nil,
      targetID: userID,
      status: "pending",
      creationDate: Date(),
      expiresAt: Date().addingTimeInterval(604_800),
      message: message
    )
    followRequests.append(request)
  }

  func respondToFollowRequest(requestID _: String, accept _: Bool) async throws {
    if shouldFail { throw mockError }
    // Mock implementation - no-op
  }

  // Relationship queries
  func getFollowers(for userID: String, limit: Int) async throws -> [UserProfile] {
    if shouldFail { throw mockError }

    // Find all users who follow the given userID
    var followers: [String] = []
    for (followerId, followingSet) in relationships {
      if followingSet.contains(userID) {
        followers.append(followerId)
      }
    }

    return followers.prefix(limit).map { id in
      UserProfile(
        id: id,
        userID: id,
        username: "user\(id)",
        bio: "Mock bio",
        workoutCount: 10,
        totalXP: 100,
        creationDate: Date(),
        modificationDate: Date(),
        isVerified: false,
        privacyLevel: .publicProfile
      )
    }
  }

  func getFollowing(for userID: String, limit: Int) async throws -> [UserProfile] {
    getFollowingCallCount += 1

    if shouldFail || shouldFailNextAction {
      shouldFailNextAction = false
      throw mockError
    }

    let following = relationships[userID] ?? []
    return Array(following).prefix(limit).map { id in
      UserProfile(
        id: id,
        userID: id,
        username: "user\(id)",
        bio: "Mock bio",
        workoutCount: 10,
        totalXP: 100,
        creationDate: Date(),
        modificationDate: Date(),
        isVerified: false,
        privacyLevel: .publicProfile
      )
    }
  }

  func checkRelationship(between userID: String, and targetID: String) async throws
    -> RelationshipStatus
  {
    if shouldFail { throw mockError }

    if blockedUsers[userID]?.contains(targetID) == true {
      return .blocked
    }

    let userFollowsTarget = relationships[userID]?.contains(targetID) == true
    let targetFollowsUser = relationships[targetID]?.contains(userID) == true

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
  func getFollowerCount(for userID: String) async throws -> Int {
    if shouldFail { throw mockError }

    var count = 0
    for (_, followingSet) in relationships {
      if followingSet.contains(userID) {
        count += 1
      }
    }
    return count
  }

  func getFollowingCount(for userID: String) async throws -> Int {
    if shouldFail { throw mockError }
    return relationships[userID]?.count ?? 0
  }

  // Block/Mute operations
  func blockUser(_ userID: String) async throws {
    if shouldFail { throw mockError }

    let currentUserId = "mock-current-user"
    var blocked = blockedUsers[currentUserId] ?? []
    blocked.insert(userID)
    blockedUsers[currentUserId] = blocked

    // Also unfollow if following
    relationships[currentUserId]?.remove(userID)
    relationships[userID]?.remove(currentUserId)
  }

  func unblockUser(_ userID: String) async throws {
    if shouldFail { throw mockError }

    let currentUserId = "mock-current-user"
    blockedUsers[currentUserId]?.remove(userID)
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
    return followRequests.filter { $0.requesterID == "mock-current-user" }
  }

  func cancelFollowRequest(requestID _: String) async throws {
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

  func refreshCounts(for userID: String) async throws -> (followers: Int, following: Int) {
    if shouldFail { throw mockError }

    // Calculate counts directly from relationships
    var followers = 0
    var following = 0

    // Count following (users this userID follows)
    following = relationships[userID]?.count ?? 0

    // Count followers (users who follow this userID)
    for (_, followingSet) in relationships {
      if followingSet.contains(userID) {
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

    for (userID, following) in relationships {
      followingCounts[userID] = following.count

      for followedId in following {
        followerCounts[followedId] = (followerCounts[followedId] ?? 0) + 1
      }
    }

    followersCountSubject.send(followerCounts)
    followingCountSubject.send(followingCounts)
  }
}
