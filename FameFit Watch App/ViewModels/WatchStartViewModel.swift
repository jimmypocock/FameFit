//
//  WatchStartViewModel.swift
//  FameFit Watch App
//
//  ViewModel for WatchStartView - handles workout selection and group workouts
//

import Foundation
import SwiftUI
import HealthKit
import Combine

@MainActor
final class WatchStartViewModel: ObservableObject {
    // MARK: - Dependencies
    
    private let stateManager: WorkoutStateManaging
    private let groupWorkoutCoordinator: GroupWorkoutCoordinating
    private let cacheManager: CacheManager
    
    // MARK: - Published State
    
    @Published var workoutTypes: [HKWorkoutActivityType] = []
    @Published var groupWorkouts: [WatchGroupWorkout] = []
    @Published var isLoadingGroupWorkouts = false
    @Published var selectedWorkout: HKWorkoutActivityType?
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    
    // MARK: - Computed Properties
    
    var hasGroupWorkouts: Bool {
        !groupWorkouts.isEmpty
    }
    
    var upcomingGroupWorkouts: [WatchGroupWorkout] {
        groupWorkouts.filter { $0.scheduledStart > Date() }
            .sorted { $0.scheduledStart < $1.scheduledStart }
    }
    
    var activeGroupWorkouts: [WatchGroupWorkout] {
        let now = Date()
        return groupWorkouts.filter { 
            $0.scheduledStart <= now && $0.scheduledEnd > now 
        }
    }
    
    // MARK: - Initialization
    
    init(
        stateManager: WorkoutStateManaging,
        groupWorkoutCoordinator: GroupWorkoutCoordinating,
        cacheManager: CacheManager
    ) {
        self.stateManager = stateManager
        self.groupWorkoutCoordinator = groupWorkoutCoordinator
        self.cacheManager = cacheManager
        
        setupWorkoutTypes()
        Task {
            await loadGroupWorkouts()
        }
    }
    
    // MARK: - Setup
    
    private func setupWorkoutTypes() {
        // Use all workout types from centralized configuration
        workoutTypes = WorkoutTypes.all.map { $0.type }
    }
    
    // MARK: - Public Methods
    
    func selectWorkout(_ type: HKWorkoutActivityType) {
        selectedWorkout = type
        stateManager.selectWorkoutType(type)
    }
    
    func startGroupWorkout(_ workout: WatchGroupWorkout) async {
        do {
            // Join the group workout
            try await groupWorkoutCoordinator.joinGroupWorkout(
                id: workout.id,
                name: workout.name,
                isHost: workout.hostID == "current-user" // Check if user is host
            )
            
            // Select the workout type (convert string to enum)
            if let workoutType = workoutTypeFromString(workout.workoutType) {
                selectWorkout(workoutType)
            }
        } catch {
            showError("Failed to start group workout: \(error.localizedDescription)")
        }
    }
    
    func refreshGroupWorkouts() async {
        isLoadingGroupWorkouts = true
        defer { isLoadingGroupWorkouts = false }
        
        // Try to get fresh data from cache or coordinator
        await loadGroupWorkouts()
    }
    
    // MARK: - Private Methods
    
    private func loadGroupWorkouts() async {
        // First, try to load from cache for immediate display
        if let cached: [WatchGroupWorkout] = await cacheManager.loadCached(
            [WatchGroupWorkout].self,
            for: WatchConfiguration.StorageKeys.GroupWorkout.activeWorkouts.rawValue,
            maxAge: WatchConfiguration.Cache.groupWorkoutCacheDuration
        ) {
            self.groupWorkouts = cached
        }
        
        // Then try to get fresh data from coordinator
        let fresh = await groupWorkoutCoordinator.getCachedGroupWorkouts()
        if !fresh.isEmpty {
            self.groupWorkouts = fresh
            
            // Update cache
            await cacheManager.cache(
                fresh,
                for: WatchConfiguration.StorageKeys.GroupWorkout.activeWorkouts.rawValue
            )
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
    }
    
    private func workoutTypeFromString(_ string: String) -> HKWorkoutActivityType? {
        switch string.lowercased() {
        case "running": return .running
        case "walking": return .walking
        case "cycling": return .cycling
        case "swimming": return .swimming
        case "yoga": return .yoga
        case "pilates": return .pilates
        case "functionalstrength", "functional strength": return .functionalStrengthTraining
        case "strength", "traditional strength": return .traditionalStrengthTraining
        case "hiit", "highintensity": return .highIntensityIntervalTraining
        case "rowing": return .rowing
        case "elliptical": return .elliptical
        case "stairs", "stairclimbing": return .stairs
        default: return .other
        }
    }
    
    // MARK: - Display Helpers
    
    func workoutIcon(for type: HKWorkoutActivityType) -> String {
        // Use centralized workout type configuration
        return WorkoutTypes.icon(for: type)
    }
    
    func workoutName(for type: HKWorkoutActivityType) -> String {
        // Use centralized workout type configuration
        return WorkoutTypes.name(for: type)
    }
}