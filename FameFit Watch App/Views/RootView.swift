//
//  RootView.swift
//  FameFit Watch App
//
//  Root view with app initialization and navigation logic
//

import SwiftUI
import HealthKit
import WatchConnectivity

struct RootView: View {
    // MARK: - Dependencies
    
    @StateObject private var dependencies = DependencyContainer()
    @StateObject private var accountService = AccountVerificationService()
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var navigationCoordinator = WatchNavigationCoordinator()
    
    // MARK: - App Lifecycle
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var displayMode: WatchConfiguration.DisplayMode = .active
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if accountService.accountStatus == .checking {
                // Loading state
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                
            } else if accountService.shouldShowSetupPrompt {
                // Account setup needed
                AccountSetupView(accountService: accountService)
                
            } else {
                // Main app
                NavigationStack(path: $navigationCoordinator.navigationPath) {
                    WatchStartView()
                        .navigationDestination(for: WatchNavigationCoordinator.Route.self) { route in
                            switch route {
                            case .workoutList:
                                // This shouldn't happen as root is already workout list
                                WatchStartView()
                            case .session(let workoutType):
                                SessionPagingView()
                                    .onAppear {
                                        // Ensure workout type is set
                                        workoutManager.selectedWorkout = workoutType
                                    }
                            case .summary(_):
                                SummaryView()
                            }
                        }
                }
                .environmentObject(workoutManager)
                .environmentObject(accountService)
                .environmentObject(navigationCoordinator)
                .environmentObject(dependencies)  // Add the container itself
                .environmentObject(dependencies.sessionViewModel)
                .environmentObject(dependencies.summaryViewModel)
                .withDependencies(dependencies)
                .withNavigationCoordinator(navigationCoordinator)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onAppear {
            Task {
                await setupApp()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupApp() async {
        // Check account status
        await accountService.checkAccountStatus()
        
        // Request HealthKit authorization
        await requestHealthKitAuthorization()
        
        // Setup watch connectivity
        dependencies.watchConnectivity.setupHandlers()
        
        FameFitLogger.info("🚀 FameFit Watch App launched", category: FameFitLogger.system)
    }
    
    private func requestHealthKitAuthorization() async {
        do {
            try await dependencies.healthKitSession.requestAuthorization()
            FameFitLogger.info("✅ HealthKit authorization granted", category: FameFitLogger.system)
        } catch {
            FameFitLogger.error("❌ HealthKit authorization failed: \(error)", category: FameFitLogger.system)
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        // Update display mode based on scene phase
        switch phase {
        case .active:
            displayMode = .active
            dependencies.sessionViewModel.updateDisplayMode(.active)
            FameFitLogger.debug("📱 App active", category: FameFitLogger.system)
            
            // Request fresh profile when Watch app becomes active
            FameFitLogger.info("⌚📱 Watch app became active - requesting profile sync", category: FameFitLogger.sync)
            WatchConnectivityManager.shared.requestUserProfileFromPhone()
            
            // Also request workout sync if needed
            if WCSession.default.isReachable {
                let message = ["command": "requestWorkoutSync"]
                WCSession.default.sendMessage(message, replyHandler: { response in
                    FameFitLogger.info("⌚ Received workout sync response: \(response)", category: FameFitLogger.sync)
                }) { error in
                    FameFitLogger.debug("⌚ Could not request workout sync: \(error)", category: FameFitLogger.sync)
                }
            }
            
        case .inactive:
            displayMode = .alwaysOn
            dependencies.sessionViewModel.updateDisplayMode(.alwaysOn)
            FameFitLogger.debug("🌙 App inactive (Always-On Display)", category: FameFitLogger.system)
            
        case .background:
            displayMode = .background
            dependencies.sessionViewModel.updateDisplayMode(.background)
            FameFitLogger.debug("📴 App backgrounded", category: FameFitLogger.system)
            
        @unknown default:
            break
        }
    }
}