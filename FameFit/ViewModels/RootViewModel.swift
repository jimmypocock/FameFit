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
        guard let _ = authManager.userID else {
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
        
        // Get the CloudKit user ID (not the Sign in with Apple ID)
        // This is what the profile was created with
        do {
            let cloudKitUserID = try await cloudKitManager.getCurrentUserID()
            
            // Verify profile exists in CloudKit using the CloudKit user ID
            _ = try await container.userProfileService.fetchProfileByUserID(cloudKitUserID)
            FameFitLogger.info("User profile verified with CloudKit user ID, showing main app", category: FameFitLogger.auth)
            navigationState = .main
        } catch {
            // Profile doesn't exist, but user might be in the middle of onboarding
            FameFitLogger.info("User profile not found in CloudKit, continuing onboarding", category: FameFitLogger.auth)
            // Don't reset hasCompletedOnboarding - let OnboardingViewModel handle the flow
            // Only show onboarding if not already showing it
            if navigationState != .onboarding {
                navigationState = .onboarding
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