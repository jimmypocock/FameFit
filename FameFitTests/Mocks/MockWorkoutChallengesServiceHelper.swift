//
//  MockWorkoutChallengesServiceHelper.swift
//  FameFitTests
//
//  Helper for WorkoutChallengesService testing
//

import CloudKit
@testable import FameFit

// Create a test-friendly version of WorkoutChallengesService
class TestableWorkoutChallengesService: WorkoutChallengesServicing {
    // Dependencies
    let cloudKitManager: any CloudKitManaging
    let userProfileService: any UserProfileServicing
    let notificationManager: any NotificationManaging
    let rateLimiter: any RateLimitingServicing
    
    init(
        cloudKitManager: any CloudKitManaging,
        userProfileService: any UserProfileServicing,
        notificationManager: any NotificationManaging,
        rateLimiter: any RateLimitingServicing
    ) {
        self.cloudKitManager = cloudKitManager
        self.userProfileService = userProfileService
        self.notificationManager = notificationManager
        self.rateLimiter = rateLimiter
    }
    private var mockRecords: [String: CKRecord] = [:]
    private var mockQueryResults: [CKRecord] = []

    func createChallenge(_ challenge: WorkoutChallenge) async throws -> WorkoutChallenge {
        // Check authentication
        guard cloudKitManager.currentUserID != nil else {
            throw ChallengeError.notAuthenticated
        }

        // Validate challenge
        guard WorkoutChallenge.isValidChallenge(
            type: challenge.type,
            targetValue: challenge.targetValue,
            duration: challenge.endDate.timeIntervalSince(challenge.startDate)
        ) else {
            throw ChallengeError.invalidChallenge
        }

        // Check rate limiting
        do {
            _ = try await rateLimiter.checkLimit(for: .workoutPost, userId: cloudKitManager.currentUserID!)
        } catch {
            throw ChallengeError.rateLimited
        }

        // Check active challenges
        if mockQueryResults.count >= 5 {
            throw ChallengeError.tooManyChallenges
        }

        // Create challenge
        var newChallenge = challenge
        newChallenge.status = .pending

        // Store record
        let record = newChallenge.toCKRecord()
        mockRecords[record.recordID.recordName] = record

        // Record action
        await rateLimiter.recordAction(.workoutPost, userId: cloudKitManager.currentUserID!)

        // Send notifications
        for participant in newChallenge.participants where participant.id != cloudKitManager.currentUserID {
            // Track notification for testing
            if let mockManager = notificationManager as? MockNotificationManager {
                mockManager.scheduleNotificationCallCount += 1
            }
        }

        return newChallenge
    }

    func fetchChallenge(challengeId: String) async throws -> WorkoutChallenge {
        guard let record = mockRecords[challengeId] else {
            throw ChallengeError.challengeNotFound
        }

        guard let challenge = WorkoutChallenge(from: record) else {
            throw ChallengeError.challengeNotFound
        }

        return challenge
    }

    func fetchActiveChallenge(for _: String) async throws -> [WorkoutChallenge] {
        mockQueryResults.compactMap { WorkoutChallenge(from: $0) }
    }

    func acceptChallenge(challengeId: String) async throws -> WorkoutChallenge {
        guard let userId = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        var challenge = try await fetchChallenge(challengeId: challengeId)

        guard challenge.participants.contains(where: { $0.id == userId }) else {
            throw ChallengeError.notParticipant
        }

        guard challenge.status.canBeAccepted else {
            throw ChallengeError.invalidStatus
        }

        challenge.status = .active

        // Update record
        let record = challenge.toCKRecord(recordID: CKRecord.ID(recordName: challengeId))
        mockRecords[challengeId] = record

        // Notify all participants
        for _ in challenge.participants {
            // Track notification for testing
            if let mockManager = notificationManager as? MockNotificationManager {
                mockManager.scheduleNotificationCallCount += 1
            }
        }

        return challenge
    }

    func updateProgress(challengeId: String, progress: Double, workoutId _: String? = nil) async throws {
        guard let userId = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        var challenge = try await fetchChallenge(challengeId: challengeId)

        guard challenge.status.isActive else {
            throw ChallengeError.challengeNotActive
        }

        guard let participantIndex = challenge.participants.firstIndex(where: { $0.id == userId }) else {
            throw ChallengeError.notParticipant
        }

        challenge.participants[participantIndex].progress = progress
        challenge.participants[participantIndex].lastUpdated = Date()

        if progress >= challenge.targetValue {
            challenge.participants[participantIndex].isWinning = true
            _ = try await completeChallenge(challengeId: challengeId)
            return
        }

        // Update record
        let record = challenge.toCKRecord(recordID: CKRecord.ID(recordName: challengeId))
        mockRecords[challengeId] = record

        if let manager = cloudKitManager as? MockCloudKitManager {
            manager.saveCallCount += 1
        }
    }

