//
//  OnboardingView.swift
//  FameFit
//
//  Main onboarding flow controller
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dependencyContainer) var container
    @StateObject private var viewModel: OnboardingViewModel
    
    init(container: DependencyContainer? = nil) {
        let actualContainer = container ?? DependencyContainer()
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(container: actualContainer))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ZStack {
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    LoadingView()
                }
            } else {
                switch viewModel.currentStep {
                case .welcome:
                    // WelcomeView has its own background
                    WelcomeView(viewModel: viewModel)
                case .signIn:
                    // SignIn is now integrated into WelcomeView
                    // This case should not be reached, but show HealthKit as fallback
                    HealthKitPermissionView(viewModel: viewModel)
                case .healthKit:
                    HealthKitPermissionView(viewModel: viewModel)
                case .profile:
                    ProfileCreationView(viewModel: viewModel)
                case .gameMechanics:
                    GameMechanicsView(viewModel: viewModel)
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    let container = DependencyContainer()
    return OnboardingView()
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutObserver)
        .environment(\.dependencyContainer, container)
}