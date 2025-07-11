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
        
        // Check for UI testing mode
        if ProcessInfo.processInfo.arguments.contains("UI-Testing") {
            if ProcessInfo.processInfo.arguments.contains("--reset-state") {
                // Clear all user data for fresh onboarding test
                UserDefaults.standard.removeObject(forKey: "FameFitUserID")
                UserDefaults.standard.removeObject(forKey: "FameFitUserName")
                // UserDefaults automatically synchronizes
            } else if ProcessInfo.processInfo.arguments.contains("--skip-onboarding") {
                // Set up mock authenticated state for UI testing
                // Use UserDefaults to persist the state so sign out can work
                UserDefaults.standard.set("test-user", forKey: "FameFitUserID")
                UserDefaults.standard.set("Test User", forKey: "FameFitUserName")
                // UserDefaults automatically synchronizes
                
                // Set authentication immediately (synchronously)
                container.authenticationManager.userID = "test-user"
                container.authenticationManager.userName = "Test User"
                container.authenticationManager.isAuthenticated = true
                
                // Set up CloudKit mock data
                container.cloudKitManager.isSignedIn = true
                container.cloudKitManager.userName = "Test User"
                container.cloudKitManager.followerCount = 100
                container.cloudKitManager.totalWorkouts = 20
                container.cloudKitManager.currentStreak = 5
            }
        }
        
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
