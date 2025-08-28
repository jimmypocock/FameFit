//
//  MockAuthenticationService.swift
//  FameFitTests
//
//  Mock implementation of AuthenticationProtocol for testing
//

import AuthenticationServices
import Combine
@testable import FameFit
import Foundation

/// Mock authentication manager for testing
class MockAuthenticationService: AuthenticationProtocol {
    // MARK: - Published Properties

    @Published var isAuthenticated: Bool = false
    @Published var authUserID: String?
    @Published var username: String?
    @Published var lastError: FameFitError?
    @Published var hasCompletedOnboarding: Bool = false

    // MARK: - Publisher Properties

    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> {
        $isAuthenticated.eraseToAnyPublisher()
    }

    var authUserIDPublisher: AnyPublisher<String?, Never> {
        $authUserID.eraseToAnyPublisher()
    }

    var usernamePublisher: AnyPublisher<String?, Never> {
        $username.eraseToAnyPublisher()
    }

    var lastErrorPublisher: AnyPublisher<FameFitError?, Never> {
        $lastError.eraseToAnyPublisher()
    }

    var hasCompletedOnboardingPublisher: AnyPublisher<Bool, Never> {
        $hasCompletedOnboarding.eraseToAnyPublisher()
    }

    // MARK: - Method Call Tracking

    var checkAuthenticationStatusCalled = false
    var handleSignInWithAppleCalled = false
    var signOutCalled = false
    var completeOnboardingCalled = false

    // MARK: - Test Configuration

    var shouldFailAuthentication = false
    var shouldFailSignOut = false
    var shouldFailOnboarding = false

    // MARK: - Protocol Methods

    func checkAuthenticationStatus() {
        checkAuthenticationStatusCalled = true

        if shouldFailAuthentication {
            isAuthenticated = false
            authUserID = nil
            username = nil
            lastError = .authenticationFailed(NSError(domain: "MockAuthError", code: 1))
        } else {
            // Simulate checking stored credentials
            if authUserID != nil {
                isAuthenticated = true
                lastError = nil
            }
        }
    }

    func handleSignInWithApple(credential: ASAuthorizationAppleIDCredential) {
        handleSignInWithAppleCalled = true

        if shouldFailAuthentication {
            lastError = .authenticationFailed(NSError(domain: "MockAuthError", code: 2))
            isAuthenticated = false
            return
        }

        // Simulate successful sign in
        authUserID = credential.user
        username = "Test User"
        isAuthenticated = true
        lastError = nil
    }

    func signOut() {
        signOutCalled = true

        if shouldFailSignOut {
            lastError = .unknownError(NSError(
                domain: "MockAuthError",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Sign out failed"]
            ))
            return
        }

        // Simulate successful sign out
        isAuthenticated = false
        authUserID = nil
        username = nil
        hasCompletedOnboarding = false
        lastError = nil
    }

    func completeOnboarding() {
        completeOnboardingCalled = true

        if shouldFailOnboarding {
            lastError = .unknownError(NSError(
                domain: "MockAuthError",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Onboarding failed"]
            ))
            return
        }

        // Simulate successful onboarding completion
        hasCompletedOnboarding = true
        lastError = nil
    }

    // MARK: - Test Helpers

    func simulateAuthentication(userID: String = "test-user", username: String = "Test User") {
        self.authUserID = userID
        self.username = username
        isAuthenticated = true
        hasCompletedOnboarding = true
        lastError = nil
    }

    func simulateAuthenticationError(_ error: FameFitError = .authenticationFailed(NSError(
        domain: "SimulatedAuthError",
        code: 3
    ))) {
        isAuthenticated = false
        authUserID = nil
        username = nil
        lastError = error
    }

    func reset() {
        checkAuthenticationStatusCalled = false
        handleSignInWithAppleCalled = false
        signOutCalled = false
        completeOnboardingCalled = false
        shouldFailAuthentication = false
        shouldFailSignOut = false
        shouldFailOnboarding = false

        isAuthenticated = false
        authUserID = nil
        username = nil
        lastError = nil
        hasCompletedOnboarding = false
    }
}
