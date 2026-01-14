//
//  FameFitApp.swift
//  FameFit
//
//  Created by Jimmy Pocock on 6/27/25.
//

import SwiftUI

@main
struct FameFitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dependencyContainer: DependencyContainer
    @StateObject private var appInitializer: AppInitializer

    init() {
        // Create the dependency container
        let container = DependencyContainer()
        _dependencyContainer = StateObject(wrappedValue: container)
        
        // Create app initializer
        let initializer = AppInitializer(dependencyContainer: container)
        _appInitializer = StateObject(wrappedValue: initializer)
        
        #if DEBUG
            // Configure for UI testing if applicable
            configureForUITesting(with: container)

            // Configure mock services based on launch arguments
            configureMockServices()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(dependencyContainer.authenticationManager)
                .environmentObject(dependencyContainer.cloudKitManager)
                .environmentObject(dependencyContainer.workoutObserver)
                .environmentObject(dependencyContainer.notificationStore)
                .environment(\.dependencyContainer, dependencyContainer)
                #if DEBUG
                .mockModeIndicator()
                #endif
                .task {
                    // Configure AppDelegate with dependencies on first launch
                    if appDelegate.dependencyContainer == nil {
                        appDelegate.configure(with: dependencyContainer)
                    }
                }
                .onChange(of: dependencyContainer.authenticationManager.hasCompletedOnboarding) { _, hasCompleted in
                    // Handle authentication state changes
                    appInitializer.handleAuthenticationChange(
                        isAuthenticated: dependencyContainer.authenticationManager.isAuthenticated,
                        hasCompletedOnboarding: hasCompleted
                    )
                }
        }
    }

    #if DEBUG
    private func configureMockServices() {
        // Check for mock healthkit launch argument
        if ProcessInfo.processInfo.arguments.contains("--mock-healthkit") {
            ServiceResolver.enableMockServices()
            
            // Load any persisted mock data
            let workouts = MockDataStorage.shared.loadWorkouts()
            if !workouts.isEmpty {
                MockHealthKitService.shared.injectWorkouts(workouts)
            } else {
                // Generate default data if none exists
                let defaultWorkouts = MockHealthKitService.shared.generateWeekOfWorkouts()
                MockHealthKitService.shared.injectWorkouts(defaultWorkouts)
                MockDataStorage.shared.saveWorkouts(defaultWorkouts)
            }

            FameFitLogger.info("Mock HealthKit services initialized", category: FameFitLogger.system)
        }
        
        // Check for specific test scenarios
        if ProcessInfo.processInfo.arguments.contains("--mock-week-streak") {
            let streakWorkouts = MockHealthKitService.shared.generateStreak(days: 7)
            MockHealthKitService.shared.injectWorkouts(streakWorkouts)
        }
        
        if ProcessInfo.processInfo.arguments.contains("--mock-group-workout") {
            MockHealthKitService.shared.addRecentGroupWorkout()
        }
        
        if ProcessInfo.processInfo.arguments.contains("--mock-auto-generate") {
            MockWorkoutScheduler.shared.startAutomaticGeneration(interval: 300) // Every 5 minutes
        }
    }
    #endif
}
