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
}
