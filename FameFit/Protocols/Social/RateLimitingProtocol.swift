//
//  RateLimitingProtocol.swift
//  FameFit
//
//  Protocol for rate limiting service operations
//

import Foundation

// MARK: - Rate Limiting Protocol

protocol RateLimitingProtocol {
    func checkLimit(for action: RateLimitAction, userID: String) async throws -> Bool
    func recordAction(_ action: RateLimitAction, userID: String) async
    func resetLimits(for userID: String) async
    func getRemainingActions(for action: RateLimitAction, userID: String) async -> Int
    func getResetTime(for action: RateLimitAction, userID: String) async -> Date?
}

// MARK: - Supporting Types

struct RateLimits {
    let minutely: Int?
    let hourly: Int
    let daily: Int
    let weekly: Int?
}

enum RateLimitAction: String, CaseIterable {
    case follow
    case unfollow
    case search
    case feedRefresh
    case profileView
    case workoutPost
    case followRequest
    case report
    case like
    case comment

    var limits: RateLimits {
        switch self {
        case .follow:
            RateLimits(minutely: 5, hourly: 60, daily: 500, weekly: 1_000)
        case .unfollow:
            RateLimits(minutely: 3, hourly: 30, daily: 100, weekly: 500)
        case .search:
            RateLimits(minutely: 20, hourly: 200, daily: 1_000, weekly: nil)
        case .feedRefresh:
            RateLimits(minutely: 10, hourly: 100, daily: 1_000, weekly: nil)
        case .profileView:
            RateLimits(minutely: 30, hourly: 500, daily: 5_000, weekly: nil)
        case .workoutPost:
            RateLimits(minutely: 5, hourly: 30, daily: 100, weekly: nil)
        case .followRequest:
            RateLimits(minutely: 2, hourly: 20, daily: 100, weekly: nil)
        case .report:
            RateLimits(minutely: 1, hourly: 5, daily: 20, weekly: nil)
        case .like:
            RateLimits(minutely: 60, hourly: 600, daily: 2_000, weekly: nil)
        case .comment:
            RateLimits(minutely: 10, hourly: 100, daily: 500, weekly: nil)
        }
    }
}