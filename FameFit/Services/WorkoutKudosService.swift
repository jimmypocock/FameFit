//
//  WorkoutKudosService.swift
//  FameFit
//
//  Service for managing workout kudos/cheers
//

import CloudKit
import Combine
import Foundation

// MARK: - Kudos Service Protocol

protocol WorkoutKudosServicing {
    // Kudos actions
    func toggleKudos(for workoutId: String, ownerId: String) async throws -> KudosActionResult
    func removeKudos(for workoutId: String) async throws

    // Fetching kudos
    func getKudosSummary(for workoutId: String) async throws -> WorkoutKudosSummary
    func getUserKudos(for userId: String, limit: Int) async throws -> [WorkoutKudos]
    func hasUserGivenKudos(workoutId: String, userId: String) async throws -> Bool

    // Batch operations
    func getKudosSummaries(for workoutIds: [String]) async throws -> [String: WorkoutKudosSummary]

    // Real-time updates
    var kudosUpdates: AnyPublisher<KudosUpdate, Never> { get }
}

// MARK: - Kudos Update Event

struct KudosUpdate {
    let workoutId: String
    let action: KudosAction
    let userID: String
    let newCount: Int

    enum KudosAction {
        case added
        case removed
    }
}

// MARK: - Kudos Service Implementation

final class WorkoutKudosService: WorkoutKudosServicing {
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private let userProfileService: UserProfileServicing
    private let notificationManager: NotificationManaging
    private let rateLimiter: RateLimitingServicing

    private let kudosSubject = PassthroughSubject<KudosUpdate, Never>()
    var kudosUpdates: AnyPublisher<KudosUpdate, Never> {
        kudosSubject.eraseToAnyPublisher()
    }

    // Cache for quick lookups
    private var kudosCache = [String: Set<String>]() // workoutId -> Set of userIds
    private let cacheQueue = DispatchQueue(label: "com.famefit.kudoscache")

    init(
        container: CKContainer = .default(),
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging,
        rateLimiter: RateLimitingServicing
    ) {
        self.container = container
        publicDatabase = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase
        self.userProfileService = userProfileService
        self.notificationManager = notificationManager
        self.rateLimiter = rateLimiter
    }

    // MARK: - Kudos Actions

    func toggleKudos(for workoutId: String, ownerId: String) async throws -> KudosActionResult {
        let currentUserId = try await getCurrentUserId()

        // Check rate limiting
        do {
            let allowed = try await rateLimiter.checkLimit(for: .like, userId: currentUserId)
            guard allowed else {
                throw KudosError.rateLimited
            }
        } catch {
            throw KudosError.rateLimited
        }

        // Check if kudos already exists
        if try await hasUserGivenKudos(workoutId: workoutId, userId: currentUserId) {
            // Remove kudos
            try await removeKudos(for: workoutId)
            updateCache(workoutId: workoutId, userId: currentUserId, action: .remove)

            // Emit update
            let newCount = getCachedCount(for: workoutId)
            kudosSubject.send(KudosUpdate(
                workoutId: workoutId,
                action: .removed,
                userID: currentUserId,
                newCount: newCount
            ))

            return .removed
        } else {
            // Add kudos
            let kudos = WorkoutKudos(
                workoutId: workoutId,
                userID: currentUserId,
                workoutOwnerId: ownerId
            )

            let record = kudos.toCloudKitRecord(in: publicDatabase)
            try await publicDatabase.save(record)

            updateCache(workoutId: workoutId, userId: currentUserId, action: .add)

            // Record the action for rate limiting
            await rateLimiter.recordAction(.like, userId: currentUserId)

            // Send notification if not own workout
            if currentUserId != ownerId {
                if let userProfile = try? await userProfileService.fetchProfile(userId: currentUserId) {
                    await notificationManager.notifyWorkoutKudos(
                        from: userProfile,
                        for: workoutId
                    )
                }
            }

            // Emit update
            let newCount = getCachedCount(for: workoutId)
            kudosSubject.send(KudosUpdate(
                workoutId: workoutId,
                action: .added,
                userID: currentUserId,
                newCount: newCount
            ))

            return .added
        }
    }

    func removeKudos(for workoutId: String) async throws {
        let currentUserId = try await getCurrentUserId()

        // Find and delete the kudos record
        let predicate = NSPredicate(
            format: "workoutId == %@ AND userID == %@",
            workoutId,
            currentUserId
        )

        let query = CKQuery(recordType: WorkoutKudos.recordType, predicate: predicate)
        let results = try await publicDatabase.records(matching: query)

        for (recordId, _) in results.matchResults {
            try await publicDatabase.deleteRecord(withID: recordId)
        }
    }

    // MARK: - Fetching Kudos

