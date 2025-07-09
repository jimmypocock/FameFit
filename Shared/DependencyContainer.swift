//
//  DependencyContainer.swift
//  FameFit
//
//  Manages dependency injection for the app
//

import Foundation
import SwiftUI

class DependencyContainer: ObservableObject {
    let authenticationManager: AuthenticationManager
    let cloudKitManager: CloudKitManager
    let workoutObserver: WorkoutObserver
    
    init() {
        // Create instances with proper dependency injection
        self.cloudKitManager = CloudKitManager()
        self.authenticationManager = AuthenticationManager(cloudKitManager: cloudKitManager)
        self.workoutObserver = WorkoutObserver(cloudKitManager: cloudKitManager)
        
        // Wire up dependencies
        cloudKitManager.authenticationManager = authenticationManager
    }
    
    // For testing, allow injection of mock managers
    init(
        authenticationManager: AuthenticationManager,
        cloudKitManager: CloudKitManager,
        workoutObserver: WorkoutObserver
    ) {
        self.authenticationManager = authenticationManager
        self.cloudKitManager = cloudKitManager
        self.workoutObserver = workoutObserver
    }
}

// MARK: - Environment Key
struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer()
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}