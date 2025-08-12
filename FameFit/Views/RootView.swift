//
//  RootView.swift
//  FameFit
//
//  Root navigation view for the app
//

import SwiftUI

struct RootView: View {
    @Environment(\.dependencyContainer) var container
    @StateObject private var viewModel: RootViewModel
    
    init() {
        // We'll create the view model with a temporary container
        // and replace it with the proper one when the view appears
        let tempContainer = DependencyContainer(skipInitialization: true)
        _viewModel = StateObject(wrappedValue: RootViewModel(container: tempContainer))
    }
    
    var body: some View {
        Group {
            switch viewModel.navigationState {
            case .loading:
                LoadingView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingView(container: container)
                    .transition(.opacity)
            case .main:
                MainView(viewModel: viewModel.mainViewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.navigationState)
        .onAppear {
            // Configure with the proper container when it's available
            viewModel.updateDependencies(container: container)
        }
        .task {
            // Initialize navigation state
            await viewModel.initialize()
        }
    }
}