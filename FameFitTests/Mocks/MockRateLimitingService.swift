//
//  MockRateLimitingService.swift
//  FameFitTests
//
//  Shared mock implementation of RateLimitingServicing for testing
//

@testable import FameFit
import Foundation

class MockRateLimitingService: RateLimitingServicing {
    var shouldAllowAction = true
    var shouldAllow = true // Alias for consistency
    var checkLimitCalled = false
    var recordActionCalled = false
    var recordActionCallCount = 0 // Add this property
    var shouldThrowRateLimitError = false
    var shouldThrowError = false // Add alias for consistency
    var errorToThrow: Error = NSError(
        domain: "RateLimitError",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded"]
    ) // Add this property
    var mockRemainingActions = 10
    var mockResetTime: Date?
    var lastCheckedAction: RateLimitAction?
    var lastCheckedUserId: String?

    func checkLimit(for action: RateLimitAction, userId: String) async throws -> Bool {
        checkLimitCalled = true
        lastCheckedAction = action
        lastCheckedUserId = userId

        if shouldThrowRateLimitError || shouldThrowError {
            throw errorToThrow
        }
        return shouldAllowAction && shouldAllow
    }

    func recordAction(_: RateLimitAction, userId _: String) async {
        recordActionCalled = true
        recordActionCallCount += 1
    }

    func resetLimits(for _: String) async {
        // Reset for testing
    }

    func getRemainingActions(for _: RateLimitAction, userId _: String) async -> Int {
        mockRemainingActions
    }

    func getResetTime(for _: RateLimitAction, userId _: String) async -> Date? {
        mockResetTime
    }

    // Additional helper methods for testing
    func reset() {
        checkLimitCalled = false
        recordActionCalled = false
        shouldThrowRateLimitError = false
        shouldAllowAction = true
        shouldAllow = true
        lastCheckedAction = nil
        lastCheckedUserId = nil
    }

    func isLimited(for _: RateLimitAction, userId _: String) -> Bool {
        shouldThrowRateLimitError
    }

    func timeUntilReset(for _: RateLimitAction, userId _: String) -> TimeInterval? {
        shouldThrowRateLimitError ? 300 : nil
    }
}
