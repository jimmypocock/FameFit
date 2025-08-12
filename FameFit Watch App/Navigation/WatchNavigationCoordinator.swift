//
//  WatchNavigationCoordinator.swift
//  FameFit Watch App
//
//  Central navigation coordinator for Watch app
//

import SwiftUI
import HealthKit

@MainActor
final class WatchNavigationCoordinator: ObservableObject {
    
    // MARK: - Navigation Routes
    
    enum Route: Hashable {
        case workoutList
        case session(HKWorkoutActivityType)
        case summary(workout: HKWorkout?)
    }
    
    // MARK: - Sheet Types
    
    enum Sheet: Identifiable {
        case accountSetup
        case workoutSelection
        
        var id: String {
            switch self {
            case .accountSetup: return "accountSetup"
            case .workoutSelection: return "workoutSelection"
            }
        }
    }
    
    // MARK: - Published State
    
    @Published var navigationPath = NavigationPath()
    @Published var presentedSheet: Sheet?
    @Published var selectedWorkoutType: HKWorkoutActivityType?
    
    // MARK: - Navigation Actions
    
    /// Navigate to workout session
    func startWorkout(_ type: HKWorkoutActivityType) {
        FameFitLogger.debug("📍 Navigation: Starting workout \(type.displayName)", category: FameFitLogger.sync)
        selectedWorkoutType = type
        // Use Route enum instead of raw type
        navigationPath.append(Route.session(type))
    }
    
    /// Navigate to workout summary
    func showSummary(workout: HKWorkout?) {
        FameFitLogger.debug("📍 Navigation: showSummary called - current path count: \(navigationPath.count)", category: FameFitLogger.sync)
        
        // Navigate from session to summary by pushing summary onto the stack
        // Use Task to defer navigation to next run loop, avoiding multiple updates per frame
        Task { @MainActor in
            withAnimation(.none) {
                FameFitLogger.debug("📍 Navigation: Appending summary to path", category: FameFitLogger.sync)
                navigationPath.append(Route.summary(workout: workout))
                FameFitLogger.debug("📍 Navigation: Path after append: \(navigationPath.count) items", category: FameFitLogger.sync)
            }
        }
    }
    
    /// Dismiss summary and return to workout list
    func dismissSummary() {
        FameFitLogger.debug("📍 Navigation: Dismissing summary", category: FameFitLogger.sync)
        // Just pop back to the root (workout list)
        returnToWorkoutList()
    }
    
    /// Return to workout list
    func returnToWorkoutList() {
        FameFitLogger.debug("📍 Navigation: Returning to workout list", category: FameFitLogger.sync)
        // Clear entire navigation stack
        if !navigationPath.isEmpty {
            // Remove all items from the path
            let count = navigationPath.count
            for _ in 0..<count {
                navigationPath.removeLast()
            }
        }
        selectedWorkoutType = nil
    }
    
    /// Show account setup
    func showAccountSetup() {
        FameFitLogger.debug("📍 Navigation: Showing account setup", category: FameFitLogger.sync)
        presentedSheet = .accountSetup
    }
    
    /// Show workout selection sheet
    func showWorkoutSelection() {
        FameFitLogger.debug("📍 Navigation: Showing workout selection", category: FameFitLogger.sync)
        presentedSheet = .workoutSelection
    }
    
    /// Dismiss any presented sheet
    func dismissSheet() {
        FameFitLogger.debug("📍 Navigation: Dismissing sheet", category: FameFitLogger.sync)
        presentedSheet = nil
    }
    
    /// Reset all navigation state
    func reset() {
        FameFitLogger.debug("📍 Navigation: Resetting all navigation state", category: FameFitLogger.sync)
        navigationPath = NavigationPath()
        presentedSheet = nil
        selectedWorkoutType = nil
    }
    
    // MARK: - State Queries
    
    /// Check if we're in a workout session
    var isInWorkoutSession: Bool {
        selectedWorkoutType != nil
    }
}

// MARK: - Environment Key

struct NavigationCoordinatorKey: EnvironmentKey {
    static let defaultValue: WatchNavigationCoordinator? = nil
}

extension EnvironmentValues {
    var navigationCoordinator: WatchNavigationCoordinator? {
        get { self[NavigationCoordinatorKey.self] }
        set { self[NavigationCoordinatorKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func withNavigationCoordinator(_ coordinator: WatchNavigationCoordinator) -> some View {
        self.environment(\.navigationCoordinator, coordinator)
    }
}