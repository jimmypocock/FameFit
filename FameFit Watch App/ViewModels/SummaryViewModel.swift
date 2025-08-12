//
//  SummaryViewModel.swift
//  FameFit Watch App
//
//  ViewModel for workout summary - handles post-workout display and sync
//

import Foundation
import SwiftUI
import HealthKit
import Combine

@MainActor
final class SummaryViewModel: ObservableObject {
    // MARK: - Dependencies
    
    private let healthKitSession: HealthKitSessionManaging
    private let watchConnectivity: WatchConnectivityService
    private let cacheManager: CacheManager
    
    // MARK: - Published State
    
    @Published var workout: HKWorkout?
    @Published var duration: TimeInterval = 0
    @Published var activeEnergy: Double = 0
    @Published var averageHeartRate: Double = 0
    @Published var distance: Double = 0
    @Published var xpEarned: Int = 0
    @Published var challengeProgress: [ChallengeInfo] = []
    @Published var isSyncing = false
    @Published var syncComplete = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedCalories: String {
        "\(Int(activeEnergy)) cal"
    }
    
    var formattedHeartRate: String {
        averageHeartRate > 0 ? "\(Int(averageHeartRate)) bpm" : "--"
    }
    
    var formattedDistance: String {
        if distance > 0 {
            let miles = distance / 1609.34
            return String(format: "%.2f mi", miles)
        }
        return "--"
    }
    
    var summaryMessage: String {
        if xpEarned > 0 {
            return "+\(xpEarned) XP earned!"
        } else {
            return "Great workout!"
        }
    }
    
    
    var hasChallengeProgress: Bool {
        !challengeProgress.isEmpty
    }
    
    // MARK: - Initialization
    
    init(
        healthKitSession: HealthKitSessionManaging,
        watchConnectivity: WatchConnectivityService,
        cacheManager: CacheManager
    ) {
        self.healthKitSession = healthKitSession
        self.watchConnectivity = watchConnectivity
        self.cacheManager = cacheManager
    }
    
    // MARK: - Public Methods
    
    func loadWorkoutSummary(_ workout: HKWorkout) async {
        self.workout = workout
        
        // Extract basic metrics
        duration = workout.duration
        
        // Use the new API for energy burned (iOS 16+/watchOS 11+)
        if let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let energyStats = workout.statistics(for: energyBurnedType) {
            activeEnergy = energyStats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        } else {
            activeEnergy = 0
        }
        
        // Use the new API for distance (iOS 16+/watchOS 11+)
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
           let distanceStats = workout.statistics(for: distanceType) {
            distance = distanceStats.sumQuantity()?.doubleValue(for: .meter()) ?? 0
        } else {
            distance = 0
        }
        
        // Calculate average heart rate from samples if available
        if let heartRateSamples = workout.workoutEvents?.compactMap({ event in
            event.metadata?[HKMetadataKeyHeartRateMotionContext] as? Double
        }), !heartRateSamples.isEmpty {
            averageHeartRate = heartRateSamples.reduce(0, +) / Double(heartRateSamples.count)
        }
        
        // Calculate XP earned (basic formula - can be enhanced)
        calculateXP()
        
        
        // Load challenge progress from cache
        await loadChallengeProgress()
        
        // Start sync with iPhone
        await syncWorkoutData()
    }
    
    func dismiss() {
        // Clean up any resources
        workout = nil
        challengeProgress = []
    }
    
    // MARK: - Private Methods
    
    private func calculateXP() {
        // Basic XP calculation matching iOS app's logic
        // Can be enhanced with multipliers, bonuses, etc.
        var xp = 0
        
        // Base XP for completing workout
        xp += 10
        
        // Duration bonus (1 XP per minute)
        xp += Int(duration / 60)
        
        // Calorie bonus (1 XP per 10 calories)
        xp += Int(activeEnergy / 10)
        
        // Distance bonus for applicable workouts
        if let workoutType = workout?.workoutActivityType,
           [.running, .walking, .cycling, .swimming].contains(workoutType) {
            // 1 XP per 0.1 mile
            let miles = distance / 1609.34
            xp += Int(miles * 10)
        }
        
        // Heart rate zone bonus
        if averageHeartRate > 140 {
            xp += 20 // High intensity bonus
        } else if averageHeartRate > 120 {
            xp += 10 // Moderate intensity bonus
        }
        
        xpEarned = xp
    }
    
    private func loadChallengeProgress() async {
        // Load cached challenge data
        if let cached: [ChallengeInfo] = await cacheManager.loadCached(
            [ChallengeInfo].self,
            for: WatchConfiguration.StorageKeys.Challenge.activeChallenges.rawValue,
            maxAge: WatchConfiguration.Cache.challengeCacheDuration
        ) {
            challengeProgress = cached
        }
    }
    
    private func syncWorkoutData() async {
        isSyncing = true
        defer { isSyncing = false }
        
        guard let workout = workout else { return }
        
        // Create workout update
        let update = WorkoutUpdate(
            workoutID: workout.uuid.uuidString,
            status: .ended,
            timestamp: Date(),
            metrics: WorkoutMetricsData(
                heartRate: averageHeartRate,
                activeEnergy: activeEnergy,
                distance: distance,
                elapsedTime: duration,
                timestamp: Date()
            ),
            groupWorkoutID: nil // Will be set if this was a group workout
        )
        
        // Send to iPhone
        await watchConnectivity.sendWorkoutUpdate(update)
        
        // Request updated challenges
        if watchConnectivity.isReachable {
            do {
                let challenges = try await watchConnectivity.requestChallenges()
                challengeProgress = challenges
                
                // Cache the updated challenges
                await cacheManager.cache(
                    challenges,
                    for: WatchConfiguration.StorageKeys.Challenge.activeChallenges.rawValue
                )
                
                syncComplete = true
            } catch {
                // Sync failed, but workout is still saved to HealthKit
                errorMessage = "Sync failed. Workout saved locally."
            }
        } else {
            // iPhone not reachable, queue for later sync
            await queueWorkoutForSync(update)
        }
    }
    
    private func queueWorkoutForSync(_ update: WorkoutUpdate) async {
        // Load existing queue
        var queue: [WorkoutUpdate] = await cacheManager.loadCached(
            [WorkoutUpdate].self,
            for: WatchConfiguration.StorageKeys.Sync.pendingUploads.rawValue,
            maxAge: .infinity
        ) ?? []
        
        // Add this workout
        queue.append(update)
        
        // Save updated queue
        await cacheManager.cache(
            queue,
            for: WatchConfiguration.StorageKeys.Sync.pendingUploads.rawValue
        )
    }
    
    // MARK: - Display Helpers
    
    
    func challengeIcon(for challenge: ChallengeInfo) -> String {
        // Determine icon based on challenge type/name
        if challenge.name.lowercased().contains("step") {
            return "figure.walk"
        } else if challenge.name.lowercased().contains("calorie") {
            return "flame.fill"
        } else if challenge.name.lowercased().contains("distance") {
            return "location.fill"
        } else {
            return "target"
        }
    }
}