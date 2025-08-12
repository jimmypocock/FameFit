//
//  WatchGroupWorkoutCoordinator.swift
//  FameFit Watch App
//
//  Coordinates group workout functionality with caching and sync
//

import Foundation
import Combine

@MainActor
final class GroupWorkoutCoordinator: ObservableObject, GroupWorkoutCoordinating {
    // MARK: - Dependencies
    
    private let cacheManager: CacheManager
    private let watchConnectivity: WatchConnectivityService
    
    // MARK: - Published Properties
    
    @Published private(set) var currentGroupWorkout: WatchGroupWorkout?
    @Published private(set) var isGroupWorkoutHost = false
    @Published private(set) var participantCount = 0
    
    // MARK: - Private Properties
    
    private var syncTimer: Timer?
    private var lastSyncDate: Date?
    
    // MARK: - Initialization
    
    init(cacheManager: CacheManager, watchConnectivity: WatchConnectivityService) {
        self.cacheManager = cacheManager
        self.watchConnectivity = watchConnectivity
        
        Task {
            await loadCachedWatchGroupWorkout()
        }
    }
    
    // MARK: - WatchGroupWorkoutCoordinating Protocol
    
    func joinGroupWorkout(id: String, name: String, isHost: Bool) async throws {
        // Create group workout using the existing model
        let groupWorkout = WatchGroupWorkout(
            id: id,
            name: name,
            hostID: isHost ? "current-user" : "other-user",
            workoutType: "running", // Default, will be set when workout starts
            scheduledStart: Date(),
            scheduledEnd: Date().addingTimeInterval(3600), // Default 1 hour
            maxParticipants: 100,
            currentParticipants: 1,
            isActive: true
        )
        
        // Update state
        currentGroupWorkout = groupWorkout
        isGroupWorkoutHost = isHost
        participantCount = 1
        
        // Cache the group workout
        await cacheGroupWorkout(groupWorkout)
        
        // Start sync timer for participant updates
        startSyncTimer()
        
        FameFitLogger.info("👥 Joined group workout: \(name) (Host: \(isHost))", category: FameFitLogger.social)
    }
    
    func leaveGroupWorkout() async {
        // Stop sync timer
        stopSyncTimer()
        
        // Clear state
        currentGroupWorkout = nil
        isGroupWorkoutHost = false
        participantCount = 0
        
        // Clear cache
        await cacheManager.invalidate(for: WatchConfiguration.StorageKeys.GroupWorkout.pendingWorkoutID.rawValue)
        await cacheManager.invalidate(for: WatchConfiguration.StorageKeys.GroupWorkout.pendingWorkoutName.rawValue)
        
        FameFitLogger.info("👥 Left group workout", category: FameFitLogger.social)
    }
    
    func syncParticipantData(_ data: WorkoutMetricsData) async {
        guard let groupWorkout = currentGroupWorkout else { return }
        
        // Only sync if enough time has passed
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < WatchConfiguration.UpdateFrequency.groupWorkoutSync {
            return
        }
        
        // Create update with group workout context
        let update = WorkoutUpdate(
            workoutID: UUID().uuidString,
            status: .started,
            timestamp: Date(),
            metrics: data,
            groupWorkoutID: groupWorkout.id
        )
        
        // Send to iPhone for sync with other participants
        await watchConnectivity.sendWorkoutUpdate(update)
        
        lastSyncDate = Date()
        
        FameFitLogger.debug("📤 Synced participant data for group workout", category: FameFitLogger.social)
    }
    
    func getCachedGroupWorkouts() async -> [WatchGroupWorkout] {
        // Load from cache
        let cached: [WatchGroupWorkout]? = await cacheManager.loadCached(
            [WatchGroupWorkout].self,
            for: WatchConfiguration.StorageKeys.GroupWorkout.activeWorkouts.rawValue,
            maxAge: WatchConfiguration.Cache.groupWorkoutCacheDuration
        )
        
        return cached ?? []
    }
    
