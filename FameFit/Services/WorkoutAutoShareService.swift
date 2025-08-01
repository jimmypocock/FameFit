//
//  WorkoutAutoShareService.swift
//  FameFit
//
//  Service for automatically sharing workouts to the activity feed based on user settings
//

import Foundation
import Combine
import HealthKit

// MARK: - Workout Auto Share Service Protocol

protocol WorkoutAutoShareServicing: AnyObject {
    func setupAutoSharing()
    func stopAutoSharing()
}

// MARK: - Implementation

final class WorkoutAutoShareService: WorkoutAutoShareServicing {
    private let workoutObserver: WorkoutObserving
    private let activityFeedService: ActivityFeedServicing
    private let activityFeedSettingsService: ActivityFeedSettingsServicing
    private let notificationManager: NotificationManaging
    private let notificationStore: NotificationStoring
    
    private var cancellables = Set<AnyCancellable>()
    private var currentSettings: ActivityFeedSettings?
    
    init(
        workoutObserver: WorkoutObserving,
        activityFeedService: ActivityFeedServicing,
        activityFeedSettingsService: ActivityFeedSettingsServicing,
        notificationManager: NotificationManaging,
        notificationStore: any NotificationStoring
    ) {
        self.workoutObserver = workoutObserver
        self.activityFeedService = activityFeedService
        self.activityFeedSettingsService = activityFeedSettingsService
        self.notificationManager = notificationManager
        self.notificationStore = notificationStore
    }
    
    // MARK: - Public Methods
    
    func setupAutoSharing() {
        // Load initial settings
        Task {
            do {
                currentSettings = try await activityFeedSettingsService.loadSettings()
            } catch {
                print("Failed to load activity feed settings: \(error)")
            }
        }
        
        // Subscribe to settings changes
        activityFeedSettingsService.settingsPublisher
            .sink { [weak self] settings in
                self?.currentSettings = settings
            }
            .store(in: &cancellables)
        
        // Subscribe to workout completions
        workoutObserver.workoutCompletedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] workout in
                Task {
                    await self?.handleWorkoutCompletion(workout)
                }
            }
            .store(in: &cancellables)
    }
    
    func stopAutoSharing() {
        cancellables.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func handleWorkoutCompletion(_ workout: Workout) async {
        guard let settings = currentSettings,
              settings.shareActivitiesToFeed,
              settings.shareWorkouts
        else {
            print("Auto-sharing disabled or settings not loaded")
            return
        }
        
        // Convert workout type for checking
        guard let hkWorkoutType = HKWorkoutActivityType.fromDisplayName(workout.workoutType) else {
            print("Invalid workout type")
            return
        }
        
        // Create a mock HKWorkout for the settings check (not ideal but works with current API)
        // In production, we'd refactor shouldShareWorkout to work with our Workout model
        let mockWorkout = createMockHKWorkout(from: workout, type: hkWorkoutType)
        
        guard settings.shouldShareWorkout(mockWorkout) else {
            print("Workout doesn't meet sharing criteria")
            return
        }
        
        // Get privacy level for workouts
        let privacy = settings.workoutPrivacy
        
        // Apply sharing delay if configured
        if settings.sharingDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(settings.sharingDelay * 1_000_000_000))
            
            // Re-check settings in case user changed them during delay
            guard let currentSettings = self.currentSettings,
                  currentSettings.shareActivitiesToFeed,
                  currentSettings.shareWorkouts
            else {
                print("Sharing disabled during delay period")
                return
            }
        }
        
        do {
            // Share the workout
            try await activityFeedService.postWorkoutActivity(
                workoutHistory: workout,
                privacy: privacy,
                includeDetails: settings.shareWorkoutDetails
            )
            
            // Send notification about auto-share
            await sendAutoShareNotification(for: workout, privacy: privacy)
            
            print("Successfully auto-shared workout: \(workout.workoutType)")
            
        } catch {
            print("Failed to auto-share workout: \(error)")
        }
    }
    
    private func createMockHKWorkout(from workout: Workout, type: HKWorkoutActivityType) -> HKWorkout {
        // This is a workaround since we can't create real HKWorkout objects
        // In production, we'd refactor ActivityFeedSettings.shouldShareWorkout to accept our Workout model
        let mockWorkout = HKWorkout(
            activityType: type,
            start: workout.startDate,
            end: workout.endDate,
            duration: workout.duration,
            totalEnergyBurned: workout.totalEnergyBurned > 0 ? 
                HKQuantity(unit: .kilocalorie(), doubleValue: workout.totalEnergyBurned) : nil,
            totalDistance: (workout.totalDistance ?? 0) > 0 ? 
                HKQuantity(unit: .meter(), doubleValue: workout.totalDistance ?? 0) : nil,
            metadata: nil
        )
        return mockWorkout
    }
    
    private func sendAutoShareNotification(for workout: Workout, privacy: WorkoutPrivacy) async {
        let workoutType = workout.workoutType
        
        // Create a FameFit notification for the notification store
        let fameFitNotification = FameFitNotification(
            title: "Workout Shared 📢",
            body: "Your \(workoutType) has been automatically shared to your activity feed with \(privacy.displayName) privacy",
            character: FameFitCharacter.defaultCharacter,
            workoutDuration: Int(workout.duration / 60),
            calories: Int(workout.totalEnergyBurned),
            followersEarned: workout.xpEarned ?? 0
        )
        
        // Add to notification store
        notificationStore.addFameFitNotification(fameFitNotification)
        
        // Send system notification for workout sharing
        await notificationManager.notifyWorkoutCompleted(workout)
        
        // Log for debugging
        print("Sent auto-share notification for \(workoutType)")
    }
}