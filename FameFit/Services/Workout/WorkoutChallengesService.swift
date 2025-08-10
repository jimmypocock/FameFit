//
//  WorkoutChallengesService.swift
//  FameFit
//
//  Service for managing workout challenges between users
//

import CloudKit
import Combine
import Foundation
import HealthKit


// MARK: - Service Implementation

final class WorkoutChallengesService: WorkoutChallengesProtocol {
    // MARK: - Properties

    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private let cloudKitManager: any CloudKitProtocol
    private let userProfileService: any UserProfileProtocol
    private let notificationManager: any NotificationProtocol
    private let rateLimiter: any RateLimitingProtocol
    private let workoutChallengeLinksService: WorkoutChallengeLinksProtocol?

    // Publishers
    @Published private var activeChallenges: [String: [WorkoutChallenge]] = [:] // userID: challenges
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        cloudKitManager: any CloudKitProtocol,
        userProfileService: any UserProfileProtocol,
        notificationManager: any NotificationProtocol,
        rateLimiter: any RateLimitingProtocol,
        workoutChallengeLinksService: WorkoutChallengeLinksProtocol? = nil,
        publicDatabase: CKDatabase? = nil,
        privateDatabase: CKDatabase? = nil
    ) {
        self.cloudKitManager = cloudKitManager
        self.userProfileService = userProfileService
        self.notificationManager = notificationManager
        self.rateLimiter = rateLimiter
        self.workoutChallengeLinksService = workoutChallengeLinksService
        self.publicDatabase = publicDatabase ?? CKContainer.default().publicCloudDatabase
        self.privateDatabase = privateDatabase ?? CKContainer.default().privateCloudDatabase
    }

    // MARK: - Challenge Management

    func createChallenge(_ challenge: WorkoutChallenge) async throws -> WorkoutChallenge {
        FameFitLogger.info("Creating challenge: \(challenge.name)", category: FameFitLogger.social)
        
        guard let userID = cloudKitManager.currentUserID else {
            FameFitLogger.error("Create challenge failed: Not authenticated", category: FameFitLogger.auth)
            throw ChallengeError.notAuthenticated
        }

        // Validate challenge
        guard WorkoutChallenge.isValidChallenge(
            type: challenge.type,
            targetValue: challenge.targetValue,
            duration: challenge.endDate.timeIntervalSince(challenge.startDate)
        ) else {
            FameFitLogger.error("Create challenge failed: Invalid challenge parameters", category: FameFitLogger.social)
            throw ChallengeError.invalidChallenge
        }

        // Check rate limiting
        do {
            _ = try await rateLimiter.checkLimit(for: .workoutPost, userID: userID)
        } catch {
            throw ChallengeError.rateLimited
        }

        // Ensure user isn't already in too many active challenges
        let activeChallenges = try await fetchActiveChallenge(for: userID)
        guard activeChallenges.count < 5 else { // Max 5 active challenges
            throw ChallengeError.tooManyChallenges
        }

        // Create challenge with pending status
        var newChallenge = challenge
        newChallenge.status = .pending

        // Save to CloudKit
        let record = newChallenge.toCKRecord()
        FameFitLogger.debug("Saving challenge to CloudKit", category: FameFitLogger.cloudKit)

        do {
            let savedRecord = try await publicDatabase.save(record)
            FameFitLogger.info("Challenge saved successfully", category: FameFitLogger.cloudKit)
            
            guard let savedChallenge = WorkoutChallenge(from: savedRecord) else {
                FameFitLogger.error("Failed to parse saved challenge record", category: FameFitLogger.cloudKit)
                throw ChallengeError.saveFailed
            }

            // Record the action for rate limiting
            await rateLimiter.recordAction(.workoutPost, userID: userID)

            // Send notifications to invited participants
            if let creatorProfile = try? await userProfileService.fetchProfile(userID: userID) {
                for participant in savedChallenge.participants where participant.id != userID {
                    await notificationManager.notifyChallengeInvite(challenge: savedChallenge, from: creatorProfile)
                }
            }

            return savedChallenge
        } catch {
            FameFitLogger.error("Failed to save challenge to CloudKit", error: error, category: FameFitLogger.cloudKit)
            throw ChallengeError.saveFailed
        }
    }

    func acceptChallenge(workoutChallengeID: String) async throws -> WorkoutChallenge {
        guard let userID = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        // Fetch challenge
        var challenge = try await fetchChallenge(workoutChallengeID: workoutChallengeID)

        // Verify user is a participant
        guard challenge.participants.contains(where: { $0.id == userID }) else {
            throw ChallengeError.notParticipant
        }

        // Verify challenge can be accepted
        guard challenge.status.canBeAccepted else {
            throw ChallengeError.invalidStatus
        }

        // Check if all participants have accepted
        // For now, we'll activate immediately with 2 participants
        challenge.status = .active

        // Update in CloudKit
        let recordID = CKRecord.ID(recordName: workoutChallengeID)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            let savedRecord = try await publicDatabase.save(record)
            guard let updatedChallenge = WorkoutChallenge(from: savedRecord) else {
                throw ChallengeError.saveFailed
            }

            // Notify all participants that challenge is active
            await notificationManager.notifyChallengeStart(challenge: updatedChallenge)

            return updatedChallenge
        } catch {
            throw ChallengeError.updateFailed
        }
    }

    func declineChallenge(workoutChallengeID: String) async throws {
        guard let userID = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        var challenge = try await fetchChallenge(workoutChallengeID: workoutChallengeID)

        // Verify user is a participant
        guard challenge.participants.contains(where: { $0.id == userID }) else {
            throw ChallengeError.notParticipant
        }

        // Update status
        challenge.status = .declined

        // Update in CloudKit
        let recordID = CKRecord.ID(recordName: workoutChallengeID)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            _ = try await publicDatabase.save(record)

            // Notify creator (could add a specific decline notification in the future)
            // For now, the creator will see the status change in the UI
        } catch {
            throw ChallengeError.updateFailed
        }
    }

    func cancelChallenge(workoutChallengeID: String) async throws {
        guard let userID = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        var challenge = try await fetchChallenge(workoutChallengeID: workoutChallengeID)

        // Only creator can cancel
        guard challenge.creatorID == userID else {
            throw ChallengeError.notAuthorized
        }

        // Update status
        challenge.status = .cancelled

        // Update in CloudKit
        let recordID = CKRecord.ID(recordName: workoutChallengeID)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            _ = try await publicDatabase.save(record)

            // Notify participants (could add a specific cancellation notification in the future)
            // For now, participants will see the status change in the UI
        } catch {
            throw ChallengeError.updateFailed
        }
    }

    func updateProgress(workoutChallengeID: String, progress: Double, workoutID: String? = nil) async throws {
        guard let userID = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        var challenge = try await fetchChallenge(workoutChallengeID: workoutChallengeID)

        // Verify challenge is active
        guard challenge.status.isActive else {
            throw ChallengeError.challengeNotActive
        }
        
        // If we have the links service, use it to calculate real progress
        let actualProgress: Double
        if let linksService = workoutChallengeLinksService {
            actualProgress = try await linksService.calculateUserProgress(
                userID: userID,
                workoutChallengeID: workoutChallengeID
            )
            FameFitLogger.info("📊 Using link-based progress: \(actualProgress)", category: FameFitLogger.social)
        } else {
            // Fallback to provided progress (legacy)
            actualProgress = progress
            FameFitLogger.warning("⚠️ Using legacy progress tracking", category: FameFitLogger.social)
        }

        // Find and update participant progress
        guard let participantIndex = challenge.participants.firstIndex(where: { $0.id == userID }) else {
            throw ChallengeError.notParticipant
        }

        challenge.participants[participantIndex].progress = actualProgress
        challenge.participants[participantIndex].lastUpdated = Date()

        // Check if target reached
        if actualProgress >= challenge.targetValue {
            challenge.participants[participantIndex].isWinning = true

            // Complete challenge if someone reached target
            _ = try await completeChallenge(workoutChallengeID: workoutChallengeID)
            return
        }

        // Update in CloudKit
        let recordID = CKRecord.ID(recordName: workoutChallengeID)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            _ = try await publicDatabase.save(record)

            // Store update for tracking
            let update = ChallengeUpdate(
                workoutChallengeID: workoutChallengeID,
                userID: userID,
                progressValue: progress,
                timestamp: Date(),
                workoutID: workoutID
            )
            await storeChallengeUpdate(update)
        } catch {
            throw ChallengeError.updateFailed
        }
    }

    func completeChallenge(workoutChallengeID: String) async throws -> WorkoutChallenge {
        var challenge = try await fetchChallenge(workoutChallengeID: workoutChallengeID)

        // Verify challenge is active or expired
        guard challenge.status.isActive || challenge.isExpired else {
            throw ChallengeError.invalidStatus
        }

        // Determine winner
        if let leadingParticipant = challenge.leadingParticipant {
            challenge.winnerID = leadingParticipant.id
        }

        challenge.status = .completed

        // Update in CloudKit
        let recordID = CKRecord.ID(recordName: workoutChallengeID)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            let savedRecord = try await publicDatabase.save(record)
            guard let completedChallenge = WorkoutChallenge(from: savedRecord) else {
                throw ChallengeError.saveFailed
            }

            // Award XP if there was a stake
            if completedChallenge.xpStake > 0, let winnerID = completedChallenge.winnerID {
                await awardChallengeXP(challenge: completedChallenge, winnerID: winnerID)
            }

            // Notify all participants
            for participant in completedChallenge.participants {
                await notificationManager.notifyChallengeComplete(
                    challenge: completedChallenge,
                    isWinner: participant.id == completedChallenge.winnerID
                )
            }

            return completedChallenge
        } catch {
            throw ChallengeError.updateFailed
        }
    }

    // MARK: - Challenge Fetching

    func fetchActiveChallenge(for userID: String) async throws -> [WorkoutChallenge] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "ANY participants.id == %@", userID),
            NSPredicate(format: "status == %@", ChallengeStatus.active.rawValue)
        ])

        return try await fetchChallenges(with: predicate)
    }

    func fetchPendingChallenge(for userID: String) async throws -> [WorkoutChallenge] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "ANY participants.id == %@", userID),
            NSPredicate(format: "status == %@", ChallengeStatus.pending.rawValue)
        ])

        return try await fetchChallenges(with: predicate)
    }

    func fetchCompletedChallenge(for userID: String) async throws -> [WorkoutChallenge] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "ANY participants.id == %@", userID),
            NSPredicate(format: "status == %@", ChallengeStatus.completed.rawValue)
        ])

        return try await fetchChallenges(with: predicate, limit: 20)
    }

    func fetchChallenge(workoutChallengeID: String) async throws -> WorkoutChallenge {
        let recordID = CKRecord.ID(recordName: workoutChallengeID)

        do {
            let record = try await publicDatabase.record(for: recordID)
            guard let challenge = WorkoutChallenge(from: record) else {
                throw ChallengeError.challengeNotFound
            }
            return challenge
        } catch {
            throw ChallengeError.challengeNotFound
        }
    }

    func inviteToChallenge(workoutChallengeID: String, userIDs: [String]) async throws {
        // Implementation for adding participants to existing challenge
        // This would be used for group challenges
    }

    func getChallengeSuggestions(for userID: String) async throws -> [WorkoutChallenge] {
        // Get public challenges user might be interested in
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isPublic == %@", NSNumber(value: true)),
            NSPredicate(format: "status == %@", ChallengeStatus.pending.rawValue),
            NSPredicate(format: "NOT (ANY participants.id == %@)", userID)
        ])

        return try await fetchChallenges(with: predicate, limit: 10)
    }

    // MARK: - Private Methods

    private func fetchChallenges(with predicate: NSPredicate, limit: Int = 50) async throws -> [WorkoutChallenge] {
        let query = CKQuery(recordType: "WorkoutChallenges", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        do {
            let results = try await publicDatabase.records(matching: query, resultsLimit: limit)
            return results.matchResults.compactMap { _, result in
                try? result.get()
            }.compactMap { WorkoutChallenge(from: $0) }
        } catch {
            FameFitLogger.error("Failed to fetch challenges", error: error, category: FameFitLogger.cloudKit)
            throw ChallengeError.fetchFailed
        }
    }

    private func storeChallengeUpdate(_: ChallengeUpdate) async {
        // Store challenge updates for progress tracking
        // This could be used for analytics and progress graphs
    }

    private func awardChallengeXP(challenge: WorkoutChallenge, winnerID: String) async {
        _ = challenge.winnerTakesAll
            ? challenge.xpStake * challenge.participants.count
            : challenge.xpStake * 2 // Double the stake

        // Award XP through CloudKit manager
        // This would need to be implemented in CloudKitService
    }

}

// MARK: - Challenge Errors

enum ChallengeError: LocalizedError {
    case notAuthenticated
    case notAuthorized
    case notParticipant
    case invalidChallenge
    case invalidStatus
    case challengeNotActive
    case challengeNotFound
    case tooManyChallenges
    case rateLimited
    case saveFailed
    case updateFailed
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "You must be signed in to manage challenges"
        case .notAuthorized:
            "You are not authorized to perform this action"
        case .notParticipant:
            "You are not a participant in this challenge"
        case .invalidChallenge:
            "Invalid challenge parameters"
        case .invalidStatus:
            "Challenge is not in the correct status for this action"
        case .challengeNotActive:
            "Challenge is not currently active"
        case .challengeNotFound:
            "Challenge not found"
        case .tooManyChallenges:
            "You have too many active challenges"
        case .rateLimited:
            "You're creating challenges too quickly. Please wait."
        case .saveFailed:
            "Failed to save challenge"
        case .updateFailed:
            "Failed to update challenge"
        case .fetchFailed:
            "Failed to fetch challenges"
        }
    }
}
