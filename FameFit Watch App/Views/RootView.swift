//
//  RootView.swift
//  FameFit Watch App
//
//  Root view with app initialization and navigation logic
//

import SwiftUI
import HealthKit

struct RootView: View {
    // MARK: - Dependencies
    
    @StateObject private var dependencies = DependencyContainer()
    @StateObject private var accountService = AccountVerificationService()
    @StateObject private var workoutManager = WorkoutManager()
    
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
                NavigationStack {
                    WatchStartView()
                        .environmentObject(workoutManager)
                        .environmentObject(dependencies.sessionViewModel)
                        .environmentObject(dependencies.summaryViewModel)
                }
                .withDependencies(dependencies)
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