//
//  FameFitApp.swift
//  FameFit
//
//  Created by Jimmy Pocock on 6/27/25.
//

import SwiftUI

@main
struct FameFitApp: App {
    @StateObject private var dependencyContainer = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            if dependencyContainer.authenticationManager.isAuthenticated {
                MainView()
                    .environmentObject(dependencyContainer.authenticationManager)
                    .environmentObject(dependencyContainer.cloudKitManager)
                    .environmentObject(dependencyContainer.workoutObserver)
                    .environment(\.dependencyContainer, dependencyContainer)
            } else {
                OnboardingView()
                    .environmentObject(dependencyContainer.authenticationManager)
                    .environmentObject(dependencyContainer.cloudKitManager)
                    .environmentObject(dependencyContainer.workoutObserver)
                    .environment(\.dependencyContainer, dependencyContainer)
            }
        }
    }
}
