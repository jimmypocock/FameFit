//
//  ModernHealthKitService.swift
//  FameFit
//
//  Modern async/await implementation of HealthKit service
//

import Foundation
import HealthKit
import os.log

// MARK: - Modern HealthKit Service Protocol

protocol ModernHealthKitServicing {
    var isHealthDataAvailable: Bool { get }
    
    func requestAuthorization() async throws -> Bool
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    func enableBackgroundDelivery() async throws
    func fetchWorkouts(limit: Int) async throws -> [HKWorkout]
    func fetchWorkoutsWithPredicate(_ predicate: NSPredicate?, limit: Int, sortDescriptors: [NSSortDescriptor]) async throws -> [HKWorkout]
    func save(_ workout: HKWorkout) async throws
    func fetchStatistics(for type: HKQuantityType, predicate: NSPredicate?, options: HKStatisticsOptions) async throws -> HKStatistics?
    func startObservingWorkouts() async throws -> AsyncStream<HKWorkout>
}

// MARK: - Modern HealthKit Service Implementation

final class ModernHealthKitService: ModernHealthKitServicing, @unchecked Sendable {
    private let healthStore: HKHealthStore
    private var observerQuery: HKObserverQuery?
    
    // Types we need to read/write
    private static let shareTypes: Set<HKSampleType> = [
        HKObjectType.workoutType()
    ]
    
    private static let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
        HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
        HKObjectType.activitySummaryType()
    ]
    
    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }
    
    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            healthStore.requestAuthorization(
                toShare: Self.shareTypes,
                read: Self.readTypes
            ) { success, error in
                if let error = error {
                    FameFitLogger.error("HealthKit authorization failed", error: error, category: FameFitLogger.healthKit)
                    continuation.resume(throwing: error)
                } else {
                    FameFitLogger.info("HealthKit authorization success: \(success)", category: FameFitLogger.healthKit)
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: type)
    }
    
    // MARK: - Background Delivery
    
    func enableBackgroundDelivery() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.enableBackgroundDelivery(
                for: HKObjectType.workoutType(),
                frequency: .immediate
            ) { success, error in
                if let error = error {
                    FameFitLogger.error("Background delivery setup failed", error: error, category: FameFitLogger.healthKit)
                    continuation.resume(throwing: error)
                } else {
                    FameFitLogger.info("Background delivery enabled: \(success)", category: FameFitLogger.healthKit)
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Workout Fetching
    
    func fetchWorkouts(limit: Int) async throws -> [HKWorkout] {
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )
        
        return try await fetchWorkoutsWithPredicate(
            nil,
            limit: limit,
            sortDescriptors: [sortDescriptor]
        )
    }
    
    func fetchWorkoutsWithPredicate(
        _ predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]
    ) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: limit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error = error {
                    FameFitLogger.error("Workout fetch failed", error: error, category: FameFitLogger.healthKit)
                    continuation.resume(throwing: error)
                } else {
                    let workouts = (samples as? [HKWorkout]) ?? []
                    FameFitLogger.info("Fetched \(workouts.count) workouts", category: FameFitLogger.healthKit)
                    continuation.resume(returning: workouts)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Saving Workouts
    
    func save(_ workout: HKWorkout) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(workout) { success, error in
                if let error = error {
                    FameFitLogger.error("Failed to save workout", error: error, category: FameFitLogger.healthKit)
                    continuation.resume(throwing: error)
                } else if !success {
                    FameFitLogger.error("Workout save returned false", category: FameFitLogger.healthKit)
                    continuation.resume(throwing: HealthKitError.saveFailed)
                } else {
                    FameFitLogger.info("Workout saved successfully", category: FameFitLogger.healthKit)
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Statistics
    
    func fetchStatistics(
        for type: HKQuantityType,
        predicate: NSPredicate?,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatistics?, Error>) in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, statistics, error in
                if let error = error {
                    FameFitLogger.error("Statistics fetch failed", error: error, category: FameFitLogger.healthKit)
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: statistics)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Workout Observation
    
    func startObservingWorkouts() async throws -> AsyncStream<HKWorkout> {
        // Stop any existing observer
        if let existingQuery = observerQuery {
            healthStore.stop(existingQuery)
            observerQuery = nil
        }
        
        return AsyncStream { continuation in
            let query = HKObserverQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: nil
            ) { [weak self] query, completionHandler, error in
                guard let self = self else {
                    completionHandler()
                    return
                }
                
                if let error = error {
                    FameFitLogger.error("Observer query error", error: error, category: FameFitLogger.healthKit)
                    completionHandler()
                    return
                }
                
                // When we get an update, fetch the latest workouts
                Task {
                    do {
                        // Fetch workouts from the last 24 hours
                        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
                        let predicate = HKQuery.predicateForSamples(
                            withStart: oneDayAgo,
                            end: Date(),
                            options: .strictStartDate
                        )
                        
                        let workouts = try await self.fetchWorkoutsWithPredicate(
                            predicate,
                            limit: 10,
                            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                        )
                        
                        // Send each workout to the stream
                        for workout in workouts {
                            continuation.yield(workout)
                        }
                    } catch {
                        FameFitLogger.error("Failed to fetch workouts in observer", error: error, category: FameFitLogger.healthKit)
                    }
                    
                    completionHandler()
                }
            }
            
            self.observerQuery = query
            self.healthStore.execute(query)
            
            continuation.onTermination = { _ in
                if let query = self.observerQuery {
                    self.healthStore.stop(query)
                    self.observerQuery = nil
                }
            }
        }
    }
    
    deinit {
        if let query = observerQuery {
            healthStore.stop(query)
        }
    }
}

// MARK: - HealthKit Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case saveFailed
    case queryFailed
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .saveFailed:
            return "Failed to save workout to HealthKit"
        case .queryFailed:
            return "Failed to query HealthKit data"
        case .invalidData:
            return "Invalid HealthKit data"
        }
    }
}