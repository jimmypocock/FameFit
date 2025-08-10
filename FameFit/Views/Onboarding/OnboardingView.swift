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
        ZStack {
            LinearGradient(
                colors: [Color.purple, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if viewModel.isLoading {
                LoadingView()
            } else {
                VStack {
                    switch viewModel.currentStep {
                    case .welcome:
                        WelcomeView(viewModel: viewModel)
                    case .signIn:
                        SignInView(viewModel: viewModel)
                    case .healthKit:
                        HealthKitPermissionView(viewModel: viewModel)
                    case .profile:
                        ProfileCreationView(viewModel: viewModel)
                    case .gameMechanics:
                        GameMechanicsView(viewModel: viewModel)
                    }
                }
                .padding()
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