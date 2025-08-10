//
//  RootViewModel.swift
//  FameFit
//
//  Handles navigation state and business logic for app root
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class RootViewModel: ObservableObject {
    // MARK: - Navigation State
    
    enum NavigationState: Equatable {
        case loading
        case onboarding
        case main
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var navigationState: NavigationState = .loading
    @Published private(set) var mainViewModel: MainViewModel
    
    // MARK: - Dependencies
    
    private var authManager: AuthenticationService
    private var cloudKitManager: CloudKitService
    private var notificationStore: NotificationStore
    private var container: DependencyContainer
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var hasInitialized = false
    private var hasProperDependencies = false
    
    // MARK: - Initialization
    
    init(container: DependencyContainer) {
        self.container = container
        self.authManager = container.authenticationManager
        self.cloudKitManager = container.cloudKitManager
        self.notificationStore = container.notificationStore
        
        // Create MainViewModel with dependencies
        self.mainViewModel = MainViewModel(
            authManager: authManager,
            cloudKitManager: cloudKitManager,
            notificationStore: notificationStore,
            userProfileService: container.userProfileService,
            socialFollowingService: container.socialFollowingService,
            watchConnectivityManager: container.watchConnectivityManager
        )
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Update dependencies when the proper container becomes available
    func updateDependencies(container: DependencyContainer) {
        guard !hasProperDependencies else { return }
        
        // Cancel existing subscriptions
        cancellables.removeAll()
        
        // Update dependencies
        self.container = container
        self.authManager = container.authenticationManager
        self.cloudKitManager = container.cloudKitManager
        self.notificationStore = container.notificationStore
        
        // Recreate MainViewModel with proper dependencies
        self.mainViewModel = MainViewModel(
            authManager: authManager,
            cloudKitManager: cloudKitManager,
            notificationStore: notificationStore,
            userProfileService: container.userProfileService,
            socialFollowingService: container.socialFollowingService,
            watchConnectivityManager: container.watchConnectivityManager
        )
        
        hasProperDependencies = true
        setupBindings()
    }
    
    /// Initialize the app and determine initial navigation state
    func initialize() async {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        // Wait a moment for dependencies to be updated if needed
        if !hasProperDependencies {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        await determineNavigationState()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Listen for authentication changes
        authManager.$isAuthenticated
            .dropFirst() // Skip initial value
            .sink { [weak self] isAuthenticated in
                Task { @MainActor [weak self] in
                    await self?.handleAuthenticationChange(isAuthenticated: isAuthenticated)
                }
            }
            .store(in: &cancellables)
        
        // Listen for onboarding completion
        authManager.$hasCompletedOnboarding
            .dropFirst() // Skip initial value
            .filter { $0 } // Only react when it becomes true
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.determineNavigationState()
                }
            }
            .store(in: &cancellables)
    }
    
    private func determineNavigationState() async {
        // Start with loading state
        navigationState = .loading
        
        // Check authentication status
        guard authManager.isAuthenticated else {
            FameFitLogger.debug("User not authenticated, showing onboarding", category: FameFitLogger.auth)
            navigationState = .onboarding
            return
        }
        
        // Check if we have a Sign in with Apple user ID
        guard let _ = authManager.authUserID else {
            FameFitLogger.debug("No user ID available, showing onboarding", category: FameFitLogger.auth)
            navigationState = .onboarding
            return
        }
        
        // Check if user has completed onboarding flag
        guard authManager.hasCompletedOnboarding else {
            FameFitLogger.debug("User hasn't completed onboarding, showing onboarding", category: FameFitLogger.auth)
            navigationState = .onboarding
            return
        }
        
        // Get CloudKit user ID and verify profile
        do {
            // This will fetch the CloudKit user ID if not cached, or return cached value
            let cloudKitUserID = try await cloudKitManager.getCurrentUserID()
            FameFitLogger.info("Got CloudKit user ID: \(cloudKitUserID)", category: FameFitLogger.auth)
            
            // Verify profile exists in CloudKit using the CloudKit user ID
            let profile = try await container.userProfileService.fetchProfileByUserID(cloudKitUserID)
            FameFitLogger.info("✅ User profile verified: \(profile.username), showing main app", category: FameFitLogger.auth)
            
            // Load the profile into MainViewModel before showing main screen
            mainViewModel.loadUserProfile()
            
            navigationState = .main
        } catch {
            // Check if this is actually a profile not found error vs network/CloudKit error
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("profile not found") || errorString.contains("record not found") {
                FameFitLogger.info("Profile doesn't exist, user needs to complete onboarding", category: FameFitLogger.auth)
                navigationState = .onboarding
            } else {
                // This is a different error (network, CloudKit not ready, etc)
                FameFitLogger.error("Failed to verify user profile due to error: \(error)", category: FameFitLogger.auth)
                // Show main screen anyway - the app will try to load the profile again
                navigationState = .main
            }
        }
    }
    
    private func handleAuthenticationChange(isAuthenticated: Bool) async {
        if isAuthenticated {
            // User just signed in, check their status
            await determineNavigationState()
        } else {
            // User signed out, go straight to onboarding
            FameFitLogger.info("User signed out, showing onboarding", category: FameFitLogger.auth)
            navigationState = .onboarding
        }
    }
}

// MARK: - Mock Implementation for Testing

#if DEBUG
final class MockRootViewModel: ObservableObject {
    @Published var navigationState: RootViewModel.NavigationState
    @Published var mainViewModel: MainViewModel
    
    init(navigationState: RootViewModel.NavigationState = .loading) {
        self.navigationState = navigationState
        self.mainViewModel = MainViewModel()
    }
    
    func initialize() async {
        // No-op for testing
    }
}
#endif