    func getKudosSummary(for workoutId: String) async throws -> WorkoutKudosSummary {
        let currentUserId = try await getCurrentUserId()

        // Fetch all kudos for the workout
        let predicate = NSPredicate(format: "workoutId == %@", workoutId)
        let query = CKQuery(recordType: WorkoutKudos.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]

        let results = try await publicDatabase.records(matching: query)
        var kudosList: [WorkoutKudos] = []

        for (_, result) in results.matchResults {
            switch result {
            case let .success(record):
                if let kudos = WorkoutKudos(record: record) {
                    kudosList.append(kudos)
                }
            case let .failure(error):
                print("Error fetching kudos: \(error)")
            }
        }

        // Get user info for recent kudos
        let recentUserIds = kudosList.prefix(3).map(\.userID)
        var recentUsers: [WorkoutKudosSummary.KudosUser] = []

        for userID in recentUserIds {
            if let profile = try? await userProfileService.fetchProfile(userId: userID) {
                recentUsers.append(WorkoutKudosSummary.KudosUser(
                    userID: profile.id,
                    username: profile.username,
                    profileImageURL: profile.profileImageURL
                ))
            }
        }

        return WorkoutKudosSummary(
            workoutId: workoutId,
            totalCount: kudosList.count,
            hasUserKudos: kudosList.contains { $0.userID == currentUserId },
            recentUsers: recentUsers
        )
    }

    func getUserKudos(for userId: String, limit: Int = 20) async throws -> [WorkoutKudos] {
        let predicate = NSPredicate(format: "userID == %@", userId)
        let query = CKQuery(recordType: WorkoutKudos.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]

        var kudosList: [WorkoutKudos] = []
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = limit

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            operation.recordMatchedBlock = { _, result in
                switch result {
                case let .success(record):
                    if let kudos = WorkoutKudos(record: record) {
                        kudosList.append(kudos)
                    }
                case let .failure(error):
                    print("Error fetching kudos record: \(error)")
                }
            }

            operation.queryResultBlock = { result in
                if !hasResumed {
                    hasResumed = true
                    switch result {
                    case .success:
                        continuation.resume(returning: kudosList)
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }

            publicDatabase.add(operation)
        }
    }

    func hasUserGivenKudos(workoutId: String, userId: String) async throws -> Bool {
        // Check cache first
        if let cached = getCachedKudos(workoutId: workoutId, userId: userId) {
            return cached
        }

        let predicate = NSPredicate(
            format: "workoutId == %@ AND userID == %@",
            workoutId,
            userId
        )

        let query = CKQuery(recordType: WorkoutKudos.recordType, predicate: predicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: 1)

        let hasKudos = !results.matchResults.isEmpty
        updateCache(workoutId: workoutId, userId: userId, action: hasKudos ? .add : .remove)

        return hasKudos
    }

    // MARK: - Batch Operations

    func getKudosSummaries(for workoutIds: [String]) async throws -> [String: WorkoutKudosSummary] {
        guard !workoutIds.isEmpty else { return [:] }

        var summaries: [String: WorkoutKudosSummary] = [:]

        // Batch fetch kudos for all workouts
        let chunks = workoutIds.chunked(into: 20) // CloudKit limit

        for chunk in chunks {
            let predicate = NSPredicate(format: "workoutId IN %@", chunk)
            let query = CKQuery(recordType: WorkoutKudos.recordType, predicate: predicate)

            let results = try await publicDatabase.records(matching: query)

            // Group by workout
            var kudosByWorkout: [String: [WorkoutKudos]] = [:]

            for (_, result) in results.matchResults {
                switch result {
                case let .success(record):
                    if let kudos = WorkoutKudos(record: record) {
                        kudosByWorkout[kudos.workoutId, default: []].append(kudos)
                    }
                case .failure:
                    continue
                }
            }

            // Create summaries
            for workoutId in chunk {
                let kudosList = kudosByWorkout[workoutId] ?? []
                let currentUserId = try await getCurrentUserId()

                summaries[workoutId] = WorkoutKudosSummary(
                    workoutId: workoutId,
                    totalCount: kudosList.count,
                    hasUserKudos: kudosList.contains { $0.userID == currentUserId },
                    recentUsers: [] // Skip fetching users for batch operation
                )
            }
        }

        return summaries
    }

    // MARK: - Private Helpers

    private func getCurrentUserId() async throws -> String {
        let recordID = try await container.userRecordID()
        return recordID.recordName
    }

    private func updateCache(workoutId: String, userId: String, action: CacheAction) {
        cacheQueue.async { [weak self] in
            switch action {
            case .add:
                self?.kudosCache[workoutId, default: []].insert(userId)
            case .remove:
                self?.kudosCache[workoutId]?.remove(userId)
            }
        }
    }

    private func getCachedKudos(workoutId: String, userId: String) -> Bool? {
        cacheQueue.sync {
            kudosCache[workoutId]?.contains(userId)
        }
    }

    private func getCachedCount(for workoutId: String) -> Int {
        cacheQueue.sync {
            kudosCache[workoutId]?.count ?? 0
        }
    }

    private enum CacheAction {
        case add
        case remove
    }
}

// MARK: - Errors

enum KudosError: LocalizedError {
    case rateLimited
    case unauthorized
    case workoutNotFound

    var errorDescription: String? {
        switch self {
        case .rateLimited:
            "You're doing that too fast. Please try again later."
        case .unauthorized:
            "You don't have permission to perform this action."
        case .workoutNotFound:
            "The workout could not be found."
        }
    }
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
