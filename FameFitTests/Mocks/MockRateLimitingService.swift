//
//  MockRateLimitingService.swift
//  FameFitTests
//
//  Mock implementation of RateLimitingProtocol for testing
//

import Foundation

@testable import FameFit

final class MockRateLimitingService: RateLimitingProtocol {
  var shouldAllow = true
  var shouldThrowRateLimitError = false
  var shouldThrowError = false
  var errorToThrow: Error?
  var recordedActions: [(action: RateLimitAction, userID: String, date: Date)] = []
  var remainingActions: [RateLimitAction: Int] = [:]
  var resetTimes: [RateLimitAction: Date] = [:]
  var checkLimitCalled = false
  var recordActionCalled = false
  var recordActionCallCount = 0

  func checkLimit(for action: RateLimitAction, userID: String) async throws -> Bool {
    checkLimitCalled = true
    recordedActions.append((action: action, userID: userID, date: Date()))

    if shouldThrowError, let error = errorToThrow {
      throw error
    }

    if shouldThrowRateLimitError || !shouldAllow {
      throw SocialServiceError.rateLimitExceeded(
        action: action.rawValue,
        resetTime: resetTimes[action] ?? Date().addingTimeInterval(3_600)
      )
    }

    return true
  }

  func recordAction(_ action: RateLimitAction, userID: String) async {
    recordActionCalled = true
    recordActionCallCount += 1
    recordedActions.append((action: action, userID: userID, date: Date()))
  }

  func resetLimits(for userID: String) async {
    recordedActions.removeAll { $0.userID == userID }
  }

  func getRemainingActions(for action: RateLimitAction, userID _: String) async -> Int {
    remainingActions[action] ?? 10
  }

  func getResetTime(for action: RateLimitAction, userID _: String) async -> Date? {
    resetTimes[action]
  }

  // Test helpers
  func reset() {
    shouldAllow = true
    shouldThrowRateLimitError = false
    shouldThrowError = false
    errorToThrow = nil
    recordedActions.removeAll()
    remainingActions.removeAll()
    resetTimes.removeAll()
    checkLimitCalled = false
    recordActionCalled = false
    recordActionCallCount = 0
  }
}
