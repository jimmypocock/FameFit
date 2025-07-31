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
    func acceptChallenge(challengeId: String) async throws -> WorkoutChallenge
    func declineChallenge(challengeId: String) async throws
    func cancelChallenge(challengeId: String) async throws
    func updateProgress(challengeId: String, progress: Double, workoutId: String?) async throws
    func completeChallenge(challengeId: String) async throws -> WorkoutChallenge

    func fetchActiveChallenge(for userId: String) async throws -> [WorkoutChallenge]
    func fetchPendingChallenge(for userId: String) async throws -> [WorkoutChallenge]
    func fetchCompletedChallenge(for userId: String) async throws -> [WorkoutChallenge]
    func fetchChallenge(challengeId: String) async throws -> WorkoutChallenge

    func inviteToChallenge(challengeId: String, userIds: [String]) async throws
    func getChallengeSuggestions(for userId: String) async throws -> [WorkoutChallenge]
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
    @Published private var activeChallenges: [String: [WorkoutChallenge]] = [:] // userId: challenges
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
        guard let userId = cloudKitManager.currentUserID else {
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
            _ = try await rateLimiter.checkLimit(for: .workoutPost, userId: userId)
        } catch {
            throw ChallengeError.rateLimited
        }

        // Ensure user isn't already in too many active challenges
        let activeChallenges = try await fetchActiveChallenge(for: userId)
        guard activeChallenges.count < 5 else { // Max 5 active challenges
            throw ChallengeError.tooManyChallenges
        }

        // Create challenge with pending status
        var newChallenge = challenge
        newChallenge.status = .pending

        // Save to CloudKit
        let record = newChallenge.toCKRecord()

        do {
            let savedRecord = try await publicDatabase.save(record)
            guard let savedChallenge = WorkoutChallenge(from: savedRecord) else {
                throw ChallengeError.saveFailed
            }

            // Record the action for rate limiting
            await rateLimiter.recordAction(.workoutPost, userId: userId)

            // Send notifications to invited participants
            for participant in savedChallenge.participants where participant.id != userId {
                await sendChallengeInviteNotification(challenge: savedChallenge, to: participant.id)
            }

            return savedChallenge
        } catch {
            throw ChallengeError.saveFailed
        }
    }

    func acceptChallenge(challengeId: String) async throws -> WorkoutChallenge {
        guard let userId = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        // Fetch challenge
        var challenge = try await fetchChallenge(challengeId: challengeId)

        // Verify user is a participant
        guard challenge.participants.contains(where: { $0.id == userId }) else {
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
        let recordID = CKRecord.ID(recordName: challengeId)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            let savedRecord = try await publicDatabase.save(record)
            guard let updatedChallenge = WorkoutChallenge(from: savedRecord) else {
                throw ChallengeError.saveFailed
            }

            // Notify all participants that challenge is active
            for participant in updatedChallenge.participants {
                await sendChallengeStartedNotification(challenge: updatedChallenge, to: participant.id)
            }

            return updatedChallenge
        } catch {
            throw ChallengeError.updateFailed
        }
    }

    func declineChallenge(challengeId: String) async throws {
        guard let userId = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        var challenge = try await fetchChallenge(challengeId: challengeId)

        // Verify user is a participant
        guard challenge.participants.contains(where: { $0.id == userId }) else {
            throw ChallengeError.notParticipant
        }

        // Update status
        challenge.status = .declined

        // Update in CloudKit
        let recordID = CKRecord.ID(recordName: challengeId)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            _ = try await publicDatabase.save(record)

            // Notify creator
            if challenge.creatorId != userId {
                await sendChallengeDeclinedNotification(challenge: challenge, by: userId)
            }
        } catch {
            throw ChallengeError.updateFailed
        }
    }

    func cancelChallenge(challengeId: String) async throws {
        guard let userId = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        var challenge = try await fetchChallenge(challengeId: challengeId)

        // Only creator can cancel
        guard challenge.creatorId == userId else {
            throw ChallengeError.notAuthorized
        }

        // Update status
        challenge.status = .cancelled

        // Update in CloudKit
        let recordID = CKRecord.ID(recordName: challengeId)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            _ = try await publicDatabase.save(record)

            // Notify participants
            for participant in challenge.participants where participant.id != userId {
                await sendChallengeCancelledNotification(challenge: challenge, to: participant.id)
            }
        } catch {
            throw ChallengeError.updateFailed
        }
    }

    func updateProgress(challengeId: String, progress: Double, workoutId: String? = nil) async throws {
        guard let userId = cloudKitManager.currentUserID else {
            throw ChallengeError.notAuthenticated
        }

        var challenge = try await fetchChallenge(challengeId: challengeId)

        // Verify challenge is active
        guard challenge.status.isActive else {
            throw ChallengeError.challengeNotActive
        }

        // Find and update participant progress
        guard let participantIndex = challenge.participants.firstIndex(where: { $0.id == userId }) else {
            throw ChallengeError.notParticipant
        }

        challenge.participants[participantIndex].progress = progress
        challenge.participants[participantIndex].lastUpdated = Date()

        // Check if target reached
        if progress >= challenge.targetValue {
            challenge.participants[participantIndex].isWinning = true

            // Complete challenge if someone reached target
            _ = try await completeChallenge(challengeId: challengeId)
            return
        }

        // Update in CloudKit
        let recordID = CKRecord.ID(recordName: challengeId)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            _ = try await publicDatabase.save(record)

            // Store update for tracking
            let update = ChallengeUpdate(
                challengeId: challengeId,
                userId: userId,
                progressValue: progress,
                timestamp: Date(),
                workoutId: workoutId
            )
            await storeChallengeUpdate(update)
        } catch {
            throw ChallengeError.updateFailed
        }
    }

    func completeChallenge(challengeId: String) async throws -> WorkoutChallenge {
        var challenge = try await fetchChallenge(challengeId: challengeId)

        // Verify challenge is active or expired
        guard challenge.status.isActive || challenge.isExpired else {
            throw ChallengeError.invalidStatus
        }

        // Determine winner
        if let leadingParticipant = challenge.leadingParticipant {
            challenge.winnerId = leadingParticipant.id
        }

        challenge.status = .completed

        // Update in CloudKit
        let recordID = CKRecord.ID(recordName: challengeId)
        let record = challenge.toCKRecord(recordID: recordID)

        do {
            let savedRecord = try await publicDatabase.save(record)
            guard let completedChallenge = WorkoutChallenge(from: savedRecord) else {
                throw ChallengeError.saveFailed
            }

            // Award XP if there was a stake
            if completedChallenge.xpStake > 0, let winnerId = completedChallenge.winnerId {
                await awardChallengeXP(challenge: completedChallenge, winnerId: winnerId)
            }

            // Notify all participants
            for participant in completedChallenge.participants {
                await sendChallengeCompletedNotification(
                    challenge: completedChallenge,
                    to: participant.id,
                    isWinner: participant.id == completedChallenge.winnerId
                )
            }

            return completedChallenge
        } catch {
            throw ChallengeError.updateFailed
        }
    }

    // MARK: - Challenge Fetching

    func fetchActiveChallenge(for userId: String) async throws -> [WorkoutChallenge] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "ANY participants.id == %@", userId),
            NSPredicate(format: "status == %@", ChallengeStatus.active.rawValue)
        ])

        return try await fetchChallenges(with: predicate)
    }

    func fetchPendingChallenge(for userId: String) async throws -> [WorkoutChallenge] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "ANY participants.id == %@", userId),
            NSPredicate(format: "status == %@", ChallengeStatus.pending.rawValue)
        ])

        return try await fetchChallenges(with: predicate)
    }

    func fetchCompletedChallenge(for userId: String) async throws -> [WorkoutChallenge] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "ANY participants.id == %@", userId),
            NSPredicate(format: "status == %@", ChallengeStatus.completed.rawValue)
        ])

        return try await fetchChallenges(with: predicate, limit: 20)
    }

    func fetchChallenge(challengeId: String) async throws -> WorkoutChallenge {
        let recordID = CKRecord.ID(recordName: challengeId)

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

    func inviteToChallenge(challengeId _: String, userIds _: [String]) async throws {
        // Implementation for adding participants to existing challenge
        // This would be used for group challenges
    }

    func getChallengeSuggestions(for userId: String) async throws -> [WorkoutChallenge] {
        // Get public challenges user might be interested in
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isPublic == %@", NSNumber(value: true)),
            NSPredicate(format: "status == %@", ChallengeStatus.pending.rawValue),
            NSPredicate(format: "NOT (ANY participants.id == %@)", userId)
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
            throw ChallengeError.fetchFailed
        }
    }

    private func storeChallengeUpdate(_: ChallengeUpdate) async {
        // Store challenge updates for progress tracking
        // This could be used for analytics and progress graphs
    }

    private func awardChallengeXP(challenge: WorkoutChallenge, winnerId _: String) async {
        _ = challenge.winnerTakesAll
            ? challenge.xpStake * challenge.participants.count
            : challenge.xpStake * 2 // Double the stake

        // Award XP through CloudKit manager
        // This would need to be implemented in CloudKitManager
    }

    // MARK: - Notifications

    private func sendChallengeInviteNotification(challenge: WorkoutChallenge, to userId: String) async {
        guard let inviterProfile = try? await userProfileService.fetchProfile(userId: challenge.creatorId) else {
            return
        }

        // For now, we'll create a local notification that works with the current system
        // In a full implementation, this would be sent via push notifications
        let notification = NotificationItem(
            type: .challengeInvite,
            title: "New Challenge Invite! \(challenge.type.icon)",
            body: "\(inviterProfile.username) challenged you: \(challenge.name)",
            metadata: .challenge(ChallengeNotificationMetadata(
                challengeId: challenge.id,
                challengeName: challenge.name,
                challengeType: challenge.type.rawValue,
                creatorId: challenge.creatorId,
                creatorName: inviterProfile.username,
                targetValue: challenge.targetValue,
                endDate: challenge.endDate
            )),
            actions: [.accept, .decline]
        )

        // Store notification locally (in a real app, this would be sent via APNS)
        // For now, we'll just log it or store it in UserDefaults
        print("Challenge invite notification would be sent to user \(userId): \(notification.title)")
    }

    private func sendChallengeStartedNotification(challenge: WorkoutChallenge, to userId: String) async {
        let notification = NotificationItem(
            type: .challengeStarted,
            title: "Challenge Started! 🏁",
            body: "\(challenge.name) is now active. Good luck!",
            metadata: .challenge(ChallengeNotificationMetadata(
                challengeId: challenge.id,
                challengeName: challenge.name,
                challengeType: challenge.type.rawValue,
                creatorId: challenge.creatorId,
                creatorName: nil,
                targetValue: challenge.targetValue,
                endDate: challenge.endDate
            )),
            actions: [.view]
        )

        print("Challenge started notification would be sent to user \(userId): \(notification.title)")
    }

    private func sendChallengeDeclinedNotification(challenge: WorkoutChallenge, by userId: String) async {
        guard let declinerProfile = try? await userProfileService.fetchProfile(userId: userId) else {
            return
        }

        let notification = NotificationItem(
            type: .challengeCompleted,
            title: "Challenge Declined",
            body: "\(declinerProfile.username) declined your challenge: \(challenge.name)",
            actions: []
        )

        print("Challenge declined notification would be sent to user \(challenge.creatorId): \(notification.title)")
    }

    private func sendChallengeCancelledNotification(challenge: WorkoutChallenge, to userId: String) async {
        let notification = NotificationItem(
            type: .challengeCompleted,
            title: "Challenge Cancelled",
            body: "The challenge '\(challenge.name)' has been cancelled",
            actions: []
        )

        print("Challenge cancelled notification would be sent to user \(userId): \(notification.title)")
    }

    private func sendChallengeCompletedNotification(
        challenge: WorkoutChallenge,
        to userId: String,
        isWinner: Bool
    ) async {
        let title = isWinner ? "You Won! 🏆" : "Challenge Completed!"
        let body = isWinner
            ? "Congratulations! You won \(challenge.name)!"
            : "The challenge '\(challenge.name)' has ended. Check the results!"

        let notification = NotificationItem(
            type: .challengeCompleted,
            title: title,
            body: body,
            metadata: .challenge(ChallengeNotificationMetadata(
                challengeId: challenge.id,
                challengeName: challenge.name,
                challengeType: challenge.type.rawValue,
                creatorId: challenge.creatorId,
                creatorName: nil,
                targetValue: challenge.targetValue,
                endDate: challenge.endDate
            )),
            actions: [.view]
        )

        print("Challenge completed notification would be sent to user \(userId): \(notification.title)")
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
