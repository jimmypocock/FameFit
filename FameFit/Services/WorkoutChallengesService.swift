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

// MARK: - Protocol

protocol WorkoutChallengesServicing {
    func createChallenge(_ challenge: WorkoutChallenge) async throws -> WorkoutChallenge
    func acceptChallenge(challengeID: String) async throws -> WorkoutChallenge
    func declineChallenge(challengeID: String) async throws
    func cancelChallenge(challengeID: String) async throws
    func updateProgress(challengeID: String, progress: Double, workoutID: String?) async throws
    func completeChallenge(challengeID: String) async throws -> WorkoutChallenge

    func fetchActiveChallenge(for userID: String) async throws -> [WorkoutChallenge]
    func fetchPendingChallenge(for userID: String) async throws -> [WorkoutChallenge]
    func fetchCompletedChallenge(for userID: String) async throws -> [WorkoutChallenge]
    func fetchChallenge(challengeID: String) async throws -> WorkoutChallenge

    func inviteToChallenge(challengeID: String, userIDs: [String]) async throws
    func getChallengeSuggestions(for userID: String) async throws -> [WorkoutChallenge]
}

// MARK: - Service Implementation

final class WorkoutChallengesService: WorkoutChallengesServicing {
    // MARK: - Properties

    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private let cloudKitManager: any CloudKitManaging
    private let userProfileService: any UserProfileServicing
    private let notificationManager: any NotificationManaging
    private let rateLimiter: any RateLimitingServicing

