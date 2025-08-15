//
//  MockWorkoutInjector.swift
//  FameFit
//
//  Injects mock workout data into the real HealthKit system for development testing
//

#if DEBUG

import Foundation
import HealthKit
import Darwin

/// Injects mock workouts into the real system without replacing any services
final class MockWorkoutInjector {
    
    static let shared = MockWorkoutInjector()
    
    private let healthStore = HKHealthStore()
    private var isEnabled: Bool {
        // Multiple safety checks to ensure this NEVER runs in production
        guard !isRunningInAppStore() else { return false }
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return false }
        
        return ProcessInfo.processInfo.arguments.contains("--mock-healthkit") ||
               ProcessInfo.processInfo.environment["USE_MOCK_HEALTHKIT"] == "1"
    }
    
    private func isRunningInAppStore() -> Bool {
        // Check if running from App Store / TestFlight
        #if targetEnvironment(simulator)
        return false  // Simulator is always development
        #else
        // Check for sandbox receipt (indicates App Store/TestFlight)
        if let url = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: url.path) {
            return true
        }
        // Check if debugger is attached (development builds have debugger)
        return !isDebuggerAttached()
        #endif
    }
    
    private func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.size
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        return result == 0 && (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    private init() {
        if isEnabled {
            FameFitLogger.info("Mock workout injection enabled", category: FameFitLogger.healthKit)
        }
    }
    
    // MARK: - Workout Scenarios
    
    enum Scenario {
        case quickTest(duration: TimeInterval = 30)
        case morningRun
        case eveningHIIT
        case strengthTraining
        case groupWorkout(participants: Int = 3)
        case weekStreak
    }
    
    // MARK: - Public Methods
    
    /// Injects a mock workout that will be picked up by the WorkoutSyncService
    func injectWorkout(scenario: Scenario, completion: @escaping (Bool) -> Void = { _ in }) {
        guard isEnabled else {
            FameFitLogger.debug("Mock injection disabled", category: FameFitLogger.healthKit)
            completion(false)
            return
        }
        
        Task {
            do {
                let workout = try await createWorkout(for: scenario)
                
                // Save to real HealthKit
                try await healthStore.save(workout)
                
                // The WorkoutSyncService will pick this up and sync to CloudKit
                FameFitLogger.info("Injected mock workout: \(workout.workoutActivityType)", category: FameFitLogger.healthKit)
                
                await MainActor.run {
                    completion(true)
                }
            } catch {
                FameFitLogger.error("Failed to inject mock workout", error: error)
                await MainActor.run {
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func createWorkout(for scenario: Scenario) async throws -> HKWorkout {
        let configuration: (type: HKWorkoutActivityType, duration: TimeInterval, distance: Double?, energy: Double)
        
        switch scenario {
        case .quickTest(let duration):
            configuration = (.running, duration, 100, 5)
            
        case .morningRun:
            configuration = (.running, 30 * 60, 5000, 300)
            
        case .eveningHIIT:
            configuration = (.highIntensityIntervalTraining, 25 * 60, nil, 250)
            
        case .strengthTraining:
            configuration = (.functionalStrengthTraining, 45 * 60, nil, 200)
            
        case .groupWorkout:
            configuration = (.running, 35 * 60, 6000, 350)
            
        case .weekStreak:
            // This will create multiple workouts
            for day in 0..<7 {
                let date = Date().addingTimeInterval(-Double(day) * 86400)
                _ = try await createAndSaveWorkout(
                    type: .running,
                    duration: TimeInterval.random(in: 20...40) * 60,
                    distance: Double.random(in: 3000...7000),
                    energy: Double.random(in: 200...400),
                    startDate: date
                )
            }
            // Return the most recent one
            configuration = (.running, 30 * 60, 5000, 300)
        }
        
        return try await createAndSaveWorkout(
            type: configuration.type,
            duration: configuration.duration,
            distance: configuration.distance,
            energy: configuration.energy,
            startDate: Date().addingTimeInterval(-configuration.duration - 60) // Ended 1 minute ago
        )
    }
    
    private func createAndSaveWorkout(
        type: HKWorkoutActivityType,
        duration: TimeInterval,
        distance: Double?,
        energy: Double,
        startDate: Date
    ) async throws -> HKWorkout {
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = type
        configuration.locationType = .indoor
        
        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )
        
        // Begin collection with completion handler wrapped in async
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: startDate) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if !success {
                    continuation.resume(throwing: NSError(domain: "MockWorkoutInjector", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to begin collection"]))
                } else {
                    continuation.resume()
                }
            }
        }
        
        // Add samples
        let endDate = startDate.addingTimeInterval(duration)
        
        // Add energy burned
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: energy)
            let energySample = HKQuantitySample(
                type: energyType,
                quantity: energyQuantity,
                start: startDate,
                end: endDate
            )
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add([energySample]) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if !success {
                        continuation.resume(throwing: NSError(domain: "MockWorkoutInjector", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to add energy samples"]))
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        
        // Add distance if applicable
        if let distance = distance,
           let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distance)
            let distanceSample = HKQuantitySample(
                type: distanceType,
                quantity: distanceQuantity,
                start: startDate,
                end: endDate
            )
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add([distanceSample]) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if !success {
                        continuation.resume(throwing: NSError(domain: "MockWorkoutInjector", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to add distance samples"]))
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        
        // Add mock heart rate data
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let heartRateSamples = generateHeartRateSamples(
                type: heartRateType,
                workoutType: type,
                startDate: startDate,
                duration: duration
            )
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add(heartRateSamples) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if !success {
                        continuation.resume(throwing: NSError(domain: "MockWorkoutInjector", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to add heart rate samples"]))
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        
        // End collection and finish workout
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: endDate) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if !success {
                    continuation.resume(throwing: NSError(domain: "MockWorkoutInjector", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to end collection"]))
                } else {
                    continuation.resume()
                }
            }
        }
        
        let workout = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout, Error>) in
            builder.finishWorkout { workout, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let workout = workout {
                    continuation.resume(returning: workout)
                } else {
                    continuation.resume(throwing: NSError(domain: "MockWorkoutInjector", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to finish workout"]))
                }
            }
        }
        
        return workout
    }
    
    private func generateHeartRateSamples(
        type: HKQuantityType,
        workoutType: HKWorkoutActivityType,
        startDate: Date,
        duration: TimeInterval
    ) -> [HKQuantitySample] {
        
        var samples: [HKQuantitySample] = []
        let sampleInterval: TimeInterval = 5 // Every 5 seconds
        let sampleCount = Int(duration / sampleInterval)
        
        let baseHeartRate: Double
        switch workoutType {
        case .running: baseHeartRate = 140
        case .highIntensityIntervalTraining: baseHeartRate = 150
        case .functionalStrengthTraining: baseHeartRate = 120
        case .yoga: baseHeartRate = 80
        default: baseHeartRate = 100
        }
        
        for i in 0..<sampleCount {
            let timestamp = startDate.addingTimeInterval(Double(i) * sampleInterval)
            let variation = Double.random(in: -10...10)
            let heartRate = baseHeartRate + variation
            
            let quantity = HKQuantity(unit: .count().unitDivided(by: .minute()), doubleValue: heartRate)
            let sample = HKQuantitySample(
                type: type,
                quantity: quantity,
                start: timestamp,
                end: timestamp.addingTimeInterval(sampleInterval)
            )
            
            samples.append(sample)
        }
        
        return samples
    }
}

// MARK: - Quick Actions

extension MockWorkoutInjector {
    
    /// Adds a workout that just finished
    func addJustCompletedWorkout(completion: @escaping (Bool) -> Void = { _ in }) {
        injectWorkout(scenario: .quickTest(duration: 30 * 60), completion: completion)
    }
    
    /// Adds a morning run
    func addMorningRun(completion: @escaping (Bool) -> Void = { _ in }) {
        injectWorkout(scenario: .morningRun, completion: completion)
    }
    
    /// Adds a week of workouts for streak testing
    func addWeekStreak(completion: @escaping (Bool) -> Void = { _ in }) {
        injectWorkout(scenario: .weekStreak, completion: completion)
    }
}

#endif