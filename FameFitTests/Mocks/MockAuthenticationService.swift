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
    @Published var userID: String?
    @Published var userName: String?
    @Published var lastError: FameFitError?
    @Published var hasCompletedOnboarding: Bool = false

    // MARK: - Publisher Properties

    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> {
        $isAuthenticated.eraseToAnyPublisher()
    }

    var userIDPublisher: AnyPublisher<String?, Never> {
        $userID.eraseToAnyPublisher()
    }

    var userNamePublisher: AnyPublisher<String?, Never> {
        $userName.eraseToAnyPublisher()
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
            userID = nil
            userName = nil
            lastError = .authenticationFailed(NSError(domain: "MockAuthError", code: 1))
        } else {
            // Simulate checking stored credentials
            if userID != nil {
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
        userID = credential.user
        userName = "Test User"
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
        userID = nil
        userName = nil
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

    func simulateAuthentication(userID: String = "test-user", userName: String = "Test User") {
        self.userID = userID
        self.userName = userName
        isAuthenticated = true
        hasCompletedOnboarding = true
        lastError = nil
    }

    func simulateAuthenticationError(_ error: FameFitError = .authenticationFailed(NSError(
        domain: "SimulatedAuthError",
        code: 3
    ))) {
        isAuthenticated = false
        userID = nil
        userName = nil
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
        userID = nil
        userName = nil
        lastError = nil
        hasCompletedOnboarding = false
    }
}
