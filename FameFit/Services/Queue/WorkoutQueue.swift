//
//  WorkoutQueue.swift
//  FameFit
//
//  Workout-specific queue processing
//

import Foundation
import CloudKit
import os.log

/// Handles workout-specific queue operations
@MainActor
final class WorkoutQueue {
    private let queue = Queue()
    private let cloudKitManager: CloudKitService
    private let xpTransactionService: XPTransactionService
    private let activityFeedService: ActivityFeedProtocol
    private let notificationManager: NotificationProtocol?
    private let logger = Logger(subsystem: "com.famefit", category: "WorkoutQueue")
    
    init(cloudKitManager: CloudKitService,
         xpTransactionService: XPTransactionService,
         activityFeedService: ActivityFeedProtocol,
         notificationManager: NotificationProtocol?) {
        self.cloudKitManager = cloudKitManager
        self.xpTransactionService = xpTransactionService
        self.activityFeedService = activityFeedService
        self.notificationManager = notificationManager
    }
    
    // MARK: - Queue Operations
    
    /// Queue a workout for processing
    func queueWorkout(_ workout: Workout, xpResult: (baseXP: Int, finalXP: Int, factors: XPCalculationFactors)) async throws {
        guard let userID = cloudKitManager.currentUserID else {
            throw WorkoutProcessingError.noUserID
        }
        
        // Step 1: Queue workout save (critical - must happen first)
        let savePayload = WorkoutSavePayload(workout: workout, userID: userID)
        let saveData = try JSONEncoder().encode(savePayload)
        let saveItem = QueueItem(
            id: "workout_save_\(workout.id)",
            type: .workoutSave,
            data: saveData,
            priority: .critical
        )
        await queue.enqueue(saveItem)
        
        // Step 2: Queue dependent operations that will run after save succeeds
        
        // XP Transaction
        let xpPayload = XPTransactionPayload(
            workoutID: workout.id,
            userID: userID,
            baseXP: xpResult.baseXP,
            finalXP: xpResult.finalXP,
            factors: xpResult.factors
        )
        let xpData = try JSONEncoder().encode(xpPayload)
        let xpItem = QueueItem(
            id: "xp_transaction_\(workout.id)",
            type: .xpTransaction,
            data: xpData,
            priority: .high
        )
        await queue.enqueue(xpItem)
        
        // Stats Update (depends on XP transaction)
        let statsPayload = StatsUpdatePayload(
            userID: userID,
            xpEarned: xpResult.finalXP,
            workoutCompleted: true
        )
        let statsData = try JSONEncoder().encode(statsPayload)
        let statsItem = QueueItem(
            id: "stats_update_\(workout.id)",
            type: .statsUpdate,
            data: statsData,
            priority: .high
        )
        await queue.enqueue(statsItem)
        
        // Activity Feed (independent)
        let feedPayload = ActivityFeedPayload(
            workout: workout,
            privacy: .public,
            includeDetails: true
        )
        let feedData = try JSONEncoder().encode(feedPayload)
        let feedItem = QueueItem(
            id: "activity_feed_\(workout.id)",
            type: .activityFeed,
            data: feedData,
            priority: .medium
        )
        await queue.enqueue(feedItem)
        
        // Notification (independent)
        let notificationPayload = NotificationPayload(
            workoutID: workout.id,
            xpEarned: xpResult.finalXP,
            workoutType: workout.workoutType,
            previousXP: cloudKitManager.totalXP - xpResult.finalXP,
            currentXP: cloudKitManager.totalXP
        )
        let notificationData = try JSONEncoder().encode(notificationPayload)
        let notificationItem = QueueItem(
            id: "notification_\(workout.id)",
            type: .notification,
            data: notificationData,
            priority: .low
        )
        await queue.enqueue(notificationItem)
        
        logger.info("Queued workout \(workout.id) with all operations")
    }
    
    /// Process next item in queue
    func processNext() async -> Bool {
        guard let item = await queue.dequeue() else {
            return false
        }
        
        do {
            switch item.type {
            case .workoutSave:
                try await processWorkoutSave(item)
            case .xpTransaction:
                try await processXPTransaction(item)
            case .statsUpdate:
                try await processStatsUpdate(item)
            case .activityFeed:
                try await processActivityFeed(item)
            case .notification:
                await processNotification(item)
            case .challengeLink:
                try await processChallengeLink(item)
            default:
                logger.warning("Unhandled queue item type: \(item.type.rawValue)")
            }
            
            // Remove from queue on success
            await queue.remove(id: item.id)
            logger.info("Successfully processed \(item.description)")
            return true
            
        } catch {
            logger.error("Failed to process \(item.description): \(error.localizedDescription)")
            await queue.handleFailure(for: item)
            return false
        }
    }
    
