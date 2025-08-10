//
//  AntiSpamProtocol.swift
//  FameFit
//
//  Protocol for anti-spam service operations
//

import Foundation

// MARK: - Anti-Spam Protocol

protocol AntiSpamProtocol {
    func checkForSpam(userID: String, action: SpamCheckAction) async -> SpamCheckResult
    func reportSpam(userID: String, targetID: String, reason: SpamReason) async throws
    func getSpamScore(for userID: String) async -> Double
}

// MARK: - Supporting Types

enum SpamCheckAction {
    case follow(targetID: String)
    case message(content: String)
    case profileUpdate(content: String)
    case workoutPost
}

struct SpamCheckResult {
    let isSpam: Bool
    let confidence: Double
    let reason: String?
    let suggestedAction: SpamAction?
}

enum SpamAction {
    case block
    case captcha
    case rateLimit
    case shadowBan
    case warn
}

enum SpamReason: String, CaseIterable {
    case massFollowing = "mass_following"
    case inappropriateContent = "inappropriate_content"
    case harassment
    case fakeAccount = "fake_account"
    case other
}