    // MARK: - Private Methods
    
    private func loadCachedWatchGroupWorkout() async {
        // Check if there's a pending group workout from iPhone sync
        let repository = UserDefaultsRepository()
        
        if let workoutID: String = try? await repository.load(
            String.self,
            for: WatchConfiguration.StorageKeys.GroupWorkout.pendingWorkoutID.rawValue
        ),
        let workoutName: String = try? await repository.load(
            String.self,
            for: WatchConfiguration.StorageKeys.GroupWorkout.pendingWorkoutName.rawValue
        ) {
            let isHost: Bool = (try? await repository.load(
                Bool.self,
                for: WatchConfiguration.StorageKeys.GroupWorkout.pendingWorkoutIsHost.rawValue
            )) ?? false
            
            // Auto-join the cached group workout
            try? await joinGroupWorkout(
                id: workoutID,
                name: workoutName,
                isHost: isHost
            )
        }
    }
    
    private func cacheGroupWorkout(_ workout: WatchGroupWorkout) async {
        let repository = UserDefaultsRepository()
        
        try? await repository.save(workout.id, for: WatchConfiguration.StorageKeys.GroupWorkout.pendingWorkoutID.rawValue)
        try? await repository.save(workout.name, for: WatchConfiguration.StorageKeys.GroupWorkout.pendingWorkoutName.rawValue)
        try? await repository.save(isGroupWorkoutHost, for: WatchConfiguration.StorageKeys.GroupWorkout.pendingWorkoutIsHost.rawValue)
        try? await repository.save(workout.workoutType, for: WatchConfiguration.StorageKeys.GroupWorkout.pendingWorkoutType.rawValue)
    }
    
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(
            withTimeInterval: WatchConfiguration.UpdateFrequency.groupWorkoutSync,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.requestParticipantUpdate()
            }
        }
    }
    
    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    private func requestParticipantUpdate() async {
        guard watchConnectivity.isReachable else { return }
        
        // Request updated participant count from iPhone
        // This would be implemented in the refactored WatchConnectivityManager
        
        FameFitLogger.debug("📡 Requesting participant update", category: FameFitLogger.social)
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Timer cleanup happens automatically when the object is deallocated
        syncTimer?.invalidate()
    }
}

// MARK: - Mock Implementation for Previews

final class MockGroupWorkoutCoordinator: GroupWorkoutCoordinating {
    var currentGroupWorkout: WatchGroupWorkout? = WatchGroupWorkout(
        id: "mock-123",
        name: "Morning Run Club",
        hostID: "host-123",
        workoutType: "running",
        scheduledStart: Date(),
        scheduledEnd: Date().addingTimeInterval(3600),
        maxParticipants: 10,
        currentParticipants: 5,
        isActive: true
    )
    
    var isGroupWorkoutHost = false
    var participantCount = 5
    
    func joinGroupWorkout(id: String, name: String, isHost: Bool) async throws {
        // Mock implementation
    }
    
    func leaveGroupWorkout() async {
        // Mock implementation
    }
    
    func syncParticipantData(_ data: WorkoutMetricsData) async {
        // Mock implementation
    }
    
    func getCachedGroupWorkouts() async -> [WatchGroupWorkout] {
        return [
            WatchGroupWorkout(
                id: "mock-1",
                name: "Morning Run",
                hostID: "host-1",
                workoutType: "running",
                scheduledStart: Date().addingTimeInterval(3600),
                scheduledEnd: Date().addingTimeInterval(7200),
                maxParticipants: 10,
                currentParticipants: 3,
                isActive: true
            ),
            WatchGroupWorkout(
                id: "mock-2",
                name: "Evening Yoga",
                hostID: "host-2",
                workoutType: "yoga",
                scheduledStart: Date().addingTimeInterval(28800),
                scheduledEnd: Date().addingTimeInterval(32400),
                maxParticipants: 15,
                currentParticipants: 8,
                isActive: false
            )
        ]
    }
}