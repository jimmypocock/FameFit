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
            } else if ProcessInfo.processInfo.arguments.contains("--mock-auth-for-onboarding") {
                // Set up mock authenticated state for onboarding UI testing
                // This simulates a user who has signed in but not completed onboarding
                UserDefaults.standard.set("test-user", forKey: "FameFitUserID")
                UserDefaults.standard.set("Test User", forKey: "FameFitUserName")
                
                container.authenticationManager.userID = "test-user"
                container.authenticationManager.userName = "Test User"
                container.authenticationManager.isAuthenticated = true
                container.authenticationManager.hasCompletedOnboarding = false
                
                // Set up CloudKit mock data
                container.cloudKitManager.isSignedIn = true
                container.cloudKitManager.userName = "Test User"
            } else if ProcessInfo.processInfo.arguments.contains("--skip-onboarding") {
                // Set up mock authenticated state for UI testing
                // Use UserDefaults to persist the state so sign out can work
                UserDefaults.standard.set("test-user", forKey: "FameFitUserID")
                UserDefaults.standard.set("Test User", forKey: "FameFitUserName")
                // UserDefaults automatically synchronizes
                
                // Set authentication immediately (synchronously)
                // Set onboarding complete in UserDefaults too
                UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
                
                container.authenticationManager.userID = "test-user"
                container.authenticationManager.userName = "Test User"
                container.authenticationManager.isAuthenticated = true
                container.authenticationManager.hasCompletedOnboarding = true
                
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
            ContentView()
                .environmentObject(dependencyContainer.authenticationManager)
                .environmentObject(dependencyContainer.cloudKitManager)
                .environmentObject(dependencyContainer.workoutObserver)
                .environmentObject(dependencyContainer.notificationStore)
                .environment(\.dependencyContainer, dependencyContainer)
                .onAppear {
                    // Share container with AppDelegate if it doesn't have one
                    if appDelegate.dependencyContainer == nil {
                        appDelegate.dependencyContainer = dependencyContainer
                        
                        // Start the reliable sync manager using HKAnchoredObjectQuery
                        // This provides more reliable workout tracking than observer queries
                        dependencyContainer.workoutSyncManager.startReliableSync()
                    }
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var notificationStore: NotificationStore
    
    var body: some View {
        if authManager.isAuthenticated && authManager.hasCompletedOnboarding {
            let viewModel = MainViewModel(
                authManager: authManager,
                cloudKitManager: cloudKitManager,
                notificationStore: notificationStore
            )
            MainView(viewModel: viewModel)
        } else {
            OnboardingView()
        }
    }
}
