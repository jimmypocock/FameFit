//
//  HealthKitSessionManager.swift
//  FameFit Watch App
//
//  Manages HealthKit workout sessions with clean separation of concerns
//

import Foundation
import HealthKit
import Combine

final class HealthKitSessionManager: NSObject, HealthKitSessionManaging {
    // MARK: - Properties
    
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    // MARK: - Publishers
    
    private let sessionStateSubject = PassthroughSubject<HKWorkoutSessionState, Never>()
    var sessionState: AnyPublisher<HKWorkoutSessionState, Never> {
        sessionStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - HealthKitSessionManaging Protocol
    
    var currentSession: HKWorkoutSession? {
        session
    }
    
    func requestAuthorization() async throws {
        let typesToShare: Set = [HKQuantityType.workoutType()]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKQuantityType.quantityType(forIdentifier: .distanceSwimming)!,
            HKObjectType.workoutType()
        ]
        
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
    
    func startSession(for activityType: HKWorkoutActivityType) async throws -> HKWorkoutSession {
        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor
        
        // Create session and builder
        let newSession = try HKWorkoutSession(
            healthStore: healthStore,
            configuration: configuration
        )
        
        let newBuilder = newSession.associatedWorkoutBuilder()
        newBuilder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        
        // Set delegates
        newSession.delegate = self
        newBuilder.delegate = self
        
        // Store references
        self.session = newSession
        self.builder = newBuilder
        
        // Start session and builder
        let startDate = Date()
        newSession.startActivity(with: startDate)
        try await newBuilder.beginCollection(at: startDate)
        
        FameFitLogger.info("🏃 Started workout session: \(activityType)", category: FameFitLogger.workout)
        
        return newSession
    }
    
    func pauseSession() async throws {
        guard let session = session else {
            throw WorkoutError.noActiveSession
        }
        
        session.pause()
        sessionStateSubject.send(.paused)
        
        FameFitLogger.info("⏸️ Paused workout session", category: FameFitLogger.workout)
    }
    
    func resumeSession() async throws {
        guard let session = session else {
            throw WorkoutError.noActiveSession
        }
        
        session.resume()
        sessionStateSubject.send(.running)
        
        FameFitLogger.info("▶️ Resumed workout session", category: FameFitLogger.workout)
    }
    
    func endSession() async throws -> HKWorkout? {
        guard let session = session, let builder = builder else {
            throw WorkoutError.noActiveSession
        }
        
        session.end()
        
        do {
            try await builder.endCollection(at: Date())
            let workout = try await builder.finishWorkout()
            
            // Clear references
            self.session = nil
            self.builder = nil
            
            FameFitLogger.info("✅ Ended workout session successfully", category: FameFitLogger.workout)
            
            return workout
        } catch {
            FameFitLogger.error("❌ Failed to finish workout: \(error)", category: FameFitLogger.workout)
            throw error
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HealthKitSessionManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, 
                       didChangeTo toState: HKWorkoutSessionState,
                       from fromState: HKWorkoutSessionState, 
                       date: Date) {
        sessionStateSubject.send(toState)
        
        FameFitLogger.debug("Session state changed: \(fromState) → \(toState)", category: FameFitLogger.workout)
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, 
                       didFailWithError error: Error) {
        FameFitLogger.error("❌ Workout session error: \(error)", category: FameFitLogger.workout)
        sessionStateSubject.send(.stopped)
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HealthKitSessionManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, 
                       didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Data collection is handled by MetricsCollector
        // This delegate method is required but we don't process here
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Event collection handled if needed
    }
}

// MARK: - Error Types

enum WorkoutError: LocalizedError {
    case noActiveSession
    case authorizationDenied
    case healthKitNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active workout session"
        case .authorizationDenied:
            return "HealthKit authorization denied"
        case .healthKitNotAvailable:
            return "HealthKit is not available"
        }
    }
}

// MARK: - Mock Implementation for Previews

final class MockHealthKitSessionManager: HealthKitSessionManaging {
    var currentSession: HKWorkoutSession?
    
    let sessionState = Just(HKWorkoutSessionState.running)
        .eraseToAnyPublisher()
    
    func requestAuthorization() async throws {
        // Mock implementation
    }
    
    func startSession(for activityType: HKWorkoutActivityType) async throws -> HKWorkoutSession {
        // Return mock session
        fatalError("Mock session not implemented - use real device for testing")
    }
    
    func pauseSession() async throws {
        // Mock implementation
    }
    
    func resumeSession() async throws {
        // Mock implementation
    }
    
    func endSession() async throws -> HKWorkout? {
        // Mock implementation
        return nil
    }
}