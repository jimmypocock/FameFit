//
//  AntiSpamService.swift
//  FameFit
//
//  Service for detecting and preventing spam/abuse
//

import Foundation

// MARK: - Anti-Spam Service Implementation

final class AntiSpamService: AntiSpamServicing, @unchecked Sendable {
    private let profanityWords: Set<String> = [
        // This would be a comprehensive list in production
        "spam", "bot", "fake"
    ]
    
    private var userSpamScores: [String: Double] = [:]
    private let scoreQueue = DispatchQueue(label: "com.famefit.antispam", attributes: .concurrent)
    
    func checkForSpam(userId: String, action: SpamCheckAction) async -> SpamCheckResult {
        switch action {
        case .follow(let targetId):
            return await checkFollowSpam(userId: userId, targetId: targetId)
            
        case .message(let content):
            return checkContentSpam(content: content)
            
        case .profileUpdate(let content):
            return checkContentSpam(content: content)
            
        case .workoutPost:
            return await checkWorkoutSpam(userId: userId)
        }
    }
    
    func reportSpam(userId: String, targetId: String, reason: SpamReason) async throws {
        // In production, this would:
        // 1. Log the report to CloudKit
        // 2. Update spam scores
        // 3. Notify moderation team
        // 4. Take automatic action if threshold reached
        
        await updateSpamScore(for: targetId, delta: 10.0)
    }
    
    func getSpamScore(for userId: String) async -> Double {
        return await withCheckedContinuation { continuation in
            scoreQueue.sync {
                continuation.resume(returning: userSpamScores[userId] ?? 0.0)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkFollowSpam(userId: String, targetId: String) async -> SpamCheckResult {
        let score = await getSpamScore(for: userId)
        
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
        if words.count > 10 && Double(uniqueWords.count) / Double(words.count) < 0.3 {
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
    
    private func checkWorkoutSpam(userId: String) async -> SpamCheckResult {
        // Check for unrealistic workout patterns
        // In production, this would analyze workout history
        
        return SpamCheckResult(
            isSpam: false,
            confidence: 0.1,
            reason: nil,
            suggestedAction: nil
        )
    }
    
    private func updateSpamScore(for userId: String, delta: Double) async {
        await withCheckedContinuation { continuation in
            scoreQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                let currentScore = self.userSpamScores[userId] ?? 0.0
                self.userSpamScores[userId] = max(0, currentScore + delta)
                continuation.resume()
            }
        }
    }
}

// MARK: - Mock Anti-Spam Service

final class MockAntiSpamService: AntiSpamServicing {
    var shouldDetectSpam = false
    var mockSpamResult = SpamCheckResult(
        isSpam: false,
        confidence: 0.1,
        reason: nil,
        suggestedAction: nil
    )
    
    func checkForSpam(userId: String, action: SpamCheckAction) async -> SpamCheckResult {
        return shouldDetectSpam ? mockSpamResult : SpamCheckResult(
            isSpam: false,
            confidence: 0.0,
            reason: nil,
            suggestedAction: nil
        )
    }
    
    func reportSpam(userId: String, targetId: String, reason: SpamReason) async throws {
        // No-op for mock
    }
    
    func getSpamScore(for userId: String) async -> Double {
        return 0.0
    }
}