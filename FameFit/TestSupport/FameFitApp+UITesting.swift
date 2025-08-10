//
//  FameFitApp+UITesting.swift
//  FameFit
//
//  UI Testing configuration support for FameFitApp
//

#if DEBUG
import SwiftUI

// MARK: - UI Testing Support
extension FameFitApp {
    
    /// Configures the app for UI testing based on launch arguments
    /// - Parameter container: The dependency container to configure
    func configureForUITesting(with container: DependencyContainer) {
        let testConfiguration = UITestConfiguration(from: ProcessInfo.processInfo.arguments)
        testConfiguration.apply(to: container)
    }
}

// MARK: - UI Test Configuration
private struct UITestConfiguration {
    
    // MARK: - Configuration Types
    enum TestMode {
        case resetState
        case skipOnboarding
        case authenticatedWithoutOnboarding
        case none
    }
    
    // MARK: - Properties
    let mode: TestMode
    
    // MARK: - Initialization
    init(from arguments: [String]) {
        guard arguments.contains("UI-Testing") else {
            self.mode = .none
            return
        }
        
        if arguments.contains("--reset-state") {
            self.mode = .resetState
        } else if arguments.contains("--skip-onboarding") {
            self.mode = .skipOnboarding
        } else if arguments.contains("--mock-auth-for-onboarding") {
            self.mode = .authenticatedWithoutOnboarding
        } else {
            self.mode = .none
        }
    }
    
    // MARK: - Application
    func apply(to container: DependencyContainer) {
        switch mode {
        case .resetState:
            resetApplicationState(container: container)
        case .skipOnboarding:
            configureAuthenticatedState(
                container: container,
                hasCompletedOnboarding: true
            )
        case .authenticatedWithoutOnboarding:
            configureAuthenticatedState(
                container: container,
                hasCompletedOnboarding: false
            )
        case .none:
            break
        }
    }
    
    // MARK: - Private Methods
    private func resetApplicationState(container: DependencyContainer) {
        // Sign out from authentication
        container.authenticationManager.signOut()
        
        // Clear all user defaults related to onboarding and authentication
        let keysToRemove = [
            "hasCompletedOnboarding",
            "isAuthenticated"
        ]
        
        keysToRemove.forEach { key in
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        UserDefaults.standard.synchronize()
    }
    
    private func configureAuthenticatedState(
        container: DependencyContainer,
        hasCompletedOnboarding: Bool
    ) {
        container.authenticationManager.setUITestingState(
            isAuthenticated: true,
            hasCompletedOnboarding: hasCompletedOnboarding,
            userID: UITestConstants.defaultUserID
        )
    }
}

// MARK: - Constants
private enum UITestConstants {
    static let defaultUserID = "ui-test-user"
}

#endif