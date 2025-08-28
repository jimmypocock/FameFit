//
//  WorkoutSyncViewModel.swift
//  FameFit
//
//  Debug view model for manually syncing HealthKit workouts to CloudKit
//

import Foundation
import HealthKit
import CloudKit

@MainActor
final class WorkoutSyncViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var workouts: [WorkoutSyncItem] = []
    @Published var isLoading = false
    @Published var statusMessage = ""
    @Published var errorMessage = ""
    @Published var successMessage = ""
    
    // CloudKit Status
    @Published var cloudKitStatus = "Checking..."
    @Published var cloudKitUserID: String?
    @Published var iCloudAccountStatus: String = "Unknown"
    @Published var hasUserProfile = false
    
    // MARK: - Private Properties
    
    private let healthStore = HKHealthStore()
    private let cloudKitService: CloudKitService
    private let workoutProcessor: WorkoutProcessor?
    private let userProfileService: UserProfileProtocol?
    
    // MARK: - Initialization
    
    init(cloudKitService: CloudKitService, workoutProcessor: WorkoutProcessor? = nil, userProfileService: UserProfileProtocol? = nil) {
        self.cloudKitService = cloudKitService
        self.workoutProcessor = workoutProcessor
        self.userProfileService = userProfileService
    }
    
    // MARK: - Data Model
    
    struct WorkoutSyncItem: Identifiable {
        let id: String
        let workout: HKWorkout
        let displayName: String
        let duration: String
        let date: String
        var isSynced: Bool
        
        init(workout: HKWorkout, isSynced: Bool) {
            self.id = workout.uuid.uuidString
            self.workout = workout
            self.displayName = workout.workoutActivityType.displayName
            
            // Format duration
            let minutes = Int(workout.duration) / 60
            self.duration = "\(minutes) min"
            
            // Format date
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            self.date = formatter.string(from: workout.endDate)
            
            self.isSynced = isSynced
        }
    }
    
    // MARK: - Public Methods
    
    /// Check CloudKit and iCloud status using CloudKitService
    func checkCloudKitStatus() async {
        // Use CloudKitService to check status
        cloudKitService.checkAccountStatus()
        
        // Wait a moment for the async check to complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Get status from CloudKitService
        if cloudKitService.isSignedIn {
            iCloudAccountStatus = "✅ iCloud Available"
            
            // Get the cached user ID first
            cloudKitUserID = cloudKitService.currentUserID
            
            if let userID = cloudKitUserID {
                cloudKitStatus = "✅ Connected (ID: \(userID))"
            } else {
                // Try to fetch it if not cached
                do {
                    let userID = try await cloudKitService.getCurrentUserID()
                    cloudKitUserID = userID
                    cloudKitStatus = "✅ Connected (ID: \(userID))"
                } catch {
                    cloudKitStatus = "⚠️ Connected but no user ID: \(error.localizedDescription)"
                }
            }
            
            // Check if we have a UserProfile
            await checkUserProfile()
            
        } else {
            iCloudAccountStatus = "❌ Not signed into iCloud or iCloud Drive disabled"
            cloudKitStatus = "❌ Not available"
            cloudKitUserID = nil
            
            // Check the specific error
            if let error = cloudKitService.lastError {
                switch error {
                case .cloudKitNotAvailable:
                    iCloudAccountStatus = "❌ iCloud not available"
                case .cloudKitUserNotFound:
                    iCloudAccountStatus = "❌ CloudKit user not found"
                default:
                    iCloudAccountStatus = "❌ Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Try to manually fetch CloudKit user ID using CloudKitService
    func fetchCloudKitUserID() async {
        isLoading = true
        clearMessages()
        statusMessage = "Fetching CloudKit user ID..."
        
        // First check if signed in
        if !cloudKitService.isSignedIn {
            errorMessage = "❌ Not signed into iCloud. Please sign into iCloud in Settings."
            isLoading = false
            return
        }
        
        do {
            // Use CloudKitService to get the user ID (it will fetch if needed)
            let userID = try await cloudKitService.getCurrentUserID()
            cloudKitUserID = userID
            
            successMessage = "✅ CloudKit User ID fetched: \(userID)"
            cloudKitStatus = "✅ Connected (ID: \(userID))"
            
            // Check for UserProfile
            await checkUserProfile()
            
        } catch {
            errorMessage = "❌ Failed to fetch user ID: \(error.localizedDescription)"
            cloudKitStatus = "❌ Not connected"
            
            // Update from CloudKitService error state
            if let serviceError = cloudKitService.lastError {
                errorMessage = "❌ \(serviceError.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    private func checkUserProfile() async {
        // This would check if a UserProfile exists for the current user
        // For now, we'll just set it based on whether we have workouts
        do {
            let workouts = try await withCheckedThrowingContinuation { continuation in
                cloudKitService.fetchWorkouts { result in
                    continuation.resume(with: result)
                }
            }
            hasUserProfile = !workouts.isEmpty
        } catch {
            hasUserProfile = false
        }
    }
    
    // MARK: - Public Methods
    
    /// Scan HealthKit for workouts using the same sync window as automatic sync
    func scanHealthKit() async {
        clearMessages()
        isLoading = true
        statusMessage = "Scanning HealthKit..."
        
        do {
            // Check HealthKit authorization
            let workoutType = HKObjectType.workoutType()
            let authStatus = healthStore.authorizationStatus(for: workoutType)
            
            if authStatus == .notDetermined {
                errorMessage = "HealthKit permission not granted. Please grant permission in Settings."
                isLoading = false
                return
            }
            
            // Use WorkoutSyncPolicy to get the EXACT same window as automatic sync
            // Get actual profile creation date if available
            var profileCreatedAt = Date()
            if let userID = cloudKitService.currentUserID,
               let profileService = userProfileService {
                do {
                    let profile = try await profileService.fetchProfileByUserID(userID)
                    profileCreatedAt = profile.creationDate
                } catch {
                    // Use current date as fallback if profile fetch fails
                    FameFitLogger.debug("Could not fetch user profile for sync window: \(error)", category: FameFitLogger.workout)
                }
            }
            
            // Create policy with actual profile date - this is the SINGLE source of truth for sync windows
            let syncPolicy = WorkoutSyncPolicy(profileCreatedAt: profileCreatedAt)
            
            let startDate = syncPolicy.getSyncStartDate()
            let endDate = syncPolicy.getSyncEndDate()
            
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictEndDate
            )
            
            let sortDescriptor = NSSortDescriptor(
                key: HKSampleSortIdentifierEndDate,
                ascending: false
            )
            
            // Fetch workouts from HealthKit
            let hkWorkouts = try await fetchWorkouts(
                predicate: predicate,
                sortDescriptors: [sortDescriptor]
            )
            
            // Show what window was scanned
            let days = Int(-startDate.timeIntervalSinceNow / (24 * 60 * 60))
            let windowDescription = days <= 1 ? "last 24 hours" : "last \(days) days"
            statusMessage = "Found \(hkWorkouts.count) workout(s) from \(windowDescription)"
            
            // Check which workouts are already synced
            let syncedIDs = await getSyncedWorkoutIDs()
            
            // Create workout items
            workouts = hkWorkouts.map { workout in
                WorkoutSyncItem(
                    workout: workout,
                    isSynced: syncedIDs.contains(workout.uuid.uuidString)
                )
            }
            
            let unsyncedCount = workouts.filter { !$0.isSynced }.count
            if unsyncedCount > 0 {
                statusMessage = "Found \(hkWorkouts.count) workout(s), \(unsyncedCount) not synced"
            }
            
        } catch {
            errorMessage = "Failed to scan HealthKit: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Sync unsynced workouts to CloudKit
    func syncWorkoutsToCloudKit() async {
        clearMessages()
        
        let unsyncedWorkouts = workouts.filter { !$0.isSynced }
        
        guard !unsyncedWorkouts.isEmpty else {
            statusMessage = "No workouts to sync"
            return
        }
        
        isLoading = true
        statusMessage = "Syncing \(unsyncedWorkouts.count) workout(s)..."
        
        var successCount = 0
        var failedWorkouts: [(workout: WorkoutSyncItem, error: Error)] = []
        
        // CloudKitService.saveWorkout will now fetch the user ID if needed
        // No need to check it here
        
        for item in unsyncedWorkouts {
            do {
                // Use WorkoutProcessor if available for proper processing (XP calculation, etc.)
                // Otherwise fall back to direct save
                if let processor = workoutProcessor {
                    // Process through the central pipeline - this creates XP transactions
                    try await processor.processHealthKitWorkout(item.workout)
                } else {
                    // Fallback: Convert and save directly (no XP transaction)
                    let workout = Workout(from: item.workout, followersEarned: 10, xpEarned: 10)
                    try await cloudKitService.saveWorkout(workout)
                }
                
                // Mark as synced
                if let index = workouts.firstIndex(where: { $0.id == item.id }) {
                    workouts[index].isSynced = true
                }
                
                successCount += 1
                statusMessage = "Synced \(successCount) of \(unsyncedWorkouts.count)..."
                
            } catch {
                // Enhanced error message with user ID info from CloudKitService
                var enhancedError = error.localizedDescription
                if error.localizedDescription.contains("User record not found") || error.localizedDescription.contains("user ID") {
                    let currentID = cloudKitService.currentUserID ?? "nil"
                    enhancedError = "\(error.localizedDescription)\nCurrent CloudKit ID: \(currentID)\nTry 'Fetch CloudKit User ID' button above"
                }
                failedWorkouts.append((item, FameFitError.cloudKitSyncFailed(NSError(domain: "Sync", code: 0, userInfo: [NSLocalizedDescriptionKey: enhancedError]))))
                print("Failed to sync workout \(item.displayName): \(enhancedError)")
            }
        }
        
        isLoading = false
        
        // Show results
        if failedWorkouts.isEmpty {
            successMessage = "✅ Successfully synced \(successCount) workout(s)"
            statusMessage = ""
        } else {
            if successCount > 0 {
                statusMessage = "Synced \(successCount) workout(s)"
            }
            
            let errorDetails = failedWorkouts.map { item, error in
                "\(item.displayName): \(error.localizedDescription)"
            }.joined(separator: "\n")
            
            errorMessage = "❌ Failed to sync \(failedWorkouts.count) workout(s):\n\(errorDetails)"
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchWorkouts(
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let workouts = samples as? [HKWorkout] ?? []
                    continuation.resume(returning: workouts)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func getSyncedWorkoutIDs() async -> Set<String> {
        do {
            // Query CloudKit for existing workout IDs
            let workouts = try await withCheckedThrowingContinuation { continuation in
                cloudKitService.fetchWorkouts { result in
                    continuation.resume(with: result)
                }
            }
            
            return Set(workouts.map { $0.id })
        } catch {
            print("Failed to fetch synced workouts: \(error)")
            return []
        }
    }
    
    private func clearMessages() {
        statusMessage = ""
        errorMessage = ""
        successMessage = ""
    }
}