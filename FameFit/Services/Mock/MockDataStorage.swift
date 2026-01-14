//
//  MockDataStorage.swift
//  FameFit
//
//  Persistent storage for mock data during development
//

#if DEBUG

import Foundation
import HealthKit

/// Manages persistent storage of mock data between app sessions
final class MockDataStorage {
    
    // MARK: - Properties
    
    static let shared = MockDataStorage()
    
    private let userDefaults: UserDefaults
    private let suiteName = "com.jimmypocock.FameFit.MockData"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Keys
    
    private enum StorageKeys {
        static let workouts = "mock.workouts"
        static let lastAnchor = "mock.lastAnchor"
        static let configuration = "mock.configuration"
        static let scheduledWorkouts = "mock.scheduledWorkouts"
        static let activeScenarios = "mock.activeScenarios"
    }
    
    // MARK: - Initialization
    
    private init() {
        // Use a separate UserDefaults suite for mock data
        self.userDefaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        
        // Configure encoder/decoder
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Workout Storage
    
    /// Stores mock workouts persistently
    func saveWorkouts(_ workouts: [HKWorkout]) {
        let workoutData = workouts.compactMap { workout -> MockWorkoutData? in
            MockWorkoutData(from: workout)
        }
        
        do {
            let data = try encoder.encode(workoutData)
            userDefaults.set(data, forKey: StorageKeys.workouts)
            FameFitLogger.debug("Saved \(workouts.count) mock workouts to storage", category: FameFitLogger.system)
        } catch {
            FameFitLogger.error("Failed to save mock workouts", error: error)
        }
    }
    
    /// Loads previously stored mock workouts
    func loadWorkouts() -> [HKWorkout] {
        guard let data = userDefaults.data(forKey: StorageKeys.workouts) else {
            FameFitLogger.debug("No stored mock workouts found", category: FameFitLogger.system)
            return []
        }
        
        do {
            let workoutData = try decoder.decode([MockWorkoutData].self, from: data)
            let workouts = workoutData.compactMap { $0.toHKWorkout() }
            FameFitLogger.debug("Loaded \(workouts.count) mock workouts from storage", category: FameFitLogger.system)
            return workouts
        } catch {
            FameFitLogger.error("Failed to load mock workouts", error: error)
            return []
        }
    }
    
    /// Appends a workout to persistent storage
    func appendWorkout(_ workout: HKWorkout) {
        var workouts = loadWorkouts()
        workouts.append(workout)
        saveWorkouts(workouts)
    }
    
    /// Removes workouts older than the specified date
    func removeWorkoutsOlderThan(_ date: Date) {
        let workouts = loadWorkouts().filter { $0.endDate > date }
        saveWorkouts(workouts)
        FameFitLogger.debug("Removed workouts older than \(date)", category: FameFitLogger.system)
    }
    
    // MARK: - Configuration Storage
    
    /// Stores mock service configuration
    func saveConfiguration(_ config: MockConfiguration) {
        do {
            let data = try encoder.encode(config)
            userDefaults.set(data, forKey: StorageKeys.configuration)
        } catch {
            FameFitLogger.error("Failed to save mock configuration", error: error)
        }
    }
    
    /// Loads mock service configuration
    func loadConfiguration() -> MockConfiguration? {
        guard let data = userDefaults.data(forKey: StorageKeys.configuration) else {
            return nil
        }
        
        do {
            return try decoder.decode(MockConfiguration.self, from: data)
        } catch {
            FameFitLogger.error("Failed to load mock configuration", error: error)
            return nil
        }
    }
    
    // MARK: - Anchor Storage
    
    /// Stores the last query anchor for incremental updates
    func saveLastAnchor(_ anchorData: Data?) {
        userDefaults.set(anchorData, forKey: StorageKeys.lastAnchor)
    }
    
    /// Loads the last query anchor
    func loadLastAnchor() -> Data? {
        userDefaults.data(forKey: StorageKeys.lastAnchor)
    }
    
    // MARK: - Scheduled Workouts
    
    /// Stores scheduled workout scenarios
    func saveScheduledWorkouts(_ schedules: [ScheduledWorkout]) {
        do {
            let data = try encoder.encode(schedules)
            userDefaults.set(data, forKey: StorageKeys.scheduledWorkouts)
        } catch {
            FameFitLogger.error("Failed to save scheduled workouts", error: error)
        }
    }
    
    /// Loads scheduled workout scenarios
    func loadScheduledWorkouts() -> [ScheduledWorkout] {
        guard let data = userDefaults.data(forKey: StorageKeys.scheduledWorkouts) else {
            return []
        }
        
        do {
            return try decoder.decode([ScheduledWorkout].self, from: data)
        } catch {
            FameFitLogger.error("Failed to load scheduled workouts", error: error)
            return []
        }
    }
    
    // MARK: - Active Scenarios
    
    /// Tracks which mock scenarios are currently active
    func setActiveScenarios(_ scenarios: Set<String>) {
        userDefaults.set(Array(scenarios), forKey: StorageKeys.activeScenarios)
    }
    
    /// Gets currently active mock scenarios
    func getActiveScenarios() -> Set<String> {
        let array = userDefaults.stringArray(forKey: StorageKeys.activeScenarios) ?? []
        return Set(array)
    }
    
    // MARK: - Clear Methods
    
    /// Clears all stored mock data
    func clearAll() {
        userDefaults.removeObject(forKey: StorageKeys.workouts)
        userDefaults.removeObject(forKey: StorageKeys.lastAnchor)
        userDefaults.removeObject(forKey: StorageKeys.configuration)
        userDefaults.removeObject(forKey: StorageKeys.scheduledWorkouts)
        userDefaults.removeObject(forKey: StorageKeys.activeScenarios)
        
        FameFitLogger.info("Cleared all mock data storage", category: FameFitLogger.system)
    }
    
    /// Clears only workout data
    func clearWorkouts() {
        userDefaults.removeObject(forKey: StorageKeys.workouts)
        FameFitLogger.info("Cleared mock workout storage", category: FameFitLogger.system)
    }
}

// MARK: - Supporting Types

/// Codable representation of HKWorkout for storage
struct MockWorkoutData: Codable {
    let id: UUID
    let activityType: Int
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let totalEnergyBurned: Double? // in kilocalories
    let totalDistance: Double? // in meters
    let metadata: [String: String]
    let deviceName: String?
    let sourceName: String?
    
