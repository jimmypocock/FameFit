//
//  DependencyContainer.swift
//  FameFit
//
//  Manages dependency injection for the app
//

import Foundation
import SwiftUI
import HealthKit

class DependencyContainer: ObservableObject {
    let authenticationManager: AuthenticationManager
    let cloudKitManager: CloudKitManager
    let workoutObserver: WorkoutObserver
    let healthKitService: HealthKitService
    let workoutSyncManager: WorkoutSyncManager
    let workoutSyncQueue: WorkoutSyncQueue
    let notificationStore: NotificationStore
    
    init() {
        // Create instances with proper dependency injection
        self.cloudKitManager = CloudKitManager()
        self.authenticationManager = AuthenticationManager(cloudKitManager: cloudKitManager)
        self.healthKitService = RealHealthKitService()
        self.notificationStore = NotificationStore()
        
        self.workoutObserver = WorkoutObserver(
            cloudKitManager: cloudKitManager,
            healthKitService: healthKitService
        )
        
        self.workoutSyncManager = WorkoutSyncManager(
            cloudKitManager: cloudKitManager,
            healthKitService: healthKitService
        )
        
        self.workoutSyncQueue = WorkoutSyncQueue(
            cloudKitManager: cloudKitManager
        )
        
        // Wire up dependencies
        cloudKitManager.authenticationManager = authenticationManager
        
        // Give workout observer access to notification store
        workoutObserver.notificationStore = notificationStore
        
        // Give workout sync manager access to notification store
        workoutSyncManager.notificationStore = notificationStore
    }
    
    // For testing, allow injection of mock managers
    init(
        authenticationManager: AuthenticationManager,
        cloudKitManager: CloudKitManager,
        workoutObserver: WorkoutObserver,
        healthKitService: HealthKitService? = nil,
        workoutSyncManager: WorkoutSyncManager? = nil,
        workoutSyncQueue: WorkoutSyncQueue? = nil,
        notificationStore: NotificationStore? = nil
    ) {
        self.authenticationManager = authenticationManager
        self.cloudKitManager = cloudKitManager
        self.workoutObserver = workoutObserver
        self.healthKitService = healthKitService ?? RealHealthKitService()
        self.workoutSyncManager = workoutSyncManager ?? WorkoutSyncManager(
            cloudKitManager: cloudKitManager,
            healthKitService: self.healthKitService
        )
        self.workoutSyncQueue = workoutSyncQueue ?? WorkoutSyncQueue(
            cloudKitManager: cloudKitManager
        )
        self.notificationStore = notificationStore ?? NotificationStore()
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