//
//  BackgroundWorkoutProcessor.swift
//  FameFit
//
//  Handles background processing of workouts for auto-sharing
//

import Foundation
import HealthKit
import BackgroundTasks

// MARK: - Background Workout Processor

final class BackgroundWorkoutProcessor {
    static let shared = BackgroundWorkoutProcessor()
    
    // Background task identifier
    static let taskIdentifier = "com.jimmypocock.FameFit.workout-processing"
    
    private var dependencyContainer: DependencyContainer?
    
    private init() {}
    
    // MARK: - Setup
    
    func configure(with container: DependencyContainer) {
        self.dependencyContainer = container
        // Background task registration is handled in AppDelegate
    }
    
    // MARK: - Background Task Handling
    
    func handleBackgroundTask(_ task: BGTask) {
        // Schedule the next background task
        scheduleNextBackgroundTask()
        
        // Create a task to process workouts
        let processingTask = Task {
            do {
                let processed = try await processRecentWorkouts()
                print("Background task processed \(processed) workouts")
                task.setTaskCompleted(success: true)
            } catch {
                print("Background task failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
        
        // Handle expiration
        task.expirationHandler = {
            processingTask.cancel()
            print("Background task expired")
        }
    }
    
    // MARK: - Workout Processing
    
    private func processRecentWorkouts() async throws -> Int {
        guard let container = dependencyContainer else {
            print("No dependency container available for background processing")
            return 0
        }
        
        // Get the last processed date
        let lastProcessedKey = "BackgroundProcessor.lastProcessedDate"
        let lastProcessedDate = UserDefaults.standard.object(forKey: lastProcessedKey) as? Date ?? Date().addingTimeInterval(-3600) // Default to 1 hour ago
        
        // Fetch workouts since last processed date
        let healthStore = HKHealthStore()
        let workoutType = HKObjectType.workoutType()
        
        let predicate = HKQuery.predicateForSamples(
            withStart: lastProcessedDate,
            end: Date(),
            options: .strictEndDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: true
        )
        
        // Execute query asynchronously
        let workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 10,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let workouts = (samples as? [HKWorkout]) ?? []
                    continuation.resume(returning: workouts)
                }
            }
            healthStore.execute(query)
        }
        
        // Process each workout
        var processedCount = 0
        for hkWorkout in workouts {
            // Convert to our Workout model
            let workout = Workout(from: hkWorkout, followersEarned: 0)
            
            // Check if auto-sharing is enabled
            let settings = try await container.activitySharingSettingsService.loadSettings()
            guard settings.shareActivitiesToFeed && settings.shareWorkouts else {
                continue
            }
            
            // Check if this workout should be shared
            guard settings.shouldShareWorkout(hkWorkout) else {
                continue
            }
            
            // Share the workout
            do {
                try await container.activityFeedService.postWorkoutActivity(
                    workoutHistory: workout,
                    privacy: settings.workoutPrivacy,
                    includeDetails: settings.shareWorkoutDetails
                )
                
                // Send notification
                await sendBackgroundShareNotification(for: workout, container: container)
                
                processedCount += 1
                print("Background: Shared workout \(workout.workoutType)")
            } catch {
                print("Background: Failed to share workout: \(error)")
            }
        }
        
        // Update last processed date
        if let lastWorkout = workouts.last {
            UserDefaults.standard.set(lastWorkout.endDate, forKey: lastProcessedKey)
        }
        
        return processedCount
    }
    
    // MARK: - Notifications
    
    private func sendBackgroundShareNotification(for workout: Workout, container: DependencyContainer) async {
        let workoutType = workout.workoutType
        
        let notification = FameFitNotification(
            title: "Background Share 🌙",
            body: "Your \(workoutType) was automatically shared while the app was closed",
            character: FameFitCharacter.defaultCharacter,
            workoutDuration: Int(workout.duration / 60),
            calories: Int(workout.totalEnergyBurned),
            followersEarned: workout.xpEarned ?? 0
        )
        
        container.notificationStore.addFameFitNotification(notification)
    }
    
    // MARK: - Task Scheduling
    
    func scheduleNextBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Scheduled next background task")
        } catch {
            print("Failed to schedule background task: \(error)")
        }
    }
    
    // MARK: - Manual Trigger
    
    func triggerBackgroundProcessing() {
        // This can be called when the app enters background to ensure processing happens
        Task {
            do {
                let processed = try await processRecentWorkouts()
                print("Manual background processing completed: \(processed) workouts")
            } catch {
                print("Manual background processing failed: \(error)")
            }
        }
    }
}