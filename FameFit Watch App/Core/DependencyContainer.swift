//
//  DependencyContainer.swift
//  FameFit Watch App
//
//  Central dependency injection container using modern Swift patterns
//

import Foundation
import SwiftUI
import Combine

// MARK: - Dependency Container

@MainActor
final class DependencyContainer: ObservableObject {
    // MARK: - Core Services
    
    let dataRepository: DataRepository
    let cacheManager: CacheManager
    let healthKitSession: HealthKitSessionManaging
    let metricsCollector: WorkoutMetricsCollecting
    let stateManager: WorkoutStateManaging
    let groupWorkoutCoordinator: GroupWorkoutCoordinating
    let watchConnectivity: WatchConnectivityService
    let achievementManager: any AchievementManaging
    
    // MARK: - View Models
    
    @Published private(set) var watchStartViewModel: WatchStartViewModel!
    @Published private(set) var sessionViewModel: SessionViewModel!
    @Published private(set) var summaryViewModel: SummaryViewModel!
    
    // MARK: - Initialization
    
    init(isPreview: Bool = false) {
        // Initialize data layer
        self.dataRepository = UserDefaultsRepository()
        self.cacheManager = CacheManager(repository: dataRepository)
        
        // Initialize services
        if isPreview {
            // Use mock implementations for previews
            self.healthKitSession = MockHealthKitSessionManager()
            self.metricsCollector = MockMetricsCollector()
            self.stateManager = MockWorkoutStateManager()
            self.groupWorkoutCoordinator = MockGroupWorkoutCoordinator()
            self.watchConnectivity = MockWatchConnectivityService()
            self.achievementManager = AchievementManager(
                persister: UserDefaultsAchievementPersister()
            )
        } else {
            // Use real implementations
            self.healthKitSession = HealthKitSessionManager()
            self.metricsCollector = WorkoutMetricsCollector()
            self.stateManager = WorkoutStateManager()
            // For now, use mock until we adapt the existing WatchConnectivityManager
            self.watchConnectivity = MockWatchConnectivityService()
            self.groupWorkoutCoordinator = GroupWorkoutCoordinator(
                cacheManager: cacheManager,
                watchConnectivity: MockWatchConnectivityService()
            )
            self.achievementManager = AchievementManager(
                persister: UserDefaultsAchievementPersister()
            )
        }
        
        // Initialize view models with dependencies
        self.watchStartViewModel = WatchStartViewModel(
            stateManager: stateManager,
            groupWorkoutCoordinator: groupWorkoutCoordinator,
            cacheManager: cacheManager
        )
        
        self.sessionViewModel = SessionViewModel(
            healthKitSession: healthKitSession,
            metricsCollector: metricsCollector,
            stateManager: stateManager,
            groupWorkoutCoordinator: groupWorkoutCoordinator,
            achievementManager: achievementManager
        )
        
        self.summaryViewModel = SummaryViewModel(
            healthKitSession: healthKitSession,
            achievementManager: achievementManager,
            watchConnectivity: watchConnectivity,
            cacheManager: cacheManager
        )
        
        // Setup service connections
        setupServiceConnections()
    }
    
    // MARK: - Service Setup
    
    private func setupServiceConnections() {
        // Connect services that need to communicate
        watchConnectivity.setupHandlers()
        
        // Start background tasks if needed
        Task {
            await startBackgroundTasks()
        }
    }
    
    private func startBackgroundTasks() async {
        // Setup periodic sync tasks
        Timer.publish(
            every: WatchConfiguration.UpdateFrequency.backgroundSync,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { _ in
            Task {
                await self.performBackgroundSync()
            }
        }
        .store(in: &cancellables)
    }
    
    private func performBackgroundSync() async {
        // Sync cached data with iPhone if reachable
        guard watchConnectivity.isReachable else { return }
        
        // Update profile cache
        if let age = await cacheManager.repository.age(
            for: WatchConfiguration.StorageKeys.Profile.userData.rawValue
        ), age > WatchConfiguration.Cache.profileCacheDuration {
            try? await updateUserProfile()
        }
        
        // Update group workouts cache
        if let age = await cacheManager.repository.age(
            for: WatchConfiguration.StorageKeys.GroupWorkout.activeWorkouts.rawValue
        ), age > WatchConfiguration.Cache.groupWorkoutCacheDuration {
            try? await updateGroupWorkouts()
        }
    }
    
    private func updateUserProfile() async throws {
        let profile = try await watchConnectivity.requestUserProfile()
        await cacheManager.cache(profile, for: WatchConfiguration.StorageKeys.Profile.userData.rawValue)
    }
    
    private func updateGroupWorkouts() async throws {
        let workouts = try await watchConnectivity.requestGroupWorkouts()
        await cacheManager.cache(workouts, for: WatchConfiguration.StorageKeys.GroupWorkout.activeWorkouts.rawValue)
    }
    
    // MARK: - Cleanup
    
    private var cancellables = Set<AnyCancellable>()
    
    func cleanup() {
        cancellables.removeAll()
    }
}

// MARK: - Environment Key

private struct DependencyContainerKey: EnvironmentKey {
    nonisolated static let defaultValue: DependencyContainer = {
        // Create a default value on the main actor
        let container = MainActor.assumeIsolated {
            DependencyContainer(isPreview: true)
        }
        return container
    }()
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func withDependencies(_ container: DependencyContainer) -> some View {
        self.environment(\.dependencies, container)
    }
}