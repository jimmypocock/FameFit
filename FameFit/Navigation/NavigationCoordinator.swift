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
    
    func navigateToProfile(userId: String) {
        profilePath.append(NavigationDestination.profile(userId))
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
        let path = components.path
        let pathComponents = path.split(separator: "/")
        guard pathComponents.count >= 2 else { return }
        
        let type = String(pathComponents[0])
        let id = String(pathComponents[1])
        
        switch type {
        case "groupworkout":
            navigateToGroupWorkoutDetail(id: id)
        case "profile":
            navigateToProfile(userId: id)
        case "challenge":
            navigateToChallenge(id: id)
        case "workout":
            navigateToWorkout(id: id)
        default:
            FameFitLogger.warning("Unknown deep link type: \(type)", category: FameFitLogger.ui)
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