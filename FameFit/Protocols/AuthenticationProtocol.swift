//
//  AuthenticationProtocol.swift
//  FameFit
//
//  Protocol for authentication services
//

import AuthenticationServices
import Combine
import Foundation

protocol AuthenticationProtocol: ObservableObject {
    var isAuthenticated: Bool { get }
    var authUserID: String? { get }  // Sign in with Apple ID
    var userName: String? { get }
    var lastError: FameFitError? { get }
    var hasCompletedOnboarding: Bool { get }

    // Publisher properties for reactive updates
    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> { get }
    var authUserIDPublisher: AnyPublisher<String?, Never> { get }
    var userNamePublisher: AnyPublisher<String?, Never> { get }
    var lastErrorPublisher: AnyPublisher<FameFitError?, Never> { get }
    var hasCompletedOnboardingPublisher: AnyPublisher<Bool, Never> { get }

    func checkAuthenticationStatus()
    func handleSignInWithApple(credential: ASAuthorizationAppleIDCredential)
    func signOut()
    func completeOnboarding()
}