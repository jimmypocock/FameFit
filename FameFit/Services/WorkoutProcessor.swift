//
//  WorkoutProcessor.swift
//  FameFit
//
//  Centralized service for processing ALL workout completions consistently
//  Handles both single-person (HealthKit) and group workouts
//

import Foundation
import HealthKit
import CloudKit

/// Unified service that processes all workout completions in the app
/// This ensures consistent handling of XP, stats, feed items, and records
@MainActor
final class WorkoutProcessor {
    // MARK: - Dependencies
    
    private let cloudKitManager: CloudKitManager
    private let xpTransactionService: XPTransactionService
    private let activityFeedService: ActivityFeedServicing
    private let notificationManager: NotificationManaging?
    private let userProfileService: UserProfileServicing
    
    // MARK: - Initialization
    
    init(
        cloudKitManager: CloudKitManager,
        xpTransactionService: XPTransactionService,
        activityFeedService: ActivityFeedServicing,
        notificationManager: NotificationManaging?,
        userProfileService: UserProfileServicing
    ) {
        self.cloudKitManager = cloudKitManager
        self.xpTransactionService = xpTransactionService
        self.activityFeedService = activityFeedService
        self.notificationManager = notificationManager
        self.userProfileService = userProfileService
    }
    
    // MARK: - Public Methods
    
    /// Process a workout from HealthKit
    func processHealthKitWorkout(_ hkWorkout: HKWorkout) async throws {
        FameFitLogger.info("🏋️ Processing HealthKit workout: \(hkWorkout.workoutActivityType.displayName)", category: FameFitLogger.workout)
        
        // Create workout record
        let workout = Workout(from: hkWorkout, followersEarned: 0)
        
        // Process using common pipeline
        try await processWorkout(
            workout: workout,
            source: .healthKit,
            groupWorkoutID: nil
        )
    }
    
    /// Process a group workout start for host
    func processGroupWorkoutStart(
        groupWorkout: GroupWorkout,
        hostID: String
    ) async throws {
        FameFitLogger.info("🏋️ Processing group workout start for host: \(groupWorkout.name)", category: FameFitLogger.workout)
        
        // Store the start time for this user
        let key = "group_workout_start_\(groupWorkout.id)_\(hostID)"
        UserDefaults.standard.set(Date(), forKey: key)
    }
    
    /// Process a group workout start for participant
    func processGroupWorkoutJoin(
        groupWorkout: GroupWorkout,
        participantID: String
    ) async throws {
        FameFitLogger.info("🏋️ Processing group workout join for participant: \(groupWorkout.name)", category: FameFitLogger.workout)
        
        // Store the join time for this participant
        let key = "group_workout_start_\(groupWorkout.id)_\(participantID)"
        UserDefaults.standard.set(Date(), forKey: key)
    }
    
