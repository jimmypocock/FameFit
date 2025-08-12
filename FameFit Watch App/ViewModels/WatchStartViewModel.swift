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
        workoutTypes = [
            .running,
            .walking,
            .cycling,
            .swimming,
            .functionalStrengthTraining,
            .traditionalStrengthTraining,
            .crossTraining,
            .elliptical,
            .rowing,
            .stairs,
            .highIntensityIntervalTraining,
            .yoga,
            .pilates,
            .socialDance,
            .martialArts,
            .boxing,
            .kickboxing,
            .climbing,
            .golf,
            .tennis,
            .basketball,
            .soccer,
            .americanFootball,
            .baseball,
            .volleyball,
            .hockey,
            .lacrosse,
            .rugby,
            .softball,
            .badminton,
            .tableTennis,
            .paddleSports,
            .surfingSports,
            .snowSports,
            .skatingSports,
            .handCycling,
            .coreTraining,
            .jumpRope,
            .flexibility,
            .cooldown
        ]
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
        switch type {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "figure.strengthtraining.traditional"
        case .yoga: return "figure.yoga"
        case .dance: return "figure.dance"
        case .boxing, .kickboxing: return "figure.boxing"
        case .basketball: return "basketball.fill"
        case .soccer: return "soccerball"
        case .tennis: return "tennisball.fill"
        case .golf: return "figure.golf"
        case .americanFootball: return "football.fill"
        case .baseball, .softball: return "baseball.fill"
        case .volleyball: return "volleyball.fill"
        case .hockey: return "hockey.puck.fill"
        default: return "figure.mixed.cardio"
        }
    }
    
    func workoutName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Bike"
        case .swimming: return "Swim"
        case .functionalStrengthTraining: return "Functional Strength"
        case .traditionalStrengthTraining: return "Traditional Strength"
        case .crossTraining: return "Cross Training"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairs: return "Stairs"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .dance: return "Dance"
        case .martialArts: return "Martial Arts"
        case .boxing: return "Boxing"
        case .kickboxing: return "Kickboxing"
        case .climbing: return "Climbing"
        case .golf: return "Golf"
        case .tennis: return "Tennis"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .americanFootball: return "Football"
        case .baseball: return "Baseball"
        case .volleyball: return "Volleyball"
        case .hockey: return "Hockey"
        case .lacrosse: return "Lacrosse"
        case .rugby: return "Rugby"
        case .softball: return "Softball"
        case .badminton: return "Badminton"
        case .tableTennis: return "Table Tennis"
        case .paddleSports: return "Paddle Sports"
        case .surfingSports: return "Surfing"
        case .snowSports: return "Snow Sports"
        case .skatingSports: return "Skating"
        case .handCycling: return "Hand Cycling"
        case .coreTraining: return "Core Training"
        case .jumpRope: return "Jump Rope"
        case .flexibility: return "Flexibility"
        case .cooldown: return "Cooldown"
        default: return "Other"
        }
    }
}