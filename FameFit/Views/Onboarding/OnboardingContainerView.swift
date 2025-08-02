//
//  OnboardingContainerView.swift
//  FameFit
//
//  Main container for the onboarding flow
//

import SwiftUI

struct OnboardingContainerView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var workoutObserver: WorkoutObserver
    @Environment(\.dependencyContainer) var container

    @State private var onboardingStep = 0
    @State private var showSignIn = false
    @State private var healthKitAuthorized = false
    @State private var showProfileCreation = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                switch onboardingStep {
                case 0:
                    WelcomeOnboardingView(onboardingStep: $onboardingStep)
                case 1:
                    SignInOnboardingView(onboardingStep: $onboardingStep, showSignIn: $showSignIn)
                case 2:
                    HealthKitOnboardingView(onboardingStep: $onboardingStep, healthKitAuthorized: $healthKitAuthorized)
                case 3:
                    ProfileSetupOnboardingView(onboardingStep: $onboardingStep, showProfileCreation: $showProfileCreation)
                case 4:
                    ActivitySharingOnboardingView(onboardingStep: $onboardingStep)
                case 5:
                    GameMechanicsOnboardingView(onboardingStep: $onboardingStep)
                default:
                    Text("Welcome to FameFit!")
                }
            }
            .padding()
        }
        .sheet(isPresented: $showProfileCreation) {
            ProfileCreationView()
                .interactiveDismissDisabled()
                .onDisappear {
                    // Check if profile was actually created
                    Task {
                        // Add a small delay to allow CloudKit to sync
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        
                        do {
                            _ = try await container.userProfileService.fetchCurrentUserProfile()
                            // Profile exists, move to next step
                            print("✅ Profile created successfully, moving to activity sharing")
                            onboardingStep = 4
                        } catch {
                            // Profile doesn't exist, stay on profile creation step
                            print("❌ Profile creation was not completed, staying on profile step")
                            // Keep them on the profile creation step
                            onboardingStep = 3
                        }
                    }
                }
        }
        .onAppear {
            // If user is already authenticated, skip to the appropriate step
            if authManager.isAuthenticated {
                // Check if user has a profile
                Task {
                    do {
                        _ = try await container.userProfileService.fetchCurrentUserProfile()
                        // Has profile, check if they've set up activity sharing
                        do {
                            _ = try await container.activitySharingSettingsService.loadSettings()
                            // Has settings, skip to final step
                            onboardingStep = 5
                        } catch {
                            // No settings yet, go to activity sharing step
                            onboardingStep = 4
                        }
                    } catch {
                        // No profile, go to HealthKit permissions then profile creation
                        onboardingStep = 2
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingContainerView()
        .environmentObject(AuthenticationManager(cloudKitManager: CloudKitManager()))
        .environmentObject(CloudKitManager())
        .environmentObject(WorkoutObserver(cloudKitManager: CloudKitManager(), healthKitService: RealHealthKitService()))
        .environment(\.dependencyContainer, DependencyContainer())
}