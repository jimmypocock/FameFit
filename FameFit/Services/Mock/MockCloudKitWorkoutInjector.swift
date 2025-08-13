//
//  MockCloudKitWorkoutInjector.swift
//  FameFit
//
//  Injects mock workouts directly into CloudKit for development testing
//  This bypasses HealthKit entirely and allows both Watch and iPhone to see the same data
//

#if DEBUG

import Foundation
import CloudKit
import Darwin

/// Injects mock workouts directly into CloudKit, bypassing HealthKit
/// This allows both Watch and iPhone apps to see the same test data during development
final class MockCloudKitWorkoutInjector {
    
    static let shared = MockCloudKitWorkoutInjector()
    
    private let database: CKDatabase
    
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
        self.database = CKContainer(identifier: "iCloud.com.jimmypocock.FameFit").privateCloudDatabase
        
        if isEnabled {
            FameFitLogger.info("Mock CloudKit injection enabled", category: FameFitLogger.healthKit)
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
        case watchWorkout(type: String, duration: TimeInterval)
    }
    
    // MARK: - Public Methods
    
    /// Injects a mock workout directly into CloudKit
    func injectWorkout(scenario: Scenario, source: String = "iPhone", completion: @escaping (Bool) -> Void = { _ in }) {
        guard isEnabled else {
            FameFitLogger.debug("Mock injection disabled", category: FameFitLogger.healthKit)
            completion(false)
            return
        }
        
        Task {
            do {
                let record = createWorkoutRecord(for: scenario, source: source)
                
                // Save directly to CloudKit
                let savedRecord = try await database.save(record)
                
                FameFitLogger.info("Injected mock workout to CloudKit: \(savedRecord.recordID.recordName)", category: FameFitLogger.healthKit)
                
                // Post notification so UI updates
                await MainActor.run {
                    NotificationCenter.default.post(name: Notification.Name("WorkoutSyncedToCloudKit"), object: nil)
                    completion(true)
                }
            } catch {
                FameFitLogger.error("Failed to inject mock workout to CloudKit", error: error)
                await MainActor.run {
                    completion(false)
                }
            }
        }
    }
    
    /// Simulates a Watch workout being synced to CloudKit
    func injectWatchWorkout(type: String, duration: TimeInterval, completion: @escaping (Bool) -> Void = { _ in }) {
        injectWorkout(scenario: .watchWorkout(type: type, duration: duration), source: "Watch", completion: completion)
    }
    
    // MARK: - Private Methods
    
    private func createWorkoutRecord(for scenario: Scenario, source: String) -> CKRecord {
        let record = CKRecord(recordType: "Workouts")
        let workoutID = UUID().uuidString
        
        let configuration: (type: String, duration: TimeInterval, distance: Double?, energy: Double, followers: Int)
        
        switch scenario {
        case .quickTest(let duration):
            configuration = ("Running", duration, 100, 5, 1)
            
        case .morningRun:
            configuration = ("Running", 30 * 60, 5000, 300, 25)
            
        case .eveningHIIT:
            configuration = ("HIIT", 25 * 60, nil, 250, 20)
            
        case .strengthTraining:
            configuration = ("Strength Training", 45 * 60, nil, 200, 15)
            
        case .groupWorkout:
            configuration = ("Group Run", 35 * 60, 6000, 350, 50)
            
        case .weekStreak:
            // Create multiple workouts for the week
            for day in 0..<7 {
                let date = Date().addingTimeInterval(-Double(day) * 86400)
                let dailyRecord = CKRecord(recordType: "Workouts")
                dailyRecord["workoutID"] = UUID().uuidString
                dailyRecord["workoutType"] = "Running"
                dailyRecord["startDate"] = date.addingTimeInterval(-30 * 60)
                dailyRecord["endDate"] = date
                dailyRecord["duration"] = 30.0 * 60.0
                dailyRecord["totalEnergyBurned"] = Double.random(in: 200...400)
                dailyRecord["totalDistance"] = Double.random(in: 3000...7000)
                dailyRecord["averageHeartRate"] = Double.random(in: 130...160)
                dailyRecord["followersEarned"] = Int64.random(in: 10...30)
                dailyRecord["source"] = source
                
                Task {
                    try? await database.save(dailyRecord)
                }
            }
            // Configure the main record
            configuration = ("Running", 30 * 60, 5000, 300, 25)
            
        case .watchWorkout(let type, let duration):
            configuration = (type, duration, 
                           type == "Running" ? Double.random(in: 1000...5000) : nil,
                           Double.random(in: 100...400),
                           Int.random(in: 5...30))
        }
        
        // Set record fields
        record["workoutID"] = workoutID
        record["workoutType"] = configuration.type
        record["startDate"] = Date().addingTimeInterval(-configuration.duration - 60)
        record["endDate"] = Date().addingTimeInterval(-60) // Ended 1 minute ago
        record["duration"] = configuration.duration
        record["totalEnergyBurned"] = configuration.energy
        if let distance = configuration.distance {
            record["totalDistance"] = distance
        }
        record["averageHeartRate"] = Double.random(in: 120...170)
        record["followersEarned"] = Int64(configuration.followers)
        record["source"] = source
        
        // Add some variety to the data
        if Bool.random() {
            record["notes"] = "Great workout! Feeling strong 💪"
        }
        
        return record
    }
}

// MARK: - Watch-Specific Extensions

extension MockCloudKitWorkoutInjector {
    
    /// Simulates the Watch app creating and syncing a workout
    func simulateWatchWorkout(
        type: String,
        duration: TimeInterval,
        energy: Double,
        distance: Double? = nil,
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        guard isEnabled else {
            completion(false)
            return
        }
        
        Task {
            do {
                let record = CKRecord(recordType: "Workouts")
                let workoutID = UUID().uuidString
                
                record["workoutID"] = workoutID
                record["workoutType"] = type
                record["startDate"] = Date().addingTimeInterval(-duration - 60)
                record["endDate"] = Date().addingTimeInterval(-60)
                record["duration"] = duration
                record["totalEnergyBurned"] = energy
                if let distance = distance {
                    record["totalDistance"] = distance
                }
                record["averageHeartRate"] = Double.random(in: 120...170)
                record["followersEarned"] = Int64.random(in: 5...30)
                record["source"] = "Watch"
                
                let savedRecord = try await database.save(record)
                
                FameFitLogger.info("Simulated Watch workout synced to CloudKit: \(savedRecord.recordID.recordName)", category: FameFitLogger.healthKit)
                
                // Post notification that mimics what would happen with real WatchConnectivity
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: Notification.Name("WatchWorkoutReceived"),
                        object: nil,
                        userInfo: ["workoutID": workoutID]
                    )
                    completion(true)
                }
            } catch {
                FameFitLogger.error("Failed to simulate Watch workout", error: error)
                await MainActor.run {
                    completion(false)
                }
            }
        }
    }
}

#endif