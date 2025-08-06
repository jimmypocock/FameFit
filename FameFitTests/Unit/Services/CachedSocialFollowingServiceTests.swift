//
//  CachedSocialFollowingServiceTests.swift
//  FameFitTests
//
//  Tests for the cached social following service
//

import XCTest
@testable import FameFit
import CloudKit

class CachedSocialFollowingServiceTests: XCTestCase {
    var sut: CachedSocialFollowingService!
    var mockCloudKitManager: MockCloudKitManager!
    var mockRateLimiter: MockRateLimitingService!
    var mockProfileService: MockUserProfileService!
    
    override func setUp() {
        super.setUp()
        
        mockCloudKitManager = MockCloudKitManager()
        mockRateLimiter = MockRateLimitingService()
        mockProfileService = MockUserProfileService()
        
        sut = CachedSocialFollowingService(
            cloudKitManager: mockCloudKitManager,
            rateLimiter: mockRateLimiter,
            profileService: mockProfileService
        )
    }
    
    override func tearDown() {
        sut = nil
        mockCloudKitManager = nil
        mockRateLimiter = nil
        mockProfileService = nil
        
        super.tearDown()
    }
    
    // MARK: - ID Validation Tests
    
    func testValidatesCloudKitUserID() async throws {
        // Valid CloudKit user ID format
        let validID = "_65016d98fd8579ab704d38d23d066b2f"
        
        // Should not throw for valid ID
        try await sut.follow(userId: validID)
        
        // Invalid IDs should throw
        let invalidIDs = [
            "6F835AC7-8100-4B8B-95F5-94AB7F431AA0", // Profile UUID
            "not_a_valid_id",
            "_short",
            "_65016d98fd8579ab704d38d23d066b2f_toolong"
        ]
        
        for invalidID in invalidIDs {
            do {
                try await sut.follow(userId: invalidID)
                XCTFail("Should have thrown for invalid ID: \(invalidID)")
            } catch {
                // Expected error
                XCTAssertTrue(error is SocialServiceError)
            }
        }
    }
    
    // MARK: - Caching Tests
    
    func testCachesFollowerCounts() async throws {
        let userID = "_65016d98fd8579ab704d38d23d066b2f"
        
        // First call should hit the service
        let count1 = try await sut.getFollowersCount(for: userID)
        XCTAssertEqual(mockCloudKitManager.countQueryCalls, 1)
        
        // Second call should use cache
        let count2 = try await sut.getFollowersCount(for: userID)
        XCTAssertEqual(mockCloudKitManager.countQueryCalls, 1) // No additional calls
        XCTAssertEqual(count1, count2)
    }
    
    func testCachesFollowersList() async throws {
        let userID = "_65016d98fd8579ab704d38d23d066b2f"
        
        // Set up mock profile
        let mockProfile = UserProfile(
            id: "profile-123",
            userID: userID,
            username: "testuser",
            bio: "Test bio",
            profileImage: nil,
            workoutCount: 10,
            totalXP: 1000,
            level: 5,
            joinedDate: Date(),
            lastActive: Date(),
            privacyLevel: .public
        )
        mockProfileService.profilesByUserID[userID] = mockProfile
        
        // First call should hit the service
        let followers1 = try await sut.getFollowers(for: userID)
        XCTAssertEqual(mockCloudKitManager.queryCallCount, 1)
        
        // Second call should use cache
        let followers2 = try await sut.getFollowers(for: userID)
        XCTAssertEqual(mockCloudKitManager.queryCallCount, 1) // No additional calls
        XCTAssertEqual(followers1.count, followers2.count)
    }
    
    func testCacheInvalidationOnFollow() async throws {
        let followerID = "_65016d98fd8579ab704d38d23d066b2f"
        let followingID = "_75016d98fd8579ab704d38d23d066b2e"
        
        // Pre-cache counts
        _ = try await sut.getFollowersCount(for: followingID)
        _ = try await sut.getFollowingCount(for: followerID)
        
        let initialQueryCount = mockCloudKitManager.countQueryCalls
        
        // Follow action should invalidate caches
        try await sut.follow(userId: followingID)
        
        // Next calls should hit the service again (cache invalidated)
        _ = try await sut.getFollowersCount(for: followingID)
        _ = try await sut.getFollowingCount(for: followerID)
        
        XCTAssertGreaterThan(mockCloudKitManager.countQueryCalls, initialQueryCount)
    }
    
    // MARK: - Relationship Tests
    
    func testCheckRelationshipUsesCorrectIDs() async throws {
        let userID1 = "_65016d98fd8579ab704d38d23d066b2f"
        let userID2 = "_75016d98fd8579ab704d38d23d066b2e"
        
        let status = try await sut.checkRelationship(between: userID1, and: userID2)
        
        // Verify the query used CloudKit user IDs
        XCTAssertTrue(mockCloudKitManager.lastQueryPredicate?.contains(userID1) ?? false)
        XCTAssertTrue(mockCloudKitManager.lastQueryPredicate?.contains(userID2) ?? false)
    }
}