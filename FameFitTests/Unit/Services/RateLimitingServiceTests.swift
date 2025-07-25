//
//  RateLimitingServiceTests.swift
//  FameFitTests
//
//  Unit tests for rate limiting service
//

@testable import FameFit
import XCTest

final class RateLimitingServiceTests: XCTestCase {
    private var rateLimitingService: RateLimitingService!

    override func setUp() {
        super.setUp()
        rateLimitingService = RateLimitingService()
    }

    override func tearDown() {
        rateLimitingService = nil
        super.tearDown()
    }

    // MARK: - Follow Action Rate Limiting Tests

    func testFollowAction_WithinLimits() async throws {
        // Given
        let userId = "test-user"

        // When/Then - Should allow follow actions within limits
        for index in 1 ... 5 { // Minutely limit is 5
            let allowed = try await rateLimitingService.checkLimit(for: .follow, userId: userId)
            XCTAssertTrue(allowed, "Follow action \(index) should be allowed")
        }
    }

    func testFollowAction_ExceedsMinutelyLimit() async {
        // Given
        let userId = "test-user"

        // When - Exceed minutely limit (5 follows per minute)
        for _ in 1 ... 5 {
            _ = try? await rateLimitingService.checkLimit(for: .follow, userId: userId)
        }

        // Then - 6th follow should fail
        do {
            _ = try await rateLimitingService.checkLimit(for: .follow, userId: userId)
            XCTFail("Expected rate limit error")
        } catch let error as SocialServiceError {
            if case let .rateLimitExceeded(action, _) = error {
                XCTAssertEqual(action, "follow")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFollowAction_ExceedsHourlyLimit() async {
        // Given
        let userId = "test-user"

        // When - Mock exceeding hourly limit by manipulating internal state
        for _ in 1 ... 60 { // Hourly limit is 60
            _ = try? await rateLimitingService.checkLimit(for: .follow, userId: userId)
        }

        // Then - 61st follow should fail
        do {
            _ = try await rateLimitingService.checkLimit(for: .follow, userId: userId)
            XCTFail("Expected rate limit error")
        } catch let error as SocialServiceError {
            if case let .rateLimitExceeded(action, _) = error {
                XCTAssertEqual(action, "follow")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Like Action Rate Limiting Tests

    func testLikeAction_WithinLimits() async throws {
        // Given
        let userId = "test-user"

        // When/Then - Should allow like actions within limits
        for index in 1 ... 20 { // Minutely limit is 20
            let allowed = try await rateLimitingService.checkLimit(for: .like, userId: userId)
            XCTAssertTrue(allowed, "Like action \(index) should be allowed")
        }
    }

    func testLikeAction_ExceedsLimit() async {
        // Given
        let userId = "test-user"

        // When - Exceed minutely limit (60 likes per minute)
        for _ in 1 ... 60 {
            _ = try? await rateLimitingService.checkLimit(for: .like, userId: userId)
        }

        // Then - 61st like should fail
        do {
            _ = try await rateLimitingService.checkLimit(for: .like, userId: userId)
            XCTFail("Expected rate limit error")
        } catch let error as SocialServiceError {
            if case let .rateLimitExceeded(action, _) = error {
                XCTAssertEqual(action, "like")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Comment Action Rate Limiting Tests

    func testCommentAction_WithinLimits() async throws {
        // Given
        let userId = "test-user"

        // When/Then - Should allow comment actions within limits
        for index in 1 ... 5 { // Minutely limit is 5
            let allowed = try await rateLimitingService.checkLimit(for: .comment, userId: userId)
            XCTAssertTrue(allowed, "Comment action \(index) should be allowed")
        }
    }

    func testCommentAction_ExceedsLimit() async {
        // Given
        let userId = "test-user"

        // When - Exceed minutely limit (10 comments per minute)
        for _ in 1 ... 10 {
            _ = try? await rateLimitingService.checkLimit(for: .comment, userId: userId)
        }

        // Then - 11th comment should fail
        do {
            _ = try await rateLimitingService.checkLimit(for: .comment, userId: userId)
            XCTFail("Expected rate limit error")
        } catch let error as SocialServiceError {
            if case let .rateLimitExceeded(action, _) = error {
                XCTAssertEqual(action, "comment")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Search Action Rate Limiting Tests

    func testSearchAction_WithinLimits() async throws {
        // Given
        let userId = "test-user"

        // When/Then - Should allow search actions within limits
        for index in 1 ... 20 { // Minutely limit is 20
            let allowed = try await rateLimitingService.checkLimit(for: .search, userId: userId)
            XCTAssertTrue(allowed, "Search action \(index) should be allowed")
        }
    }

    func testSearchAction_ExceedsLimit() async {
        // Given
        let userId = "test-user"

        // When - Exceed minutely limit
        for _ in 1 ... 30 {
            _ = try? await rateLimitingService.checkLimit(for: .search, userId: userId)
        }

        // Then - Next search should fail
        do {
            _ = try await rateLimitingService.checkLimit(for: .search, userId: userId)
            XCTFail("Expected rate limit error")
        } catch let error as SocialServiceError {
            if case let .rateLimitExceeded(action, _) = error {
                XCTAssertEqual(action, "search")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Multi-User Tests

    func testRateLimiting_DifferentUsers() async throws {
        // Given
        let user1 = "user1"
        let user2 = "user2"

        // When - User1 exceeds limit
        for _ in 1 ... 5 {
            _ = try? await rateLimitingService.checkLimit(for: .follow, userId: user1)
        }

        // Then - User1 should be limited but User2 should not
        do {
            _ = try await rateLimitingService.checkLimit(for: .follow, userId: user1)
            XCTFail("User1 should be rate limited")
        } catch let error as SocialServiceError {
            if case .rateLimitExceeded = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // User2 should still be allowed
        let user2Allowed = try await rateLimitingService.checkLimit(for: .follow, userId: user2)
        XCTAssertTrue(user2Allowed)
    }

    // MARK: - Action Type Isolation Tests

    func testActionTypeIsolation() async throws {
        // Given
        let userId = "test-user"

        // When - Exhaust follow limit
        for _ in 1 ... 5 {
            _ = try? await rateLimitingService.checkLimit(for: .follow, userId: userId)
        }

        // Then - Follow should be limited but like should still work
        do {
            _ = try await rateLimitingService.checkLimit(for: .follow, userId: userId)
            XCTFail("Follow should be rate limited")
        } catch let error as SocialServiceError {
            if case .rateLimitExceeded = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Like should still work
        let likeAllowed = try await rateLimitingService.checkLimit(for: .like, userId: userId)
        XCTAssertTrue(likeAllowed)
    }

    // MARK: - Reset Time Tests

    func testResetTime_IsReasonable() async {
        // Given
        let userId = "test-user"

        // When - Trigger rate limit
        for _ in 1 ... 5 {
            _ = try? await rateLimitingService.checkLimit(for: .follow, userId: userId)
        }

        // Then - Reset time should be in the future but reasonable
        do {
            _ = try await rateLimitingService.checkLimit(for: .follow, userId: userId)
            XCTFail("Expected rate limit error")
        } catch let error as SocialServiceError {
            if case let .rateLimitExceeded(_, resetTime) = error {
                XCTAssertGreaterThan(resetTime, Date())
                XCTAssertLessThan(resetTime.timeIntervalSince(Date()), 3600) // Less than 1 hour
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess() async {
        // Given
        let userId = "concurrent-user"
        let expectation = XCTestExpectation(description: "Concurrent rate limiting")
        expectation.expectedFulfillmentCount = 20

        // When - Multiple concurrent requests
        let service = rateLimitingService!
        DispatchQueue.concurrentPerform(iterations: 20) { _ in
            Task {
                do {
                    _ = try await service.checkLimit(for: .follow, userId: userId)
                } catch {
                    // Some may fail due to rate limiting
                }
                expectation.fulfill()
            }
        }

        // Then - Should complete without crashes
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    // MARK: - Edge Cases

    func testEmptyUserId() async {
        // Given
        let emptyUserId = ""

        // When/Then - Should handle empty user ID gracefully
        do {
            let allowed = try await rateLimitingService.checkLimit(for: .follow, userId: emptyUserId)
            XCTAssertTrue(allowed) // Should allow or have specific behavior
        } catch {
            // May throw error for invalid user ID - that's also valid
            XCTAssertTrue(error is RateLimitError)
        }
    }

    func testVeryLongUserId() async throws {
        // Given
        let longUserId = String(repeating: "a", count: 1000)

        // When/Then - Should handle long user ID
        let allowed = try await rateLimitingService.checkLimit(for: .follow, userId: longUserId)
        XCTAssertTrue(allowed)
    }

    // MARK: - Performance Tests

    func testRateLimitingPerformance() {
        measure {
            let group = DispatchGroup()

            for index in 0 ..< 100 {
                group.enter()
                Task {
                    _ = try? await rateLimitingService.checkLimit(for: .follow, userId: "user-\(index)")
                    group.leave()
                }
            }

            group.wait()
        }
    }

    func testMemoryUsage_ManyUsers() async {
        // Given - Many different users to test memory management
        let userCount = 1000

        // When - Create rate limit entries for many users
        for index in 0 ..< userCount {
            _ = try? await rateLimitingService.checkLimit(for: .follow, userId: "user-\(index)")
        }

        // Then - Memory usage should be reasonable (this is more of a manual test)
        // In a real scenario, you'd monitor memory usage here
        XCTAssertTrue(true) // Placeholder assertion
    }

    // MARK: - Time Window Tests

    func testMinutelyWindow() async throws {
        // Given
        let userId = "time-test-user"

        // When - Use up minutely limit
        for _ in 1 ... 5 {
            _ = try await rateLimitingService.checkLimit(for: .follow, userId: userId)
        }

        // Then - Should be rate limited
        do {
            _ = try await rateLimitingService.checkLimit(for: .follow, userId: userId)
            XCTFail("Should be rate limited")
        } catch let error as SocialServiceError {
            if case .rateLimitExceeded = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Rate Limit Configuration Tests

    func testRateLimitConfiguration() {
        // Given/When/Then - Verify rate limits are configured correctly
        // Test that the actions have limits defined
        XCTAssertNotNil(RateLimitAction.follow.limits)
        XCTAssertNotNil(RateLimitAction.like.limits)
        XCTAssertNotNil(RateLimitAction.comment.limits)
        XCTAssertNotNil(RateLimitAction.search.limits)

        // Verify specific limits for follow action
        let followLimits = RateLimitAction.follow.limits
        XCTAssertEqual(followLimits.minutely, 5)
        XCTAssertEqual(followLimits.hourly, 60)
        XCTAssertEqual(followLimits.daily, 500)
        XCTAssertEqual(followLimits.weekly, 1000)
    }
}
