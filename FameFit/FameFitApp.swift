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
        
        #if DEBUG
        // Handle UI test launch arguments
        handleUITestLaunchArguments(container: container)
        #endif
    }
    
    #if DEBUG
    private func handleUITestLaunchArguments(container: DependencyContainer) {
        let arguments = ProcessInfo.processInfo.arguments
        
        if arguments.contains("UI-Testing") {
            if arguments.contains("--reset-state") {
                // Reset all user data for clean onboarding test
                container.authenticationManager.signOut()
                UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                UserDefaults.standard.removeObject(forKey: "isAuthenticated")
                UserDefaults.standard.synchronize()
            } else if arguments.contains("--skip-onboarding") {
                // Set up authenticated state with mock data
                container.authenticationManager.setUITestingState(
                    isAuthenticated: true,
                    hasCompletedOnboarding: true,
                    userID: "ui-test-user"
                )
            } else if arguments.contains("--mock-auth-for-onboarding") {
                // Set authenticated but not completed onboarding
                container.authenticationManager.setUITestingState(
                    isAuthenticated: true,
                    hasCompletedOnboarding: false,
                    userID: "ui-test-user"
                )
            }
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencyContainer.authenticationManager)
                .environmentObject(dependencyContainer.cloudKitManager)
                .environmentObject(dependencyContainer.workoutObserver)
                .environmentObject(dependencyContainer.notificationStore)
                .environment(\.dependencyContainer, dependencyContainer)
                .onAppear {
                    // Configure background tasks (replaces AppDelegate registration)
                    BackgroundTaskManager.shared.configure(with: dependencyContainer)
                    
                    // Share container with AppDelegate if it doesn't have one
                    if appDelegate.dependencyContainer == nil {
                        appDelegate.dependencyContainer = dependencyContainer

                        // Start the reliable sync manager using HKAnchoredObjectQuery
                        // This provides more reliable workout tracking than observer queries
                        dependencyContainer.workoutSyncManager.startReliableSync()
                        
                        // Start auto-sharing service for workouts
                        dependencyContainer.workoutAutoShareService.setupAutoSharing()

                        // Request APNS permissions if user has completed onboarding
                        if dependencyContainer.authenticationManager.hasCompletedOnboarding {
                            Task {
                                do {
                                    let granted = try await dependencyContainer.apnsManager
                                        .requestNotificationPermissions()
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
        if authManager.isAuthenticated, authManager.hasCompletedOnboarding {
            let viewModel = MainViewModel(
                authManager: authManager,
                cloudKitManager: cloudKitManager,
                notificationStore: notificationStore,
                userProfileService: container.userProfileService,
                socialFollowingService: container.socialFollowingService
            )
            TabMainView(viewModel: viewModel)
        } else {
            OnboardingView()
        }
    }
}
