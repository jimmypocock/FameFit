//
//  RootView.swift
//  FameFit
//
//  Root view that handles navigation between onboarding and main app
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthenticationService
    @EnvironmentObject var cloudKitManager: CloudKitService
    @EnvironmentObject var notificationStore: NotificationStore
    @Environment(\.dependencyContainer) var container
    @State private var hasUserProfile = false
    @State private var isCheckingProfile = true

    var body: some View {
        Group {
            if authManager.isAuthenticated, authManager.hasCompletedOnboarding, hasUserProfile {
                // Create ViewModel here in the body where container is available
                let viewModel = MainViewModel(
                    authManager: authManager,
                    cloudKitManager: cloudKitManager,
                    notificationStore: notificationStore,
                    userProfileService: container.userProfileService,
                    socialFollowingService: container.socialFollowingService,
                    watchConnectivityManager: container.watchConnectivityManager
                )
                TabMainView(viewModel: viewModel)
            } else if isCheckingProfile {
                // Show loading while checking for profile
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                OnboardingView()
            }
        }
        .task {
            await checkUserProfile()
        }
        .onChange(of: authManager.isAuthenticated) { _, newValue in
            if newValue {
                Task {
                    await checkUserProfile()
                }
            } else {
                hasUserProfile = false
                isCheckingProfile = false
            }
        }
    }
    
    private func checkUserProfile() async {
        guard authManager.isAuthenticated,
              let userID = authManager.userID else {
            await MainActor.run {
                hasUserProfile = false
                isCheckingProfile = false
            }
            return
        }
        
        // Small delay to ensure container is properly injected
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        do {
            // Check if user profile exists
            _ = try await container.userProfileService.fetchProfile(userID: userID)
            await MainActor.run {
                hasUserProfile = true
                isCheckingProfile = false
            }
        } catch {
            FameFitLogger.info("No user profile found, redirecting to onboarding", category: FameFitLogger.auth)
            await MainActor.run {
                hasUserProfile = false
                isCheckingProfile = false
                // Reset onboarding state since profile doesn't exist
                authManager.hasCompletedOnboarding = false
            }
        }
    }
}