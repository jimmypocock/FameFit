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
    func toggleKudos(for workoutID: String, ownerID: String) async throws -> KudosActionResult
    func removeKudos(for workoutID: String) async throws

    // Fetching kudos
    func getKudosSummary(for workoutID: String) async throws -> WorkoutKudosSummary
    func getUserKudos(for userID: String, limit: Int) async throws -> [WorkoutKudos]
    func hasUserGivenKudos(workoutID: String, userID: String) async throws -> Bool

    // Batch operations
    func getKudosSummaries(for workoutIDs: [String]) async throws -> [String: WorkoutKudosSummary]

    // Real-time updates
    var kudosUpdates: AnyPublisher<KudosUpdate, Never> { get }
}

// MARK: - Kudos Update Event

struct KudosUpdate {
    let workoutID: String
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
    private var kudosCache = [String: Set<String>]() // workoutID -> Set of userIDs
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

    func toggleKudos(for workoutID: String, ownerID: String) async throws -> KudosActionResult {
        let currentUserID = try await getCurrentUserID()

        // Check rate limiting
        do {
            let allowed = try await rateLimiter.checkLimit(for: .like, userID: currentUserID)
            guard allowed else {
                throw KudosError.rateLimited
            }
        } catch {
            throw KudosError.rateLimited
        }

        // Check if kudos already exists
        if try await hasUserGivenKudos(workoutID: workoutID, userID: currentUserID) {
            // Remove kudos
            try await removeKudos(for: workoutID)
            updateCache(workoutID: workoutID, userID: currentUserID, action: .remove)

            // Emit update
            let newCount = getCachedCount(for: workoutID)
            kudosSubject.send(KudosUpdate(
                workoutID: workoutID,
                action: .removed,
                userID: currentUserID,
                newCount: newCount
            ))

            return .removed
        } else {
            // Add kudos
            let kudos = WorkoutKudos(
                workoutID: workoutID,
                userID: currentUserID,
                workoutOwnerID: ownerID
            )

            let record = kudos.toCloudKitRecord(in: publicDatabase)
            try await publicDatabase.save(record)

            updateCache(workoutID: workoutID, userID: currentUserID, action: .add)

            // Record the action for rate limiting
            await rateLimiter.recordAction(.like, userID: currentUserID)

            // Send notification if not own workout
            if currentUserID != ownerID {
                if let userProfile = try? await userProfileService.fetchProfile(userID: currentUserID) {
                    await notificationManager.notifyWorkoutKudos(
                        from: userProfile,
                        for: workoutID
                    )
                }
            }

            // Emit update
            let newCount = getCachedCount(for: workoutID)
            kudosSubject.send(KudosUpdate(
                workoutID: workoutID,
                action: .added,
                userID: currentUserID,
                newCount: newCount
            ))

            return .added
        }
    }

    func removeKudos(for workoutID: String) async throws {
        let currentUserID = try await getCurrentUserID()

        // Find and delete the kudos record
        let predicate = NSPredicate(
            format: "workoutID == %@ AND userID == %@",
            workoutID,
            currentUserID
        )

        let query = CKQuery(recordType: WorkoutKudos.recordType, predicate: predicate)
        let results = try await publicDatabase.records(matching: query)

        for (recordID, _) in results.matchResults {
            try await publicDatabase.deleteRecord(withID: recordID)
        }
    }

    // MARK: - Fetching Kudos

    func getKudosSummary(for workoutID: String) async throws -> WorkoutKudosSummary {
        let currentUserID = try await getCurrentUserID()

        // Fetch all kudos for the workout
        let predicate = NSPredicate(format: "workoutID == %@", workoutID)
        let query = CKQuery(recordType: WorkoutKudos.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

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
        let recentUserIDs = kudosList.prefix(3).map(\.userID)
        var recentUsers: [WorkoutKudosSummary.KudosUser] = []

        for userID in recentUserIDs {
            if let profile = try? await userProfileService.fetchProfile(userID: userID) {
                recentUsers.append(WorkoutKudosSummary.KudosUser(
                    userID: profile.id,
                    username: profile.username,
                    profileImageURL: profile.profileImageURL
                ))
            }
        }

        return WorkoutKudosSummary(
            workoutID: workoutID,
            totalCount: kudosList.count,
            hasUserKudos: kudosList.contains { $0.userID == currentUserID},
            recentUsers: recentUsers
        )
    }

    func getUserKudos(for userID: String, limit: Int = 20) async throws -> [WorkoutKudos] {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: WorkoutKudos.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

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

    func hasUserGivenKudos(workoutID: String, userID: String) async throws -> Bool {
        // Check cache first
        if let cached = getCachedKudos(workoutID: workoutID, userID: userID) {
            return cached
        }

        let predicate = NSPredicate(
            format: "workoutID == %@ AND userID == %@",
            workoutID,
            userID
        )

        let query = CKQuery(recordType: WorkoutKudos.recordType, predicate: predicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: 1)

        let hasKudos = !results.matchResults.isEmpty
        updateCache(workoutID: workoutID, userID: userID, action: hasKudos ? .add : .remove)

        return hasKudos
    }

    // MARK: - Batch Operations

    func getKudosSummaries(for workoutIDs: [String]) async throws -> [String: WorkoutKudosSummary] {
        guard !workoutIDs.isEmpty else { return [:] }

        var summaries: [String: WorkoutKudosSummary] = [:]

        // Batch fetch kudos for all workouts
        let chunks = workoutIDs.chunked(into: 20) // CloudKit limit

        for chunk in chunks {
            let predicate = NSPredicate(format: "workoutID IN %@", chunk)
            let query = CKQuery(recordType: WorkoutKudos.recordType, predicate: predicate)

            let results = try await publicDatabase.records(matching: query)

            // Group by workout
            var kudosByWorkout: [String: [WorkoutKudos]] = [:]

            for (_, result) in results.matchResults {
                switch result {
                case let .success(record):
                    if let kudos = WorkoutKudos(record: record) {
                        kudosByWorkout[kudos.workoutID, default: []].append(kudos)
                    }
                case .failure:
                    continue
                }
            }

            // Create summaries
            for workoutID in chunk {
                let kudosList = kudosByWorkout[workoutID] ?? []
                let currentUserID = try await getCurrentUserID()

                summaries[workoutID] = WorkoutKudosSummary(
                    workoutID: workoutID,
                    totalCount: kudosList.count,
                    hasUserKudos: kudosList.contains { $0.userID == currentUserID},
                    recentUsers: [] // Skip fetching users for batch operation
                )
            }
        }

        return summaries
    }

    // MARK: - Private Helpers

    private func getCurrentUserID() async throws -> String {
        let recordID = try await container.userRecordID()
        return recordID.recordName
    }

    private func updateCache(workoutID: String, userID: String, action: CacheAction) {
        cacheQueue.async { [weak self] in
            switch action {
            case .add:
                self?.kudosCache[workoutID, default: []].insert(userID)
            case .remove:
                self?.kudosCache[workoutID]?.remove(userID)
            }
        }
    }

    private func getCachedKudos(workoutID: String, userID: String) -> Bool? {
        cacheQueue.sync {
            kudosCache[workoutID]?.contains(userID)
        }
    }

    private func getCachedCount(for workoutID: String) -> Int {
        cacheQueue.sync {
            kudosCache[workoutID]?.count ?? 0
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
