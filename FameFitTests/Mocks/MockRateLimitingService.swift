//
//  MockRateLimitingService.swift
//  FameFitTests
//
//  Shared mock implementation of RateLimitingServicing for testing
//

import Foundation
@testable import FameFit

class MockRateLimitingService: RateLimitingServicing {
    var shouldAllowAction = true
    var shouldAllow = true // Alias for consistency
    var checkLimitCalled = false
    var recordActionCalled = false
    var shouldThrowRateLimitError = false
    var mockRemainingActions = 10
    var mockResetTime: Date? = nil
    var lastCheckedAction: RateLimitAction?
    var lastCheckedUserId: String?
    
    func checkLimit(for action: RateLimitAction, userId: String) async throws -> Bool {
        checkLimitCalled = true
        lastCheckedAction = action
        lastCheckedUserId = userId
        
        if shouldThrowRateLimitError {
            throw NSError(domain: "RateLimitError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded"])
        }
        return shouldAllowAction && shouldAllow
    }
    
    func recordAction(_ action: RateLimitAction, userId: String) async {
        recordActionCalled = true
    }
    
    func resetLimits(for userId: String) async {
        // Reset for testing
    }
    
    func getRemainingActions(for action: RateLimitAction, userId: String) async -> Int {
        return mockRemainingActions
    }
    
    func getResetTime(for action: RateLimitAction, userId: String) async -> Date? {
        return mockResetTime
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
    
    func isLimited(for action: RateLimitAction, userId: String) -> Bool {
        return shouldThrowRateLimitError
    }
    
    func timeUntilReset(for action: RateLimitAction, userId: String) -> TimeInterval? {
        return shouldThrowRateLimitError ? 300 : nil
    }
}