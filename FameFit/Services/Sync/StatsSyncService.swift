//
//  StatsSyncService.swift
//  FameFit
//
//  Centralized service for syncing stats between Users and UserProfiles records
//

import Foundation
import CloudKit
import Combine

// MARK: - State Manager Actor

private actor StatsSyncStateManager {
    private var pendingSyncs: [String: UserStatsSnapshot] = [:] // UserID -> Latest stats
    private var retryQueue: [(stats: UserStatsSnapshot, attempts: Int)] = []
    
    func addPendingSync(_ stats: UserStatsSnapshot) {
        pendingSyncs[stats.userID] = stats // Only keep latest
    }
    
    func takePendingSyncs() -> [String: UserStatsSnapshot] {
        let current = pendingSyncs
        pendingSyncs.removeAll()
        return current
    }
    
    func addToRetryQueue(_ stats: UserStatsSnapshot, attempts: Int) {
        retryQueue.append((stats, attempts))
    }
    
    func takeRetryQueue() -> [(stats: UserStatsSnapshot, attempts: Int)] {
        let current = retryQueue
        retryQueue.removeAll()
        return current
    }
}

// MARK: - Stats Sync Service Protocol

protocol StatsSyncServicing {
    func syncStats(_ stats: UserStatsSnapshot) async
    func queueStatsSync(_ stats: UserStatsSnapshot)
    func processPendingSyncs() async
}

// MARK: - User Stats Snapshot Model

struct UserStatsSnapshot {
    let userID: String
    let totalWorkouts: Int
    let totalXP: Int
    let currentStreak: Int?
    let lastWorkoutDate: Date?
    
    // Extensible - add new fields here
    var additionalStats: [String: Any] = [:]
}

// MARK: - Stats Sync Service

final class StatsSyncService: StatsSyncServicing {
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private let operationQueue: CloudKitOperationQueue
    
    // Batching & throttling - protected by actor
    private let stateManager = StatsSyncStateManager()
    private var syncTimer: Timer?
    private let batchInterval: TimeInterval = 5.0 // Batch syncs every 5 seconds
    private let maxRetryAttempts = 3
    
    init(container: CKContainer, operationQueue: CloudKitOperationQueue) {
        self.publicDatabase = container.publicCloudDatabase
        self.privateDatabase = container.privateCloudDatabase
        self.operationQueue = operationQueue
        
        // Start batch timer
        startBatchTimer()
    }
    
    // MARK: - Public Methods
    
    /// Immediately sync stats (high priority)
    func syncStats(_ stats: UserStatsSnapshot) async {
        await performSync(stats)
    }
    
    /// Queue stats for batched sync (low priority)
    func queueStatsSync(_ stats: UserStatsSnapshot) {
        Task {
            await stateManager.addPendingSync(stats)
        }
    }
    
    /// Process all pending syncs
    func processPendingSyncs() async {
        let syncsToProcess = await stateManager.takePendingSyncs()
        
        // Process in parallel for efficiency
        await withTaskGroup(of: Void.self) { group in
            for (_, stats) in syncsToProcess {
                group.addTask { [weak self] in
                    await self?.performSync(stats)
                }
            }
        }
        
        // Process retries
        await processRetryQueue()
    }
    
    // MARK: - Private Methods
    
    private func performSync(_ stats: UserStatsSnapshot) async {
        do {
            // Update UserProfiles record
            try await updateUserProfile(with: stats)
            
            // Could add more sync targets here (e.g., cache, analytics)
            await updateCachedStats(stats)
            
            FameFitLogger.info("✅ Stats synced for user \(stats.userID)", category: FameFitLogger.sync)
            
        } catch {
            FameFitLogger.error("❌ Stats sync failed", error: error, category: FameFitLogger.sync)
            
            // Add to retry queue
            addToRetryQueue(stats)
        }
    }
    
    private func updateUserProfile(with stats: UserStatsSnapshot) async throws {
        // Fetch existing profile
        let predicate = NSPredicate(format: "userID == %@", stats.userID)
        let query = CKQuery(recordType: "UserProfiles", predicate: predicate)
        let results = try await publicDatabase.records(matching: query)
        
        guard let (_, profileResult) = results.matchResults.first,
              let profileRecord = try? profileResult.get() else {
            throw StatsSyncError.profileNotFound
        }
        
        // Update all stats fields
        profileRecord["workoutCount"] = stats.totalWorkouts
        profileRecord["totalXP"] = stats.totalXP
        if let streak = stats.currentStreak {
            profileRecord["currentStreak"] = streak
        }
        if let lastWorkout = stats.lastWorkoutDate {
            profileRecord["lastWorkoutDate"] = lastWorkout
        }
        profileRecord["modifiedTimestamp"] = Date()
        
        // Add any additional stats
        for (key, value) in stats.additionalStats {
            profileRecord[key] = value as? CKRecordValue
        }
        
        // Save with retry logic built into operation queue
        _ = try await operationQueue.enqueueSave(
            record: profileRecord,
            database: publicDatabase,
            priority: .low // Stats sync is low priority
        )
    }
    
    private func updateCachedStats(_ stats: UserStatsSnapshot) async {
        // Update any local caches, UserDefaults, etc.
        // This is where you'd update any denormalized data
        
        // Example: Update leaderboard cache
        await LeaderboardCache.shared.updateStats(for: stats.userID, stats: stats)
    }
    
    // MARK: - Retry Logic
    
    private func addToRetryQueue(_ stats: UserStatsSnapshot) {
        Task {
            await stateManager.addToRetryQueue(stats, attempts: 1)
        }
    }
    
    private func processRetryQueue() async {
        let retries = await stateManager.takeRetryQueue()
        
        for (stats, attempts) in retries {
            if attempts < maxRetryAttempts {
                // Exponential backoff
                let delay = Double(attempts) * 2.0
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                do {
                    try await updateUserProfile(with: stats)
                } catch {
                    // Re-add with incremented attempts
                    await stateManager.addToRetryQueue(stats, attempts: attempts + 1)
                }
            } else {
                FameFitLogger.error("❌ Stats sync failed after \(attempts) attempts for user \(stats.userID)", category: FameFitLogger.sync)
            }
        }
    }
    
    // MARK: - Batch Timer
    
    private func startBatchTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.processPendingSyncs()
            }
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}

// MARK: - Errors

enum StatsSyncError: LocalizedError {
    case profileNotFound
    case syncFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "User profile not found"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Mock Leaderboard Cache

class LeaderboardCache {
    static let shared = LeaderboardCache()
    
    func updateStats(for userID: String, stats: UserStatsSnapshot) async {
        // Update cached leaderboard data
        // This would be implemented based on your leaderboard needs
    }
}