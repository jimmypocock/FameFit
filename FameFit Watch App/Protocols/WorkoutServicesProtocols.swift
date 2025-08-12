//
//  WorkoutServicesProtocols.swift
//  FameFit Watch App
//
//  Core protocols for workout-related services
//

import Foundation
import HealthKit
import Combine

// MARK: - HealthKit Session Management

protocol HealthKitSessionManaging {
    /// Current workout session
    var currentSession: HKWorkoutSession? { get }
    
    /// Session state publisher
    var sessionState: AnyPublisher<HKWorkoutSessionState, Never> { get }
    
    /// Start a new workout session
    func startSession(for activityType: HKWorkoutActivityType) async throws -> HKWorkoutSession
    
    /// Pause the current session
    func pauseSession() async throws
    
    /// Resume a paused session
    func resumeSession() async throws
    
    /// End the current session
    func endSession() async throws -> HKWorkout?
    
    /// Request HealthKit authorization
    func requestAuthorization() async throws
}

// MARK: - Workout Metrics Collection

protocol WorkoutMetricsCollecting {
    /// Real-time metrics publishers
    var heartRate: AnyPublisher<Double, Never> { get }
    var activeEnergy: AnyPublisher<Double, Never> { get }
    var distance: AnyPublisher<Double, Never> { get }
    var elapsedTime: AnyPublisher<TimeInterval, Never> { get }
    
    /// Aggregated metrics
    var averageHeartRate: Double { get }
    var totalActiveEnergy: Double { get }
    var totalDistance: Double { get }
    
    /// Start collecting metrics for a session
    func startCollecting(for session: HKWorkoutSession)
    
    /// Stop collecting metrics
    func stopCollecting()
    
    /// Update collection frequency based on display mode
    func updateFrequency(for mode: WatchConfiguration.DisplayMode)
}

// MARK: - Workout State Management

@MainActor
protocol WorkoutStateManaging: AnyObject {
    /// Current workout state
    var isWorkoutActive: Bool { get }
    var isPaused: Bool { get }
    var selectedWorkoutType: HKWorkoutActivityType? { get }
    
    /// State change publisher
    var stateChanges: AnyPublisher<WorkoutStateChange, Never> { get }
    
    /// Update workout state
    func setWorkoutActive(_ active: Bool)
    func setPaused(_ paused: Bool)
    func selectWorkoutType(_ type: HKWorkoutActivityType)
    
    /// Reset all state
    func reset()
}

enum WorkoutStateChange {
    case started(HKWorkoutActivityType)
    case paused
    case resumed
    case ended
    case error(Error)
}

// MARK: - Group Workout Coordination

@MainActor
protocol GroupWorkoutCoordinating: AnyObject {
    /// Current group workout info
    var currentGroupWorkout: WatchGroupWorkout? { get }
    var isGroupWorkoutHost: Bool { get }
    var participantCount: Int { get }
    
    /// Join a group workout
    func joinGroupWorkout(id: String, name: String, isHost: Bool) async throws
    
    /// Leave current group workout
    func leaveGroupWorkout() async
    
    /// Sync participant data
    func syncParticipantData(_ data: WorkoutMetricsData) async
    
    /// Get cached group workouts
    func getCachedGroupWorkouts() async -> [WatchGroupWorkout]
}

// MARK: - Watch Connectivity Service

protocol WatchConnectivityService {
    /// Connection state
    var isReachable: Bool { get }
    var isPaired: Bool { get }
    
    /// Send workout data to iPhone
    func sendWorkoutUpdate(_ update: WorkoutUpdate) async
    
    /// Send metrics batch (battery-optimized)
    func sendMetricsBatch(_ metrics: [WorkoutMetricsData]) async
    
    /// Request data from iPhone
    func requestUserProfile() async throws -> UserProfile
    func requestGroupWorkouts() async throws -> [WatchGroupWorkout]
    func requestChallenges() async throws -> [ChallengeInfo]
    
    /// Setup message handlers
    func setupHandlers()
}

// MARK: - Data Models

struct WorkoutUpdate: Codable {
    let workoutID: String
    let status: WorkoutStatus
    let timestamp: Date
    let metrics: WorkoutMetricsData?
    let groupWorkoutID: String?
}

enum WorkoutStatus: String, Codable {
    case started
    case paused
    case resumed
    case ended
    case error
}

struct WorkoutMetricsData: Codable {
    let heartRate: Double
    let activeEnergy: Double
    let distance: Double
    let elapsedTime: TimeInterval
    let timestamp: Date
}

// MARK: - Simplified Group Workout Model for Watch App
// Full model exists in iOS app - this is a minimal version for Watch

struct WatchGroupWorkout: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let hostID: String
    let workoutType: String  // Store as string to avoid HKWorkoutActivityType dependency
    let scheduledStart: Date
    let scheduledEnd: Date
    let maxParticipants: Int
    var currentParticipants: Int
    let isActive: Bool
    
    // Computed property for compatibility
    var scheduledDate: Date { scheduledStart }
}


struct ChallengeInfo: Codable {
    let id: String
    let name: String
    let progress: Double
    let target: Double
    let endDate: Date
}

// MARK: - Mock Implementation

final class MockWatchConnectivityService: WatchConnectivityService {
    var isReachable = true
    var isPaired = true
    
    func sendWorkoutUpdate(_ update: WorkoutUpdate) async {}
    func sendMetricsBatch(_ metrics: [WorkoutMetricsData]) async {}
    
    func requestUserProfile() async throws -> UserProfile {
        // Return mock profile using the iOS app's UserProfile model
        return UserProfile(
            id: "mock-user",
            userID: "mock-user-id",
            username: "TestUser",
            bio: "Test bio",
            workoutCount: 25,
            totalXP: 1500,
            creationDate: Date().addingTimeInterval(-30*24*3600),
            modificationDate: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil,
            countsLastVerified: Date(),
            countsVersion: 1,
            countsSyncToken: nil
        )
    }
    
    func requestGroupWorkouts() async throws -> [WatchGroupWorkout] {
        return []
    }
    
    func requestChallenges() async throws -> [ChallengeInfo] {
        return []
    }
    
    func setupHandlers() {}
}