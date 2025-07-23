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
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hasCompletedOnboarding)
                UserDefaults.standard.synchronize()
                
                // Also reset the authentication state in the container
                container.authenticationManager.isAuthenticated = false
                container.authenticationManager.hasCompletedOnboarding = false
                container.authenticationManager.userID = nil
                container.authenticationManager.userName = nil
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
                container.cloudKitManager.totalXP = 100
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
                        
                        // Request APNS permissions if user has completed onboarding
                        if dependencyContainer.authenticationManager.hasCompletedOnboarding {
                            Task {
                                do {
                                    let granted = try await dependencyContainer.apnsManager.requestNotificationPermissions()
                                    if granted {
                                        dependencyContainer.apnsManager.registerForRemoteNotifications()
                                    }
                                } catch {
                                    print("Failed to request APNS permissions: \(error)")
                                }
                            }
                        }
                    }
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var notificationStore: NotificationStore
    @Environment(\.dependencyContainer) var container
    
    var body: some View {
        if authManager.isAuthenticated && authManager.hasCompletedOnboarding {
            let viewModel = MainViewModel(
                authManager: authManager,
                cloudKitManager: cloudKitManager,
                notificationStore: notificationStore,
                userProfileService: container.userProfileService
            )
            MainView(viewModel: viewModel)
        } else {
            OnboardingView()
        }
    }
}
