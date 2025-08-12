//
//  AntiSpamService.swift
//  FameFit
//
//  Service for detecting and preventing spam/abuse
//

import Foundation

// MARK: - Anti-Spam Service Implementation

final class AntiSpamService: AntiSpamProtocol, @unchecked Sendable {
    private let profanityWords: Set<String> = [
        // This would be a comprehensive list in production
        "spam", "bot", "fake"
    ]

    private var userSpamScores: [String: Double] = [:]
    private let scoreQueue = DispatchQueue(label: "com.famefit.antispam", attributes: .concurrent)

    func checkForSpam(userID: String, action: SpamCheckAction) async -> SpamCheckResult {
        switch action {
        case let .follow(targetID):
            await checkFollowSpam(userID: userID, targetID: targetID)

        case let .message(content):
            checkContentSpam(content: content)

        case let .profileUpdate(content):
            checkContentSpam(content: content)

        case .workoutPost:
            await checkWorkoutSpam(userID: userID)
        }
    }

    func reportSpam(userID _: String, targetID: String, reason _: SpamReason) async throws {
        // In production, this would:
        // 1. Log the report to CloudKit
        // 2. Update spam scores
        // 3. Notify moderation team
        // 4. Take automatic action if threshold reached

        await updateSpamScore(for: targetID, delta: 10.0)
    }

    func getSpamScore(for userID: String) async -> Double {
        await withCheckedContinuation { continuation in
            scoreQueue.sync {
                continuation.resume(returning: userSpamScores[userID] ?? 0.0)
            }
        }
    }

    // MARK: - Private Methods

    private func checkFollowSpam(userID: String, targetID: String) async -> SpamCheckResult {
        let score = await getSpamScore(for: userID)

        // Check for mass following patterns
        if score > 50 {
            return SpamCheckResult(
                isSpam: true,
                confidence: 0.9,
                reason: "High spam score detected",
                suggestedAction: .rateLimit
            )
        }

        return SpamCheckResult(
            isSpam: false,
            confidence: 0.1,
            reason: nil,
            suggestedAction: nil
        )
    }

    private func checkContentSpam(content: String) -> SpamCheckResult {
        let lowercased = content.lowercased()

        // Check for profanity
        for word in profanityWords {
            if lowercased.contains(word) {
                return SpamCheckResult(
                    isSpam: true,
                    confidence: 0.8,
                    reason: "Inappropriate content detected",
                    suggestedAction: .warn
                )
            }
        }

        // Check for excessive links
        let linkPattern = "(https?://|www\\.)"
        let linkCount = lowercased.components(separatedBy: linkPattern).count - 1
        if linkCount > 2 {
            return SpamCheckResult(
                isSpam: true,
                confidence: 0.7,
                reason: "Too many links detected",
                suggestedAction: .warn
            )
        }

        // Check for repetitive content
        let words = lowercased.split(separator: " ")
        let uniqueWords = Set(words)
        if words.count > 10, Double(uniqueWords.count) / Double(words.count) < 0.3 {
            return SpamCheckResult(
                isSpam: true,
                confidence: 0.6,
                reason: "Repetitive content detected",
                suggestedAction: .warn
            )
        }

        return SpamCheckResult(
            isSpam: false,
            confidence: 0.1,
            reason: nil,
            suggestedAction: nil
        )
    }

    private func checkWorkoutSpam(userID _: String) async -> SpamCheckResult {
        // Check for unrealistic workout patterns
        // In production, this would analyze workout history

        SpamCheckResult(
            isSpam: false,
            confidence: 0.1,
            reason: nil,
            suggestedAction: nil
        )
    }

    private func updateSpamScore(for userID: String, delta: Double) async {
        await withCheckedContinuation { continuation in
            scoreQueue.async(flags: .barrier) { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                let currentScore = userSpamScores[userID] ?? 0.0
                userSpamScores[userID] = max(0, currentScore + delta)
                continuation.resume()
            }
        }
    }
}
