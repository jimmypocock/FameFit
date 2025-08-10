//
//  DependencyContainer+Environment.swift
//  FameFit
//
//  SwiftUI Environment integration for DependencyContainer
//

import SwiftUI

// MARK: - Environment Key

private struct DependencyContainerKey: EnvironmentKey {
    // Use a singleton for the default container to prevent multiple initializations
    private static let sharedDefault: DependencyContainer = {
        // Note: This is accessed during SwiftUI view initialization before environment injection.
        // This is normal SwiftUI behavior and not a cause for concern.
        // The actual container will be injected by FameFitApp before any views use it.
        return MainActor.assumeIsolated {
            let container = DependencyContainer(skipInitialization: true)
            // Don't start initialization for the default container - it's just a fallback
            // The app should inject the proper container which will handle initialization
            return container
        }
    }()
    
    static var defaultValue: DependencyContainer {
        // Return the shared default container
        // This is accessed during SwiftUI's view property initialization phase
        // before the actual container is injected via .environment()
        return sharedDefault
    }
}

// MARK: - Environment Values Extension

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