    /// Process a group workout completion for host
    func processGroupWorkoutEnd(
        groupWorkout: GroupWorkout,
        hostID: String
    ) async throws {
        FameFitLogger.info("🏋️ Processing group workout end for host: \(groupWorkout.name)", category: FameFitLogger.workout)
        
        // Get start time
        let key = "group_workout_start_\(groupWorkout.id)_\(hostID)"
        guard let startTime = UserDefaults.standard.object(forKey: key) as? Date else {
            FameFitLogger.error("No start time found for group workout", category: FameFitLogger.workout)
            throw WorkoutProcessingError.noStartTime
        }
        
        // Create workout record
        let workout = createWorkoutFromGroupWorkout(
            groupWorkout: groupWorkout,
            userID: hostID,
            startTime: startTime,
            endTime: Date()
        )
        
        // Process using common pipeline
        try await processWorkout(
            workout: workout,
            source: .groupWorkout,
            groupWorkoutID: groupWorkout.id
        )
        
        // Clean up stored time
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    /// Process a group workout leave/completion for participant
    func processGroupWorkoutLeave(
        groupWorkout: GroupWorkout,
        participantID: String
    ) async throws {
        FameFitLogger.info("🏋️ Processing group workout leave for participant: \(groupWorkout.name)", category: FameFitLogger.workout)
        
        // Get start time
        let key = "group_workout_start_\(groupWorkout.id)_\(participantID)"
        guard let startTime = UserDefaults.standard.object(forKey: key) as? Date else {
            FameFitLogger.error("No start time found for participant", category: FameFitLogger.workout)
            throw WorkoutProcessingError.noStartTime
        }
        
        // Create workout record
        let workout = createWorkoutFromGroupWorkout(
            groupWorkout: groupWorkout,
            userID: participantID,
            startTime: startTime,
            endTime: Date()
        )
        
        // Process using common pipeline
        try await processWorkout(
            workout: workout,
            source: .groupWorkout,
            groupWorkoutID: groupWorkout.id
        )
        
        // Clean up stored time
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    // MARK: - Core Processing Pipeline
    
    /// The unified processing pipeline for ALL workouts
    private func processWorkout(
        workout: Workout,
        source: WorkoutSource,
        groupWorkoutID: String?
    ) async throws {
        FameFitLogger.info("📊 Processing workout through unified pipeline", category: FameFitLogger.workout)
        
        // Step 1: Calculate XP
        let xpResult = calculateXP(for: workout)
        
        // Step 2: Save workout record to CloudKit
        let workoutWithXP = Workout(
            id: workout.id,
            workoutType: workout.workoutType,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            totalEnergyBurned: workout.totalEnergyBurned,
            totalDistance: workout.totalDistance,
            averageHeartRate: workout.averageHeartRate,
            followersEarned: xpResult.finalXP, // Legacy field
            xpEarned: xpResult.finalXP,
            source: workout.source,
            groupWorkoutID: groupWorkoutID
        )
        
        try await saveWorkoutRecord(workoutWithXP)
        
        // Step 3: Create XP Transaction
        guard let userID = cloudKitManager.currentUserID else {
            throw WorkoutProcessingError.noUserID
        }
        
        _ = try await xpTransactionService.createTransaction(
            userID: userID,
            workoutID: workout.id.uuidString,
            baseXP: xpResult.baseXP,
            finalXP: xpResult.finalXP,
            factors: xpResult.factors
        )
        
        // Step 4: Update user stats
        await updateUserStats(xpEarned: xpResult.finalXP)
        
        // Step 5: Create activity feed item (if sharing is enabled)
        if await shouldShareToFeed() {
            try await createFeedItem(
                workout: workoutWithXP,
                xpEarned: xpResult.finalXP,
                source: source
            )
        }
        
        // Step 6: Send notifications
        await sendNotifications(
            workout: workoutWithXP,
            xpEarned: xpResult.finalXP,
            source: source
        )
        
        // Step 7: Update user profile workout count
        await updateUserProfileWorkoutCount()
        
        FameFitLogger.info("✅ Workout processing complete: +\(xpResult.finalXP) XP", category: FameFitLogger.workout)
    }
    
    // MARK: - Helper Methods
    
    private func createWorkoutFromGroupWorkout(
        groupWorkout: GroupWorkout,
        userID: String,
        startTime: Date,
        endTime: Date
    ) -> Workout {
        let duration = endTime.timeIntervalSince(startTime)
        
        // Estimate calories based on workout type and duration (rough estimates)
        let caloriesPerMinute: Double = {
            switch groupWorkout.workoutType {
            case .running: return 10
            case .cycling: return 8
            case .swimming: return 11
            case .walking: return 4
            case .hiking: return 6
            case .yoga: return 3
            case .functionalStrengthTraining: return 8
            case .traditionalStrengthTraining: return 6
            case .crossTraining: return 9
            case .elliptical: return 8
            case .rowing: return 10
            case .stairClimbing: return 9
            case .highIntensityIntervalTraining: return 12
            case .dance: return 6
            case .boxing: return 12
            case .kickboxing: return 10
            case .pilates: return 4
            case .tennis: return 8
            case .basketball: return 8
            case .soccer: return 8
            default: return 5
            }
        }()
        
        let estimatedCalories = (duration / 60) * caloriesPerMinute
        
        return Workout(
            id: UUID(),
            workoutType: groupWorkout.workoutType.storageKey,
            startDate: startTime,
            endDate: endTime,
            duration: duration,
            totalEnergyBurned: estimatedCalories,
            totalDistance: nil, // Could be added to group workouts later
            averageHeartRate: nil, // Could be added if we integrate with Watch
            followersEarned: 0,
            xpEarned: nil,
            source: "Group Workout",
            groupWorkoutID: groupWorkout.id
        )
    }
    
    private func calculateXP(for workout: Workout) -> (baseXP: Int, finalXP: Int, factors: XPCalculationFactors) {
        let currentStreak = cloudKitManager.currentStreak
        let userStats = UserStats(
            totalWorkouts: cloudKitManager.totalWorkouts,
            currentStreak: currentStreak,
            recentWorkouts: [],
            totalXP: cloudKitManager.totalXP
        )
        
        let result = XPCalculator.calculateXP(for: workout, userStats: userStats)
        
        // Check for special bonuses
        let workoutCount = cloudKitManager.totalWorkouts + 1
        let bonusXP = XPCalculator.calculateSpecialBonus(
            workoutNumber: workoutCount,
            isPersonalRecord: false
        )
        
        return (
            baseXP: result.baseXP,
            finalXP: result.finalXP + bonusXP,
            factors: result.factors
        )
    }
    
    private func saveWorkoutRecord(_ workout: Workout) async throws {
        let record = CKRecord(recordType: "Workouts")
        record["workoutID"] = workout.id.uuidString
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
        
        _ = try await cloudKitManager.privateDatabase.save(record)
        FameFitLogger.info("💾 Saved workout record to CloudKit", category: FameFitLogger.workout)
    }
    
    private func updateUserStats(xpEarned: Int) async {
        await cloudKitManager.completeWorkout(xpEarned: xpEarned)
        // This now updates both XP and workout count
    }
    
    private func shouldShareToFeed() async -> Bool {
        // Check user's sharing preferences
        // This would check ActivityFeedSettings
        return true // For now, always share
    }
    
    private func createFeedItem(
        workout: Workout,
        xpEarned: Int,
        source: WorkoutSource
    ) async throws {
        let privacy: WorkoutPrivacy = .public // Could be configurable
        let includeDetails = true // Could be configurable
        
        do {
            try await activityFeedService.postWorkoutActivity(
                workoutHistory: workout,
                privacy: privacy,
                includeDetails: includeDetails
            )
            FameFitLogger.info("📢 Created activity feed item", category: FameFitLogger.social)
        } catch {
            FameFitLogger.error("❌ Failed to create activity feed item: \(error)", category: FameFitLogger.social)
            // Don't throw - we don't want feed failures to break workout processing
            // But log it so we know what happened
        }
    }
    
    private func sendNotifications(
        workout: Workout,
        xpEarned: Int,
        source: WorkoutSource
    ) async {
        guard let notificationManager = notificationManager else { return }
        
        // Send XP milestone notifications
        let previousXP = cloudKitManager.totalXP - xpEarned
        await notificationManager.notifyXPMilestone(
            previousXP: previousXP,
            currentXP: cloudKitManager.totalXP
        )
        
        // Could add more notification types here
    }
    
    private func updateUserProfileWorkoutCount() async {
        // Trigger profile update with new workout count
        // This will be reflected when the profile is next fetched
        FameFitLogger.info("📈 Updated user profile workout count", category: FameFitLogger.social)
    }
}

// MARK: - Supporting Types

enum WorkoutSource {
    case healthKit
    case groupWorkout
    case manual // For future manual entry
}

enum WorkoutProcessingError: LocalizedError {
    case noStartTime
    case noUserID
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .noStartTime:
            return "No start time found for workout"
        case .noUserID:
            return "User not authenticated"
        case .saveFailed:
            return "Failed to save workout"
        }
    }
}

// MARK: - Workout Extension

extension Workout {
    init(
        id: UUID,
        workoutType: String,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        totalEnergyBurned: Double,
        totalDistance: Double?,
        averageHeartRate: Double?,
        followersEarned: Int,
        xpEarned: Int?,
        source: String,
        groupWorkoutID: String?
    ) {
        self.id = id
        self.workoutType = workoutType
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.totalEnergyBurned = totalEnergyBurned
        self.totalDistance = totalDistance
        self.averageHeartRate = averageHeartRate
        self.followersEarned = followersEarned
        self.xpEarned = xpEarned
        self.source = source
        
        // Store group workout ID in a property if available
        // This might need to be added to the Workout model
    }
    
    var groupWorkoutID: String? {
        // This would need to be added to the Workout model
        return nil
    }
}