    init(from workout: HKWorkout) {
        self.id = workout.uuid
        self.activityType = workout.workoutActivityType.rawValue
        self.startDate = workout.startDate
        self.endDate = workout.endDate
        self.duration = workout.duration
        self.totalEnergyBurned = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        self.totalDistance = workout.totalDistance?.doubleValue(for: .meter())
        
        // Convert metadata to string representation
        var stringMetadata: [String: String] = [:]
        if let metadata = workout.metadata {
            for (key, value) in metadata {
                stringMetadata[key] = String(describing: value)
            }
        }
        self.metadata = stringMetadata
        
        self.deviceName = workout.device?.name
        self.sourceName = workout.sourceRevision?.source.name
    }
    
    func toHKWorkout() -> HKWorkout? {
        let activityType = HKWorkoutActivityType(rawValue: UInt(activityType)) ?? .other
        
        let energyBurned = totalEnergyBurned.map {
            HKQuantity(unit: .kilocalorie(), doubleValue: $0)
        }
        
        let distance = totalDistance.map {
            HKQuantity(unit: .meter(), doubleValue: $0)
        }
        
        // Convert string metadata back to original types
        var convertedMetadata: [String: Any] = [:]
        for (key, value) in metadata {
            // Try to convert back to appropriate types
            if let boolValue = Bool(value) {
                convertedMetadata[key] = boolValue
            } else if let intValue = Int(value) {
                convertedMetadata[key] = intValue
            } else if let doubleValue = Double(value) {
                convertedMetadata[key] = doubleValue
            } else {
                convertedMetadata[key] = value
            }
        }
        
        return HKWorkout(
            activityType: activityType,
            start: startDate,
            end: endDate,
            duration: duration,
            totalEnergyBurned: energyBurned,
            totalDistance: distance,
            metadata: convertedMetadata.isEmpty ? nil : convertedMetadata
        )
    }
}

/// Configuration for mock service behavior
struct MockConfiguration: Codable {
    var autoGenerateWorkouts: Bool = false
    var generationInterval: TimeInterval = 3600 // 1 hour
    var defaultIntensity: Double = 0.7
    var defaultWorkoutType: Int = HKWorkoutActivityType.running.rawValue
    var enableBackgroundGeneration: Bool = false
    var maxStoredWorkouts: Int = 100
}

/// Scheduled workout for automatic generation
struct ScheduledWorkout: Codable {
    let id: UUID
    let scheduledDate: Date
    let scenarioName: String
    let isRecurring: Bool
    let recurrenceInterval: TimeInterval?
    
    init(
        scheduledDate: Date,
        scenarioName: String,
        isRecurring: Bool = false,
        recurrenceInterval: TimeInterval? = nil
    ) {
        self.id = UUID()
        self.scheduledDate = scheduledDate
        self.scenarioName = scenarioName
        self.isRecurring = isRecurring
        self.recurrenceInterval = recurrenceInterval
    }
}

#endif