    // Publishers
    @Published private var activeChallenges: [String: [WorkoutChallenge]] = [:] // userID: challenges
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        cloudKitManager: any CloudKitManaging,
        userProfileService: any UserProfileServicing,
        notificationManager: any NotificationManaging,
        rateLimiter: any RateLimitingServicing,
        publicDatabase: CKDatabase? = nil,
        privateDatabase: CKDatabase? = nil
    ) {
        self.cloudKitManager = cloudKitManager
        self.userProfileService = userProfileService
        self.notificationManager = notificationManager
        self.rateLimiter = rateLimiter
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
            for participant in savedChallenge.participants where participant.id != userID {
                await sendChallengeInviteFameFitNotification(challenge: savedChallenge, to: participant.id)
            }

            return savedChallenge
        } catch {
            FameFitLogger.error("Failed to save challenge to CloudKit", error: error, category: FameFitLogger.cloudKit)
            throw ChallengeError.saveFailed
        }
    }

    func acceptChallenge(challengeID: String) async throws -> WorkoutChallenge {
        guard let userID = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        // Fetch challenge
        var challenge = try await fetchChallenge(challengeID: challengeID)

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
        let recordID = CKRecord.ID(recordName: challengeID)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            let savedRecord = try await publicDatabase.save(record)
            guard let updatedChallenge = WorkoutChallenge(from: savedRecord) else {
                throw ChallengeError.saveFailed
            }

            // Notify all participants that challenge is active
            for participant in updatedChallenge.participants {
                await sendChallengeStartedFameFitNotification(challenge: updatedChallenge, to: participant.id)
            }

            return updatedChallenge
        } catch {
            throw ChallengeError.updateFailed
        }
    }

    func declineChallenge(challengeID: String) async throws {
        guard let userID = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        var challenge = try await fetchChallenge(challengeID: challengeID)

        // Verify user is a participant
        guard challenge.participants.contains(where: { $0.id == userID }) else {
            throw ChallengeError.notParticipant
        }

        // Update status
        challenge.status = .declined

        // Update in CloudKit
        let recordID = CKRecord.ID(recordName: challengeID)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            _ = try await publicDatabase.save(record)

            // Notify creator
            if challenge.creatorID != userID {
                await sendChallengeDeclinedFameFitNotification(challenge: challenge, by: userID)
            }
        } catch {
            throw ChallengeError.updateFailed
        }
    }

    func cancelChallenge(challengeID: String) async throws {
        guard let userID = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        var challenge = try await fetchChallenge(challengeID: challengeID)

        // Only creator can cancel
        guard challenge.creatorID == userID else {
            throw ChallengeError.notAuthorized
        }

        // Update status
        challenge.status = .cancelled

        // Update in CloudKit
        let recordID = CKRecord.ID(recordName: challengeID)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            _ = try await publicDatabase.save(record)

            // Notify participants
            for participant in challenge.participants where participant.id != userID {
                await sendChallengeCancelledFameFitNotification(challenge: challenge, to: participant.id)
            }
        } catch {
            throw ChallengeError.updateFailed
        }
    }

    func updateProgress(challengeID: String, progress: Double, workoutID: String? = nil) async throws {
        guard let userID = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        var challenge = try await fetchChallenge(challengeID: challengeID)

        // Verify challenge is active
        guard challenge.status.isActive else {
            throw ChallengeError.challengeNotActive
        }

        // Find and update participant progress
        guard let participantIndex = challenge.participants.firstIndex(where: { $0.id == userID }) else {
            throw ChallengeError.notParticipant
        }

        challenge.participants[participantIndex].progress = progress
        challenge.participants[participantIndex].lastUpdated = Date()

        // Check if target reached
        if progress >= challenge.targetValue {
            challenge.participants[participantIndex].isWinning = true

            // Complete challenge if someone reached target
            _ = try await completeChallenge(challengeID: challengeID)
            return
        }

        // Update in CloudKit
        let recordID = CKRecord.ID(recordName: challengeID)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            _ = try await publicDatabase.save(record)

            // Store update for tracking
            let update = ChallengeUpdate(
                challengeID: challengeID,
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

    func completeChallenge(challengeID: String) async throws -> WorkoutChallenge {
        var challenge = try await fetchChallenge(challengeID: challengeID)

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
        let recordID = CKRecord.ID(recordName: challengeID)
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
                await sendChallengeCompletedFameFitNotification(
                    challenge: completedChallenge,
                    to: participant.id,
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

    func fetchChallenge(challengeID: String) async throws -> WorkoutChallenge {
        let recordID = CKRecord.ID(recordName: challengeID)

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

    func inviteToChallenge(challengeID: String, userIDs: [String]) async throws {
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
        query.sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]

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
        // This would need to be implemented in CloudKitManager
    }

    // MARK: - Notifications

    private func sendChallengeInviteFameFitNotification(challenge: WorkoutChallenge, to userID: String) async {
        guard let inviterProfile = try? await userProfileService.fetchProfile(userID: challenge.creatorID) else {
            return
        }

        // For now, we'll create a local notification that works with the current system
        // In a full implementation, this would be sent via push notifications
        let notification = FameFitNotification(
            type: .challengeInvite,
            title: "New Challenge Invite! \(challenge.type.icon)",
            body: "\(inviterProfile.username) challenged you: \(challenge.name)",
            metadata: .challenge(ChallengeNotificationMetadata(
                challengeID: challenge.id,
                challengeName: challenge.name,
                challengeType: challenge.type.rawValue,
                creatorID: challenge.creatorID,
                creatorName: inviterProfile.username,
                targetValue: challenge.targetValue,
                endDate: challenge.endDate
            )),
            actions: [.accept, .decline]
        )

        // Store notification locally (in a real app, this would be sent via APNS)
        // For now, we'll just log it or store it in UserDefaults
        print("Challenge invite notification would be sent to user \(userID): \(notification.title)")
    }

    private func sendChallengeStartedFameFitNotification(challenge: WorkoutChallenge, to userID: String) async {
        let notification = FameFitNotification(
            type: .challengeStarted,
            title: "Challenge Started! 🏁",
            body: "\(challenge.name) is now active. Good luck!",
            metadata: .challenge(ChallengeNotificationMetadata(
                challengeID: challenge.id,
                challengeName: challenge.name,
                challengeType: challenge.type.rawValue,
                creatorID: challenge.creatorID,
                creatorName: nil,
                targetValue: challenge.targetValue,
                endDate: challenge.endDate
            )),
            actions: [.view]
        )

        print("Challenge started notification would be sent to user \(userID): \(notification.title)")
    }

    private func sendChallengeDeclinedFameFitNotification(challenge: WorkoutChallenge, by userID: String) async {
        guard let declinerProfile = try? await userProfileService.fetchProfile(userID: userID) else {
            return
        }

        let notification = FameFitNotification(
            type: .challengeCompleted,
            title: "Challenge Declined",
            body: "\(declinerProfile.username) declined your challenge: \(challenge.name)",
            actions: []
        )

        print("Challenge declined notification would be sent to user \(challenge.creatorID): \(notification.title)")
    }

    private func sendChallengeCancelledFameFitNotification(challenge: WorkoutChallenge, to userID: String) async {
        let notification = FameFitNotification(
            type: .challengeCompleted,
            title: "Challenge Cancelled",
            body: "The challenge '\(challenge.name)' has been cancelled",
            actions: []
        )

        print("Challenge cancelled notification would be sent to user \(userID): \(notification.title)")
    }

    private func sendChallengeCompletedFameFitNotification(
        challenge: WorkoutChallenge,
        to userID: String,
        isWinner: Bool
    ) async {
        let title = isWinner ? "You Won! 🏆" : "Challenge Completed!"
        let body = isWinner
            ? "Congratulations! You won \(challenge.name)!"
            : "The challenge '\(challenge.name)' has ended. Check the results!"

        let notification = FameFitNotification(
            type: .challengeCompleted,
            title: title,
            body: body,
            metadata: .challenge(ChallengeNotificationMetadata(
                challengeID: challenge.id,
                challengeName: challenge.name,
                challengeType: challenge.type.rawValue,
                creatorID: challenge.creatorID,
                creatorName: nil,
                targetValue: challenge.targetValue,
                endDate: challenge.endDate
            )),
            actions: [.view]
        )

        print("Challenge completed notification would be sent to user \(userID): \(notification.title)")
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