    /// Process all pending items
    func processAll() async {
        var processedCount = 0
        let maxBatchSize = 10
        
        while processedCount < maxBatchSize {
            let processed = await processNext()
            if !processed {
                break
            }
            processedCount += 1
        }
        
        if processedCount > 0 {
            logger.info("Processed \(processedCount) queue items")
        }
    }
    
    // MARK: - Processing Methods
    
    private func processWorkoutSave(_ item: QueueItem) async throws {
        let payload = try JSONDecoder().decode(WorkoutSavePayload.self, from: item.data)
        let workout = payload.workout
        
        // Create CloudKit record
        let record = CKRecord(recordType: "Workouts")
        record["workoutID"] = workout.id
        record["workoutType"] = workout.workoutType
        record["startDate"] = workout.startDate
        record["endDate"] = workout.endDate
        record["duration"] = workout.duration
        record["totalEnergyBurned"] = workout.totalEnergyBurned
        record["totalDistance"] = workout.totalDistance
        record["averageHeartRate"] = workout.averageHeartRate
        record["followersEarned"] = workout.followersEarned
        record["xpEarned"] = workout.xpEarned
        record["source"] = workout.source
        
        if let groupWorkoutID = workout.groupWorkoutID {
            record["groupWorkoutID"] = groupWorkoutID
        }
        
        // Save with retry
        _ = try await cloudKitManager.saveWithRetry(
            record,
            database: cloudKitManager.privateDatabase,
            configuration: .aggressive
        )
        
        logger.info("Saved workout \(workout.id) to CloudKit")
    }
    
    private func processXPTransaction(_ item: QueueItem) async throws {
        let payload = try JSONDecoder().decode(XPTransactionPayload.self, from: item.data)
        
        _ = try await xpTransactionService.createTransaction(
            userID: payload.userID,
            workoutID: payload.workoutID,
            baseXP: payload.baseXP,
            finalXP: payload.finalXP,
            factors: payload.factors
        )
        
        logger.info("Created XP transaction for workout \(payload.workoutID)")
    }
    
    private func processStatsUpdate(_ item: QueueItem) async throws {
        let payload = try JSONDecoder().decode(StatsUpdatePayload.self, from: item.data)
        
        // Update user stats in CloudKit
        await cloudKitManager.completeWorkout(xpEarned: payload.xpEarned)
        
        logger.info("Updated stats for user \(payload.userID)")
    }
    
    private func processActivityFeed(_ item: QueueItem) async throws {
        let payload = try JSONDecoder().decode(ActivityFeedPayload.self, from: item.data)
        
        try await activityFeedService.postWorkoutActivity(
            workout: payload.workout,
            privacy: payload.privacy,
            includeDetails: payload.includeDetails
        )
        
        logger.info("Posted workout \(payload.workout.id) to activity feed")
    }
    
    private func processNotification(_ item: QueueItem) async {
        guard let notificationManager = notificationManager else { return }
        
        do {
            let payload = try JSONDecoder().decode(NotificationPayload.self, from: item.data)
            
            // Send XP milestone notifications
            await notificationManager.notifyXPMilestone(
                previousXP: payload.previousXP,
                currentXP: payload.currentXP
            )
            
            // Post notification for feed refresh
            NotificationCenter.default.post(
                name: Notification.Name("WorkoutCompleted"),
                object: nil,
                userInfo: ["workoutID": payload.workoutID]
            )
            
            await queue.remove(id: item.id)
            
        } catch {
            logger.error("Failed to process notification: \(error.localizedDescription)")
            await queue.handleFailure(for: item)
        }
    }
    
    private func processChallengeLink(_ item: QueueItem) async throws {
        let payload = try JSONDecoder().decode(ChallengeLinkPayload.self, from: item.data)
        // Challenge processing would go here
        logger.info("Processing challenge links for workout \(payload.workout.id)")
    }
    
    // MARK: - Monitoring
    
    /// Get queue statistics
    func getQueueStats() async -> (pending: Int, failed: Int) {
        let pending = await queue.getPendingItems().count
        let failed = await queue.getFailedItems().count
        return (pending, failed)
    }
    
    /// Get failed items for debugging
    func getFailedItems() async -> [QueueItem] {
        await queue.getFailedItems()
    }
}