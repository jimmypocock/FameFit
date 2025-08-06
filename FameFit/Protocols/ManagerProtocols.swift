//
//  ManagerProtocols.swift
//  FameFit
//
//  Created for dependency injection and testability
//

import AuthenticationServices
import CloudKit
import Combine
import Foundation
import HealthKit

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
    func setupUserRecord(userID: String, displayName: String)
    func fetchUserRecord()
    func addXP(_ xp: Int)
    func recordWorkout(_ workout: HKWorkout, completion: @escaping (Bool) -> Void)
    func getXPTitle() -> String
    func saveWorkout(_ workoutHistory: Workout)
    func fetchWorkouts(completion: @escaping (Result<[Workout], Error>) -> Void)
    func recalculateStatsIfNeeded() async throws
    func recalculateUserStats() async throws
    func clearAllWorkoutsAndResetStats() async throws
    func debugCloudKitEnvironment() async throws
    func forceResetStats() async throws
    
    // Additional CloudKit operations
    func fetchRecords(withQuery query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?) async throws -> [CKRecord]
    func fetchRecords(ofType recordType: String, predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?, limit: Int?) async throws -> [CKRecord]
    func save(_ record: CKRecord) async throws -> CKRecord
    func delete(withRecordID recordID: CKRecord.ID) async throws
    func getCurrentUserID() async throws -> String
    var database: CKDatabase { get }
}

// MARK: - WorkoutObserver Protocol

protocol WorkoutObserving: ObservableObject {
    var allWorkouts: [HKWorkout] { get }
    var todaysWorkouts: [HKWorkout] { get }
    var isAuthorized: Bool { get }
    var lastError: FameFitError? { get }
    
    // Publisher for workout completion events
    var workoutCompletedPublisher: AnyPublisher<Workout, Never> { get }

    func requestHealthKitAuthorization(completion: @escaping (Bool, FameFitError?) -> Void)
    func startObservingWorkouts()
    func fetchInitialWorkouts()
}
