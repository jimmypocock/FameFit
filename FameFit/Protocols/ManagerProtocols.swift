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
    
    // Publisher properties for reactive updates
    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> { get }
    var userIDPublisher: AnyPublisher<String?, Never> { get }
    var userNamePublisher: AnyPublisher<String?, Never> { get }
    var lastErrorPublisher: AnyPublisher<FameFitError?, Never> { get }
    var hasCompletedOnboardingPublisher: AnyPublisher<Bool, Never> { get }
    
    func checkAuthenticationStatus()
    func handleSignInWithApple(credential: ASAuthorizationAppleIDCredential)
    func signOut()
    func completeOnboarding()
}

// MARK: - CloudKitManager Protocol
protocol CloudKitManaging: ObservableObject {
    var isAvailable: Bool { get }
    var currentUserID: String? { get }
    var totalXP: Int { get }
    var totalWorkouts: Int { get }
    var currentStreak: Int { get }
    var userName: String { get }
    var lastWorkoutTimestamp: Date? { get }
    var joinTimestamp: Date? { get }
    var lastError: FameFitError? { get }
    
    // Publisher properties for reactive updates
    var isAvailablePublisher: AnyPublisher<Bool, Never> { get }
    var totalXPPublisher: AnyPublisher<Int, Never> { get }
    var totalWorkoutsPublisher: AnyPublisher<Int, Never> { get }
    var currentStreakPublisher: AnyPublisher<Int, Never> { get }
    var userNamePublisher: AnyPublisher<String, Never> { get }
    var lastWorkoutTimestampPublisher: AnyPublisher<Date?, Never> { get }
    var joinTimestampPublisher: AnyPublisher<Date?, Never> { get }
    var lastErrorPublisher: AnyPublisher<FameFitError?, Never> { get }
    
    func checkAccountStatus()
    func fetchUserRecord()
    func recordWorkout(_ workout: HKWorkout, completion: @escaping (Bool) -> Void)
    func getXPTitle() -> String
    func saveWorkoutHistory(_ workoutHistory: WorkoutHistoryItem)
    func fetchWorkoutHistory(completion: @escaping (Result<[WorkoutHistoryItem], Error>) -> Void)
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
