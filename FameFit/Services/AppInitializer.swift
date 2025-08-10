//
//  AppInitializer.swift
//  FameFit
//
//  Manages app initialization and service startup based on authentication state
//

import Foundation
import SwiftUI

/// Handles app initialization and service configuration
@MainActor
final class AppInitializer: ObservableObject {
    
    // MARK: - Properties
    
    private let dependencyContainer: DependencyContainer
    private var hasInitialized = false
    private var userServicesStarted = false
    
    // MARK: - Initialization
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
    }
    
    // MARK: - Public Methods
    
    /// Performs initial app setup
    /// Should be called once when app launches
    func performInitialSetup() {
        guard !hasInitialized else {
            FameFitLogger.debug("AppInitializer.performInitialSetup called but already initialized", category: FameFitLogger.app)
            return
        }
        hasInitialized = true
        
        FameFitLogger.info("🚀 AppInitializer.performInitialSetup starting...", category: FameFitLogger.app)
        
        // Configure background services (these always run)
        configureBackgroundServices()
        
        // Configure user-dependent services if onboarding is complete
        if dependencyContainer.authenticationManager.hasCompletedOnboarding {
            FameFitLogger.info("User has completed onboarding, starting user services from performInitialSetup", category: FameFitLogger.app)
            Task {
                await configureUserServices()
            }
        } else {
            FameFitLogger.info("User has not completed onboarding, skipping user services", category: FameFitLogger.app)
        }
    }
    
    /// Called when authentication state changes
    func handleAuthenticationChange(isAuthenticated: Bool, hasCompletedOnboarding: Bool) {
        FameFitLogger.info("📱 AppInitializer.handleAuthenticationChange called - isAuth: \(isAuthenticated), hasOnboarded: \(hasCompletedOnboarding)", category: FameFitLogger.app)
        
        if isAuthenticated && hasCompletedOnboarding {
            Task {
                await configureUserServices()
            }
        } else {
            // Stop services if user logs out
            stopUserServices()
        }
    }
    
    // MARK: - Private Methods
    
    /// Configure services that run regardless of auth state
    private func configureBackgroundServices() {
        // Configure background task manager
        BackgroundTaskManager.shared.configure(with: dependencyContainer)
        
        FameFitLogger.info("Background services configured", category: FameFitLogger.app)
    }
    
    /// Configure services that require authenticated user
    private func configureUserServices() async {
        guard !userServicesStarted else {
            FameFitLogger.info("User services already started, skipping duplicate initialization", category: FameFitLogger.app)
            return
        }
        
        userServicesStarted = true
        FameFitLogger.info("Starting user services...", category: FameFitLogger.app)
        
        // Setup push notifications (handles both local and remote permissions)
        await setupPushNotifications()
        
        // Start workout sync
        startWorkoutSync()
        
        // Setup auto-sharing
        setupAutoSharing()
        
        // Start group workout service (sets up CloudKit subscriptions)
        startGroupWorkoutService()
        
        // Verify counts if needed
        await verifyCountsIfNeeded()
        
        FameFitLogger.info("User services configured successfully", category: FameFitLogger.app)
    }
    
    /// Stop user-specific services
    private func stopUserServices() {
        guard userServicesStarted else {
            FameFitLogger.info("User services not started, nothing to stop", category: FameFitLogger.app)
            return
        }
        
        // Stop workout sync
        dependencyContainer.workoutSyncManager.stopSync()
        
        userServicesStarted = false
        FameFitLogger.info("User services stopped", category: FameFitLogger.app)
    }
    
    // MARK: - Service Configuration
    
    private func startWorkoutSync() {
        // Start the reliable sync manager using HKAnchoredObjectQuery
        // This provides more reliable workout tracking than observer queries
        dependencyContainer.workoutSyncManager.startReliableSync()
    }
    
    private func setupAutoSharing() {
        // Start auto-sharing service for workouts
        dependencyContainer.workoutAutoShareService.setupAutoSharing()
    }
    
    private func startGroupWorkoutService() {
        // Start group workout service and setup CloudKit subscriptions
        // Only called after user is authenticated
        if let groupWorkoutService = dependencyContainer.groupWorkoutService as? GroupWorkoutService {
            groupWorkoutService.startService()
        }
    }
    
    private func verifyCountsIfNeeded() async {
        // Verify counts if needed (runs in background)
        guard dependencyContainer.countVerificationService.shouldVerifyOnAppLaunch() else { return }
        
        do {
            let result = try await dependencyContainer.countVerificationService.verifyAllCounts()
            if result.xpCorrected || result.workoutCountCorrected {
                FameFitLogger.info("🔢 Count verification completed: \(result.summary)", category: FameFitLogger.data)
            }
        } catch {
            FameFitLogger.error("🔢 Count verification failed", error: error, category: FameFitLogger.data)
        }
    }
    
    private func setupPushNotifications() async {
        // APNSService handles both local and remote notification permissions
        do {
            let granted = try await dependencyContainer.apnsManager.requestNotificationPermissions()
            if granted {
                // Register for remote push notifications from CloudKit
                dependencyContainer.apnsManager.registerForRemoteNotifications()
                FameFitLogger.info("Notification permissions granted, registered for push notifications", category: FameFitLogger.app)
            } else {
                FameFitLogger.info("Notification permissions denied by user", category: FameFitLogger.app)
            }
        } catch {
            FameFitLogger.error("Failed to request notification permissions", error: error, category: FameFitLogger.app)
        }
    }
}