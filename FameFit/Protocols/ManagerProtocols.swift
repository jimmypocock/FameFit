//
//  ManagerProtocols.swift
//  FameFit
//
//  Created for dependency injection and testability
//

import Foundation
import HealthKit
import Combine
import AuthenticationServices

// MARK: - AuthenticationManager Protocol
protocol AuthenticationManaging: ObservableObject {
    var isAuthenticated: Bool { get }
    var userID: String? { get }
    var userName: String? { get }
    var lastError: FameFitError? { get }
    var hasCompletedOnboarding: Bool { get }
    
    func checkAuthenticationStatus()
    func handleSignInWithApple(credential: ASAuthorizationAppleIDCredential)
    func signOut()
    func completeOnboarding()
}

// MARK: - CloudKitManager Protocol
protocol CloudKitManaging: ObservableObject {
    var isAvailable: Bool { get }
    var followerCount: Int { get }
    var totalWorkouts: Int { get }
    var currentStreak: Int { get }
    var userName: String { get }
    var lastWorkoutTimestamp: Date? { get }
    var joinTimestamp: Date? { get }
    var lastError: FameFitError? { get }
    
    func checkAccountStatus()
    func fetchUserRecord()
    func recordWorkout(_ workout: HKWorkout, completion: @escaping (Bool) -> Void)
    func getFollowerTitle() -> String
}

// MARK: - WorkoutObserver Protocol
protocol WorkoutObserving: ObservableObject {
    var allWorkouts: [HKWorkout] { get }
    var todaysWorkouts: [HKWorkout] { get }
    var isAuthorized: Bool { get }
    var lastError: FameFitError? { get }
    
    func requestHealthKitAuthorization(completion: @escaping (Bool, FameFitError?) -> Void)
    func startObservingWorkouts()
    func fetchInitialWorkouts()
}
