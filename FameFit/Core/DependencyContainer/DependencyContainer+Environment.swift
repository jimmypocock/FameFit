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
        FameFitLogger.warning("Creating default DependencyContainer - this should be injected at app level", category: FameFitLogger.general)
        return MainActor.assumeIsolated {
            let container = DependencyContainer()
            // Start initialization for the default container since it will be reused
            container.cloudKitManager.startInitialization()
            return container
        }
    }()
    
    static var defaultValue: DependencyContainer {
        // Log warning each time it's accessed
        FameFitLogger.warning("Using default DependencyContainer - this should be injected at app level", category: FameFitLogger.general)
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