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
    private let workoutChallengesService: WorkoutChallengesServicing
    private let workoutChallengeLinksService: WorkoutChallengeLinksServicing
    
    // MARK: - Initialization
    
    init(
        cloudKitManager: CloudKitManager,
        xpTransactionService: XPTransactionService,
        activityFeedService: ActivityFeedServicing,
        notificationManager: NotificationManaging?,
        userProfileService: UserProfileServicing,
        workoutChallengesService: WorkoutChallengesServicing,
        workoutChallengeLinksService: WorkoutChallengeLinksServicing
    ) {
        self.cloudKitManager = cloudKitManager
        self.xpTransactionService = xpTransactionService
        self.activityFeedService = activityFeedService
        self.notificationManager = notificationManager
        self.userProfileService = userProfileService
        self.workoutChallengesService = workoutChallengesService
        self.workoutChallengeLinksService = workoutChallengeLinksService
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
        
        // Step 6: Process challenges
        await processWorkoutForChallenges(workout: workoutWithXP, userID: userID)
        
        // Step 7: Send notifications
        await sendNotifications(
            workout: workoutWithXP,
            xpEarned: xpResult.finalXP,
            source: source
        )
        
        // Step 8: Update user profile workout count
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
        record["id"] = workout.id.uuidString
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
        
        // Post notification for feed refresh
        NotificationCenter.default.post(
            name: Notification.Name("WorkoutCompleted"),
            object: nil,
            userInfo: ["workoutID": workout.id.uuidString]
        )
        
        // Could add more notification types here
    }
    
    private func updateUserProfileWorkoutCount() async {
        // Trigger profile update with new workout count
        // This will be reflected when the profile is next fetched
        FameFitLogger.info("📈 Updated user profile workout count", category: FameFitLogger.social)
    }
    
    // MARK: - Challenge Processing
    
    // MARK: - Verification Helper
    
    private func verifyLinkWithRetry(link: WorkoutChallengeLink, workoutChallengeIDs: [String]) async {
        do {
            // First attempt at verification
            _ = try await workoutChallengeLinksService.verifyLink(linkID: link.id)
            FameFitLogger.info("✅ Verified challenge link: \(link.id)", category: FameFitLogger.workout)
            
        } catch let error as VerificationFailureReason where error == .timeout {
            FameFitLogger.warning("⏱️ Verification timed out for link: \(link.id)", category: FameFitLogger.workout)
            
            // Check if challenge is ending soon - use grace period if needed
            if let workoutChallengeID = workoutChallengeIDs.first(where: { $0 == link.workoutChallengeID }) {
                await checkForGracePeriodVerification(link: link, workoutChallengeID: workoutChallengeID)
            }
            
        } catch {
            FameFitLogger.warning("⚠️ Initial verification failed for link: \(link.id): \(error)", category: FameFitLogger.workout)
            
            // Schedule retry with backoff
            Task {
                do {
                    _ = try await workoutChallengeLinksService.retryVerificationWithBackoff(linkID: link.id)
                    FameFitLogger.info("✅ Retry verification successful for link: \(link.id)", category: FameFitLogger.workout)
                } catch {
                    FameFitLogger.error("❌ All verification attempts failed for link: \(link.id)", error: error, category: FameFitLogger.workout)
                    
                    // Final fallback - check if user can request manual verification
                    await notifyUserAboutVerificationFailure(linkID: link.id)
                }
            }
        }
    }
    
    private func checkForGracePeriodVerification(link: WorkoutChallengeLink, workoutChallengeID: String) async {
        do {
            // Fetch challenge to get end date
            let challenge = try await workoutChallengesService.fetchChallenge(workoutChallengeID: workoutChallengeID)
            
            // Check if within grace period
            let timeSinceChallengeEnd = Date().timeIntervalSince(challenge.endDate)
            if timeSinceChallengeEnd <= VerificationConfig.challengeEndGracePeriod && timeSinceChallengeEnd > 0 {
                _ = try await workoutChallengeLinksService.verifyWithGracePeriod(
                    linkID: link.id,
                    challengeEndDate: challenge.endDate
                )
                FameFitLogger.info("✅ Grace period verification successful for link: \(link.id)", category: FameFitLogger.workout)
            }
        } catch {
            FameFitLogger.error("Failed to apply grace period verification", error: error, category: FameFitLogger.workout)
        }
    }
    
    private func notifyUserAboutVerificationFailure(linkID: String) async {
        // Send notification to user about verification failure and manual verification option
        guard let notificationManager = notificationManager else { return }
        
        // Get workout type for the notification (generic for now)
        await notificationManager.notifyChallengeVerificationFailure(
            linkID: linkID,
            workoutName: "workout"
        )
    }
    
    private func processWorkoutForChallenges(workout: Workout, userID: String) async {
        do {
            // Fetch user's active challenges
            let activeChallenges = try await workoutChallengesService.fetchActiveChallenge(for: userID)
            
            guard !activeChallenges.isEmpty else {
                FameFitLogger.debug("No active challenges for user \(userID)", category: FameFitLogger.workout)
                return
            }
            
            FameFitLogger.info("🎯 Processing workout for \(activeChallenges.count) active challenges", category: FameFitLogger.workout)
            
            // Get challenge IDs
            let workoutChallengeIDs = activeChallenges.map { $0.id }
            
            // Process the workout for all active challenges
            let createdLinks = try await workoutChallengeLinksService.processWorkoutForChallenges(
                workout: workout,
                userID: userID,
                activeChallengeIDs: workoutChallengeIDs
            )
            
            if !createdLinks.isEmpty {
                FameFitLogger.info("✅ Created \(createdLinks.count) challenge links for workout", category: FameFitLogger.workout)
                
                // Start verification process with proper retry logic
                Task {
                    // Initial delay to ensure HealthKit data is confirmed
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    
                    for link in createdLinks {
                        await verifyLinkWithRetry(link: link, workoutChallengeIDs: workoutChallengeIDs)
                    }
                }
            }
        } catch {
            FameFitLogger.error("Failed to process workout for challenges", error: error, category: FameFitLogger.workout)
        }
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