    func completeChallenge(challengeId: String) async throws -> WorkoutChallenge {
        var challenge = try await fetchChallenge(challengeId: challengeId)

        guard challenge.status.isActive || challenge.isExpired else {
            throw ChallengeError.invalidStatus
        }

        if let leadingParticipant = challenge.leadingParticipant {
            challenge.winnerId = leadingParticipant.id
        }

        challenge.status = .completed

        // Update record
        let record = challenge.toCKRecord(recordID: CKRecord.ID(recordName: challengeId))
        mockRecords[challengeId] = record

        // Notify all participants
        for _ in challenge.participants {
            // Track notification for testing
            if let mockManager = notificationManager as? MockNotificationManager {
                mockManager.scheduleNotificationCallCount += 1
            }
        }

        return challenge
    }

    // MARK: - Missing Protocol Methods
    
    func declineChallenge(challengeId: String) async throws {
        guard let userId = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }
        
        var challenge = try await fetchChallenge(challengeId: challengeId)
        
        guard challenge.participants.contains(where: { $0.id == userId }) else {
            throw ChallengeError.notParticipant
        }
        
        challenge.status = .declined
        
        // Update record
        let record = challenge.toCKRecord(recordID: CKRecord.ID(recordName: challengeId))
        mockRecords[challengeId] = record
    }
    
    func cancelChallenge(challengeId: String) async throws {
        guard let userId = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }
        
        var challenge = try await fetchChallenge(challengeId: challengeId)
        
        guard challenge.creatorId == userId else {
            throw ChallengeError.notAuthorized
        }
        
        challenge.status = .cancelled
        
        // Update record
        let record = challenge.toCKRecord(recordID: CKRecord.ID(recordName: challengeId))
        mockRecords[challengeId] = record
    }
    
    func fetchPendingChallenge(for userId: String) async throws -> [WorkoutChallenge] {
        mockQueryResults
            .compactMap { WorkoutChallenge(from: $0) }
            .filter { $0.status == .pending && $0.participants.contains(where: { $0.id == userId }) }
    }
    
    func fetchCompletedChallenge(for userId: String) async throws -> [WorkoutChallenge] {
        mockQueryResults
            .compactMap { WorkoutChallenge(from: $0) }
            .filter { $0.status == .completed && $0.participants.contains(where: { $0.id == userId }) }
    }
    
    func inviteToChallenge(challengeId: String, userIds: [String]) async throws {
        guard cloudKitManager.currentUserID != nil else {
            throw ChallengeError.notAuthenticated
        }
        
        var challenge = try await fetchChallenge(challengeId: challengeId)
        
        // Add new participants
        for userId in userIds {
            if !challenge.participants.contains(where: { $0.id == userId }) {
                let participant = ChallengeParticipant(
                    id: userId,
                    displayName: "User \(userId)",
                    profileImageURL: nil,
                    progress: 0,
                    lastUpdated: Date(),
                    isWinning: false
                )
                challenge.participants.append(participant)
            }
        }
        
        // Update record
        let record = challenge.toCKRecord(recordID: CKRecord.ID(recordName: challengeId))
        mockRecords[challengeId] = record
        
        // Send notifications
        for _ in userIds {
            // Track notification for testing
            if let mockManager = notificationManager as? MockNotificationManager {
                mockManager.scheduleNotificationCallCount += 1
            }
        }
    }
    
    func getChallengeSuggestions(for userId: String) async throws -> [WorkoutChallenge] {
        // Return mock suggestions that are public, pending, and don't include the user
        return mockQueryResults
            .compactMap { WorkoutChallenge(from: $0) }
            .filter { challenge in
                challenge.isPublic &&
                challenge.status == .pending &&
                !challenge.participants.contains(where: { $0.id == userId })
            }
    }

    // Helper methods for testing
    func setMockRecord(_ record: CKRecord, for id: String) {
        mockRecords[id] = record
    }

    func setMockQueryResults(_ records: [CKRecord]) {
        mockQueryResults = records
    }
}
