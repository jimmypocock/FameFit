//
//  NavigationCoordinator.swift
//  FameFit
//
//  Manages app-wide navigation, deep linking, and navigation paths
//

import SwiftUI
import Combine

// MARK: - Navigation Path

enum NavigationDestination: Hashable {
    case groupWorkout(GroupWorkout)
    case groupWorkoutDetail(String) // workout ID for deep linking
    case profile(String) // user ID
    case challenge(String) // challenge ID
    case workout(String) // workout ID
    
    var id: String {
        switch self {
        case .groupWorkout(let workout): workout.id
        case .groupWorkoutDetail(let id): id
        case .profile(let id): id
        case .challenge(let id): id
        case .workout(let id): id
        }
    }
}

// MARK: - Navigation Coordinator

@MainActor
final class NavigationCoordinator: ObservableObject {
    @Published var groupWorkoutsPath = NavigationPath()
    @Published var profilePath = NavigationPath()
    @Published var challengesPath = NavigationPath()
    @Published var workoutsPath = NavigationPath()
    @Published var selectedTab: Int = 0
    
    // Deep link handling
    @Published var pendingDeepLink: URL?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Navigation Actions
    
    func navigateToGroupWorkout(_ workout: GroupWorkout) {
        selectedTab = 3 // Group workouts tab
        groupWorkoutsPath.append(NavigationDestination.groupWorkout(workout))
    }
    
    func navigateToGroupWorkoutDetail(id: String) {
        selectedTab = 3 // Group workouts tab
        groupWorkoutsPath.append(NavigationDestination.groupWorkoutDetail(id))
    }
    
    func navigateToProfile(userID: String) {
        profilePath.append(NavigationDestination.profile(userID))
    }
    
    func navigateToChallenge(id: String) {
        selectedTab = 4 // Challenges tab
        challengesPath.append(NavigationDestination.challenge(id))
    }
    
    func navigateToWorkout(id: String) {
        selectedTab = 2 // Workouts tab
        workoutsPath.append(NavigationDestination.workout(id))
    }
    
    // MARK: - Deep Link Handling
    
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
        
        // Expected format: famefit://[type]/[id]
        // e.g., famefit://groupworkout/abc123
        // In this format: host = "groupworkout", path = "/abc123"
        
        guard let host = components.host else { 
            FameFitLogger.warning("Deep link missing host: \(url)", category: FameFitLogger.ui)
            return 
        }
        
        // Remove leading slash from path and get the ID
        let pathWithoutSlash = components.path.hasPrefix("/") ? String(components.path.dropFirst()) : components.path
        guard !pathWithoutSlash.isEmpty else {
            FameFitLogger.warning("Deep link missing ID: \(url)", category: FameFitLogger.ui)
            return
        }
        
        FameFitLogger.info("Handling deep link - type: \(host), id: \(pathWithoutSlash)", category: FameFitLogger.ui)
        
        switch host {
        case "groupworkout":
            navigateToGroupWorkoutDetail(id: pathWithoutSlash)
        case "profile":
            navigateToProfile(userID: pathWithoutSlash)
        case "challenge":
            navigateToChallenge(id: pathWithoutSlash)
        case "workout":
            navigateToWorkout(id: pathWithoutSlash)
        default:
            FameFitLogger.warning("Unknown deep link type: \(host)", category: FameFitLogger.ui)
        }
    }
    
    // MARK: - Navigation Stack Management
    
    func popToRoot(for tab: Int) {
        switch tab {
        case 3: // Group workouts
            groupWorkoutsPath = NavigationPath()
        case 4: // Challenges
            challengesPath = NavigationPath()
        case 2: // Workouts
            workoutsPath = NavigationPath()
        default:
            break
        }
    }
    
    func clearAllPaths() {
        groupWorkoutsPath = NavigationPath()
        profilePath = NavigationPath()
        challengesPath = NavigationPath()
        workoutsPath = NavigationPath()
    }
}

// MARK: - Environment Key

private struct NavigationCoordinatorKey: EnvironmentKey {
    static let defaultValue: NavigationCoordinator? = nil
}

extension EnvironmentValues {
    var navigationCoordinator: NavigationCoordinator? {
        get { self[NavigationCoordinatorKey.self] }
        set { self[NavigationCoordinatorKey.self] = newValue }
    }
}
