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
    
    init() {
        // Create the dependency container
        let container = DependencyContainer()
        _dependencyContainer = StateObject(wrappedValue: container)
        
        // Share it with AppDelegate  
        // Note: We'll handle this in onAppear since init is too early
    }

    var body: some Scene {
        WindowGroup {
            if dependencyContainer.authenticationManager.isAuthenticated {
                MainView()
                    .environmentObject(dependencyContainer.authenticationManager)
                    .environmentObject(dependencyContainer.cloudKitManager)
                    .environmentObject(dependencyContainer.workoutObserver)
                    .environment(\.dependencyContainer, dependencyContainer)
                    .onAppear {
                        // Share container with AppDelegate if it doesn't have one
                        if appDelegate.dependencyContainer == nil {
                            appDelegate.dependencyContainer = dependencyContainer
                        }
                    }
            } else {
                OnboardingView()
                    .environmentObject(dependencyContainer.authenticationManager)
                    .environmentObject(dependencyContainer.cloudKitManager)
                    .environmentObject(dependencyContainer.workoutObserver)
                    .environment(\.dependencyContainer, dependencyContainer)
                    .onAppear {
                        // Share container with AppDelegate if it doesn't have one
                        if appDelegate.dependencyContainer == nil {
                            appDelegate.dependencyContainer = dependencyContainer
                        }
                    }
            }
        }
    }
}
